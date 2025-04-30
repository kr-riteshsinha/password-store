import 'package:archinfotech/password-manager.dart';
import 'package:archinfotech/provider/login_entry_provider.dart';
import 'package:archinfotech/screens/password_auth.dart';
import 'package:archinfotech/service/password_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';



void main() {
  runApp(

      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => PasswordProvider()),
          ChangeNotifierProvider(create: (_) => PasswordProvider()..fetchPasswords()),
          ChangeNotifierProvider(create: (_) => LoginEntryProvider()),
        ],
    child:
    MaterialApp(
      home: PasscodeLoginScreen()
    ),
  )
  );
}