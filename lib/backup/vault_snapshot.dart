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
  static Future<Uint8List> seal(Uint8List database, Uint8List vaultKey) async {
    final box = await _aes.encrypt(
      database,
      secretKey: SecretKey(vaultKey),
      nonce: randomBytes(nonceLengthBytes),
    );

    final out = BytesBuilder(copy: false)
      ..add(magic)
      ..addByte(currentVersion)
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

    final version = file[magic.length];
    if (version > currentVersion) {
      throw SnapshotException(
        'This backup was written by a newer version of the app '
        '(format $version). Update before restoring it.',
      );
    }

    final nonce = file.sublist(headerLength, headerLength + nonceLengthBytes);
    final mac = file.sublist(file.length - macLength);
    final cipherText = file.sublist(headerLength + nonceLengthBytes, file.length - macLength);

    try {
      final clear = await _aes.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: SecretKey(vaultKey),
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const SnapshotException(
        'This backup could not be opened: it was changed after it was '
        'written, or it belongs to a different vault.',
      );
    }
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
  static String fileNameFor(DateTime time) {
    final stamp = time.toUtc().toIso8601String().replaceAll(':', '-').split('.').first;
    return 'vault-$stamp.bin';
  }

  /// The time a snapshot was taken, read back from [fileName], or null if the
  /// name is not one of ours.
  static DateTime? timeOf(String fileName) {
    final match = RegExp(r'^vault-(.+)\.bin$').firstMatch(fileName);
    if (match == null) return null;
    final text = match.group(1)!.replaceAll('-', ':');
    // The date's own dashes were turned into colons too; put them back.
    final fixed = text.replaceFirstMapped(
      RegExp(r'^(\d{4}):(\d{2}):(\d{2})'),
      (m) => '${m[1]}-${m[2]}-${m[3]}',
    );
    // Snapshots are named in UTC; without the Z this would be read as local
    // time and every timestamp would shift by the time zone offset.
    return DateTime.tryParse('${fixed}Z');
  }
}

class SnapshotException implements Exception {
  final String message;
  const SnapshotException(this.message);
  @override
  String toString() => message;
}
