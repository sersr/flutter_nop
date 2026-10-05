import 'dart:collection';

import 'package:flutter/material.dart';

import '../../change_notifier.dart';

typedef AList<E> = AutoListenList<E>;

class AutoListenList<E> extends ValueNotifier<List<E>> with ListBase<E> {
  AutoListenList(super._value, {this._notifierDelegate});
  List<E> get _value => value;
  final ValueNotifier<List<E>>? _notifierDelegate;
  @override
  List<E> get value {
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
  int get length => value.length;

  @override
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
