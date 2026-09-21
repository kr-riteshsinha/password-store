import 'package:shared_preferences/shared_preferences.dart';

/// What this device remembers about backup: where it goes, and when it last
/// happened. Per install, never part of the vault.
class BackupSettings {
  static const _folderKey = 'backupFolder';
  static const _lastBackupKey = 'lastBackupAt';

  /// The shortest passcode allowed once backups leave the device.
  ///
  /// On the device an attacker needs the device *and* the passcode. In
  /// someone's cloud storage the passcode is the only thing left, and a
  /// four-digit one falls to an offline attack even at Argon2id cost
  /// (`docs/sync-design.md` §6, DECIDED 5).
  static const minPasscodeLength = 8;

  /// Whether [passcode] is strong enough to turn backup on.
  static bool passcodeAllowsBackup(String passcode) =>
      passcode.trim().length >= minPasscodeLength;

  /// The message shown when it is not.
  static String get passcodeTooShortMessage =>
      'Backups are stored outside this device, so your passcode must be at '
      'least $minPasscodeLength characters. Change it first, then turn on '
      'backup.';

  Future<String?> folder() async =>
      (await SharedPreferences.getInstance()).getString(_folderKey);

  Future<void> setFolder(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null) {
      await prefs.remove(_folderKey);
      await prefs.remove(_lastBackupKey);
    } else {
      await prefs.setString(_folderKey, path);
    }
  }

  Future<DateTime?> lastBackupAt() async {
    final text = (await SharedPreferences.getInstance()).getString(_lastBackupKey);
    return text == null ? null : DateTime.tryParse(text)?.toUtc();
  }

  Future<void> setLastBackupAt(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastBackupKey, time.toUtc().toIso8601String());
  }
}
