import 'package:archinfotech/provider/login_entry_provider.dart';
import 'package:archinfotech/screens/new_profile_screen.dart';
import 'package:archinfotech/utils/loadingOverlay.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../password-manager.dart';
import '../provider/LoadingProvider.dart';
import 'forget_password.dart';

class PasscodeLoginScreen extends StatefulWidget {
  const PasscodeLoginScreen({super.key});

  @override
  _PasscodeLoginScreenState createState() => _PasscodeLoginScreenState();
}

class _PasscodeLoginScreenState extends State<PasscodeLoginScreen> {
  final passcodeController = TextEditingController();
  bool _obscurePassword = true;

  /// What kind of vault is on this device. Null until it has been checked.
  VaultState? _vaultState;

  bool? get _hasProfile =>
      _vaultState == null ? null : _vaultState != VaultState.none;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkRecentAuth();
  }

  Future<void> _loadProfile() async {
    final state = await context.read<LoginEntryProvider>().vaultState();
    if (!mounted) return;
    setState(() {
      _vaultState = state;
    });
  }

  Future<void> _checkRecentAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final lastAuthTime = prefs.getInt('lastAuthTime');
    if (lastAuthTime != null) {
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final fifteenMinutesInMillis = 15 * 60 * 1000;

      if (currentTime - lastAuthTime < fifteenMinutesInMillis) {
        // Skip login if last auth was less than 15 minutes ago
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => PasswordManagerApp()),
          );
        }
      }
    }
  }

  Future<void> validatePasscode(BuildContext context) async {
    final loadingProvider = context.read<LoadingProvider>();
    final loginProvider = context.read<LoginEntryProvider>();
    await loadingProvider.whileLoading(() async {
      final entered = passcodeController.text.trim();

      if (entered.isEmpty) {
        showSnackbar("Please enter a passcode");
        return;
      }

      final state = _vaultState ?? await loginProvider.vaultState();
      if (state == VaultState.none) {
        showSnackbar("No vault yet. Create one first.");
        return;
      }

      // The vault has no stored passcode: the right one unwraps the database
      // key, a wrong one fails to.
      final unlocked = await loginProvider.unlockWithPasscodeAndOpen(entered);
      if (!mounted) return;

      if (!unlocked) {
        showSnackbar("Invalid passcode");
        return;
      }

      final profile = await loginProvider.getProfile();
      await loginProvider.saveLoginDetails(profile?.name ?? '');
      if (!mounted) return;

      showSnackbar("Login successful");
      Navigator.push(
        this.context,
        MaterialPageRoute(builder: (context) => PasswordManagerApp()),
      );
    }, message: ' Logging in...');
  }

  void showSnackbar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    passcodeController.dispose();
    super.dispose();
  }

  /// First launch: there is no vault yet, so the only step is to create one.
  List<Widget> _buildFirstRun() {
    return [
      const Text(
        "Welcome",
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF464EB8),
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        "Set a passcode to create your vault on this device.",
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CreateProfileScreen()),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6264A7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(double.infinity, 50),
        ),
        child: const Text(
          "Set Up Vault",
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
    ];
  }

  List<Widget> _buildLogin() {
    return [
      const Text(
        "Login",
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF464EB8),
        ),
      ),
      const SizedBox(height: 24),
      TextField(
        controller: passcodeController,
        obscureText: _obscurePassword,
        decoration: InputDecoration(
          labelText: "Passcode",
          prefixIcon: const Icon(Icons.lock),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility : Icons.visibility_off,
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
        ),
      ),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: () {
          validatePasscode(context);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6264A7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(double.infinity, 50),
        ),
        child: const Text(
          "Login",
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ForgotPasswordScreen()),
              );
            },
            child: const Text(
              "Forgot Passcode?",
              style: TextStyle(
                color: Color(0xFF464EB8),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Card(
            elevation: 8,
            color: Colors.white70,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Lottie.asset(
                    'assets/animations/lock.json',
                    height: 120,
                    repeat: true,
                  ),
                  const SizedBox(height: 16),
                  if (_hasProfile == false)
                    ..._buildFirstRun()
                  else
                    ..._buildLogin(),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: const LoadingOverlay(),
    );
  }
}
