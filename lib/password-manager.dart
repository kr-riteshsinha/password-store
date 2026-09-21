import 'package:archinfotech/screens/add-login.dart';
import 'package:archinfotech/screens/list_login.dart';
import 'package:archinfotech/screens/setting-drawer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'backup/backup_folder.dart';
import 'backup/backup_manager.dart';
import 'backup/backup_settings.dart';
import 'provider/login_entry_provider.dart';

class PasswordManagerApp extends StatefulWidget {
  const PasswordManagerApp({super.key});

  @override
  State<PasswordManagerApp> createState() => _PasswordManagerAppState();
}

class _PasswordManagerAppState extends State<PasswordManagerApp> {
  @override
  void initState() {
    super.initState();
    _backUpIfDue();
  }

  /// The daily backup (`docs/sync-design.md` §5.1). Runs once the vault is
  /// open, says nothing, and gives up quietly: a folder that is unmounted or
  /// no longer permitted must not stand between the user and their
  /// passwords. The backup screen shows when the last one happened.
  Future<void> _backUpIfDue() async {
    final provider = context.read<LoginEntryProvider>();
    final settings = BackupSettings();

    try {
      final path = await settings.folder();
      final key = provider.databaseKey;
      final meta = provider.meta;
      if (path == null || key == null || meta == null) return;

      final info = await BackupManager().backUpIfDue(
        folder: LocalBackupFolder(path),
        databaseKey: key,
        meta: meta,
        deviceId: provider.deviceId ?? '',
        deviceName: (await provider.getProfile())?.name,
        lastBackupAt: await settings.lastBackupAt(),
      );
      if (info != null) await settings.setLastBackupAt(info.takenAt);
    } catch (e) {
      debugPrint('Daily backup did not run: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      drawer: SettingDrawer(),// light background like Teams
      appBar: AppBar(

        backgroundColor: const Color(0xFF6264A7),//const Color(0xFF464EB8), // Teams purple
        elevation: 0,
        title: const Text(
          "Password Vault",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddLoginScreen()),
              );
            },
            icon: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: LoginListScreen(), // this will show list in nice padding
      ),
    );
  }
}
