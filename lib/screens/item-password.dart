import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:archinfotech/service/password_provider.dart';

import '../models/passwordEntry.dart';
import 'edit-password.dart';

class PasswordItem extends StatelessWidget {
  const PasswordItem(this.passwordEntry, {super.key});

  final PasswordEntry passwordEntry;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(passwordEntry.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFF3B30), // iOS red color
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 28),
            SizedBox(height: 2),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (direction) {
        Provider.of<PasswordProvider>(context, listen: false)
            .deletePassword(passwordEntry.id!);

        // iOS-style swipe to delete undo snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${passwordEntry.category}" deleted'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'Undo',
              textColor: Colors.white,
              onPressed: () {
                Provider.of<PasswordProvider>(context, listen: false)
                    .addPassword(passwordEntry);
              },
            ),
          ),
        );
      },
      child: InkWell(
        onTap: () {
          // Replace with your edit password screen navigation
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditPasswordScreen(passwordEntry: passwordEntry),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Card(
          elevation: 0,
          margin: const EdgeInsets.only(), // Remove margin as it's handled by InkWell's parent
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 0.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  passwordEntry.category,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      passwordEntry.password,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}