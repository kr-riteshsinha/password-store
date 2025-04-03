import 'package:flutter/material.dart';

import '../models/passwordEntry.dart';

class PasswordProvider  extends ChangeNotifier{

  List<PasswordEntry> _passwords = [];

  List<PasswordEntry> get passwords => _passwords;
  Future<void> fetchPasswords() async {
    // _passwords = await _dbHelper.getPasswords();
    _passwords = this.mockPasswordEntries;

    notifyListeners();
  }

  List<PasswordEntry> mockPasswordEntries = [
    PasswordEntry(
      id: 1,
      username: 'john_doe@example.com',
      password: 'john1234!',
      category: 'Email',
      expiryDate: '2025-12-31',
    ),
    PasswordEntry(
      id: 2,
      username: 'mary_smith@company.com',
      password: 'mary2024',
      category: 'Work',
      expiryDate: '2025-06-15',
    ),
    PasswordEntry(
      id: 3,
      username: 'admin@website.com',
      password: 'admin!2024',
      category: 'Admin Panel',
      expiryDate: '2025-01-01',
    ),
    PasswordEntry(
      id: 4,
      username: 'alice.jones1234@gmail.com',
      password: 'alice@2025',
      category: 'Social Media',
      expiryDate: '2025-03-20',
    ),
    PasswordEntry(
      id: 5,
      username: 'bob_brown@service.com',
      password: 'bob_2024#',
      category: 'Service Account',
      expiryDate: '2026-09-12',
    ),
  ];

  void addPassword(newEntry) {
    mockPasswordEntries.add(newEntry);
    fetchPasswords();
    //notifyListeners();

  }
  Future<void> deletePassword(int id) async {
   // await _dbHelper.deletePassword(id);
   // mockPasswordEntries.remove(value)
    await fetchPasswords();  // ✅ Refresh list after deleting
  }

  Future<void> updatePassword( newEntry) async {
    mockPasswordEntries.add(newEntry);
    await fetchPasswords();  // ✅ Refresh list after deleting

  }
}