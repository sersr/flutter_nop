import 'package:flutter/foundation.dart';

mixin NotifyStateMixin {
  final _notifier = ValueNotifier(false);
  ValueListenable<bool> get stateNotifier => _notifier;

  void notifyState(bool open) => _notifier.value = open;
  void _addListener(VoidCallback callback) {
    _notifier.addListener(callback);
  }

  void _removeListener(VoidCallback callback) {
    _notifier.removeListener(callback);
  }
}

mixin NotifyStateOnChangeNotifier on ChangeNotifier {
  NotifyStateMixin? _handle;
  set handle(NotifyStateMixin? newHandle) {
    if (_handle != newHandle) {
      if (_added) {
        _handle?._removeListener(_listen);
        _added = false;
      }
      _handle = newHandle;
      if (_handle != null && hasListeners) {
        _added = true;
        _handle?._addListener(_listen);
      }
    }
  }

  void _listen() {
    if (_handle == null && !hasListeners) return;
    final open = _handle!._notifier.value;
    if (open) {
      onOpen();
    } else {
      onClose();
    }
  }

  bool _added = false;
  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    if (!_added && hasListeners) {
      _added = true;
      _handle?._addListener(_listen);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (hasListeners) return;
    if (!hasListeners && _added) {
      _added = false;
      _handle?._removeListener(_listen);
    }
  }

  @override
  void dispose() {
    handle = null;
    super.dispose();
  }

  void onOpen() {}
  void onClose() {}
}
