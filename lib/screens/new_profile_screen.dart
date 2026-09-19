import 'package:archinfotech/password-manager.dart';
import 'package:archinfotech/utils/passcode_rules.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/login_entry_provider.dart';

class CreateProfileScreen extends StatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  _CreateProfileScreenState createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  final hintController = TextEditingController();
  final hintAnswerController = TextEditingController();


  @override
  void dispose() {
    nameController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    hintController.dispose();
    hintAnswerController.dispose();
    super.dispose();
  }

  Future<void> saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // Single-profile vault: only one profile can ever be created.
    final loginProvider = Provider.of<LoginEntryProvider>(context, listen: false);
    if (await loginProvider.getProfile() != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A vault already exists on this device')),
      );
      return;
    }
    final profile = await loginProvider.createVault(
      name: nameController.text,
      passcode: passwordController.text.trim(),
      hintQuestion: hintController.text,
      hintAnswer: hintAnswerController.text,
    );
    await loginProvider.saveLoginDetails(profile.name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vault created')),
    );
    // Setting the passcode is the first login, so go straight to the vault.
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => PasswordManagerApp()),
      (route) => false,
    );
  }
  bool _obscurePasscode = true;
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Set Up Your Vault",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF464EB8),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 2 / 3,
            child: Card(
              elevation: 8,
              color: Colors.white70,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Create your vault",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF464EB8),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: "Your name",
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) =>
                        value!.isEmpty ? 'Please enter your name' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: passwordController,
                        obscureText: _obscurePasscode,
                        decoration: InputDecoration(
                          labelText: "Passcode",
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(onPressed: (){
                            setState(() {
                              _obscurePasscode = !_obscurePasscode;
                            });

                          }, icon: Icon(
                            _obscurePasscode  ? Icons.visibility_off:Icons.visibility,
                          )
                          )
                        ),
                        validator: (value) =>
                        newPasscodeError(value!, value),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: confirmController,
                        obscureText: _obscurePasscode,
                        decoration: InputDecoration(
                          labelText: "Confirm passcode",
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) =>
                        value != passwordController.text ? "Passcodes don't match" : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: hintController,
                        decoration: InputDecoration(
                          labelText: "Hint Question (e.g. Your favorite color?)",
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) =>
                        value!.isEmpty ? 'Please enter a hint question' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: hintAnswerController,
                        decoration: InputDecoration(
                          labelText: "Answer (used if you forget the passcode)",
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) =>
                        value!.trim().isEmpty ? 'Please enter an answer' : null,
                      ),

                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: saveProfile,
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
                          "Create Vault",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
