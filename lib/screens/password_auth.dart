import 'package:archinfotech/models/profile.dart';
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
  final usernameController = TextEditingController();
  String? _lastLoggedInUser;
  bool _showUserSwitch = false;
  List<ProfileEntry> _allProfiles = [];
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadAllProfiles();
    _loadLastLoggedInUser();
    _checkRecentAuth();
  }

  Future<void> _loadLastLoggedInUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastLoggedInUser = prefs.getString('lastLoggedInUser');
      if(_lastLoggedInUser !=null) {
        usernameController.text = _lastLoggedInUser!;
      }
      if(_allProfiles == null) {
        _loadAllProfiles();
      }
      _showUserSwitch = _allProfiles.length > 1;
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
  Future<void> _loadAllProfiles() async {
    _allProfiles = await Provider.of<LoginEntryProvider>(context,
      listen: false,
    ).getAllProfiles();

    if (_allProfiles.length > 1) {
      setState(() {
        _showUserSwitch = true;
      });
    }
  }

  Future<void> validatePasscode(BuildContext context) async {
    final loadingProvider = context.read<LoadingProvider>();
    await loadingProvider.whileLoading(() async {
      final enteredUsername = usernameController.text.trim();
      final entered = passcodeController.text.trim();
      ProfileEntry? entry;

      if (entered.isEmpty) {
        showSnackbar("Please enter a passcode");
      } else if (enteredUsername.isEmpty) {
        showSnackbar("Please enter a username");

      }
        ProfileEntry? profileEntry = await Provider.of<LoginEntryProvider>(
          context,
          listen: false,
        ).findProfileByName(enteredUsername);

        if (profileEntry !=null ) {
          if (profileEntry.password == entered) {
            Provider.of<LoginEntryProvider>(
              context,
              listen: false,
            ).saveLoginDetails(entry?.name);

            showSnackbar("Login successful");
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PasswordManagerApp()),
            );
          }
        } else {
        showSnackbar("Invalid passcode");
      }
    }, message: ' Logging in...');
  }

  void _showUserSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select User"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _allProfiles.length,
            itemBuilder: (context, index) {
              final profile = _allProfiles[index];
              return ListTile(
                title: Text(profile.name),
                onTap: () {
                  Provider.of<LoginEntryProvider>(
                    context,
                    listen: false,
                  ).switchProfile(profile.name);
                  Navigator.pop(context);
                  setState(() {
                    _lastLoggedInUser = profile.name;
                    usernameController.text=_lastLoggedInUser!;
                  });
                },
              );
            },
          ),
        ),
      ),
    );
  }
  void showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    passcodeController.dispose();
    super.dispose();
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
                    controller: usernameController,
                    decoration: InputDecoration(
                      labelText: "Username",
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: _showUserSwitch
                          ? IconButton(
                        icon: const Icon(Icons.arrow_drop_down),
                        onPressed: _showUserSelectionDialog,
                      )
                          : null,
                    ),
                    readOnly: _showUserSwitch,
                    onTap: _showUserSwitch ? _showUserSelectionDialog : null,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passcodeController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: "Password",
                      prefixIcon: const Icon(Icons.lock),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
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
                            MaterialPageRoute(
                              builder: (context) => ForgotPasswordScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          "Forgot Password?",
                          style: TextStyle(
                            color: Color(0xFF464EB8),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CreateProfileScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          "Create Account",
                          style: TextStyle(
                            color: Color(0xFF464EB8),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
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
