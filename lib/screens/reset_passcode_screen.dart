import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/login_entry_provider.dart';
import '../utils/passcode_rules.dart';
import 'password_auth.dart';

/// Sets a new vault passcode after the recovery answer has been verified.
/// Unlike [ChangePasswordScreen], it doesn't ask for the current passcode.
class ResetPasscodeScreen extends StatefulWidget {
  const ResetPasscodeScreen({super.key});

  @override
  State<ResetPasscodeScreen> createState() => _ResetPasscodeScreenState();
}

class _ResetPasscodeScreenState extends State<ResetPasscodeScreen> {
  final passcodeController = TextEditingController();
  final confirmController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    passcodeController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  void showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final error = newPasscodeError(passcodeController.text, confirmController.text);
    if (error != null) {
      showSnackbar(error);
      return;
    }
    final reset = await context.read<LoginEntryProvider>().resetPasscode(
      passcodeController.text.trim(),
    );
    if (!mounted) return;
    if (!reset) {
      showSnackbar('No vault found on this device');
      return;
    }
    showSnackbar('Passcode reset. Log in with your new passcode.');
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const PasscodeLoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Reset Passcode",
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
              controller: passcodeController,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: "New Passcode",
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: _obscure,
              decoration: const InputDecoration(labelText: "Confirm New Passcode"),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}
