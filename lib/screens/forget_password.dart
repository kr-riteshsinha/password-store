import 'package:archinfotech/models/profile.dart';
import 'package:archinfotech/provider/login_entry_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'change_password.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final username = TextEditingController();
  final hintQuestion = TextEditingController();
  final hintAnswer = TextEditingController();

  Future<void> validate() async {
    final name = username.text.trim().toLowerCase();
    final question = hintQuestion.text.trim().toLowerCase();
    final answer = hintAnswer.text.trim().toLowerCase();

    final loginProvider = context.read<LoginEntryProvider>();
    ProfileEntry? entry = await loginProvider.forgetPassword(
      name,
      question,
      answer,
    );
    if (entry != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Details don't match")));
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Add Login",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF6264A7),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: username,
              decoration: const InputDecoration(labelText: "Name"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: hintQuestion,
              decoration: const InputDecoration(labelText: "Hint Question"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: hintAnswer,
              decoration: const InputDecoration(labelText: "Hint Answer"),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel"),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: validate,
                  child: const Text("Validate"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
