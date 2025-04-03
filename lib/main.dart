import 'package:archinfotech/password-manager.dart';
import 'package:archinfotech/password-store.dart';
import 'package:archinfotech/service/password_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => PasswordProvider()),
          ChangeNotifierProvider(create: (_) => PasswordProvider()..fetchPasswords()),

        ],
    child:
    MaterialApp(
      home: PasswordManagerApp()
    ),
  )
  );
}