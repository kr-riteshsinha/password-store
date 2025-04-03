import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/passwordEntry.dart';
import '../service/password_provider.dart';

class AddPasswordScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _AddPasswordScreen();
  }

}

class _AddPasswordScreen extends State<AddPasswordScreen> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();
  final TextEditingController expiryDateController = TextEditingController();
  bool isFavorite = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PasswordProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: Text('Add Password')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: usernameController, decoration: InputDecoration(labelText: 'Username')),
            TextField(controller: passwordController, decoration: InputDecoration(labelText: 'Password')),
            TextField(controller: categoryController, decoration: InputDecoration(labelText: 'Category')),
            TextField(controller: expiryDateController, decoration: InputDecoration(labelText: 'Expiry Date')),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Favorite', style: TextStyle(fontSize: 16)),
                Switch(
                  value: isFavorite,
                  onChanged: (value) {
                    setState(() {
                      isFavorite = value;
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final newEntry = PasswordEntry(
                  username: usernameController.text,
                  password: passwordController.text,
                  category: categoryController.text,
                  expiryDate: expiryDateController.text,
                );
                Provider.of<PasswordProvider>(context, listen: false).addPassword(newEntry);
                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }


}