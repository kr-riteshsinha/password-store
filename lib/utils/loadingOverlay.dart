import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/LoadingProvider.dart';

class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<LoadingProvider, bool>(
          (provider) => provider.isLoading,
    );
    final message = context.select<LoadingProvider, String?>(
          (provider) => provider.loadingMessage,
    );

    return Stack(
      children: [
        if (isLoading)
          ModalBarrier(
            dismissible: false,
            color: Colors.black.withOpacity(0.3),
          ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: isLoading
              ? Center(
            key: const ValueKey('loading'),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFF6264A7), // Microsoft Teams primary color
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xFF6264A7), // Text in Teams-style blue
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          )
              : const SizedBox.shrink(key: ValueKey('empty')),
        ),
      ],
    );
  }
}
