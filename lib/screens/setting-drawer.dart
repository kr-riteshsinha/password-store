import 'package:archinfotech/screens/change_password.dart';
import 'package:archinfotech/screens/password_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingDrawer extends StatefulWidget {
  const SettingDrawer({super.key});

  @override
  State<SettingDrawer> createState() => _SettingDrawerState();
}

class _SettingDrawerState extends State<SettingDrawer> {
  String username = 'Guest';

  @override
  void initState() {
    super.initState();
    loadLoginDetails();
  }

  Future<void> loadLoginDetails() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      username = prefs.getString('username') ?? 'Guest';
    });
  }

  void logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const PasscodeLoginScreen()),
          (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = const Color(0xFF6264A7); // Teams purple-blue

    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.75,
      child: Drawer(
        backgroundColor: const Color(0xFFF5F6FA),
        child: Column(
          children: [
            Container(
              color: primaryColor,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_circle,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    username,
                    style: theme.textTheme.titleLarge!.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_2_rounded),
              title: const Text('Profile', style: TextStyle(fontSize: 18)),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.apple_sharp),
              title: const Text('ICloud', style: TextStyle(fontSize: 18)),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings', style: TextStyle(fontSize: 18)),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.lock_clock_rounded),
              title: const Text('Change Password', style: TextStyle(fontSize: 18)),
              onTap: () {
                Navigator.push(context,
                MaterialPageRoute(builder: (context) => ChangePasswordScreen())
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Logout', style: TextStyle(fontSize: 18)),
              onTap: logout,
            ),
          ],
        ),
      ),
    );
  }
}
