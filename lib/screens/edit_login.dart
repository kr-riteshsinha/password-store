import 'package:archinfotech/provider/login_entry_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../models/login_entry.dart';

class EditLoginScreen extends StatefulWidget {
  final LoginEntry loginEntry;

  const EditLoginScreen({super.key, required this.loginEntry});

  @override
  _EditLoginScreenState createState() => _EditLoginScreenState();
}

class _EditLoginScreenState extends State<EditLoginScreen> {
  late Map<String, TextEditingController> controllers;
  final Map<String, bool> _obscureFields = {
    'username': true,
    'password': true,
  };

  final List<Map<String, dynamic>> fields = [
    {'label': 'Title', 'key': 'title'},
    {'label': 'Username', 'key': 'username', 'obscure': true},
    {'label': 'Password', 'key': 'password', 'obscure': true},
    {'label': 'Website', 'key': 'website'},
    {'label': 'TOTP Secret', 'key': 'totpSecret', 'optional': true},
  ];

  @override
  void initState() {
    super.initState();
    controllers = {
      'title': TextEditingController(text: widget.loginEntry.title),
      'username': TextEditingController(text: widget.loginEntry.username),
      'password': TextEditingController(text: widget.loginEntry.password),
      'website': TextEditingController(text: widget.loginEntry.website),
      'totpSecret': TextEditingController(text: widget.loginEntry.totpSecret ?? ''),
    };
  }

  @override
  void dispose() {
    for (var controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void copyToClipboard(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  void saveLogin() {
    if (controllers['title']!.text.isEmpty ||
        controllers['username']!.text.isEmpty ||
        controllers['password']!.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    final updated = LoginEntry(
      id: widget.loginEntry.id,
      title: controllers['title']!.text,
      username: controllers['username']!.text,
      password: controllers['password']!.text,
      website: controllers['website']!.text,
      totpSecret: controllers['totpSecret']!.text.isNotEmpty
          ? controllers['totpSecret']!.text
          : null,
    );

    Provider.of<LoginEntryProvider>(context, listen: false).updateEntry(updated);
    Navigator.pop(context);
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIcon: isSensitive
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Edit Login",
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
              onPressed: saveLogin,
              icon: const Icon(Icons.save_alt_sharp, color: Colors.white),
              label: const Text("Save"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6264A7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

