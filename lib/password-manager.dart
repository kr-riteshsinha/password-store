import 'package:archinfotech/screens/add-login.dart';
import 'package:archinfotech/screens/list_login.dart';
import 'package:archinfotech/screens/setting-drawer.dart';
import 'package:flutter/material.dart';

class PasswordManagerApp extends StatelessWidget {

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
