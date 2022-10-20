import 'dart:collection';

import 'package:flutter/material.dart';

import '../../change_notifier.dart';

extension AutoMap<K, V> on Map<K, V> {
  AutoListenMap<K, V> get cs {
    return AutoListenMap(this);
  }
}

class AutoListenMap<K, V> extends ChangeNotifier
    with MapMixin<K, V>, AutoListenChangeNotifierMixin {
  AutoListenMap(this.parent);

  final Map<K, V> parent;

  @override
  V? operator [](Object? key) {
    autoListen();
    return parent[key];
  }

  @override
  void operator []=(key, value) {
    if (!identical(parent[key], value)) {
      parent[key] = value;
      notifyListeners();
    }
  }

  @override
  void clear() {
    if (parent.isNotEmpty) {
      parent.clear();
      notifyListeners();
    }
  }

  @override
  Iterable<K> get keys {
    autoListen();
    return parent.keys;
  }

  @override
  V? remove(Object? key) {
    final value = parent.remove(key);
    if (value != null) {
      notifyListeners();
    }
    return value;
  }
}
