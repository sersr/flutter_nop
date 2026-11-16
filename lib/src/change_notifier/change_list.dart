import 'dart:math';

import 'package:flutter/foundation.dart';

import 'change_auto_listen.dart';

typedef AList<E> = AutoListenList<E>;

extension type AutoListenList<E>(ValueNotifier<List<E>> target)
    implements ValueNotifier<List<E>> {
  AutoListenList.val(List<E> list) : this(.new(list));

  List<E> get _value => target.value;

  List<E> get value {
    autoListen();
    return target.value;
  }

  set value(List<E> newValue) {
    target.value = newValue;
  }

  void notify() {
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    target.notifyListeners();
  }

  int get length => value.length;

  set length(int newLength) {
    _value.length = newLength;
    notify();
  }

  E get first => value.first;

  set first(E element) {
    _value.first = element;
    notify();
  }

  E get last => value.last;

  set last(E element) {
    _value.last = element;
    notify();
  }

  E get single => value.single;

  E operator [](int index) => value[index];

  void operator []=(int index, E element) {
    _value[index] = element;
    notify();
  }

  List<E> operator +(List<E> other) => value + other;

  void add(E element) {
    _value.add(element);
    notify();
  }

  void addAll(Iterable<E> iterable) {
    _value.addAll(iterable);
    notify();
  }

  void clear() {
    if (_value.isEmpty) return;
    _value.clear();
    notify();
  }

  void insert(int index, E element) {
    _value.insert(index, element);
    notify();
  }

  void insertAll(int index, Iterable<E> iterable) {
    _value.insertAll(index, iterable);
    notify();
  }

  bool remove(Object? element) {
    final removed = _value.remove(element);
    if (removed) notify();
    return removed;
  }

  E removeAt(int index) {
    final removed = _value.removeAt(index);
    notify();
    return removed;
  }

  E removeLast() {
    final removed = _value.removeLast();
    notify();
    return removed;
  }

  void removeRange(int start, int end) {
    _value.removeRange(start, end);
    notify();
  }

  void removeWhere(bool Function(E element) test) {
    _value.removeWhere(test);
    notify();
  }

  void retainWhere(bool Function(E element) test) {
    _value.retainWhere(test);
    notify();
  }

  void replaceRange(int start, int end, Iterable<E> replacements) {
    _value.replaceRange(start, end, replacements);
    notify();
  }

  void fillRange(int start, int end, [E? fillValue]) {
    _value.fillRange(start, end, fillValue);
    notify();
  }

  void setAll(int index, Iterable<E> iterable) {
    _value.setAll(index, iterable);
    notify();
  }

  void setRange(int start, int end, Iterable<E> iterable, [int skipCount = 0]) {
    _value.setRange(start, end, iterable, skipCount);
    notify();
  }

  void shuffle([Random? random]) {
    _value.shuffle(random);
    notify();
  }

  void sort([int Function(E a, E b)? compare]) {
    _value.sort(compare);
    notify();
  }

  bool any(bool Function(E element) test) => value.any(test);

  Map<int, E> asMap() => value.asMap();

  List<R> cast<R>() => value.cast<R>();

  bool contains(Object? element) => value.contains(element);

  E elementAt(int index) => value.elementAt(index);

  bool every(bool Function(E element) test) => value.every(test);

  Iterable<T> expand<T>(Iterable<T> Function(E element) toElements) =>
      value.expand(toElements);

  E firstWhere(bool Function(E element) test, {E Function()? orElse}) =>
      value.firstWhere(test, orElse: orElse);

  T fold<T>(T initialValue, T Function(T previousValue, E element) combine) =>
      value.fold(initialValue, combine);

  Iterable<E> followedBy(Iterable<E> other) => value.followedBy(other);

  void forEach(void Function(E element) action) => value.forEach(action);

  Iterable<E> getRange(int start, int end) => value.getRange(start, end);

  int indexOf(E element, [int start = 0]) => value.indexOf(element, start);

  int indexWhere(bool Function(E element) test, [int start = 0]) =>
      value.indexWhere(test, start);

  bool get isEmpty => value.isEmpty;

  bool get isNotEmpty => value.isNotEmpty;

  Iterator<E> get iterator => value.iterator;

  String join([String separator = '']) => value.join(separator);

  int lastIndexOf(E element, [int? start]) => value.lastIndexOf(element, start);

  int lastIndexWhere(bool Function(E element) test, [int? start]) =>
      value.lastIndexWhere(test, start);

  E lastWhere(bool Function(E element) test, {E Function()? orElse}) =>
      value.lastWhere(test, orElse: orElse);

  Iterable<T> map<T>(T Function(E element) toElement) => value.map(toElement);

  E reduce(E Function(E value, E element) combine) => value.reduce(combine);

  Iterable<E> get reversed => value.reversed;

  E singleWhere(bool Function(E element) test, {E Function()? orElse}) =>
      value.singleWhere(test, orElse: orElse);

  Iterable<E> skip(int count) => value.skip(count);

  Iterable<E> skipWhile(bool Function(E element) test) => value.skipWhile(test);

  List<E> sublist(int start, [int? end]) => value.sublist(start, end);

  Iterable<E> take(int count) => value.take(count);

  Iterable<E> takeWhile(bool Function(E element) test) => value.takeWhile(test);

  List<E> toList({bool growable = true}) => value.toList(growable: growable);

  Set<E> toSet() => value.toSet();

  Iterable<E> where(bool Function(E element) test) => value.where(test);

  Iterable<T> whereType<T>() => value.whereType<T>();
}
