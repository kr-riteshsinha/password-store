import 'package:flutter/cupertino.dart';

class LoadingProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _loadingMessage;

  bool get isLoading => _isLoading;
  String? get loadingMessage => _loadingMessage;

  void startLoading([String? message]) {
    _isLoading = true;
    _loadingMessage = message;
    notifyListeners();
  }

  void stopLoading() {
    _isLoading = false;
    _loadingMessage = null;
    notifyListeners();
  }

  Future<T> whileLoading<T>(Future<T> Function() asyncFunction,
      {String? message}) async {
    startLoading(message);
    try {
      return await asyncFunction();
    } finally {
      stopLoading();
    }
  }
}