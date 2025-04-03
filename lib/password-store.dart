import 'package:archinfotech/screens/list-password.dart';
import 'package:archinfotech/service/password_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PasswordStore extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _PasswordStore();
  }

}

class _PasswordStore extends State<PasswordStore> {

  Widget mainContent = const Center( child: const Text(" No Exenses Found"));

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PasswordProvider>(context);
    if (provider.passwords.isNotEmpty) {
      mainContent = PasswordListScreen();
    } else {
      Widget mainContent = const Center(
        child: Text('No expenses found. Start adding some!'),
      );
    }
    return  Scaffold(
        appBar: AppBar(
          title: const Text("List"),
          actions: [
            IconButton(onPressed: () {}, icon: const Icon(Icons.add))
          ],
        ),
        body: Column(
          children: [
            Expanded(child: mainContent)
          ],
        ),
    );
  }

}