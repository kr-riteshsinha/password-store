import 'dart:io';

import 'package:archinfotech/provider/db_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Switches sqflite to its FFI (desktop) implementation and a fresh temp
/// directory, so tests run on the host and each test file gets its own
/// `logins.db`.
///
/// Call from `setUpAll` before anything touches [DbHelper.instance].
Future<void> initTestDatabase() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final dir = await Directory.systemTemp.createTemp('password_store_test_');
  await databaseFactory.setDatabasesPath(dir.path);
}

/// Deletes every row so each test starts from an empty vault.
Future<void> clearTables() async {
  final db = await DbHelper.instance.database;
  await db.delete('login_entries');
  await db.delete('profile');
}
