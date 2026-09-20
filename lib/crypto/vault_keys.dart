import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:hashlib/hashlib.dart';

/// Length of the database key and of every key-encryption key, in bytes.
const keyLengthBytes = 32;

/// Length of the Argon2id salt, in bytes.
const saltLengthBytes = 16;

/// Length of the AES-GCM nonce, in bytes.
const nonceLengthBytes = 12;

final _random = Random.secure();

/// Cryptographically secure random bytes.
Uint8List randomBytes(int length) {
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = _random.nextInt(256);
  }
  return bytes;
}

/// Argon2id settings, stored alongside the vault so the same key can be
/// derived again later, and so the cost can be raised in a future version
/// without locking anyone out.
class KdfParams {
  final Uint8List salt;
  final int memoryKiB;
  final int iterations;
  final int parallelism;

  const KdfParams({
    required this.salt,
    required this.memoryKiB,
    required this.iterations,
    required this.parallelism,
  });

  /// OWASP's first recommended Argon2id setting (46 MiB, t=1, p=1).
  factory KdfParams.generate() => KdfParams(
        salt: randomBytes(saltLengthBytes),
        memoryKiB: 47104,
        iterations: 1,
        parallelism: 1,
      );

  Map<String, dynamic> toJson() => {
        'salt': base64Encode(salt),
        'memoryKiB': memoryKiB,
        'iterations': iterations,
        'parallelism': parallelism,
      };

  factory KdfParams.fromJson(Map<String, dynamic> json) => KdfParams(
        salt: base64Decode(json['salt'] as String),
        memoryKiB: json['memoryKiB'] as int,
        iterations: json['iterations'] as int,
        parallelism: json['parallelism'] as int,
      );
}

/// A key sealed with AES-GCM. The tag makes a wrong passcode fail to unwrap,
/// which is how the app checks a passcode without storing one.
class WrappedKey {
  final Uint8List nonce;
  final Uint8List cipherText;
  final Uint8List mac;

  const WrappedKey({
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });

  Map<String, dynamic> toJson() => {
        'nonce': base64Encode(nonce),
        'cipherText': base64Encode(cipherText),
        'mac': base64Encode(mac),
      };

  factory WrappedKey.fromJson(Map<String, dynamic> json) => WrappedKey(
        nonce: base64Decode(json['nonce'] as String),
        cipherText: base64Decode(json['cipherText'] as String),
        mac: base64Decode(json['mac'] as String),
      );
}

/// Derives key-encryption keys from what the user knows, and wraps or unwraps
/// the database key with them.
///
/// The database key itself is random and never derived from the passcode, so
/// changing the passcode rewraps one key instead of re-encrypting the vault.
class VaultKeys {
  static final _aes = AesGcm.with256bits();

  /// Derives a key-encryption key from a passcode or recovery answer.
  /// Blocking and deliberately slow; call it off the UI thread.
  static Uint8List deriveKek(String secret, KdfParams params) {
    final digest = Argon2(
      salt: params.salt,
      type: Argon2Type.argon2id,
      hashLength: keyLengthBytes,
      iterations: params.iterations,
      parallelism: params.parallelism,
      memorySizeKB: params.memoryKiB,
    ).convert(utf8.encode(secret));
    return Uint8List.fromList(digest.bytes);
  }

  /// Seals [key] with [kek].
  static Future<WrappedKey> wrap(Uint8List key, Uint8List kek) async {
    final nonce = randomBytes(nonceLengthBytes);
    final box = await _aes.encrypt(
      key,
      secretKey: SecretKey(kek),
      nonce: nonce,
    );
    return WrappedKey(
      nonce: Uint8List.fromList(box.nonce),
      cipherText: Uint8List.fromList(box.cipherText),
      mac: Uint8List.fromList(box.mac.bytes),
    );
  }

  /// Opens [wrapped] with [kek], or returns null if [kek] is wrong or the
  /// stored bytes have been tampered with.
  static Future<Uint8List?> unwrap(WrappedKey wrapped, Uint8List kek) async {
    try {
      final clear = await _aes.decrypt(
        SecretBox(wrapped.cipherText, nonce: wrapped.nonce, mac: Mac(wrapped.mac)),
        secretKey: SecretKey(kek),
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      return null;
    }
  }

  /// A new random database key.
  static Uint8List newDatabaseKey() => randomBytes(keyLengthBytes);

  /// The database key as hex, which is what gets handed to SQLCipher.
  ///
  /// sqflite_sqlcipher takes a *passphrase*, not a raw `x'<hex>'` key, so
  /// SQLCipher runs its own PBKDF2 over this string. That is harmless: the
  /// input already has 256 bits of entropy, and passing hex keeps the app and
  /// the host tests deriving the same key.
  static String toPassphrase(Uint8List databaseKey) =>
      databaseKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
