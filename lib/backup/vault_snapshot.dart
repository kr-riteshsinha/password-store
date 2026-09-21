import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../crypto/vault_keys.dart';

/// A sealed copy of the whole vault, ready to be written to the user's own
/// storage (`docs/sync-design.md` §5.1).
///
/// The bytes on disk are:
///
/// ```
/// "PVSNAP" | version (1 byte) | nonce (12) | ciphertext | tag (16)
/// ```
///
/// The magic and version are in the clear so a file can be recognised, and
/// refused, without the key. Everything else is AES-GCM under the vault key,
/// which also means a tampered or truncated snapshot fails to open rather
/// than restoring something subtly wrong.
class VaultSnapshot {
  /// Marks the file as ours. Six bytes, so the header stays short.
  static final Uint8List magic = Uint8List.fromList(utf8.encode('PVSNAP'));

  /// The format this app writes. A file claiming a newer one is refused:
  /// restoring a format we don't understand is how vaults get mangled.
  static const currentVersion = 1;

  static final _aes = AesGcm.with256bits();

  /// Seals [database] — the bytes of an encrypted database copy — under
  /// [vaultKey].
  static Future<Uint8List> seal(
    Uint8List database,
    Uint8List vaultKey, {
    /// Only tests pass this, to produce a file as a future version would.
    int version = currentVersion,
  }) async {
    final header = Uint8List.fromList([...magic, version]);
    final box = await _aes.encrypt(
      database,
      secretKey: SecretKey(vaultKey),
      nonce: randomBytes(nonceLengthBytes),
      // The header is authenticated, not encrypted. Without this, flipping
      // the version byte in a stored backup would turn every restore into
      // "written by a newer version" — an undetectable way to deny someone
      // their only copy.
      aad: header,
    );

    final out = BytesBuilder(copy: false)
      ..add(header)
      ..add(box.nonce)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    return out.toBytes();
  }

  /// Opens a sealed snapshot, or throws [SnapshotException] if it is not one
  /// of ours, is from a newer version, has been tampered with, or the key is
  /// wrong.
  static Future<Uint8List> open(Uint8List file, Uint8List vaultKey) async {
    const headerLength = 7; // magic + version
    const macLength = 16;

    // Identify the file before judging its length, so someone restoring the
    // wrong file is told what it is rather than that it is "too short".
    if (!looksLikeSnapshot(file)) {
      throw const SnapshotException('This file is not a Password Vault backup.');
    }
    if (file.length < headerLength + nonceLengthBytes + macLength) {
      throw const SnapshotException('This backup is incomplete.');
    }

    final nonce = file.sublist(headerLength, headerLength + nonceLengthBytes);
    final mac = file.sublist(file.length - macLength);
    final cipherText = file.sublist(headerLength + nonceLengthBytes, file.length - macLength);

    // Decrypt first, then judge the version. The header is authenticated, so
    // this tells apart "genuinely written by a newer build" from "someone
    // edited the version byte" — the latter would otherwise be an
    // undetectable way to make every restore refuse.
    final Uint8List clear;
    try {
      final decrypted = await _aes.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: SecretKey(vaultKey),
        aad: file.sublist(0, headerLength),
      );
      clear = Uint8List.fromList(decrypted);
    } on SecretBoxAuthenticationError {
      throw const SnapshotException(
        'This backup could not be opened: it was changed after it was '
        'written, or it belongs to a different vault.',
      );
    }

    final version = file[magic.length];
    if (version > currentVersion) {
      throw SnapshotException(
        'This backup was written by a newer version of the app '
        '(format $version). Update before restoring it.',
      );
    }

    return clear;
  }

  /// Whether [file] looks like one of our snapshots, without needing the key.
  static bool looksLikeSnapshot(Uint8List file) {
    if (file.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (file[i] != magic[i]) return false;
    }
    return true;
  }

  /// The name a snapshot taken at [time] is stored under. Sortable, and
  /// readable enough to recognise in a file listing.
  /// Milliseconds are kept: "Back up now" tapped twice in the same second
  /// must not overwrite the earlier snapshot.
  static String fileNameFor(DateTime time) {
    final stamp = time.toUtc().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    return 'vault-$stamp.bin';
  }

  /// The time a snapshot was taken, read back from [fileName], or null if the
  /// name is not one of ours.
  static DateTime? timeOf(String fileName) {
    final match = RegExp(r'^vault-(.+)\.bin$').firstMatch(fileName);
    if (match == null) return null;
    // vault-2026-10-03T14-02-30-123Z.bin -> 2026-10-03T14:02:30.123Z
    final match2 = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2})-(\d{2})-(\d{2})-(\d{3})Z$',
    ).firstMatch(match.group(1)!);
    if (match2 == null) return null;
    final g = match2.groups([1, 2, 3, 4, 5, 6, 7]).map((e) => e!).toList();
    // Parsed as UTC explicitly: without the Z this would be read as local
    // time and every timestamp would shift by the time zone offset.
    return DateTime.tryParse(
      '${g[0]}-${g[1]}-${g[2]}T${g[3]}:${g[4]}:${g[5]}.${g[6]}Z',
    );
  }
}

class SnapshotException implements Exception {
  final String message;
  const SnapshotException(this.message);
  @override
  String toString() => message;
}
