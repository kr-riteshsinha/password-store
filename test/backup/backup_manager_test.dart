import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archinfotech/backup/backup_folder.dart';
import 'package:archinfotech/backup/backup_manager.dart';
import 'package:archinfotech/backup/backup_service.dart';
import 'package:archinfotech/backup/vault_snapshot.dart';
import 'package:archinfotech/crypto/vault_keys.dart';
import 'package:archinfotech/crypto/vault_meta.dart';
import 'package:archinfotech/models/login_entry.dart';
import 'package:archinfotech/provider/db_helper.dart';
import 'package:flutter_test/flutter_test.dart';

import '../crypto/vault_keys_test.dart' show cheapParams;
import '../helpers/test_database.dart';

LoginEntry _entry(String id, {String title = 'GitHub'}) => LoginEntry(
      id: id,
      title: title,
      username: 'octocat',
      password: 'pw-$id',
      website: 'https://github.com',
    );

void main() {
  final db = DbHelper.instance;
  late Directory root;
  late LocalBackupFolder folder;
  late BackupManager manager;
  late VaultMeta meta;

  setUpAll(initEncryptedTestDatabase);

  setUp(() async {
    await resetVault();
    await openTestVault();
    root = await Directory.systemTemp.createTemp('backup_folder_');
    folder = LocalBackupFolder(root.path);
    manager = BackupManager(
      service: BackupService(
        temporaryDirectory: () => root.createTempSync('work_'),
      ),
    );
    final created = await createVaultKeys(
      passcode: '12345678',
      recoveryAnswer: 'Blue',
      newParams: cheapParams,
    );
    meta = created.meta;
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  tearDownAll(resetVault);

  Future<SnapshotInfo> backUp({DateTime? now, String deviceId = 'device-a'}) =>
      manager.backUp(
        folder: folder,
        databaseKey: testDatabaseKey,
        meta: meta,
        deviceId: deviceId,
        deviceName: deviceId == 'device-a' ? "Ritesh's Mac" : 'Pixel',
        now: now,
      );

  group('backing up', () {
    test('writes the snapshot, the keys and who did it', () async {
      await db.insertEntry(_entry('1'));

      final info = await backUp();

      expect(await folder.exists(BackupLayout.snapshotPath(info.fileName)), isTrue);
      expect(await folder.exists(BackupLayout.meta), isTrue);
      expect(await folder.exists(BackupLayout.lastBackup), isTrue);
    });

    test('the keys travel with the backup, so another device can unlock it', () async {
      await backUp();

      final remote = await manager.remoteMeta(folder);

      expect(remote, isNotNull);
      expect(await unlockWithPasscode(remote!, '12345678'), isNotNull);
      expect(remote.vaultId, meta.vaultId);
    });

    test('nothing readable is written to the folder', () async {
      await db.insertEntry(_entry('1', title: 'Very Private Bank'));

      final info = await backUp();

      final snapshot = await folder.read(BackupLayout.snapshotPath(info.fileName));
      final text = String.fromCharCodes(snapshot.where((b) => b >= 32 && b < 127));
      expect(text, isNot(contains('Very Private Bank')));
      expect(text, isNot(contains('octocat')));

      // meta.json is not secret, but it must hold no passcode either.
      final metaText = utf8.decode(await folder.read(BackupLayout.meta));
      expect(metaText, isNot(contains('12345678')));
      expect(metaText.toLowerCase(), isNot(contains('blue')));
    });

    test('a backup restores onto a device that has never seen the vault', () async {
      // The other device's vault has its own random database key — reusing
      // this device's key would make the test pass while the app failed.
      // The key and the meta must be the pair that belong together: the meta
      // wraps exactly the key the vault is encrypted with.
      final theirVault = await createVaultKeys(
        passcode: '12345678',
        recoveryAnswer: 'Blue',
        newParams: cheapParams,
      );
      final theirKey = theirVault.databaseKey;
      final theirMeta = theirVault.meta;

      await resetVault();
      await db.openEncrypted(theirKey);
      await db.insertEntry(_entry('1'));
      await manager.backUp(
        folder: folder,
        databaseKey: theirKey,
        meta: theirMeta,
        deviceId: 'device-b',
      );
      final theirSnapshot = (await manager.listSnapshots(folder)).single;

      // This device: a different vault entirely.
      await resetVault();
      await openTestVault();
      expect(await db.fetchEntries(), isEmpty);

      // The key comes from the folder's own meta.json, unwrapped with the
      // passcode — never from the local vault.
      final key = await manager.keyForFolder(folder, '12345678');
      expect(key, isNotNull);
      await manager.restore(
        folder: folder,
        fileName: theirSnapshot.fileName,
        databaseKey: key!,
      );
      await db.openEncrypted(key);

      expect((await db.fetchEntries()).single.id, '1');
    });

    test('the local key cannot open another device\'s backup', () async {
      final theirKey = VaultKeys.newDatabaseKey();
      await resetVault();
      await db.openEncrypted(theirKey);
      await db.insertEntry(_entry('1'));
      await manager.backUp(
        folder: folder,
        databaseKey: theirKey,
        meta: meta,
        deviceId: 'device-b',
      );
      final theirSnapshot = (await manager.listSnapshots(folder)).single;

      await resetVault();
      await openTestVault();

      // This is what the screen used to do, and why restore could never have
      // worked across devices.
      await expectLater(
        manager.restore(
          folder: folder,
          fileName: theirSnapshot.fileName,
          databaseKey: testDatabaseKey,
        ),
        throwsA(isA<SnapshotException>()),
      );
    });

    test('the wrong passcode yields no key for the folder', () async {
      await backUp();

      expect(await manager.keyForFolder(folder, 'wrong-passcode'), isNull);
    });

    test('keeps ten snapshots and deletes the oldest', () async {
      for (var i = 0; i < 12; i++) {
        await backUp(now: DateTime.utc(2026, 1, 1).add(Duration(days: i)));
      }

      final snapshots = await manager.listSnapshots(folder);

      expect(snapshots, hasLength(BackupService.keepSnapshots));
      expect(snapshots.first.takenAt, DateTime.utc(2026, 1, 12));
      expect(snapshots.last.takenAt, DateTime.utc(2026, 1, 3));
    });

    test('lists snapshots newest first', () async {
      await backUp(now: DateTime.utc(2026, 1, 1));
      await backUp(now: DateTime.utc(2026, 3, 1));
      await backUp(now: DateTime.utc(2026, 2, 1));

      final snapshots = await manager.listSnapshots(folder);

      expect(
        snapshots.map((s) => s.takenAt),
        [DateTime.utc(2026, 3, 1), DateTime.utc(2026, 2, 1), DateTime.utc(2026, 1, 1)],
      );
    });

    test('ignores files in the folder that are not snapshots', () async {
      await backUp();
      await folder.write(
        BackupLayout.snapshotPath('holiday-photo.jpg'),
        Uint8List.fromList([1, 2, 3]),
      );

      expect(await manager.listSnapshots(folder), hasLength(1));
    });
  });

  group('the wrong folder', () {
    test('a folder whose details cannot be read is refused', () async {
      // A cloud placeholder that has not downloaded yet looks like this.
      // Carrying on would overwrite meta.json — the only key that opens the
      // snapshots already there.
      await backUp();
      await folder.write(
        BackupLayout.meta,
        Uint8List.fromList('not json'.codeUnits),
      );

      await expectLater(
        manager.checkVault(folder, meta.vaultId),
        throwsA(isA<BackupFolderException>()),
      );
    });

    test('a vault with no id of its own is refused', () async {
      await backUp();

      await expectLater(
        manager.checkVault(folder, null),
        throwsA(isA<BackupFolderException>()),
      );
    });

    test('another vault\'s folder is refused', () async {
      await backUp();
      final otherVault = meta.copyWith(vaultId: newVaultId());

      await expectLater(
        manager.backUp(
          folder: folder,
          databaseKey: testDatabaseKey,
          meta: otherVault,
          deviceId: 'device-b',
        ),
        throwsA(isA<BackupFolderException>()),
      );
    });

    test('an empty folder is fine', () async {
      await expectLater(manager.checkVault(folder, meta.vaultId), completes);
    });

    test('a folder holding the same vault is fine', () async {
      await backUp();

      await expectLater(manager.checkVault(folder, meta.vaultId), completes);
    });
  });

  group('two devices', () {
    test('no warning when this device backed up last', () async {
      await backUp(deviceId: 'device-a');

      expect(await manager.otherDeviceWarning(folder, 'device-a'), isNull);
    });

    test('warns, by name, when another device backed up last', () async {
      await backUp(deviceId: 'device-b');

      final warning = await manager.otherDeviceWarning(folder, 'device-a');

      expect(warning, contains('Pixel'));
      expect(warning, contains('will be lost'));
    });

    test('no warning for a folder nobody has used', () async {
      expect(await manager.otherDeviceWarning(folder, 'device-a'), isNull);
    });
  });

  group('the daily backup', () {
    Future<SnapshotInfo?> ifDue({
      DateTime? lastBackupAt,
      DateTime? now,
      String deviceId = 'device-a',
    }) =>
        manager.backUpIfDue(
          folder: folder,
          databaseKey: testDatabaseKey,
          meta: meta,
          deviceId: deviceId,
          lastBackupAt: lastBackupAt,
          now: now,
        );

    test('runs when there has never been a backup', () async {
      expect(await ifDue(), isNotNull);
      expect(await manager.listSnapshots(folder), hasLength(1));
    });

    test('does nothing within a day of the last one', () async {
      final now = DateTime.utc(2026, 10, 3, 12);

      final info = await ifDue(
        lastBackupAt: now.subtract(const Duration(hours: 6)),
        now: now,
      );

      expect(info, isNull);
      expect(await manager.listSnapshots(folder), isEmpty);
    });

    test('will not quietly overwrite another device\'s backup', () async {
      await backUp(deviceId: 'device-b');

      // That case needs the user to decide, so the daily backup stands down
      // rather than taking the choice away.
      expect(await ifDue(deviceId: 'device-a'), isNull);
      expect(await manager.listSnapshots(folder), hasLength(1));
    });

    test('runs again a day later', () async {
      final day1 = DateTime.utc(2026, 10, 3, 12);
      await ifDue(now: day1);

      await ifDue(lastBackupAt: day1, now: day1.add(const Duration(days: 1)));

      expect(await manager.listSnapshots(folder), hasLength(2));
    });
  });

  group('when a backup is due', () {
    test('immediately, if there has never been one', () {
      expect(BackupManager.isBackupDue(null), isTrue);
    });

    test('not within a day of the last one', () {
      final now = DateTime.utc(2026, 10, 3, 12);

      expect(
        BackupManager.isBackupDue(now.subtract(const Duration(hours: 23)), now: now),
        isFalse,
      );
    });

    test('a day after the last one', () {
      final now = DateTime.utc(2026, 10, 3, 12);

      expect(
        BackupManager.isBackupDue(now.subtract(const Duration(days: 1)), now: now),
        isTrue,
      );
    });
  });
}
