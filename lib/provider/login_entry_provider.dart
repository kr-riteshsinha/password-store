import 'dart:io';
import 'dart:typed_data';

import 'package:archinfotech/models/profile.dart';
import 'package:flutter/material.dart';
import '../crypto/vault_meta.dart';
import '../models/login_entry.dart';
import 'db_helper.dart';
import 'package:uuid_v4/uuid_v4.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What kind of vault is on this device.
enum VaultState {
  /// Nothing yet: the user has to set a passcode first.
  none,

  /// An encrypted vault, opened with the key sealed in `vault_meta.json`.
  encrypted,

  /// A vault created before encryption, still in plain text. Read-only in the
  /// sense that it is not created any more; migrating it is ISSUES.md #1.
  legacy,
}

class LoginEntryProvider with ChangeNotifier {
  List<LoginEntry> _entries = [];

  /// The unlocked database key, held only while the vault is open.
  Uint8List? _databaseKey;

  /// The vault metadata, loaded when the vault is encrypted.
  VaultMeta? _meta;

  Future<VaultMetaStore> _metaStore() async =>
      VaultMetaStore(await DbHelper.instance.vaultDirectory());

  /// Which kind of vault exists on this device.
  Future<VaultState> vaultState() async {
    final meta = await (await _metaStore()).read();
    if (meta != null) {
      _meta = meta;
      return VaultState.encrypted;
    }
    // Opening the database would create the file, and SQLCipher cannot then
    // create an encrypted vault over that plaintext file. So look first.
    if (!File(await DbHelper.instance.databaseFile()).existsSync()) {
      return VaultState.none;
    }

    await DbHelper.instance.openLegacy();
    final hasProfile = await DbHelper.instance.fetchVaultProfile() != null;
    if (hasProfile) return VaultState.legacy;
    await DbHelper.instance.close();
    return VaultState.none;
  }

  /// Removes an empty plaintext database left behind by an earlier version,
  /// so setup can create the encrypted vault in its place. A database with
  /// anything in it is left alone: that is a legacy vault, and #42 migrates
  /// it.
  Future<void> _discardEmptyLegacyDatabase() async {
    final file = File(await DbHelper.instance.databaseFile());
    if (!file.existsSync()) return;

    await DbHelper.instance.openLegacy();
    final isEmpty = await DbHelper.instance.fetchVaultProfile() == null &&
        (await DbHelper.instance.fetchEntries()).isEmpty;
    await DbHelper.instance.close();

    if (isEmpty) file.deleteSync();
  }

  /// The recovery question to show, or null when there is none.
  Future<String?> recoveryQuestion() async {
    final meta = _meta ?? await (await _metaStore()).read();
    if (meta != null) return meta.recoveryQuestion;

    // Legacy vault: the question is in the (unencrypted) profile row. Never
    // show a hint that is really the passcode (ISSUES.md #14).
    if (!DbHelper.instance.isOpen) return null;
    final profile = await getProfile();
    if (profile == null) return null;
    final hint = profile.hint.trim();
    return hint.isEmpty || profile.hint == profile.password ? null : hint;
  }

  /// Unlocks an encrypted vault and opens the database. False if the passcode
  /// is wrong.
  Future<bool> unlockWithPasscodeAndOpen(String passcode) async {
    final meta = await (await _metaStore()).read();
    if (meta == null) return false;
    final key = await unlockWithPasscode(meta, passcode);
    if (key == null) return false;
    _meta = meta;
    _databaseKey = key;
    await DbHelper.instance.openEncrypted(key);
    return true;
  }

  /// Unlocks with the recovery answer, for a forgotten passcode.
  Future<bool> unlockWithAnswerAndOpen(String answer) async {
    final meta = await (await _metaStore()).read();
    if (meta == null) return false;
    final key = await unlockWithRecoveryAnswer(meta, answer);
    if (key == null) return false;
    _meta = meta;
    _databaseKey = key;
    await DbHelper.instance.openEncrypted(key);
    return true;
  }

  /// Opens a plaintext vault created before encryption and checks the
  /// passcode the old way.
  Future<bool> unlockLegacy(String passcode) async {
    await DbHelper.instance.openLegacy();
    final profile = await DbHelper.instance.fetchVaultProfile();
    return profile != null && profile.password == passcode;
  }

  /// Closes the vault and forgets the key.
  Future<void> lock() async {
    _databaseKey = null;
    _meta = null;
    _entries = [];
    await DbHelper.instance.close();
  }

  List<LoginEntry> get entries => List.unmodifiable(_entries);

  Future<void> loadEntries() async {
    _entries = await DbHelper.instance.fetchEntries();
    notifyListeners();
  }

  Future<void> addEntry({
    required String title,
    required String username,
    required String password,
    required String website,
    String? totpSecret,
  }) async {
    final newEntry = LoginEntry(
      id: UUIDv4().toString(),
      title: title,
      username: username,
      password: password,
      website: website,
      totpSecret: totpSecret,
    );
    await DbHelper.instance.insertEntry(newEntry);
    //_entries.add(newEntry);
    notifyListeners();
  }

  Future<void> addLoginEntry( LoginEntry entry ) async {

    await DbHelper.instance.insertEntry(entry);
    loadEntries();
    // notifyListeners();
  }

  Future<void> updateEntry(LoginEntry updatedEntry) async {
    await DbHelper.instance.updateEntry(updatedEntry);
    loadEntries();
  }

  Future<void> deleteEntry(String id) async {
    await DbHelper.instance.deleteEntry(id);
    _entries.removeWhere((entry) => entry.id == id);
    loadEntries();
  }

  Future<void> addProfile(ProfileEntry entry) async {
    await DbHelper.instance.AddProfile(entry);
  }

  /// The vault's single profile, or null before one has been created.
  Future<ProfileEntry?> getProfile() async {
    return await DbHelper.instance.fetchVaultProfile();
  }

  Future<void> updateProfile(ProfileEntry profile) async {
     await DbHelper.instance.updateProfile(profile);
  }

  /// First-run setup: generates the vault keys, writes `vault_meta.json`,
  /// creates the encrypted database and stores the profile in it.
  ///
  /// The passcode and the recovery answer are never stored: the passcode
  /// unwraps the database key, and a wrong one simply fails to unwrap.
  Future<ProfileEntry> createVault({
    required String name,
    required String passcode,
    required String hintQuestion,
    required String hintAnswer,
  }) async {
    final store = await _metaStore();
    if (await store.exists()) {
      throw StateError('A vault profile already exists');
    }

    await _discardEmptyLegacyDatabase();

    final created = await createVaultKeys(
      passcode: passcode,
      recoveryAnswer: hintAnswer,
      recoveryQuestion: hintQuestion,
    );
    await DbHelper.instance.openEncrypted(created.databaseKey);
    await store.write(created.meta);
    _meta = created.meta;
    _databaseKey = created.databaseKey;

    final profile = ProfileEntry(
      id: UUIDv4().toString(),
      name: name.trim(),
      // The passcode and answer live nowhere; these columns stay empty until
      // the schema drops them (ISSUES.md #1 follow-up).
      password: '',
      hint: hintQuestion.trim(),
      answer: '',
    );
    await DbHelper.instance.AddProfile(profile);
    return profile;
  }

  /// Whether [answer] matches the recovery answer. For an encrypted vault
  /// this unlocks it, since the answer wraps the same database key.
  Future<bool> verifyRecoveryAnswer(String answer) async {
    if (await (await _metaStore()).exists()) {
      return unlockWithAnswerAndOpen(answer);
    }

    // Legacy vault: compare the stored answer.
    if (!DbHelper.instance.isOpen) return false;
    final profile = await getProfile();
    if (profile == null) return false;
    final entered = answer.trim().toLowerCase();
    return entered.isNotEmpty && entered == profile.answer.trim().toLowerCase();
  }

  /// Sets a new passcode after a successful recovery, or when changing it.
  ///
  /// For an encrypted vault this reseals the same database key, so the vault
  /// itself is untouched however large it is. Returns false if the vault is
  /// not unlocked.
  Future<bool> resetPasscode(String newPasscode) async {
    final meta = _meta;
    final key = _databaseKey;
    if (meta != null && key != null) {
      final updated = await rewrapWithPasscode(meta, key, newPasscode);
      await (await _metaStore()).write(updated);
      _meta = updated;
      return true;
    }

    final profile = await getProfile();
    if (profile == null) return false;
    await DbHelper.instance.updateProfile(profile.copyWith(password: newPasscode));
    return true;
  }

  /// Changes the passcode, checking the current one first.
  Future<bool> changePasscode(String currentPasscode, String newPasscode) async {
    if (await (await _metaStore()).exists()) {
      if (!await unlockWithPasscodeAndOpen(currentPasscode)) return false;
      return resetPasscode(newPasscode);
    }

    final profile = await getProfile();
    if (profile == null || profile.password.trim() != currentPasscode.trim()) {
      return false;
    }
    await DbHelper.instance.updateProfile(profile.copyWith(password: newPasscode));
    return true;
  }


  Future<void> saveLoginDetails(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', name);
  }
}
