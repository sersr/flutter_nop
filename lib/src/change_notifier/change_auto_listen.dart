import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nop/utils.dart';

typedef Cs = ChangeScope;
typedef AV<T> = AutoListenNotifier<T>;

typedef AVN<T, P extends ValueNotifier<T>> = AutoListenWrapper<T, P>;

class ChangeScope extends StatefulWidget {
  const ChangeScope(this.builder, {super.key});
  final Widget Function() builder;
  static bool printEnabled = false;
  @override
  State<ChangeScope> createState() => _ChangeScopeState();
}

class _ChangeScopeState extends State<ChangeScope> {
  final _listenables = <AutoListenChangeNotifierMixin>{};

  void addListener(AutoListenChangeNotifierMixin listenable) {
    if (_listenables.contains(listenable)) return;
    assert(!ChangeScope.printEnabled ||
        Log.i('${listenable.runtimeType} added', position: 3));
    _listenables.add(listenable);
    listenable.addListener(_listen);
  }

  void _listen() {
    if (mounted) setState(() {});
  }

  void removeListener(AutoListenChangeNotifierMixin listenable) {
    if (listenable.disposed) return;
    listenable.removeListener(_listen);
  }

  void clear() {
    _listenables.forEach(removeListener);
    _listenables.clear();
  }

  @override
  void didUpdateWidget(covariant ChangeScope oldWidget) {
    clear();
    super.didUpdateWidget(oldWidget);
  }

  @override
  void didChangeDependencies() {
    clear();
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return runZoned(widget.builder, zoneValues: {_ChangeScopeState: this});
  }
}

class AutoListenNotifier<T> extends ValueNotifier<T>
    with AutoListenChangeNotifierMixin {
  AutoListenNotifier(super.value);

  @override
  T get value {
    autoListen();
    return super.value;
  }

  void update() {
    notifyListeners();
  }

  @override
  void dispose() {
    autoDispose();
    super.dispose();
  }
}

class AutoListenWrapper<T, P extends ValueNotifier<T>>
    with
        AutoListenChangeNotifierMixin,
        AutoListenValueDelegateMixin<T, P>,
        AutoListenAddRemove<T, P>
    implements ValueNotifier<T> {
  AutoListenWrapper(this.parent);

  @override
  final P parent;
  @override
  set value(T newValue) {
    parent.value = newValue;
  }

  @override
  bool get hasListeners => parent.hasListeners;

  @override
  void notifyListeners() => parent.notifyListeners();

  @override
  void dispose() {
    parent.dispose();
    autoDispose();
  }
}

class AutoListenValueListenable<T, P extends ValueListenable<T>>
    with
        AutoListenChangeNotifierMixin,
        AutoListenValueDelegateMixin<T, P>,
        AutoListenAddRemove<T, P>
    implements ValueListenable<T> {
  AutoListenValueListenable(this.parent);
  @override
  final P parent;
}

class AutoListenFnWrapper<T, P extends ValueListenable<T>>
    with
        AutoListenChangeNotifierMixin,
        AutoListenValueDelegateMixin<T, P>,
        AutoListenAddRemove<T, P>,
        ChangeNotifier
    implements ValueNotifier<T> {
  AutoListenFnWrapper(this.parent, this.updateValue);

  final void Function(T newValue) updateValue;
  @override
  final P parent;
  @override
  set value(T newValue) {
    updateValue(newValue);
  }

  ChangeNotifier? get _changeNotifier {
    if (parent case ChangeNotifier p) {
      return p;
    }
    return null;
  }

  @override
  bool get hasListeners => _changeNotifier?.hasListeners ?? super.hasListeners;

  @override
  void notifyListeners() =>
      _changeNotifier?.hasListeners ?? super.notifyListeners();

  @override
  void dispose() {
    _changeNotifier?.dispose();
    autoDispose();
    super.dispose();
  }
}

mixin AutoListenChangeNotifierMixin implements Listenable {
  void autoListen() {
    final state = Zone.current[_ChangeScopeState] as _ChangeScopeState?;
    if (state != null) {
      state.addListener(this);
    }
  }

  bool _disposed = false;
  bool get disposed => _disposed;

  void autoDispose() {
    _disposed = true;
  }
}
mixin AutoListenValueDelegateMixin<T, P extends ValueListenable<T>>
    on AutoListenChangeNotifierMixin {
  P get parent;

  T get value {
    autoListen();
    return parent.value;
  }
}
mixin AutoListenAddRemove<T, P extends Listenable>
    on AutoListenChangeNotifierMixin {
  P get parent;

  @override
  void addListener(VoidCallback listener) {
    parent.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    parent.removeListener(listener);
  }
}
