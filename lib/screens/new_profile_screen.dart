import 'package:archinfotech/models/profile.dart';
import 'package:archinfotech/provider/db_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/login_entry_provider.dart';

class CreateProfileScreen extends StatefulWidget {
  const CreateProfileScreen({Key? key}) : super(key: key);

  @override
  _CreateProfileScreenState createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final passwordController = TextEditingController();
  final hintController = TextEditingController();
  final hintAnswerController = TextEditingController();


  @override
  void dispose() {
    nameController.dispose();
    passwordController.dispose();
    hintController.dispose();
    super.dispose();
  }

  Future<void> saveProfile() async {
    if (_formKey.currentState!.validate()) {


      final profileEntry = ProfileEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: nameController.text,
        password: passwordController.text,
        hint: passwordController.text,
        answer: hintAnswerController.text,
      );

      Provider.of<LoginEntryProvider>(context, listen: false).addProfile(profileEntry);
      //Provider.of<LoginEntryProvider>(context, listen: false).addLoginEntry(newLogin);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile created successfully')),
      );

      // You can also navigate or save to database, etc.
    }
  }
  bool _obscurePasscode = true;
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Create Profile",
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
                        "New Profile",
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
                          labelText: "Name",
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
                          labelText: "Password",
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
                        value!.isEmpty ? 'Please enter a password' : null,

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
                          labelText: "Hint Answer",
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
                          "Save Profile",
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
