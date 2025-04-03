import 'package:archinfotech/models/passwordEntry.dart';
import 'package:archinfotech/screens/item-password.dart';
import 'package:archinfotech/service/password_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PasswordListScreen extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PasswordProvider>(context);
    List<PasswordEntry>  passwordItemLsit = provider.passwords;

    return ListView.builder(
      itemCount: provider.passwords.length,
      itemBuilder: (ctx, index) => Dismissible(
        key: ValueKey(provider.passwords[index]),
        background: Container(
          color: Theme.of(context).colorScheme.error.withOpacity(0.75),

        ),
        onDismissed: (direction) {
        //  onRemoveExpense(passwordlist[index]);
        },
        child: PasswordItem(provider.passwords[index])
      ),
    );
  }


}