import 'dart:typed_data';

import 'package:archinfotech/models/profile.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;

import '../crypto/vault_keys.dart';
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
  static const _dbVersion = 2;
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
  /// [openEncrypted] or [openLegacy].
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
    _db = opener != null
        ? await opener(path, passphrase, options)
        : await sqlcipher.openDatabase(
            path,
            password: passphrase,
            version: options.version,
            onCreate: options.onCreate,
            onUpgrade: options.onUpgrade,
          );
    return _db!;
  }

  /// Opens an unencrypted vault created before encryption existed.
  /// Removed once migration lands (ISSUES.md #1).
  Future<Database> openLegacy() async {
    await close();
    _db = await openDatabase(
      await databaseFile(),
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  /// Locks the vault by closing the database and dropping the key with it.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < newVersion) {
      await db.execute('''
      CREATE TABLE $_profileTable (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        password TEXT NOT NULL,
        hint TEXT NOT NULL,
        answer TEXT
      )
      
    ''');
    }
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        username TEXT NOT NULL,
        password TEXT NOT NULL,
        website TEXT NOT NULL,
        totpSecret TEXT
      )
      
    ''');
    await db.execute('''
      CREATE TABLE $_profileTable (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        password TEXT NOT NULL,
        hint TEXT NOT NULL,
        answer TEXT
      )
      
    ''');
  }

  Future<void> insertEntry(LoginEntry entry) async {
    final db = await database;
    await db.insert(_tableName, entry.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    final entries = await fetchEntries();

  }

  Future<List<LoginEntry>> fetchEntries() async {
    final db = await database;
    final maps = await db.query(_tableName);
    return maps.map((e) => LoginEntry.fromMap(e)).toList();
  }

  Future<void> updateEntry(LoginEntry entry) async {
    final db = await database;
    await db.update(_tableName, entry.toMap(), where: 'id = ?', whereArgs: [entry.id]);
  }

  Future<void> deleteEntry(String id) async {
    final db = await database;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
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

  Future<ProfileEntry?> fetchProfile(String name) async {
    final db = await database;
    final maps = await db.query(_profileTable,columns: ["id","name","password","hint","answer"],where: "name = ?", whereArgs: [name]);
    if(maps.isNotEmpty) {
      return ProfileEntry.fromMap(maps.first);
    } else {
      return null;
    }
  }
  Future<List<ProfileEntry>> fetchProfileEntries() async {
    final db = await database;
    final maps = await db.query(_profileTable);
    return maps.map((e) => ProfileEntry.fromMap(e)).toList();
  }

  Future<int> updateProfile(ProfileEntry profile) async {
    final db = await database;
    return await db.update(
      _profileTable, profile.toMap(), where: 'name = ?', whereArgs: [profile.name],   // selection arguments
    );
  }

  Future<ProfileEntry?> forgetPassword(String name,String hint , String answer) async {
    final db = await database;
    final maps = await db.query( _profileTable,
      columns: ["id", "name", "password", "hint", "answer"],
      where: "name = ? AND hint = ? AND answer = ?",
      whereArgs: [name, hint, answer],
    );
    if(maps.isNotEmpty) {
      return ProfileEntry.fromMap(maps.first);
    } else {
      return null;
    }
  }

}
