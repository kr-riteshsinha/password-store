import 'package:archinfotech/provider/db_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_database.dart';

/// Simulates an existing install on schema v1 (no `profile` table) being
/// opened by the current app. This file must stay separate: DbHelper opens its
/// database once per test isolate.
void main() {
  setUpAll(() async {
    await initTestDatabase();

    final path = p.join(await databaseFactory.getDatabasesPath(), 'logins.db');
    final v1 = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) => db.execute('''
          CREATE TABLE login_entries (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            username TEXT NOT NULL,
            password TEXT NOT NULL,
            website TEXT NOT NULL,
            totpSecret TEXT
          )
        '''),
      ),
    );
    await v1.insert('login_entries', {
      'id': '1',
      'title': 'GitHub',
      'username': 'octocat',
      'password': 'pw',
      'website': 'https://github.com',
      'totpSecret': null,
    });
    await v1.close();
  });

  test('upgrading from v1 keeps saved logins and adds the profile table', () async {
    final entries = await DbHelper.instance.fetchEntries();
    expect(entries.map((e) => e.title), ['GitHub']);

    expect(await DbHelper.instance.fetchProfileEntries(), isEmpty);
  });
}
