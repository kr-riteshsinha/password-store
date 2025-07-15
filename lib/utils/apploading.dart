import 'package:flutter/material.dart';

class AppLoadingIndicator extends StatelessWidget {
  final Color? color;

  const AppLoadingIndicator({this.color, super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}