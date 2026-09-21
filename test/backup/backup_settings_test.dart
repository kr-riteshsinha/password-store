import 'package:archinfotech/backup/backup_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late BackupSettings settings;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    settings = BackupSettings();
  });

  group('the passcode rule', () {
    test('eight characters or more is allowed', () {
      expect(BackupSettings.passcodeAllowsBackup('12345678'), isTrue);
      expect(BackupSettings.passcodeAllowsBackup('a longer passphrase'), isTrue);
    });

    test('a short passcode is refused', () {
      // The vault is fine with four on this device; a backup in someone's
      // cloud storage is not (design §6, DECIDED 5).
      expect(BackupSettings.passcodeAllowsBackup('1234'), isFalse);
      expect(BackupSettings.passcodeAllowsBackup('1234567'), isFalse);
    });

    test('padding does not count', () {
      expect(BackupSettings.passcodeAllowsBackup('  1234  '), isFalse);
    });

    test('the message says what to do', () {
      expect(BackupSettings.passcodeTooShortMessage, contains('8'));
      expect(BackupSettings.passcodeTooShortMessage, contains('Change it first'));
    });
  });

  group('remembering the folder', () {
    test('nothing is set to begin with', () async {
      expect(await settings.folder(), isNull);
      expect(await settings.lastBackupAt(), isNull);
    });

    test('a chosen folder is remembered', () async {
      await settings.setFolder('/Users/someone/Dropbox/vault');

      expect(await settings.folder(), '/Users/someone/Dropbox/vault');
    });

    test('the last backup time round-trips as UTC', () async {
      final at = DateTime.utc(2026, 10, 3, 14, 2);

      await settings.setLastBackupAt(at);

      expect(await settings.lastBackupAt(), at);
    });

    test('forgetting the folder also forgets when it was last backed up', () async {
      await settings.setFolder('/somewhere');
      await settings.setLastBackupAt(DateTime.utc(2026, 10, 3));

      await settings.setFolder(null);

      expect(await settings.folder(), isNull);
      // Otherwise choosing a new folder would look as if it had just been
      // backed up, and the daily backup would wait a day before running.
      expect(await settings.lastBackupAt(), isNull);
    });
  });
}
