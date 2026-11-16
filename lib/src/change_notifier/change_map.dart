import 'package:material_ui/material_ui.dart';

import '../../change_notifier.dart';

typedef AMap<K, V> = AutoListenMap<K, V>;

extension type AutoListenMap<K, V>(ValueNotifier<Map<K, V>> target)
    implements ValueNotifier<Map<K, V>> {
  AutoListenMap.val(Map<K, V> map) : this(.new(map));

  Map<K, V> get _value => target.value;
  Map<K, V> get value {
    autoListen();
    return target.value;
  }

  void notify() {
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    target.notifyListeners();
  }

  V? operator [](Object? key) {
    return value[key];
  }

  void operator []=(K key, V value) {
    if (!identical(_value[key], value)) {
      _value[key] = value;
      notify();
    }
  }

  void clear() {
    if (_value.isNotEmpty) {
      _value.clear();
      notify();
    }
  }

  Iterable<K> get keys => value.keys;

  Iterable<V> get values => value.values;

  V? remove(Object? key) {
    final value = _value.remove(key);
    if (value != null) {
      notify();
    }
    return value;
  }

  void addEntries(Iterable<MapEntry<K, V>> newEntries) {
    _value.addEntries(newEntries);
    notify();
  }

  void addAll(Map<K, V> other) {
    _value.addAll(other);
    notify();
  }

  Map<RK, RV> cast<RK, RV>() {
    return value.cast();
  }

  bool containsKey(Object? key) {
    return value.containsKey(key);
  }

  bool containsValue(Object? value) {
    return this.value.containsValue(value);
  }

  Iterable<MapEntry<K, V>> get entries => value.entries;

  void forEach(void Function(K key, V value) action) {
    value.forEach(action);
  }

  bool get isEmpty => value.isEmpty;

  bool get isNotEmpty => value.isNotEmpty;

  int get length => value.length;

  Map<K2, V2> map<K2, V2>(MapEntry<K2, V2> Function(K key, V value) convert) {
    return value.map(convert);
  }

  V putIfAbsent(K key, V Function() ifAbsent) {
    var changed = false;
    final v = value.putIfAbsent(key, () {
      changed = true;
      return ifAbsent();
    });

    if (changed) {
      notify();
    }
    return v;
  }

  void removeWhere(bool Function(K key, V value) test) {
    value.removeWhere(test);
  }

  V update(K key, V Function(V value) update, {V Function()? ifAbsent}) {
    final v = value.update(key, update, ifAbsent: ifAbsent);
    notify();
    return v;
  }

  void updateAll(V Function(K key, V value) update) {
    value.updateAll(update);
  }
}
