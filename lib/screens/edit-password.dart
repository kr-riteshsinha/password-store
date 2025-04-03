import 'package:flutter/material.dart';
import 'package:archinfotech/models/passwordEntry.dart';
import 'package:provider/provider.dart';
import 'package:archinfotech/service/password_provider.dart';

class EditPasswordScreen extends StatefulWidget {
  const EditPasswordScreen({super.key, required this.passwordEntry});

  final PasswordEntry passwordEntry;

  @override
  State<EditPasswordScreen> createState() => _EditPasswordScreenState();
}

class _EditPasswordScreenState extends State<EditPasswordScreen> {
  late bool isFavorite;
  late PasswordEntry passwordEntry;

  @override
  void initState() {
    super.initState();
    this.passwordEntry = widget.passwordEntry;
    isFavorite = widget.passwordEntry.isFavorite ?? false;
  }

  void _toggleFavorite() {
    setState(() {
      isFavorite = !isFavorite;
    });
    this.passwordEntry.isFavorite = isFavorite;
    // Update the favorite status in the provider
    Provider.of<PasswordProvider>(context, listen: false).updatePassword(this.passwordEntry);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Password'),
        actions: [
          IconButton(
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? Colors.red : null,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
              initialValue: widget.passwordEntry.category,
              decoration: const InputDecoration(labelText: 'Category'),
              onChanged: (value) {
                widget.passwordEntry.category = value;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: widget.passwordEntry.username,
              decoration: const InputDecoration(labelText: 'Username'),
              onChanged: (value) {
                widget.passwordEntry.username = value;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: widget.passwordEntry.password,
              decoration: const InputDecoration(labelText: 'Password'),
              onChanged: (value) {
                widget.passwordEntry.password = value;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: widget.passwordEntry.expiryDate,
              decoration: const InputDecoration(labelText: 'Expiry Date'),
              onChanged: (value) {
                widget.passwordEntry.expiryDate = value;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Save the changes
                Provider.of<PasswordProvider>(context, listen: false)
                    .updatePassword(widget.passwordEntry);
                Navigator.pop(context);
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}