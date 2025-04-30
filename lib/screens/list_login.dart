import 'package:archinfotech/provider/login_entry_provider.dart';
import 'package:archinfotech/screens/item_login.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LoginListScreen extends StatefulWidget {
  @override
  _loginListScreenState createState() => _loginListScreenState();
}

class _loginListScreenState extends State<LoginListScreen> {
  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<LoginEntryProvider>(context);
    provider.loadEntries();
    final filteredPasswords =
        provider.entries.where((entry) {
          return entry.title.toLowerCase().contains(
                searchQuery.toLowerCase(),
              ) ||
              entry.username.toString().toLowerCase().contains(
                searchQuery.toLowerCase(),
              ) ||
              entry.website.toString().toLowerCase().contains(
                searchQuery.toLowerCase(),
              );
        }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
//focusNode: ,//
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filteredPasswords.length,
            itemBuilder: (ctx, index) => LoginItem(filteredPasswords[index]),
          ),
        ),
      ],
    );
  }
}
