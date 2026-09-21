import 'dart:io';
import 'dart:typed_data';

import 'atomic_file.dart';

/// Somewhere backups are kept.
///
/// Deliberately shaped like a folder and nothing more — list, read, write,
/// delete — because that is all iCloud Drive, Dropbox, Google Drive and a
/// plain directory have in common (`docs/sync-design.md` §3.3). A provider's
/// own REST API can implement the same four methods later.
abstract class BackupFolder {
  /// Names of the files directly inside [directory], relative to the root of
  /// the backup folder, e.g. `backups/vault-....bin`.
  Future<List<String>> list(String directory);

  Future<Uint8List> read(String name);

  Future<void> write(String name, Uint8List bytes);

  Future<void> delete(String name);

  Future<bool> exists(String name);

  /// Shown to the user, so they can tell which folder they picked.
  String get description;
}

/// A folder on this machine — which is also how the app reaches iCloud
/// Drive, Dropbox, Google Drive and OneDrive on desktop, and through the
/// system picker on mobile: the provider's own client does the syncing.
class LocalBackupFolder implements BackupFolder {
  final String path;

  const LocalBackupFolder(this.path);

  @override
  String get description => path;

  File _file(String name) => File('$path/$name');

  @override
  Future<List<String>> list(String directory) async {
    final dir = Directory(directory.isEmpty ? path : '$path/$directory');
    if (!await dir.exists()) return const [];
    final entries = await dir.list().toList();
    return entries.whereType<File>().map((f) => f.path.split('/').last).toList()..sort();
  }

  @override
  Future<Uint8List> read(String name) => _file(name).readAsBytes();

  @override
  Future<void> write(String name, Uint8List bytes) async {
    final file = _file(name);
    await file.parent.create(recursive: true);
    // Written through a temporary file and renamed into place, so a sync
    // client never picks up a half-written backup.
    await writeFileAtomically(file.path, bytes);
  }

  @override
  Future<void> delete(String name) async {
    final file = _file(name);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<bool> exists(String name) => _file(name).exists();
}

/// Raised when the folder cannot be used as it is: the wrong vault, or
/// unreachable.
class BackupFolderException implements Exception {
  final String message;
  const BackupFolderException(this.message);
  @override
  String toString() => message;
}
