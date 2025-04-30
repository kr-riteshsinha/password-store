import 'package:archinfotech/models/profile.dart';
import 'package:archinfotech/password-manager.dart';
import 'package:archinfotech/provider/login_entry_provider.dart';
import 'package:archinfotech/screens/new_profile_screen.dart';
import 'package:archinfotech/utils/page_transition.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';


class PasscodeLoginScreen extends StatefulWidget {
  const PasscodeLoginScreen({Key? key}) : super(key: key);

  @override
  _PasscodeLoginScreenState createState() => _PasscodeLoginScreenState();
}

class _PasscodeLoginScreenState extends State<PasscodeLoginScreen> {
  final passcodeController = TextEditingController();
  String validPasscode = "1234";

  Future<void> validatePasscode() async {
    final entered = passcodeController.text.trim();
    ProfileEntry? entry ;
    List<ProfileEntry> profileList  =  await Provider.of<LoginEntryProvider>(context, listen: false).getCurrentProfile();
    if(profileList.isNotEmpty) {
      entry = profileList.first;
    }else {
      // todo: throw some exception
    }
    if (entered.isEmpty) {
      showSnackbar("Please enter a passcode");
    } else if (entered == entry?.password) {
      showSnackbar("Login successful");
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PasswordManagerApp()),
      );
    } else {
      showSnackbar("Invalid passcode");
    }
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

  @override
  Widget build(BuildContext context) {
   // final passcodeController = TextEditingController();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Centered Login Card
          Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 2 / 3,
              child: Card(
                elevation: 8,
                color: Colors.white70, //Colors.white.withOpacity(0.95),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
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
                          "Enter Passcode",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF464EB8),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: passcodeController,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: "••••",
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: validatePasscode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6264A7),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 14,
                            ),
                          ),
                          child: const Text(
                            "Unlock",
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 20,),
                        TextButton.icon(
                          onPressed: () {
                           // Navigator.of(context).push(PageTransitions.createRoute(CreateProfileScreen()),
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => CreateProfileScreen()),

                            );
                          },
                          icon: const Icon(Icons.person_add, size: 18, color: Color(0xFF464EB8)),
                          label: const Text(
                            "Create New Profile",
                            style: TextStyle(
                              color: Color(0xFF464EB8),
                              fontSize: 14,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        )

                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
