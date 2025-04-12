import 'package:archinfotech/screens/add-password.dart';
import 'package:archinfotech/screens/list-password.dart';
import 'package:archinfotech/service/password_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PasswordManagerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA), // light background like Teams
      appBar: AppBar(
        backgroundColor: const Color(0xFF464EB8), // Teams purple
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
                MaterialPageRoute(builder: (context) => AddPasswordScreen()),
              );
            },
            icon: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: PasswordListScreen(), // this will show list in nice padding
      ),
    );
  }
}
