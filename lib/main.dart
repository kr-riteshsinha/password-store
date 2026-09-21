import 'package:archinfotech/provider/LoadingProvider.dart';
import 'package:archinfotech/provider/platform_database.dart';
import 'package:archinfotech/provider/login_entry_provider.dart';
import 'package:archinfotech/screens/password_auth.dart';
import 'package:archinfotech/service/password_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Windows and Linux need sqflite pointed at the FFI implementation, and at
  // a real per-user directory, before anything opens the database
  // (ISSUES.md #27).
  await initPlatformDatabase();
  runApp(

      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => PasswordProvider()),
          ChangeNotifierProvider(create: (_) => PasswordProvider()..fetchPasswords()),
          ChangeNotifierProvider(create: (_) => LoginEntryProvider()),
          ChangeNotifierProvider(create: (_) => LoadingProvider()),

        ],
    child:
    MaterialApp(
      home: PasscodeLoginScreen()
    ),
  )
  );
}