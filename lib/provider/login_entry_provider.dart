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

  Future<List<ProfileEntry>> getCurrentProfile() async {
    return await DbHelper.instance.fetchProfileEntries().asStream().first;
  }
  Future<List<ProfileEntry>> getAllProfiles() async {
    return await DbHelper.instance.fetchProfileEntries();
  }

  Future<void> updateProfile(ProfileEntry profile) async {
     await DbHelper.instance.updateProfile(profile);
  }

  Future<ProfileEntry?> findProfileByName(String name) async {
    return await DbHelper.instance.fetchProfile(name);
  }


  Future<ProfileEntry?> forgetPassword(String name,String hint, String answer) async {
    return await DbHelper.instance.forgetPassword(name,hint,answer);
  }

  Future<void> saveLoginDetails(String ?name,) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', name!);
  }
  String? _currentProfileName;

  Future<void> switchProfile(String profileName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentProfile', profileName);
    _currentProfileName = profileName;
    notifyListeners();
  }
}
