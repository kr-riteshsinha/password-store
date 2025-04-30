import 'package:archinfotech/screens/edit_login.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/login_entry.dart';
import '../provider/login_entry_provider.dart';


class LoginItem extends StatelessWidget {
  final LoginEntry loginEntry;

  const LoginItem(this.loginEntry, {super.key});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(loginEntry.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 1),
        decoration: BoxDecoration(
          color:  const Color(0xFFFF3B30),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 26),
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
        Provider.of<LoginEntryProvider>(context, listen: false)
            .deleteEntry(loginEntry.id!);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${loginEntry.title}" deleted'),
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
                Provider.of<LoginEntryProvider>(context, listen: false)
                    .addLoginEntry(loginEntry);
              },
            ),
          ),
        );
      },
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
               builder: (context) => EditLoginScreen(loginEntry: loginEntry),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white, //Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.grey.shade300,
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loginEntry.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              //const SizedBox(height: 6),
              _infoRow(context, label: 'Username:', value: loginEntry.username),
              //const SizedBox(height: 6),
              _infoRow(context, label: 'Password:', value: '••••••••', isPassword: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context,
      {required String label,
        required String value,
        bool isPassword = false}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black54,
          ),
        ),
       const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.grey,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 16, color: Colors.grey),
          tooltip: "Copy",
          onPressed: () {
            Clipboard.setData(ClipboardData(text: isPassword ? loginEntry.password : value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${isPassword ? 'Password' : 'Username'} copied to clipboard')),
            );
          },
        ),
      ],
    );
  }
}
