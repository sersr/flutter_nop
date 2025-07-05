import 'dart:collection';

import 'package:flutter/material.dart';

import '../../change_notifier.dart';

extension ChangeList<E> on List<E> {
  ChangeAutoListenList<E> get cs {
    return ChangeAutoListenList(this);
  }
}

class ChangeAutoListenList<E>
    with ListBase<E>, ChangeNotifier, AutoListenChangeNotifierMixin {
  ChangeAutoListenList(this._value);
  List<E> _value;
  List<E> get value {
    autoListen();
    return _value;
  }

  set value(List<E> list) {
    if (_value == list) return;
    _value = list;
    notifyListeners();
  }

  @override
  int get length => value.length;

  void add(E element) {
    _value.add(element);
    notifyListeners();
  }

  @override
  E operator [](int index) {
    return value[index];
  }

  @override
  void operator []=(int index, E value) {
    _value[index] = value;
    notifyListeners();
  }

  @override
  set length(int newLength) {
    _value.length = newLength;
    notifyListeners();
  }

  @override
  void insertAll(int index, Iterable<E> iterable) {
    _value.insertAll(index, iterable);
    notifyListeners();
  }

  @override
  void addAll(Iterable<E> iterable) {
    _value.addAll(iterable);
    notifyListeners();
  }

  @override
  void sort([int Function(E a, E b)? compare]) {
    _value.sort(compare);
    notifyListeners();
  }
}
