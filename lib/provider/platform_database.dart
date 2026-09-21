import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Whether this platform opens the database through FFI rather than the
/// sqflite plugin.
///
/// `sqflite` and `sqflite_sqlcipher` only ship Android, iOS and macOS
/// implementations, so Windows and Linux go through `sqflite_common_ffi`
/// against the SQLCipher library bundled by `sqlcipher_flutter_libs`
/// (ISSUES.md #27).
bool get usesFfiDatabase => Platform.isWindows || Platform.isLinux;

/// Points sqflite at the FFI implementation on desktop, and at a real
/// per-user directory. Call once, before anything touches the database.
///
/// Without the explicit path, `sqflite_common_ffi` defaults to
/// `.dart_tool/sqflite_common_ffi/databases` **relative to the working
/// directory**: the vault would differ depending on where the app was
/// launched from, and would fail outright in a read-only directory such as
/// Program Files.
Future<void> initPlatformDatabase() async {
  if (!usesFfiDatabase) return;
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  await databaseFactory
      .setDatabasesPath((await getApplicationSupportDirectory()).path);
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
  // Quotes are doubled even though the passphrase is hex today: this is the
  // one statement that decides whether the vault is encrypted at all.
  final quoted = passphrase.replaceAll("'", "''");
  return databaseFactoryFfi.openDatabase(
    path,
    // Keeps whatever else the caller set (onOpen, readOnly and the rest)
    // rather than silently dropping it on this platform only.
    options: options..onConfigure = (db) => db.execute("PRAGMA key = '$quoted'"),
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
