import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/profile.dart';
import '../provider/login_entry_provider.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  late Map<String, TextEditingController> controllers;
  final Map<String, bool> _obscureFields = {'cur_pass': true, 'new_pass': true};

  final List<Map<String, dynamic>> fields = [
    {'label': 'Current Password', 'key': 'cur_pass', 'obscure': true},
    {'label': 'New Password', 'key': 'new_pass', 'obscure': true},
  ];

  @override
  void initState() {
    super.initState();
    controllers = {
      'cur_pass': TextEditingController(),
      'new_pass': TextEditingController(),
    };
  }

  Future<void> _submitChangePassword() async {
    if (controllers['cur_pass']!.text.isEmpty ||
        controllers['new_pass']!.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Both fields are required')));
      return;
    }
    var currPassword = controllers['cur_pass']!.text;
    var newPassword = controllers['new_pass']!.text;
    ProfileEntry? profile = await Provider.of<LoginEntryProvider>(
      context,
      listen: false,
    ).getProfile();

    if (profile == null || profile.password.trim() != currPassword.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Old Password does not match...')),
      );
      return;
    }

    ProfileEntry newProfile = profile.copyWith(password: newPassword);

    Provider.of<LoginEntryProvider>(
      context,
      listen: false,
    ).updateProfile(newProfile);

    // TODO: Replace with actual password change logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password changed successfully')),
    );

    Navigator.pop(context); // Or navigate to another screen if needed
  }

  void _cancelChange() {
    Navigator.pop(context);
  }

  @override
  void dispose() {
    for (var controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "change Password",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF6264A7),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ...fields.map(
              (field) => buildStyledTextField(
                field['label'],
                controllers[field['key']]!,
                obscure: field['obscure'] ?? false,
                optional: field['optional'] ?? false,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _submitChangePassword,
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
    );
  }

  Widget buildStyledTextField(
    String label,
    TextEditingController controller, {
    bool obscure = false,
    bool optional = false,
  }) {
    final key = fields.firstWhere((field) => field['label'] == label)['key'];
    final isSensitive = obscure;

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
          TextField(
            controller: controller,
            obscureText: isSensitive ? _obscureFields[key] ?? false : false,
            decoration: InputDecoration(
              hintText: label + (optional ? " (Optional)" : ""),
              filled: true,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.grey),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: const BorderSide(
                  color: Color(0xFF464EB8),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              suffixIcon:
                  isSensitive
                      ? IconButton(
                        icon: Icon(
                          (_obscureFields[key] ?? false)
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureFields[key] = !_obscureFields[key]!;
                          });
                        },
                      )
                      : null,
            ),
          ),
        ],
      ),
    );
  }
}
