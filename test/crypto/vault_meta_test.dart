import 'dart:convert';
import 'dart:io';

import 'package:archinfotech/crypto/vault_meta.dart';
import 'package:flutter_test/flutter_test.dart';

import 'vault_keys_test.dart' show cheapParams;

void main() {
  late Directory dir;
  late VaultMetaStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('vault_meta_test_');
    store = VaultMetaStore(dir.path);
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<NewVaultKeys> create({String passcode = '1234', String? answer = 'Blue'}) =>
      createVaultKeys(
        passcode: passcode,
        recoveryAnswer: answer,
        newParams: cheapParams,
      );

  group('createVaultKeys', () {
    test('seals the same database key under the passcode and the answer', () async {
      final created = await create();

      expect(await unlockWithPasscode(created.meta, '1234'), created.databaseKey);
      expect(
        await unlockWithRecoveryAnswer(created.meta, 'Blue'),
        created.databaseKey,
      );
    });

    test('gives the passcode and the answer separate salts', () async {
      final created = await create();

      expect(created.meta.passcodeKdf.salt, isNot(created.meta.recoveryKdf!.salt));
    });

    test('generates a different database key for each vault', () async {
      expect((await create()).databaseKey, isNot((await create()).databaseKey));
    });

    test('leaves recovery unset when no answer is given', () async {
      final created = await create(answer: null);

      expect(created.meta.hasRecovery, isFalse);
      expect(await unlockWithRecoveryAnswer(created.meta, 'Blue'), isNull);
    });
  });

  group('unlocking', () {
    test('a wrong passcode returns null', () async {
      final created = await create();

      expect(await unlockWithPasscode(created.meta, '9999'), isNull);
    });

    test('the answer is matched ignoring case and spaces', () async {
      final created = await create();

      expect(
        await unlockWithRecoveryAnswer(created.meta, '  bLUE  '),
        created.databaseKey,
      );
    });

    test('a wrong or empty answer returns null', () async {
      final created = await create();

      expect(await unlockWithRecoveryAnswer(created.meta, 'Red'), isNull);
      expect(await unlockWithRecoveryAnswer(created.meta, '   '), isNull);
    });
  });

  group('rewrapWithPasscode', () {
    test('opens with the new passcode and not the old one', () async {
      final created = await create();

      final updated = await rewrapWithPasscode(
        created.meta,
        created.databaseKey,
        '5678',
        newParams: cheapParams,
      );

      expect(await unlockWithPasscode(updated, '5678'), created.databaseKey);
      expect(await unlockWithPasscode(updated, '1234'), isNull);
    });

    test('keeps the database key, so the vault is not re-encrypted', () async {
      final created = await create();

      final updated = await rewrapWithPasscode(
        created.meta,
        created.databaseKey,
        '5678',
        newParams: cheapParams,
      );

      expect(await unlockWithPasscode(updated, '5678'), created.databaseKey);
    });

    test('leaves recovery working with the same answer', () async {
      final created = await create();

      final updated = await rewrapWithPasscode(
        created.meta,
        created.databaseKey,
        '5678',
        newParams: cheapParams,
      );

      expect(
        await unlockWithRecoveryAnswer(updated, 'Blue'),
        created.databaseKey,
      );
    });

    test('uses a fresh salt for the new passcode', () async {
      final created = await create();

      final updated = await rewrapWithPasscode(
        created.meta,
        created.databaseKey,
        '5678',
        newParams: cheapParams,
      );

      expect(updated.passcodeKdf.salt, isNot(created.meta.passcodeKdf.salt));
    });
  });

  group('VaultMetaStore', () {
    test('read returns null before a vault exists', () async {
      expect(await store.exists(), isFalse);
      expect(await store.read(), isNull);
    });

    test('a written vault still unlocks after being read back', () async {
      final created = await create();

      await store.write(created.meta);
      final restored = await store.read();

      expect(await unlockWithPasscode(restored!, '1234'), created.databaseKey);
      expect(await unlockWithRecoveryAnswer(restored, 'Blue'), created.databaseKey);
    });

    test('the file holds no passcode, answer or bare key', () async {
      final created = await create(passcode: 'hunter2', answer: 'Blue');
      await store.write(created.meta);

      final text = await store.file.readAsString();
      final json = jsonDecode(text) as Map<String, dynamic>;

      expect(text, isNot(contains('hunter2')));
      expect(text.toLowerCase(), isNot(contains('blue')));
      expect(text, isNot(contains(base64Encode(created.databaseKey))));
      expect(json.keys, containsAll(['version', 'passcodeKdf', 'passcodeWrap']));
    });

    test('writing again replaces the file in one step', () async {
      final created = await create();
      await store.write(created.meta);
      await store.write(created.meta);

      expect(
        await Directory(store.directory).list().map((e) => e.path.split('/').last).toList(),
        [VaultMetaStore.fileName],
      );
    });

    test('a vault from a newer app version is refused', () async {
      final created = await create();
      final json = created.meta.toJson()..['version'] = VaultMeta.currentVersion + 1;
      await store.file.writeAsString(jsonEncode(json));

      expect(store.read(), throwsA(isA<VaultMetaException>()));
    });

    test('a corrupt file is refused rather than read as an empty vault', () async {
      await store.file.writeAsString('{not json');

      expect(store.read(), throwsA(isA<VaultMetaException>()));
    });
  });
}
