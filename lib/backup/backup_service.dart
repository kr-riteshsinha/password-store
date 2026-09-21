import 'dart:io';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../provider/db_helper.dart';
import 'atomic_file.dart';
import 'vault_snapshot.dart';

/// Takes and restores sealed snapshots of the vault
/// (`docs/sync-design.md` §5.1).
///
/// This class knows nothing about where snapshots end up: it hands back
/// bytes, and takes bytes. Choosing a folder and writing to it is the next
/// phase (#55).
class BackupService {
  /// How many snapshots to keep. Ten daily ones is roughly ten days of
  /// history (design, DECIDED 4).
  static const keepSnapshots = 10;

  final DbHelper _db;

  /// Makes a **fresh** directory for temporary files, which this service
  /// deletes when it is done. It must not hand back a directory holding
  /// anything else: the whole thing is removed.
  final Directory Function() temporaryDirectory;

  BackupService({
    DbHelper? db,
    Directory Function()? temporaryDirectory,
  })  : _db = db ?? DbHelper.instance,
        temporaryDirectory = temporaryDirectory ?? Directory.systemTemp.createTempSync;

  /// Produces a sealed snapshot of the vault as it is right now.
  ///
  /// The intermediate copy is encrypted for its whole life and deleted
  /// afterwards, so a backup never leaves a readable vault behind on disk.
  Future<Uint8List> createSnapshot(Uint8List databaseKey) async {
    final directory = temporaryDirectory();
    final copy = File('${directory.path}/snapshot.db');
    try {
      await _db.exportEncryptedCopy(copy.path, databaseKey);
      final bytes = await copy.readAsBytes();
      return VaultSnapshot.seal(bytes, databaseKey);
    } finally {
      await _deleteQuietly(copy);
      await _deleteQuietly(directory);
    }
  }

  /// Replaces the vault with the one in [snapshot].
  ///
  /// Everything that can fail — a file that is not a backup, a newer format,
  /// a wrong key, a snapshot that will not open as a database — fails
  /// **before** the local vault is touched. The vault is left closed; the
  /// caller unlocks it again.
  Future<void> restoreSnapshot(Uint8List snapshot, Uint8List databaseKey) async {
    final database = await VaultSnapshot.open(snapshot, databaseKey);

    // Staged **beside the vault**, not in the system temp directory: the
    // final step renames it over the vault, and rename only works within one
    // filesystem. On Linux /tmp is often tmpfs while the vault is under the
    // home directory, so a temp-directory candidate would fail to move — and
    // it would fail after the vault had already been closed, locking the
    // user out of a vault that was never damaged.
    final candidate = File(
      '${await _db.vaultDirectory()}/restore-${DateTime.now().millisecondsSinceEpoch}.db.tmp',
    );
    try {
      await writeFileAtomically(candidate.path, database);
      await _verifyOpens(candidate.path, databaseKey);
      await _db.replaceDatabaseFile(candidate.path);
    } finally {
      await _deleteQuietly(candidate);
    }
  }

  /// Opens the candidate **and reads from it** before it replaces anything.
  ///
  /// Opening alone proves very little: SQLite is lazy, so a file of garbage
  /// can "open" and only fail when something touches a page. Counting the
  /// entries forces it to read the schema and the data, so a snapshot that
  /// decrypts but is not a usable vault cannot overwrite a working one.
  Future<void> _verifyOpens(String path, Uint8List databaseKey) async {
    Database? candidate;
    int? schemaVersion;
    try {
      // Detached: a failed check must leave the user's own vault open and
      // untouched, not closed behind them.
      candidate = await _db.openDetached(path, databaseKey);
      await candidate.rawQuery('SELECT count(*) FROM login_entries');
      await candidate.rawQuery('SELECT count(*) FROM profile');
      final rows = await candidate.rawQuery('PRAGMA user_version');
      schemaVersion = rows.isEmpty ? null : rows.first.values.first as int?;
    } catch (e) {
      throw SnapshotException('This backup did not open as a vault: $e');
    } finally {
      await candidate?.close();
    }

    // A snapshot from a newer build would pass every check above and then be
    // silently stamped back down to this schema version on the next open,
    // leaving a newer schema wearing an older label — which breaks for good
    // when that build catches up and re-runs its migration.
    if (schemaVersion != null && schemaVersion > DbHelper.schemaVersion) {
      throw SnapshotException(
        'This backup was made by a newer version of the app '
        '(database version $schemaVersion). Update before restoring it.',
      );
    }
  }

  /// The snapshot names the caller should **delete**: everything older than
  /// the [keepSnapshots] most recent ones. Files that are not snapshots are
  /// ignored, never deleted.
  static List<String> snapshotsToDelete(Iterable<String> fileNames) {
    final snapshots = fileNames
        .where((name) => VaultSnapshot.timeOf(name) != null)
        .toList()
      ..sort((a, b) => VaultSnapshot.timeOf(b)!.compareTo(VaultSnapshot.timeOf(a)!));
    return snapshots.length <= keepSnapshots
        ? const []
        : snapshots.sublist(keepSnapshots);
  }

  Future<void> _deleteQuietly(FileSystemEntity entity) async {
    try {
      if (await entity.exists()) await entity.delete(recursive: true);
    } catch (_) {
      // A leftover temporary file is not worth failing a backup over.
    }
  }
}
