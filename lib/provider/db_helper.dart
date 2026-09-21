import 'dart:typed_data';

import 'package:archinfotech/models/profile.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;

import '../crypto/vault_keys.dart';
import 'platform_database.dart';
import '../models/login_entry.dart';

/// Opens an encrypted database. Production uses SQLCipher through its plugin;
/// tests swap in an FFI implementation, since the plugin has no host build.
typedef EncryptedDatabaseOpener = Future<Database> Function(
  String path,
  String passphrase,
  OpenDatabaseOptions options,
);

class DbHelper {
  static const _dbName = 'logins.db';
  static const _dbVersion = 4;
  static const _tableName = 'login_entries';
  static const _profileTable = "profile";

  static final DbHelper instance = DbHelper._internal();
  DbHelper._internal();

  static Database? _db;

  /// Set by tests to open encrypted databases without the platform plugin.
  static EncryptedDatabaseOpener? encryptedOpenerOverride;

  /// Whether the vault is currently unlocked.
  bool get isOpen => _db != null;

  /// The open database. Callers must unlock the vault first, with
  /// [openEncrypted].
  Future<Database> get database async {
    final db = _db;
    if (db == null) {
      throw StateError('The vault is locked. Unlock it before using it.');
    }
    return db;
  }

  Future<String> databaseFile() async => join(await getDatabasesPath(), _dbName);

  /// Directory holding the database, where `vault_meta.json` also lives.
  Future<String> vaultDirectory() async => getDatabasesPath();

  /// Opens the SQLCipher-encrypted vault with [databaseKey]. The key comes
  /// from unwrapping it with the passcode, so a wrong passcode never gets
  /// this far.
  Future<Database> openEncrypted(Uint8List databaseKey) async {
    await close();
    final path = await databaseFile();
    final passphrase = VaultKeys.toPassphrase(databaseKey);
    final options = OpenDatabaseOptions(
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    final opener = encryptedOpenerOverride;
    final db = opener != null
        ? await opener(path, passphrase, options)
        // Windows and Linux have no plugin implementation, so they open the
        // bundled SQLCipher through FFI instead (ISSUES.md #27).
        : usesFfiDatabase
            ? await openEncryptedWithFfi(path, passphrase, options)
            : await sqlcipher.openDatabase(
                path,
                password: passphrase,
                version: options.version,
                onCreate: options.onCreate,
                onUpgrade: options.onUpgrade,
              );

    try {
      await assertSqlCipher(db);
    } catch (_) {
      // Otherwise the handle leaks: _db is still null, so close() cannot
      // reach it, and on Windows the open file blocks replacing the vault.
      await db.close();
      rethrow;
    }
    _db = db;
    return db;
  }

  /// Locks the vault by closing the database and dropping the key with it.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Each version gets its own branch: running every statement on every
  /// upgrade would try to create tables that already exist.
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v1 had no profile table at all.
      await db.execute(_createProfileTable);
    }
    if (oldVersion >= 2 && oldVersion < 3) {
      // v2 kept the passcode, recovery question and answer in the profile
      // row. None of them are stored any more, so the columns go. SQLite
      // cannot drop columns portably, hence the rebuild.
      await db.execute('CREATE TABLE ${_profileTable}_new (id TEXT PRIMARY KEY, name TEXT NOT NULL)');
      await db.execute('INSERT INTO ${_profileTable}_new (id, name) SELECT id, name FROM $_profileTable');
      await db.execute('DROP TABLE $_profileTable');
      await db.execute('ALTER TABLE ${_profileTable}_new RENAME TO $_profileTable');
    }
    if (oldVersion < 4) {
      // Change tracking for backup and merging (docs/sync-design.md §3.2).
      // Existing entries are backfilled as "changed once, just now, by no
      // known device", which is the truthful starting point: nothing is known
      // about their history.
      await db.execute('ALTER TABLE $_tableName ADD COLUMN updatedAt INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE $_tableName ADD COLUMN deletedAt INTEGER');
      await db.execute('ALTER TABLE $_tableName ADD COLUMN revision INTEGER NOT NULL DEFAULT 1');
      await db.execute("ALTER TABLE $_tableName ADD COLUMN deviceId TEXT NOT NULL DEFAULT ''");
      await db.update(_tableName, {'updatedAt': DateTime.now().toUtc().millisecondsSinceEpoch});
    }
  }

  static const _createProfileTable = '''
      CREATE TABLE profile (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''';

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        username TEXT NOT NULL,
        password TEXT NOT NULL,
        website TEXT NOT NULL,
        totpSecret TEXT,
        updatedAt INTEGER NOT NULL DEFAULT 0,
        deletedAt INTEGER,
        revision INTEGER NOT NULL DEFAULT 1,
        deviceId TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute(_createProfileTable);
  }

  /// The device writing to this vault, stamped onto every change.
  /// Set once per install by [LoginEntryProvider].
  static String deviceId = '';

  /// Overridable for tests, so a change's timestamp can be pinned.
  static int Function() now =
      () => DateTime.now().toUtc().millisecondsSinceEpoch;

  /// Saves a new entry, or replaces one wholesale, stamping it as a change.
  Future<void> insertEntry(LoginEntry entry) async {
    final db = await database;
    final existing = await _rawEntry(entry.id);
    await db.insert(
      _tableName,
      entry
          .copyWith(
            updatedAt: now(),
            revision: (existing?.revision ?? 0) + 1,
            deviceId: deviceId,
          )
          .toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// The live entries: tombstones are rows, but they are not entries any more.
  Future<List<LoginEntry>> fetchEntries() async {
    final db = await database;
    final maps = await db.query(_tableName, where: 'deletedAt IS NULL');
    return maps.map((e) => LoginEntry.fromMap(e)).toList();
  }

  /// Deleted entries, kept so another device cannot resurrect them
  /// (docs/sync-design.md §3.2).
  Future<List<LoginEntry>> fetchTombstones() async {
    final db = await database;
    final maps = await db.query(_tableName, where: 'deletedAt IS NOT NULL');
    return maps.map((e) => LoginEntry.fromMap(e)).toList();
  }

  /// Every row, tombstones included. For backup and merging, not for the UI.
  Future<List<LoginEntry>> fetchEntriesForSync() async {
    final db = await database;
    return (await db.query(_tableName)).map((e) => LoginEntry.fromMap(e)).toList();
  }

  Future<LoginEntry?> _rawEntry(String id) async {
    final db = await database;
    final maps = await db.query(_tableName, where: 'id = ?', whereArgs: [id], limit: 1);
    return maps.isEmpty ? null : LoginEntry.fromMap(maps.first);
  }

  Future<void> updateEntry(LoginEntry entry) async {
    final db = await database;
    final existing = await _rawEntry(entry.id);
    await db.update(
      _tableName,
      entry
          .copyWith(
            updatedAt: now(),
            revision: (existing?.revision ?? 0) + 1,
            deviceId: deviceId,
          )
          .toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  /// Soft delete: the row stays as a tombstone so the entry cannot come back
  /// from a device that has not synced yet.
  Future<void> deleteEntry(String id) async {
    final db = await database;
    final existing = await _rawEntry(id);
    if (existing == null) return;
    final at = now();
    await db.update(
      _tableName,
      {
        // The secret goes now; only the tombstone needs to survive.
        'password': '',
        'totpSecret': null,
        'deletedAt': at,
        'updatedAt': at,
        'revision': existing.revision + 1,
        'deviceId': deviceId,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Removes a tombstone for good. Used by retention, not by the UI.
  Future<void> purgeTombstone(String id) async {
    final db = await database;
    await db.delete(_tableName, where: 'id = ? AND deletedAt IS NOT NULL', whereArgs: [id]);
  }

  /// Saves the vault's profile. The app is single-profile, so this throws a
  /// [StateError] if a different profile already exists.
  Future<void> AddProfile(ProfileEntry entry) async {
    final db = await database;
    final others = await db.query(_profileTable, where: 'id != ?', whereArgs: [entry.id], limit: 1);
    if (others.isNotEmpty) {
      throw StateError('A vault profile already exists');
    }
    await db.insert(_profileTable, entry.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// The vault's single profile, or null before one has been created. Older
  /// installs may hold more than one profile; the oldest one wins.
  Future<ProfileEntry?> fetchVaultProfile() async {
    final db = await database;
    final maps = await db.query(_profileTable, orderBy: 'rowid', limit: 1);
    return maps.isEmpty ? null : ProfileEntry.fromMap(maps.first);
  }

  Future<List<ProfileEntry>> fetchProfileEntries() async {
    final db = await database;
    final maps = await db.query(_profileTable);
    return maps.map((e) => ProfileEntry.fromMap(e)).toList();
  }

  Future<int> updateProfile(ProfileEntry profile) async {
    final db = await database;
    return await db.update(
      _profileTable, profile.toMap(), where: 'id = ?', whereArgs: [profile.id],
    );
  }


}
