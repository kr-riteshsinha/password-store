import 'dart:io';

import 'package:archinfotech/crypto/vault_keys.dart';
import 'package:archinfotech/provider/db_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_database.dart';

/// Simulates an encrypted vault on schema v2, where the profile row still
/// carried the passcode, recovery question and answer, being opened by the
/// current app. This file must stay separate: DbHelper holds one open
/// database per test isolate.
void main() {
  setUpAll(() async {
    await initEncryptedTestDatabase();

    final path = p.join(await databaseFactory.getDatabasesPath(), 'logins.db');
    final passphrase = VaultKeys.toPassphrase(testDatabaseKey);
    final v2 = await databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
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
            CREATE TABLE profile (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              password TEXT NOT NULL,
              hint TEXT NOT NULL,
              answer TEXT
            )
          ''');
        },
      ),
    );
    await v2.insert('login_entries', {
      'id': '1',
      'title': 'GitHub',
      'username': 'octocat',
      'password': 'pw',
      'website': 'https://github.com',
      'totpSecret': null,
    });
    await v2.insert('profile', {
      'id': 'p1',
      'name': 'ritesh',
      'password': '1234',
      'hint': 'Favorite color?',
      'answer': 'Blue',
    });
    await v2.close();
  });

  test('upgrading from v2 keeps the logins and the profile name', () async {
    await openTestVault();

    expect((await DbHelper.instance.fetchEntries()).map((e) => e.title), ['GitHub']);
    expect((await DbHelper.instance.fetchVaultProfile())?.name, 'ritesh');
  });

  test('upgrading from v2 drops the passcode, question and answer columns', () async {
    await openTestVault();

    final columns = await (await DbHelper.instance.database)
        .rawQuery('PRAGMA table_info(profile)');

    expect(columns.map((c) => c['name']), ['id', 'name']);
  });

  test('the upgraded vault is still encrypted', () async {
    await openTestVault();
    await DbHelper.instance.close();

    final bytes = await File(await DbHelper.instance.databaseFile()).readAsBytes();
    final text = String.fromCharCodes(bytes.where((b) => b >= 32 && b < 127));

    expect(text, isNot(contains('octocat')));
    expect(text, isNot(startsWith('SQLite format 3')));
  });
}
