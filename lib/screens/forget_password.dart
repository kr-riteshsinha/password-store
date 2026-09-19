import 'package:archinfotech/provider/login_entry_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'reset_passcode_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final hintAnswer = TextEditingController();

  /// The stored recovery question, or null when there is none to show.
  String? _question;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadQuestion();
  }

  Future<void> _loadQuestion() async {
    final question = await context.read<LoginEntryProvider>().recoveryQuestion();
    if (!mounted) return;
    setState(() {
      _question = question;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    hintAnswer.dispose();
    super.dispose();
  }

  Future<void> validate() async {
    final matches = await context
        .read<LoginEntryProvider>()
        .verifyRecoveryAnswer(hintAnswer.text);
    if (!mounted) return;
    if (matches) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ResetPasscodeScreen()),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("That answer doesn't match")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Forgot Passcode",
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              !_loaded
                  ? ''
                  : _question ?? 'Enter the answer to your recovery question.',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: hintAnswer,
              decoration: const InputDecoration(labelText: "Answer"),
              onSubmitted: (_) => validate(),
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
                  child: const Text("Continue"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
