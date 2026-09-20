import 'dart:typed_data';

import 'package:archinfotech/crypto/vault_keys.dart';
import 'package:flutter_test/flutter_test.dart';

/// Argon2id at its real cost takes ~0.3s per call, which would make these
/// tests crawl. The algorithm under test is the same either way.
KdfParams cheapParams({Uint8List? salt}) => KdfParams(
      salt: salt ?? randomBytes(saltLengthBytes),
      memoryKiB: 64,
      iterations: 1,
      parallelism: 1,
    );

void main() {
  group('randomBytes', () {
    test('returns the requested length and differs each time', () {
      final a = randomBytes(32);
      final b = randomBytes(32);

      expect(a, hasLength(32));
      expect(a, isNot(equals(b)));
    });
  });

  group('deriveKek', () {
    test('is deterministic for the same secret and params', () {
      final params = cheapParams();

      expect(VaultKeys.deriveKek('1234', params), VaultKeys.deriveKek('1234', params));
    });

    test('returns a 32-byte key', () {
      expect(VaultKeys.deriveKek('1234', cheapParams()), hasLength(keyLengthBytes));
    });

    test('differs for a different secret', () {
      final params = cheapParams();

      expect(
        VaultKeys.deriveKek('1234', params),
        isNot(equals(VaultKeys.deriveKek('1235', params))),
      );
    });

    test('differs for the same secret under a different salt', () {
      expect(
        VaultKeys.deriveKek('1234', cheapParams()),
        isNot(equals(VaultKeys.deriveKek('1234', cheapParams()))),
      );
    });
  });

  group('wrap and unwrap', () {
    test('round-trips the database key', () async {
      final key = VaultKeys.newDatabaseKey();
      final kek = VaultKeys.deriveKek('1234', cheapParams());

      expect(await VaultKeys.unwrap(await VaultKeys.wrap(key, kek), kek), key);
    });

    test('returns null for the wrong key-encryption key', () async {
      final params = cheapParams();
      final wrapped = await VaultKeys.wrap(
        VaultKeys.newDatabaseKey(),
        VaultKeys.deriveKek('1234', params),
      );

      expect(await VaultKeys.unwrap(wrapped, VaultKeys.deriveKek('9999', params)), isNull);
    });

    test('returns null when the sealed bytes are tampered with', () async {
      final kek = VaultKeys.deriveKek('1234', cheapParams());
      final wrapped = await VaultKeys.wrap(VaultKeys.newDatabaseKey(), kek);
      final flipped = Uint8List.fromList(wrapped.cipherText)..[0] ^= 0xff;

      final tampered = WrappedKey(
        nonce: wrapped.nonce,
        cipherText: flipped,
        mac: wrapped.mac,
      );

      expect(await VaultKeys.unwrap(tampered, kek), isNull);
    });

    test('never stores the key in the clear', () async {
      final key = VaultKeys.newDatabaseKey();
      final wrapped = await VaultKeys.wrap(key, VaultKeys.deriveKek('1234', cheapParams()));

      expect(wrapped.cipherText, isNot(equals(key)));
      expect(wrapped.nonce, hasLength(nonceLengthBytes));
    });

    test('uses a fresh nonce for each wrapping', () async {
      final key = VaultKeys.newDatabaseKey();
      final kek = VaultKeys.deriveKek('1234', cheapParams());

      final first = await VaultKeys.wrap(key, kek);
      final second = await VaultKeys.wrap(key, kek);

      expect(first.nonce, isNot(equals(second.nonce)));
      expect(first.cipherText, isNot(equals(second.cipherText)));
    });
  });

  group('toPassphrase', () {
    test('formats the key as lowercase hex', () {
      final key = Uint8List.fromList([0x00, 0x0f, 0xff, 0xa9]);

      expect(VaultKeys.toPassphrase(key), '000fffa9');
    });

    test('is 64 hex digits for a 32-byte key', () {
      expect(
        VaultKeys.toPassphrase(VaultKeys.newDatabaseKey()),
        matches(RegExp(r'^[0-9a-f]{64}$')),
      );
    });
  });

  group('serialisation', () {
    test('KdfParams round-trips through JSON', () {
      final params = cheapParams();

      final restored = KdfParams.fromJson(params.toJson());

      expect(restored.salt, params.salt);
      expect(restored.memoryKiB, params.memoryKiB);
      expect(restored.iterations, params.iterations);
      expect(restored.parallelism, params.parallelism);
    });

    test('a restored WrappedKey still unwraps', () async {
      final key = VaultKeys.newDatabaseKey();
      final kek = VaultKeys.deriveKek('1234', cheapParams());
      final wrapped = await VaultKeys.wrap(key, kek);

      expect(await VaultKeys.unwrap(WrappedKey.fromJson(wrapped.toJson()), kek), key);
    });

    test('generated params use OWASP settings and a 16-byte salt', () {
      final params = KdfParams.generate();

      expect(params.salt, hasLength(saltLengthBytes));
      expect(params.memoryKiB, 47104);
      expect(params.iterations, 1);
      expect(params.parallelism, 1);
    });
  });
}
