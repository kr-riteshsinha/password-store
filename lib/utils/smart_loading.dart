import 'package:flutter/material.dart';

import 'apploading.dart';

enum LoaderType {
  page, // Full page loader
  button, // Small button loader
  inline, // Inline content loader
}

class SmartLoader extends StatelessWidget {
  final LoaderType type;

  const SmartLoader({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case LoaderType.page:
        return const AppLoadingIndicator();
      case LoaderType.button:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case LoaderType.inline:
        return const LinearProgressIndicator();
    }
  }
}