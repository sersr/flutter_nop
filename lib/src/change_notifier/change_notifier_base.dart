import 'package:flutter/cupertino.dart';

abstract class ChangeNotifierBase with ChangeNotifier {
  @override
  void notifyListeners() {
    if (_disposed) return;
    if (hasListeners) super.notifyListeners();
  }

  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
