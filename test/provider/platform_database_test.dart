import 'dart:io';

import 'package:archinfotech/provider/db_helper.dart';
import 'package:archinfotech/provider/platform_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_database.dart';

void main() {
  final db = DbHelper.instance;

  setUpAll(initEncryptedTestDatabase);
  setUp(resetVault);
  tearDownAll(resetVault);

  test('usesFfiDatabase is true exactly on Windows and Linux', () {
    expect(usesFfiDatabase, Platform.isWindows || Platform.isLinux);
  });

  test('initPlatformDatabase does nothing on plugin platforms', () async {
    // Deliberately not exercised on Windows or Linux: there it would replace
    // the factory and temp database path the harness installed, and the
    // default factory runs SQLite in a background isolate where the
    // SQLCipher override does not apply.
    if (usesFfiDatabase) return;

    final before = databaseFactory;
    await initPlatformDatabase();

    expect(databaseFactory, same(before));
  });

  test('assertSqlCipher passes for a vault opened with a key', () async {
    await openTestVault();

    await expectLater(assertSqlCipher(await db.database), completes);
  });

  test('opening the vault checks that SQLCipher is in use', () async {
    // openEncrypted runs the same assertion, so a build that shipped plain
    // SQLite would fail here rather than silently write a plaintext vault.
    await openTestVault();

    final rows = await (await db.database).rawQuery('PRAGMA cipher_version');

    expect(rows, isNotEmpty);
    expect(rows.first.values.first.toString(), isNotEmpty);
  });
}
