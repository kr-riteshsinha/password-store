import 'dart:io';
import 'dart:typed_data';

import 'package:archinfotech/crypto/vault_keys.dart';
import 'package:archinfotech/crypto/vault_meta.dart';
import 'package:archinfotech/models/login_entry.dart';
import 'package:archinfotech/provider/db_helper.dart';
import 'package:flutter_test/flutter_test.dart';

import '../crypto/vault_keys_test.dart' show cheapParams;
import '../helpers/test_database.dart';

LoginEntry _entry(String id) => LoginEntry(
      id: id,
      title: 'GitHub',
      username: 'octocat',
      password: 'correct-horse-battery-staple',
      website: 'https://github.com',
      totpSecret: 'JBSWY3DPEHPK3PXP',
    );

void main() {
  final db = DbHelper.instance;
  late Uint8List key;

  setUpAll(initEncryptedTestDatabase);

  setUp(() async {
    await db.close();
    final path = await db.databaseFile();
    if (File(path).existsSync()) File(path).deleteSync();
    key = VaultKeys.newDatabaseKey();
  });

  tearDownAll(() => db.close());

  test('an encrypted vault stores and reads entries', () async {
    await db.openEncrypted(key);

    await db.insertEntry(_entry('1'));

    expect((await db.fetchEntries()).single.password, 'correct-horse-battery-staple');
  });

  test('the database file holds no readable passwords', () async {
    await db.openEncrypted(key);
    await db.insertEntry(_entry('1'));
    await db.close();

    final bytes = await File(await db.databaseFile()).readAsBytes();
    final text = String.fromCharCodes(bytes.where((b) => b >= 32 && b < 127));

    expect(text, isNot(contains('correct-horse-battery-staple')));
    expect(text, isNot(contains('octocat')));
    expect(text, isNot(contains('JBSWY3DPEHPK3PXP')));
    // Not even the schema is readable, unlike a plain SQLite file.
    expect(text, isNot(contains('CREATE TABLE')));
    expect(text, isNot(startsWith('SQLite format 3')));
  });

  test('the vault does not open with the wrong key', () async {
    await db.openEncrypted(key);
    await db.insertEntry(_entry('1'));
    await db.close();

    await expectLater(
      () async {
        await db.openEncrypted(VaultKeys.newDatabaseKey());
        await db.fetchEntries();
      }(),
      throwsA(anything),
    );
  });

  test('the vault reopens with the same key', () async {
    await db.openEncrypted(key);
    await db.insertEntry(_entry('1'));
    await db.close();

    await db.openEncrypted(key);

    expect((await db.fetchEntries()).single.id, '1');
  });

  test('using the vault while locked is refused', () async {
    await db.close();

    expect(db.isOpen, isFalse);
    expect(db.fetchEntries(), throwsStateError);
  });

  test('the key from the metadata file opens the vault', () async {
    // The whole unlock path: create keys, store them, unwrap with the
    // passcode, open the vault with what comes back.
    final created = await createVaultKeys(
      passcode: '1234',
      recoveryAnswer: 'Blue',
      newParams: cheapParams,
    );
    final store = VaultMetaStore(await db.vaultDirectory());
    await store.write(created.meta);

    await db.openEncrypted(created.databaseKey);
    await db.insertEntry(_entry('1'));
    await db.close();

    final meta = await store.read();
    final unlocked = await unlockWithPasscode(meta!, '1234');
    await db.openEncrypted(unlocked!);

    expect((await db.fetchEntries()).single.id, '1');
  });

  test('a recovered key opens the same vault', () async {
    final created = await createVaultKeys(
      passcode: '1234',
      recoveryAnswer: 'Blue',
      newParams: cheapParams,
    );
    await db.openEncrypted(created.databaseKey);
    await db.insertEntry(_entry('1'));
    await db.close();

    final recovered = await unlockWithRecoveryAnswer(created.meta, 'blue');
    await db.openEncrypted(recovered!);

    expect((await db.fetchEntries()).single.id, '1');
  });
}
