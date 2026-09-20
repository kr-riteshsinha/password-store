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
}

class LoginEntryProvider with ChangeNotifier {
  List<LoginEntry> _entries = [];

  /// The unlocked database key, held only while the vault is open.
  Uint8List? _databaseKey;

  /// The vault metadata, loaded when the vault is encrypted.
  VaultMeta? _meta;

  Future<VaultMetaStore> _metaStore() async =>
      VaultMetaStore(await DbHelper.instance.vaultDirectory());

  /// Whether a vault exists on this device. Without `vault_meta.json` there
  /// is no key, so there is no vault, whatever files are lying around.
  Future<VaultState> vaultState() async {
    final meta = await (await _metaStore()).read();
    if (meta == null) return VaultState.none;
    _meta = meta;
    return VaultState.encrypted;
  }

  /// Moves aside a database with no metadata beside it.
  ///
  /// SQLCipher cannot create an encrypted database over an existing file, and
  /// such a file is unopenable anyway with no key. Renaming rather than
  /// deleting keeps a plaintext vault from a pre-encryption build recoverable
  /// by hand.
  Future<void> _setAsideOrphanDatabase() async {
    final file = File(await DbHelper.instance.databaseFile());
    if (!file.existsSync()) return;

    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    file.renameSync('${file.path}.orphan-$stamp');
  }

  /// The recovery question to show, or null when there is none.
  Future<String?> recoveryQuestion() async {
    final meta = _meta ?? await (await _metaStore()).read();
    return meta?.recoveryQuestion;
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

    await _setAsideOrphanDatabase();

    final created = await createVaultKeys(
      passcode: passcode,
      recoveryAnswer: hintAnswer,
      recoveryQuestion: hintQuestion,
    );
    await DbHelper.instance.openEncrypted(created.databaseKey);
    await store.write(created.meta);
    _meta = created.meta;
    _databaseKey = created.databaseKey;

    final profile = ProfileEntry(id: UUIDv4().toString(), name: name.trim());
    await DbHelper.instance.AddProfile(profile);
    return profile;
  }

  /// Whether [answer] matches the recovery answer. It unlocks the vault,
  /// since the answer wraps the same database key.
  Future<bool> verifyRecoveryAnswer(String answer) =>
      unlockWithAnswerAndOpen(answer);

  /// Sets a new passcode after a successful recovery, or when changing it.
  ///
  /// This reseals the same database key, so the vault itself is untouched
  /// however large it is. Returns false if the vault is not unlocked.
  Future<bool> resetPasscode(String newPasscode) async {
    final meta = _meta;
    final key = _databaseKey;
    if (meta == null || key == null) return false;

    final updated = await rewrapWithPasscode(meta, key, newPasscode);
    await (await _metaStore()).write(updated);
    _meta = updated;
    return true;
  }

  /// Changes the passcode, checking the current one first.
  Future<bool> changePasscode(String currentPasscode, String newPasscode) async {
    if (!await unlockWithPasscodeAndOpen(currentPasscode)) return false;
    return resetPasscode(newPasscode);
  }


  Future<void> saveLoginDetails(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', name);
  }
}
