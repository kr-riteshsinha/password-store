import 'dart:typed_data';

import 'package:archinfotech/models/profile.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;

import '../backup/atomic_file.dart';
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

  /// The schema this build understands. A snapshot claiming a newer one must
  /// be refused: sqflite would otherwise stamp the file back down to this
  /// version, leaving a newer schema wearing an older label.
  static int get schemaVersion => _dbVersion;
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
  Future<Database> openEncrypted(Uint8List databaseKey) async =>
      openEncryptedAt(await databaseFile(), databaseKey);

  /// Opens an encrypted database at [path] **as the vault**, closing whatever
  /// was open before.
  Future<Database> openEncryptedAt(String path, Uint8List databaseKey) async {
    await close();
    final db = await _open(path, databaseKey, readOnly: false);
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

  /// Opens an encrypted database at [path] **without touching the vault**.
  ///
  /// Backup uses this to check a candidate snapshot before restoring it: a
  /// failed check must leave the user's vault open and untouched. The caller
  /// closes the returned database.
  Future<Database> openDetached(
    String path,
    Uint8List databaseKey, {
    bool readOnly = true,
  }) =>
      _open(path, databaseKey, readOnly: readOnly);

  Future<Database> _open(
    String path,
    Uint8List databaseKey, {
    required bool readOnly,
  }) async {
    final passphrase = VaultKeys.toPassphrase(databaseKey);
    final options = readOnly
        // No version, create or upgrade hooks: checking a snapshot must never
        // migrate or create anything.
        ? OpenDatabaseOptions(readOnly: true)
        : OpenDatabaseOptions(
            version: _dbVersion,
            onCreate: _onCreate,
            onUpgrade: _onUpgrade,
          );

    final opener = encryptedOpenerOverride;
    return opener != null
        ? await opener(path, passphrase, options)
        // Windows and Linux have no plugin implementation, so they open the
        // bundled SQLCipher through FFI instead (ISSUES.md #27).
        : usesFfiDatabase
            ? await openEncryptedWithFfi(path, passphrase, options)
            : await sqlcipher.openDatabase(
                path,
                password: passphrase,
                readOnly: options.readOnly,
                version: options.version,
                onCreate: options.onCreate,
                onUpgrade: options.onUpgrade,
              );
  }

  /// Writes a consistent, still-encrypted copy of the vault to [path].
  ///
  /// Uses `sqlcipher_export`, **not** `VACUUM INTO`: with SQLCipher the
  /// latter writes a *plaintext* database, so the vault would exist
  /// unencrypted on disk, however briefly. The copy here is encrypted with
  /// the same key throughout.
  ///
  /// The vault stays open and usable while this runs; the copy is a snapshot
  /// of the moment it started.
  Future<void> exportEncryptedCopy(String path, Uint8List databaseKey) async {
    final db = await database;
    final passphrase = VaultKeys.toPassphrase(databaseKey).replaceAll("'", "''");
    final escapedPath = path.replaceAll("'", "''");

    await db.execute("ATTACH DATABASE '$escapedPath' AS backup KEY '$passphrase'");
    try {
      await db.rawQuery("SELECT sqlcipher_export('backup')");
      // The copy needs the same schema version, or the app would try to
      // upgrade it on open.
      await db.execute('PRAGMA backup.user_version = $_dbVersion');
    } finally {
      try {
        await db.execute('DETACH DATABASE backup');
      } catch (e) {
        // Never let this replace the real failure. Leaving `backup` attached
        // would also wedge the live connection: every later export would
        // fail with "database backup is already in use".
        debugPrint('Could not detach the backup database: $e');
      }
    }
  }

  /// Replaces the vault with the database at [path], atomically.
  ///
  /// The vault is closed first, the file is renamed over it, and the caller
  /// reopens. A crash mid-restore leaves either the old vault or the new one.
  Future<void> replaceDatabaseFile(String path) async {
    await close();
    await replaceFileAtomically(await databaseFile(), path);
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
      // Existing entries keep updatedAt = 0 and revision = 1, meaning "no
      // history known". Stamping the upgrade time instead would give the same
      // entry a different timestamp on every device that upgrades, so merging
      // would be decided by who upgraded last rather than by any real edit.
      await db.execute('ALTER TABLE $_tableName ADD COLUMN updatedAt INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE $_tableName ADD COLUMN deletedAt INTEGER');
      await db.execute('ALTER TABLE $_tableName ADD COLUMN revision INTEGER NOT NULL DEFAULT 1');
      await db.execute("ALTER TABLE $_tableName ADD COLUMN deviceId TEXT NOT NULL DEFAULT ''");
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
  ///
  /// The revision is bumped **in SQL**, not read and written back: two saves
  /// racing (a double-tapped Save button, say) would otherwise both read the
  /// same number and both write it, losing an increment that merging depends
  /// on.
  Future<void> insertEntry(LoginEntry entry) async {
    final db = await database;
    await db.rawInsert(
      '''
      INSERT INTO $_tableName
        (id, title, username, password, website, totpSecret, updatedAt, deletedAt, revision, deviceId)
      VALUES (?, ?, ?, ?, ?, ?, ?, NULL, 1, ?)
      ON CONFLICT(id) DO UPDATE SET
        title = excluded.title,
        username = excluded.username,
        password = excluded.password,
        website = excluded.website,
        totpSecret = excluded.totpSecret,
        updatedAt = excluded.updatedAt,
        deletedAt = NULL,
        deviceId = excluded.deviceId,
        revision = $_tableName.revision + 1
      ''',
      [
        entry.id,
        entry.title,
        entry.username,
        entry.password,
        entry.website,
        entry.totpSecret,
        now(),
        deviceId,
      ],
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

  /// Updates a live entry. A tombstone is left alone: un-deleting an entry is
  /// exactly what tombstones exist to prevent, so it cannot happen by
  /// accident from a screen that still holds the old object.
  Future<void> updateEntry(LoginEntry entry) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE $_tableName SET
        title = ?, username = ?, password = ?, website = ?, totpSecret = ?,
        updatedAt = ?, deviceId = ?, revision = revision + 1
      WHERE id = ? AND deletedAt IS NULL
      ''',
      [
        entry.title,
        entry.username,
        entry.password,
        entry.website,
        entry.totpSecret,
        now(),
        deviceId,
        entry.id,
      ],
    );
  }

  /// Soft delete: the row stays as a tombstone so the entry cannot come back
  /// from a device that has not synced yet.
  ///
  /// A tombstone keeps only the id and the timestamps. Every field the user
  /// typed is cleared, because tombstones travel to the user's own cloud
  /// storage and outlive the entry by the whole retention window
  /// (docs/sync-design.md, DECIDED 7).
  Future<void> deleteEntry(String id) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE $_tableName SET
        title = '', username = '', password = '', website = '', totpSecret = NULL,
        deletedAt = ?, updatedAt = ?, deviceId = ?, revision = revision + 1
      WHERE id = ? AND deletedAt IS NULL
      ''',
      [now(), now(), deviceId, id],
    );
  }

  /// Removes a tombstone for good.
  ///
  /// Nothing calls this yet: retention is a later phase of the sync work
  /// (docs/sync-design.md §8). Until then tombstones accumulate, which is
  /// cheap — each keeps only an id and timestamps.
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
