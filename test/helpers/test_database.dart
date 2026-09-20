import 'dart:ffi';
import 'dart:io';

import 'package:archinfotech/crypto/vault_meta.dart';
import 'package:archinfotech/provider/db_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';

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

/// Same as [initTestDatabase], but backed by the system SQLCipher library so
/// encrypted vaults can be opened on the host.
///
/// The app uses the `sqflite_sqlcipher` plugin, which has no host build, so
/// tests swap in an FFI opener that issues `PRAGMA key` itself. Both paths
/// hand SQLCipher the same passphrase, so a database written by one opens in
/// the other.
///
/// Needs SQLCipher installed: `brew install sqlcipher` on macOS,
/// `sudo apt-get install libsqlcipher-dev` on Linux. Set `SQLCIPHER_LIB` to
/// override the path.
Future<void> initEncryptedTestDatabase() async {
  final library = findSqlCipherLibrary();
  if (library == null) {
    throw StateError(
      'SQLCipher was not found. Install it (brew install sqlcipher, or '
      'sudo apt-get install libsqlcipher-dev) or set SQLCIPHER_LIB.',
    );
  }
  open
    ..overrideFor(OperatingSystem.macOS, () => DynamicLibrary.open(library))
    ..overrideFor(OperatingSystem.linux, () => DynamicLibrary.open(library));

  // The default FFI factory runs SQLite in a background isolate, where the
  // library override above does not apply, so it would silently keep using
  // plain SQLite and ignore `PRAGMA key`.
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;
  final dir = await Directory.systemTemp.createTemp('password_store_test_');
  await databaseFactory.setDatabasesPath(dir.path);

  DbHelper.encryptedOpenerOverride = (path, passphrase, options) {
    return databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: options.version,
        onCreate: options.onCreate,
        onUpgrade: options.onUpgrade,
        // Must run before anything reads the file, including the version check.
        onConfigure: (db) => db.execute("PRAGMA key = '$passphrase'"),
      ),
    );
  };
}

/// Path to a SQLCipher shared library, or null when none is installed.
///
/// The file name varies by distribution and package version, so the library
/// directories are searched rather than guessed exactly.
String? findSqlCipherLibrary() {
  final fromEnv = Platform.environment['SQLCIPHER_LIB'];
  if (fromEnv != null && fromEnv.isNotEmpty && File(fromEnv).existsSync()) {
    return fromEnv;
  }

  const directories = [
    '/opt/homebrew/opt/sqlcipher/lib',
    '/usr/local/opt/sqlcipher/lib',
    '/usr/lib/x86_64-linux-gnu',
    '/usr/lib/aarch64-linux-gnu',
    '/usr/lib',
    '/usr/local/lib',
  ];
  for (final directory in directories) {
    final dir = Directory(directory);
    if (!dir.existsSync()) continue;
    final matches = dir
        .listSync(followLinks: true)
        .whereType<File>()
        .map((f) => f.path)
        .where((path) {
          final name = path.split('/').last;
          return name.startsWith('libsqlcipher.') &&
              (name.endsWith('.dylib') || name.contains('.so'));
        })
        .toList()
      ..sort();
    if (matches.isNotEmpty) return matches.first;
  }
  return null;
}

/// Closes the vault and deletes its files, so the next test can create a new
/// one. Needed between encrypted-vault tests: a leftover `vault_meta.json`
/// makes setup refuse, and a leftover plaintext database cannot be reopened
/// with a key.
Future<void> resetVault() async {
  await DbHelper.instance.close();
  final dir = await DbHelper.instance.vaultDirectory();
  for (final name in ['logins.db', VaultMetaStore.fileName]) {
    final file = File('$dir/$name');
    if (file.existsSync()) file.deleteSync();
  }
}

/// Deletes every row so each test starts from an empty vault. Opens the
/// unencrypted vault first if nothing is open yet.
Future<void> clearTables() async {
  if (!DbHelper.instance.isOpen) {
    await DbHelper.instance.openLegacy();
  }
  final db = await DbHelper.instance.database;
  await db.delete('login_entries');
  await db.delete('profile');
}
