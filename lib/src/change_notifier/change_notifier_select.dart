import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import 'change_auto_listen.dart';

typedef ShouldNotify<T, D extends Listenable> = T Function(D parent);

extension ValueNotifierSelector<D extends Listenable> on D {
  ChangeNotifierSelector<T, D> select<T>(ShouldNotify<T, D> notifyValue,
      {Object? key}) {
    return ChangeNotifierSelector(parent: this, notifyValue: notifyValue);
  }
}

class ChangeNotifierSelector<T, D extends Listenable> extends ChangeNotifier
    implements ValueListenable<T> {
  ChangeNotifierSelector({required this.parent, required this.notifyValue});

  final D parent;
  final ShouldNotify<T, D> notifyValue;

  bool _add = false;
  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    if (!_add && hasListeners) {
      _add = true;
      parent.addListener(_listener);
      _value = notifyValue(parent);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (hasListeners) return;
    if (!hasListeners) {
      _add = false;
      parent.removeListener(_listener);
    }
  }

  void _listener() {
    final value = notifyValue(parent);

    if (!const DeepCollectionEquality().equals(_value, value)) {
      _value = value;
      if (hasListeners) notifyListeners();
    }
  }

  T? _value;

  @override
  void dispose() {
    parent.removeListener(_listener);
    super.dispose();
  }

  @override
  T get value => _value ??= notifyValue(parent);
}

extension ChangeAutoWrapperSelectorAl<T, D extends ChangeNotifier>
    on ChangeNotifierSelector<T, D> {
  AutoListenDelegate<T, ChangeNotifierSelector<T, D>> get cs {
    return AutoListenDelegate(this);
  }
}
