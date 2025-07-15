import 'package:archinfotech/provider/login_entry_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/login_entry.dart';

class AddLoginScreen extends StatefulWidget {
  const AddLoginScreen({super.key});

  @override
  _AddLoginScreenState createState() => _AddLoginScreenState();
}

class _AddLoginScreenState extends State<AddLoginScreen> {
  final titleController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final websiteController = TextEditingController();
  final totpSecretController = TextEditingController();

  @override
  void dispose() {
    titleController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    websiteController.dispose();
    totpSecretController.dispose();
    super.dispose();
  }

  void copyToClipboard(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  void saveLogin() {
    if (titleController.text.isEmpty || usernameController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    final newLogin = LoginEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: titleController.text,
      username: usernameController.text,
      password: passwordController.text,
      website: websiteController.text,
      totpSecret: totpSecretController.text.isEmpty ? null : totpSecretController.text,
    );

    Provider.of<LoginEntryProvider>(context, listen: false).addLoginEntry(newLogin);
    Navigator.pop(context);
  }

  Widget buildTextField(String label, TextEditingController controller,
      {bool obscure = false, bool optional = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            optional ? '$label (Optional)' : label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    hintText: label,
                    filled: true,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF464EB8), width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 20, color: Colors.grey),
                onPressed: () => copyToClipboard(label, controller.text),
              ),
            ],
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Add Login",style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: Colors.white,
        )),
        backgroundColor: const Color(0xFF6264A7),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        // child: Card(
        //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        //   elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                buildTextField("Title", titleController),
                buildTextField("Username", usernameController),
                buildTextField("Password", passwordController, obscure: true),
                buildTextField("Website", websiteController),
                buildTextField("TOTP Secret", totpSecretController, optional: true),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: saveLogin,
                  icon: const Icon(Icons.save_alt_sharp, color: Colors.white),
                  label: const Text("Save"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6264A7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),

                  ),
                ),
              ],
            ),
          ),
        ),
     );
  }
}
