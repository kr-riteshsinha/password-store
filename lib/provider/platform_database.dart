import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Whether this platform opens the database through FFI rather than the
/// sqflite plugin.
///
/// `sqflite` and `sqflite_sqlcipher` only ship Android, iOS and macOS
/// implementations, so Windows and Linux go through `sqflite_common_ffi`
/// against the SQLCipher library bundled by `sqlcipher_flutter_libs`
/// (ISSUES.md #27).
bool get usesFfiDatabase => !kIsWeb && (Platform.isWindows || Platform.isLinux);

/// Points sqflite at the FFI implementation on desktop. Call once, before
/// anything touches the database.
void initPlatformDatabase() {
  if (!usesFfiDatabase) return;
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

/// Opens an encrypted database through FFI.
///
/// `sqflite_common_ffi` has no password parameter, so the key is applied with
/// `PRAGMA key` in `onConfigure`, which runs before anything reads the file,
/// the version check included.
Future<Database> openEncryptedWithFfi(
  String path,
  String passphrase,
  OpenDatabaseOptions options,
) {
  return databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: options.version,
      onCreate: options.onCreate,
      onUpgrade: options.onUpgrade,
      onConfigure: (db) => db.execute("PRAGMA key = '$passphrase'"),
    ),
  );
}

/// Throws unless [db] is backed by SQLCipher.
///
/// Worth the extra query: plain SQLite ignores `PRAGMA key` instead of
/// failing, so without this check the wrong library would quietly produce an
/// unencrypted vault that still appeared to work.
Future<void> assertSqlCipher(Database db) async {
  final rows = await db.rawQuery('PRAGMA cipher_version');
  final version = rows.isEmpty ? null : rows.first.values.first;
  if (version == null || version.toString().isEmpty) {
    throw StateError(
      'This build is not using SQLCipher, so the vault would not be '
      'encrypted. Check that sqlcipher_flutter_libs is bundled.',
    );
  }
}
