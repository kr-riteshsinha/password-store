import 'dart:io';

import 'package:archinfotech/crypto/vault_keys.dart';
import 'package:archinfotech/provider/db_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_database.dart';

/// Simulates the vault shipped before backup existed — schema v3, with no
/// change tracking — being opened by the current app. This file must stay
/// separate: DbHelper holds one open database per test isolate.
void main() {
  setUpAll(() async {
    await initEncryptedTestDatabase();

    final path = p.join(await databaseFactory.getDatabasesPath(), 'logins.db');
    final passphrase = VaultKeys.toPassphrase(testDatabaseKey);
    final v3 = await databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onConfigure: (db) => db.execute("PRAGMA key = '$passphrase'"),
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE login_entries (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              username TEXT NOT NULL,
              password TEXT NOT NULL,
              website TEXT NOT NULL,
              totpSecret TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE profile (id TEXT PRIMARY KEY, name TEXT NOT NULL)
          ''');
        },
      ),
    );
    await v3.insert('login_entries', {
      'id': '1',
      'title': 'GitHub',
      'username': 'octocat',
      'password': 'correct-horse-battery-staple',
      'website': 'https://github.com',
      'totpSecret': 'JBSWY3DPEHPK3PXP',
    });
    await v3.insert('profile', {'id': 'p1', 'name': 'ritesh'});
    await v3.close();
  });

  test('upgrading from v3 keeps the entries and the profile', () async {
    await openTestVault();

    final entry = (await DbHelper.instance.fetchEntries()).single;
    expect(entry.title, 'GitHub');
    expect(entry.password, 'correct-horse-battery-staple');
    expect(entry.totpSecret, 'JBSWY3DPEHPK3PXP');
    expect((await DbHelper.instance.fetchVaultProfile())?.name, 'ritesh');
  });

  test('upgrading adds the change-tracking columns', () async {
    await openTestVault();

    final columns = await (await DbHelper.instance.database)
        .rawQuery('PRAGMA table_info(login_entries)');

    expect(
      columns.map((c) => c['name']),
      containsAll(['updatedAt', 'deletedAt', 'revision', 'deviceId']),
    );
  });

  test('existing entries are backfilled as "no history known"', () async {
    await openTestVault();

    final entry = (await DbHelper.instance.fetchEntries()).single;
    expect(entry.revision, 1);
    expect(entry.deletedAt, isNull);
    expect(entry.deviceId, isEmpty, reason: 'no device is known to have written it');
    // Deliberately 0, not the upgrade time: stamping "now" would give the
    // same entry a different timestamp on every device that upgrades, and
    // merging would then be decided by who upgraded last.
    expect(entry.updatedAt, 0);
  });

  test('the upgraded vault is still encrypted', () async {
    // Checked before anything deletes the entry: a soft delete clears the
    // password, so this assertion would otherwise pass against a plaintext
    // file simply because the string was gone.
    await openTestVault();
    expect(
      (await DbHelper.instance.fetchEntries()).single.password,
      'correct-horse-battery-staple',
      reason: 'the plaintext must still be in the vault for this to mean anything',
    );
    await DbHelper.instance.close();

    final bytes = await File(await DbHelper.instance.databaseFile()).readAsBytes();
    final text = String.fromCharCodes(bytes.where((b) => b >= 32 && b < 127));

    expect(text, isNot(contains('correct-horse-battery-staple')));
    expect(text, isNot(contains('octocat')));
    expect(text, isNot(startsWith('SQLite format 3')));
  });

  test('an upgraded entry can then be deleted and leaves a tombstone', () async {
    await openTestVault();
    DbHelper.deviceId = 'device-a';

    await DbHelper.instance.deleteEntry('1');

    expect(await DbHelper.instance.fetchEntries(), isEmpty);
    expect((await DbHelper.instance.fetchTombstones()).single.id, '1');
    DbHelper.deviceId = '';
  });

}
