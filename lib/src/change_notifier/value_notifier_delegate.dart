import 'package:flutter/foundation.dart';

import 'change_auto_listen.dart';

mixin ValueNotifierDelegate<T> on ValueNotifier<T> {
  ValueNotifier<T>? get notifierDelegate;

  @override
  T get value {
    if (notifierDelegate case ValueNotifier v) {
      v.autoListen();
    } else {
      autoListen();
    }
    return super.value;
  }

  @override
  bool get hasListeners {
    if (notifierDelegate case ValueNotifier v) {
      return v.hasListeners;
    } else {
      return super.hasListeners;
    }
  }

  @override
  void addListener(VoidCallback listener) {
    if (notifierDelegate case ValueNotifier v) {
      v.addListener(listener);
    } else {
      super.addListener(listener);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    if (notifierDelegate case ValueNotifier v) {
      v.removeListener(listener);
    } else {
      super.removeListener(listener);
    }
  }

  @override
  void notifyListeners() {
    if (notifierDelegate case ValueNotifier v) {
      v.notifyListeners();
    } else {
      super.notifyListeners();
    }
  }
}
