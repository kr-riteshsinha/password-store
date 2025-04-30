import 'package:archinfotech/screens/password_auth.dart';
import 'package:flutter/material.dart';

class SettingDrawer extends StatelessWidget {
  const SettingDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = const Color(0xFF6264A7); // Teams purple-blue

    void logout() {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const PasscodeLoginScreen()),
            (Route<dynamic> route) => false,
      );
    }
    return Container(
      width: MediaQuery.of(context).size.width * 0.75, // 75% of screen width
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
                    'Teams Panel',
                    style: theme.textTheme.titleLarge!.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.person_2_rounded,
                color: Colors.black87,
              ),
              title: const Text(
                'Profile',
                style: TextStyle(fontSize: 18, color: Colors.black87),
              ),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(
                Icons.apple_sharp,
                color: Colors.black87,
              ),
              title: const Text(
                'ICloud',
                style: TextStyle(fontSize: 18, color: Colors.black87),
              ),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(
                Icons.settings,
                color: Colors.black87,
              ),
              title: const Text(
                'Settings',
                style: TextStyle(fontSize: 18, color: Colors.black87),
              ),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(
                Icons.lock_clock_rounded,
                color: Colors.black87,
              ),
              title: const Text(
                'Change Password',
                style: TextStyle(fontSize: 18, color: Colors.black87),
              ),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(
                Icons.logout_rounded,
                color: Colors.black87,
              ),
              title: const Text(
                'Logout',
                style: TextStyle(fontSize: 18, color: Colors.black87),
              ),
              onTap: logout,
            ),
          ],
        ),
      ),
    );

  }
}
