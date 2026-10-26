import 'package:cupertino_ui/cupertino_ui.dart';

abstract class ChangeNotifierBase extends ChangeNotifier
    with ChangeNotifierMixin {}

mixin ChangeNotifierMixin on ChangeNotifier {
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
