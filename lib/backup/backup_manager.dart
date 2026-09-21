import 'dart:convert';
import 'dart:typed_data';

import '../crypto/vault_meta.dart';
import 'backup_folder.dart';
import 'backup_service.dart';
import 'vault_snapshot.dart';

/// Where things live inside the chosen folder (`docs/sync-design.md` §5.1).
class BackupLayout {
  /// The wrapped keys, so another device can unwrap the vault with the same
  /// passcode. No secret: salts, Argon2id settings and the sealed key.
  static const meta = 'meta.json';

  /// Who uploaded last, and when.
  static const lastBackup = 'last-backup.json';

  static const snapshots = 'backups';

  static String snapshotPath(String fileName) => '$snapshots/$fileName';
}

/// One backup in the folder.
class SnapshotInfo {
  final String fileName;
  final DateTime takenAt;

  const SnapshotInfo(this.fileName, this.takenAt);
}

/// What the last upload recorded about itself.
class LastBackup {
  final DateTime at;
  final String deviceId;
  final String? deviceName;

  const LastBackup({required this.at, required this.deviceId, this.deviceName});

  Map<String, dynamic> toJson() => {
        'at': at.toUtc().toIso8601String(),
        'deviceId': deviceId,
        if (deviceName != null) 'deviceName': deviceName,
      };

  static LastBackup? fromJson(Map<String, dynamic> json) {
    final at = DateTime.tryParse(json['at'] as String? ?? '');
    final deviceId = json['deviceId'] as String?;
    if (at == null || deviceId == null) return null;
    return LastBackup(
      at: at.toUtc(),
      deviceId: deviceId,
      deviceName: json['deviceName'] as String?,
    );
  }
}

/// Backs the vault up to a folder the user chose, and restores it again.
class BackupManager {
  final BackupService _service;

  BackupManager({BackupService? service}) : _service = service ?? BackupService();

  /// Checks the folder belongs to this vault, if it has been used before.
  ///
  /// Backing up into another vault's folder would mix two people's
  /// snapshots and make restore a coin toss, so it is refused outright
  /// rather than merged.
  Future<void> checkVault(BackupFolder folder, String? vaultId) async {
    if (!await folder.exists(BackupLayout.meta)) return;

    final meta = await _readMeta(folder);
    final theirs = meta?.vaultId;
    if (theirs != null && vaultId != null && theirs != vaultId) {
      throw const BackupFolderException(
        'This folder already holds backups of a different vault. '
        'Choose another folder.',
      );
    }
  }

  Future<VaultMeta?> _readMeta(BackupFolder folder) async {
    try {
      final bytes = await folder.read(BackupLayout.meta);
      return VaultMeta.fromJson(
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// Who backed this folder up last, or null if nobody has.
  Future<LastBackup?> lastBackup(BackupFolder folder) async {
    try {
      if (!await folder.exists(BackupLayout.lastBackup)) return null;
      final bytes = await folder.read(BackupLayout.lastBackup);
      return LastBackup.fromJson(
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// Whether another device uploaded here last.
  ///
  /// Backup replaces whole snapshots, so two devices backing up the same
  /// vault will lose one side's entries. Until merging lands (#53), the app
  /// warns and lets the user decide rather than pretending it is safe.
  Future<String?> otherDeviceWarning(BackupFolder folder, String deviceId) async {
    final last = await lastBackup(folder);
    if (last == null || last.deviceId == deviceId) return null;

    final who = last.deviceName ?? 'another device';
    return 'This vault was last backed up by $who. Backing up from here '
        'replaces that backup, and anything saved only on $who will be lost.';
  }

  /// Takes a snapshot and writes it to [folder], with the wrapped keys
  /// beside it, then prunes old snapshots.
  Future<SnapshotInfo> backUp({
    required BackupFolder folder,
    required Uint8List databaseKey,
    required VaultMeta meta,
    required String deviceId,
    String? deviceName,
    DateTime? now,
  }) async {
    await checkVault(folder, meta.vaultId);

    final takenAt = (now ?? DateTime.now()).toUtc();
    final snapshot = await _service.createSnapshot(databaseKey);
    final fileName = VaultSnapshot.fileNameFor(takenAt);

    // The snapshot first: until the keys are there, a half-finished backup
    // is simply a file nobody can open — never a folder that claims to hold
    // a vault it cannot restore.
    await folder.write(
      BackupLayout.snapshotPath(fileName),
      snapshot,
    );
    await folder.write(
      BackupLayout.meta,
      Uint8List.fromList(utf8.encode(jsonEncode(meta.toJson()))),
    );
    await folder.write(
      BackupLayout.lastBackup,
      Uint8List.fromList(utf8.encode(jsonEncode(
        LastBackup(at: takenAt, deviceId: deviceId, deviceName: deviceName).toJson(),
      ))),
    );

    await _prune(folder);
    return SnapshotInfo(fileName, takenAt);
  }

  /// The backups in [folder], newest first.
  Future<List<SnapshotInfo>> listSnapshots(BackupFolder folder) async {
    final names = await folder.list(BackupLayout.snapshots);
    final snapshots = <SnapshotInfo>[];
    for (final name in names) {
      final takenAt = VaultSnapshot.timeOf(name);
      if (takenAt != null) snapshots.add(SnapshotInfo(name, takenAt));
    }
    snapshots.sort((a, b) => b.takenAt.compareTo(a.takenAt));
    return snapshots;
  }

  /// Replaces the local vault with a snapshot from the folder.
  ///
  /// The vault is left closed; the caller unlocks it again. Everything that
  /// can fail does so before the local vault is touched.
  Future<void> restore({
    required BackupFolder folder,
    required String fileName,
    required Uint8List databaseKey,
  }) async {
    final bytes = await folder.read(BackupLayout.snapshotPath(fileName));
    await _service.restoreSnapshot(bytes, databaseKey);
  }

  /// The wrapped keys stored in the folder, for unlocking a restored vault
  /// on a device that has never seen it.
  Future<VaultMeta?> remoteMeta(BackupFolder folder) => _readMeta(folder);

  /// Backs up if a day has passed since the last one, and there is a folder
  /// to back up to. Returns what it did, so the caller can say so or stay
  /// quiet.
  ///
  /// Deliberately gives up rather than retries: a daily backup that fails
  /// because a folder is unmounted should not block the app or nag.
  Future<SnapshotInfo?> backUpIfDue({
    required BackupFolder folder,
    required Uint8List databaseKey,
    required VaultMeta meta,
    required String deviceId,
    String? deviceName,
    required DateTime? lastBackupAt,
    DateTime? now,
  }) async {
    if (!isBackupDue(lastBackupAt, now: now)) return null;

    // Never overwrite another device's backup without being asked: that is
    // the one case backup cannot survive (docs/sync-design.md §5.1).
    if (await otherDeviceWarning(folder, deviceId) != null) return null;

    return backUp(
      folder: folder,
      databaseKey: databaseKey,
      meta: meta,
      deviceId: deviceId,
      deviceName: deviceName,
      now: now,
    );
  }

  /// Whether a daily backup is due.
  static bool isBackupDue(DateTime? lastBackupAt, {DateTime? now}) {
    if (lastBackupAt == null) return true;
    final since = (now ?? DateTime.now()).toUtc().difference(lastBackupAt.toUtc());
    return since >= const Duration(days: 1);
  }

  Future<void> _prune(BackupFolder folder) async {
    final names = await folder.list(BackupLayout.snapshots);
    for (final name in BackupService.snapshotsToDelete(names)) {
      await folder.delete(BackupLayout.snapshotPath(name));
    }
  }
}
