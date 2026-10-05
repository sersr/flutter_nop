import 'dart:collection';

import 'package:flutter/material.dart';

import '../../change_notifier.dart';

typedef AMap<K, V> = AutoListenMap<K, V>;

class AutoListenMap<K, V> extends ValueNotifier<Map<K, V>> with MapMixin<K, V> {
  AutoListenMap(super._parent, {this._notifierDelegate});

  Map<K, V> get _parent => value;

  final ValueNotifier<Map<K, V>>? _notifierDelegate;

  @override
  Map<K, V> get value {
    if (_notifierDelegate case ValueNotifier v) {
      v.autoListen();
    } else {
      autoListen();
    }
    return super.value;
  }

  @override
  void notifyListeners() {
    if (_notifierDelegate case ValueNotifier v) {
      v.notifyListeners();
    } else {
      super.notifyListeners();
    }
  }

  @override
  V? operator [](Object? key) {
    autoListen();
    return _parent[key];
  }

  @override
  void operator []=(key, value) {
    if (!identical(_parent[key], value)) {
      _parent[key] = value;
      notifyListeners();
    }
  }

  @override
  void clear() {
    if (_parent.isNotEmpty) {
      _parent.clear();
      notifyListeners();
    }
  }

  @override
  Iterable<K> get keys {
    autoListen();
    return _parent.keys;
  }

  @override
  V? remove(Object? key) {
    final value = _parent.remove(key);
    if (value != null) {
      notifyListeners();
    }
    return value;
  }
}
