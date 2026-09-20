import 'package:archinfotech/models/profile.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/login_entry.dart';

class DbHelper {
  static const _dbName = 'logins.db';
  static const _dbVersion = 2;
  static const _tableName = 'login_entries';
  static const _profileTable = "profile";

  static final DbHelper instance = DbHelper._internal();
  DbHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    debugPrint('Database location: $dbPath');

    final path = join(dbPath, _dbName);
    debugPrint('final path : $dbPath');

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,  // Added for future schema changes
    );
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
