import 'package:archinfotech/models/profile.dart';
import 'package:flutter/material.dart';
import '../models/login_entry.dart';
import 'db_helper.dart';
import 'package:uuid_v4/uuid_v4.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginEntryProvider with ChangeNotifier {
  List<LoginEntry> _entries = [];

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

  /// First-run setup: creates the vault's single profile. Throws a
  /// [StateError] if a vault already exists.
  Future<ProfileEntry> createVault({
    required String name,
    required String passcode,
    required String hintQuestion,
    required String hintAnswer,
  }) async {
    final profile = ProfileEntry(
      id: UUIDv4().toString(),
      name: name.trim(),
      password: passcode,
      hint: hintQuestion.trim(),
      answer: hintAnswer.trim(),
    );
    await DbHelper.instance.AddProfile(profile);
    return profile;
  }

  /// The recovery question to show, or null if there is no usable one.
  /// Vaults created before the ISSUES.md #14 fix stored the passcode in
  /// `hint`, so that value must never be shown.
  Future<String?> recoveryQuestion() async {
    final profile = await getProfile();
    if (profile == null) return null;
    final hint = profile.hint.trim();
    if (hint.isEmpty || profile.hint == profile.password) return null;
    return hint;
  }

  /// Whether [answer] matches the stored recovery answer, ignoring case and
  /// surrounding spaces.
  Future<bool> verifyRecoveryAnswer(String answer) async {
    final profile = await getProfile();
    if (profile == null) return false;
    final entered = answer.trim().toLowerCase();
    return entered.isNotEmpty && entered == profile.answer.trim().toLowerCase();
  }

  /// Replaces the vault passcode after a successful recovery. Returns false
  /// if there is no vault.
  Future<bool> resetPasscode(String newPasscode) async {
    final profile = await getProfile();
    if (profile == null) return false;
    await DbHelper.instance.updateProfile(profile.copyWith(password: newPasscode));
    return true;
  }


  Future<void> saveLoginDetails(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', name);
  }
}
