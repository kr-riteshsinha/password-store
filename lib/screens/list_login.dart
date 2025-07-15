import 'package:archinfotech/provider/login_entry_provider.dart';
import 'package:archinfotech/screens/item_login.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/LoadingProvider.dart';
import '../utils/loadingOverlay.dart';

class LoginListScreen extends StatefulWidget {
  const LoginListScreen({super.key});

  @override
  _loginListScreenState createState() => _loginListScreenState();
}

class _loginListScreenState extends State<LoginListScreen> {
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEntries();
      });
  }

  Future<void> _loadEntries() async {
    final loadingProvider = context.read<LoadingProvider>();
    final loginProvider = context.read<LoginEntryProvider>();
    await loadingProvider.whileLoading(() async {
      await loginProvider.loadEntries();
    }, message: "Loading saved passwords...");
  }


  @override
  Stack build(BuildContext context)  {
    final provider = context.watch<LoginEntryProvider>();
    final entries = provider.entries;

    // provider.loadEntries();
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

    return Stack(
      children: [
        Column(
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
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filteredPasswords.length,
                itemBuilder: (ctx, index) =>
                    LoginItem(filteredPasswords[index]),
              ),
            ),
          ],
        ),

        // 👇 Overlay your custom loading animator or spinner
        const LoadingOverlay(), // Or LoadAnimator() if you've built one
      ],
    );
  }
}
