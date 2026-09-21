import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../backup/backup_folder.dart';
import '../backup/backup_manager.dart';
import '../backup/backup_settings.dart';
import '../provider/LoadingProvider.dart';
import '../provider/login_entry_provider.dart';

/// Backing the vault up to a folder the user chose — the settings drawer's
/// former `ICloud` placeholder.
///
/// This is backup, not sync: one device writes, the others restore. The
/// screen says so, because merging does not exist yet (#53) and a user who
/// believes otherwise will lose entries.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _settings = BackupSettings();
  final _manager = BackupManager();

  String? _folderPath;
  DateTime? _lastBackupAt;
  List<SnapshotInfo> _snapshots = const [];
  String? _error;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final path = await _settings.folder();
    final lastBackupAt = await _settings.lastBackupAt();
    var snapshots = const <SnapshotInfo>[];
    String? error;

    if (path != null) {
      try {
        snapshots = await _manager.listSnapshots(LocalBackupFolder(path));
      } catch (e) {
        error = 'That folder could not be read: $e';
      }
    }

    if (!mounted) return;
    setState(() {
      _folderPath = path;
      _lastBackupAt = lastBackupAt;
      _snapshots = snapshots;
      _error = error;
      _loaded = true;
    });
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _chooseFolder() async {
    final provider = context.read<LoginEntryProvider>();

    // The passcode is what protects a backup once it leaves the device, so
    // check it is long enough before anything is written anywhere.
    final passcode = await _askForPasscode();
    if (passcode == null) return;

    if (!await provider.passcodeIsCorrect(passcode)) {
      _say('That passcode is not correct.');
      return;
    }
    if (!BackupSettings.passcodeAllowsBackup(passcode)) {
      await _explain(BackupSettings.passcodeTooShortMessage);
      return;
    }

    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose a folder for your backups',
    );
    if (path == null) return;

    try {
      await _manager.checkVault(LocalBackupFolder(path), provider.vaultId);
    } on BackupFolderException catch (e) {
      _say(e.message);
      return;
    }

    await _settings.setFolder(path);
    await _load();
    if (mounted) _say('Backups will be written to this folder.');
  }

  Future<void> _backUpNow() async {
    final provider = context.read<LoginEntryProvider>();
    final loading = context.read<LoadingProvider>();
    final path = _folderPath;
    final key = provider.databaseKey;
    final meta = provider.meta;

    if (path == null) return;
    if (key == null || meta == null) {
      _say('Unlock the vault before backing it up.');
      return;
    }

    final folder = LocalBackupFolder(path);
    final warning = await _manager.otherDeviceWarning(
      folder,
      provider.deviceId ?? '',
    );
    if (warning != null && !await _confirm('Back up from this device?', warning)) {
      return;
    }

    try {
      await loading.whileLoading(() async {
        final info = await _manager.backUp(
          folder: folder,
          databaseKey: key,
          meta: meta,
          deviceId: provider.deviceId ?? '',
          deviceName: await _deviceName(),
        );
        await _settings.setLastBackupAt(info.takenAt);
      }, message: 'Backing up…');
      await _load();
      if (mounted) _say('Backed up.');
    } catch (e) {
      if (mounted) _say('Backup failed: $e');
    }
  }

  Future<void> _restore(SnapshotInfo snapshot) async {
    final provider = context.read<LoginEntryProvider>();
    final loading = context.read<LoadingProvider>();
    final path = _folderPath;
    final key = provider.databaseKey;
    if (path == null || key == null) return;

    final confirmed = await _confirm(
      'Restore this backup?',
      'Everything now in this vault is replaced by the backup from '
          '${_when(snapshot.takenAt)}. Anything saved since then, on this '
          'device, is lost.',
      confirmLabel: 'Replace my vault',
    );
    if (!confirmed) return;

    try {
      await loading.whileLoading(() async {
        await _manager.restore(
          folder: LocalBackupFolder(path),
          fileName: snapshot.fileName,
          databaseKey: key,
        );
      }, message: 'Restoring…');
    } catch (e) {
      if (mounted) _say('Restore failed: $e');
      return;
    }

    // The vault is closed after a restore, so the user unlocks the restored
    // one rather than carrying on with a vault that is no longer open.
    await provider.lock();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    _say('Restored. Unlock the vault to continue.');
  }

  Future<void> _forgetFolder() async {
    if (!await _confirm(
      'Stop backing up?',
      'The vault stays on this device and keeps working. Backups already in '
          'the folder are left alone.',
      confirmLabel: 'Stop',
    )) {
      return;
    }
    await _settings.setFolder(null);
    await _load();
  }

  Future<String?> _askForPasscode() async {
    final controller = TextEditingController();
    final passcode = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm your passcode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your backups are protected by this passcode and nothing else.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Passcode'),
              onSubmitted: (value) => Navigator.pop(context, value),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    return passcode;
  }

  Future<void> _explain(String message) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('A longer passcode is needed'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

  Future<bool> _confirm(
    String title,
    String message, {
    String confirmLabel = 'Continue',
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;

  Future<String> _deviceName() async =>
      (await context.read<LoginEntryProvider>().getProfile())?.name ?? 'this device';

  String _when(DateTime time) {
    final local = time.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Backup',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF6264A7),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _explanation(),
                const SizedBox(height: 16),
                if (_folderPath == null) _chooseFolderCard() else _folderCard(),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                if (_folderPath != null) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Backups',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (_snapshots.isEmpty)
                    const Text('No backups yet.')
                  else
                    ..._snapshots.map(_snapshotTile),
                ],
              ],
            ),
    );
  }

  Widget _explanation() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEDEDF7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Your vault is copied, still encrypted, to a folder you choose — '
          'iCloud Drive, Dropbox, Google Drive or anywhere else. Only your '
          'passcode can open it.\n\n'
          'This is a backup, not sync: edit your vault on one device. Another '
          'device can restore a backup, but it will not merge changes yet.',
        ),
      );

  Widget _chooseFolderCard() => Card(
        child: ListTile(
          leading: const Icon(Icons.folder_open),
          title: const Text('Choose a backup folder'),
          subtitle: const Text('Pick a folder your cloud storage already syncs'),
          onTap: _chooseFolder,
        ),
      );

  Widget _folderCard() => Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.folder),
              title: Text(_folderPath!),
              subtitle: Text(
                _lastBackupAt == null
                    ? 'Not backed up yet'
                    : 'Last backed up ${_when(_lastBackupAt!)}',
              ),
            ),
            const Divider(height: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: _backUpNow,
                  icon: const Icon(Icons.backup),
                  label: const Text('Back up now'),
                ),
                TextButton.icon(
                  onPressed: _chooseFolder,
                  icon: const Icon(Icons.drive_file_move),
                  label: const Text('Change folder'),
                ),
                TextButton.icon(
                  onPressed: _forgetFolder,
                  icon: const Icon(Icons.link_off),
                  label: const Text('Stop'),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _snapshotTile(SnapshotInfo snapshot) => ListTile(
        leading: const Icon(Icons.history),
        title: Text(_when(snapshot.takenAt)),
        trailing: TextButton(
          onPressed: () => _restore(snapshot),
          child: const Text('Restore'),
        ),
      );
}
