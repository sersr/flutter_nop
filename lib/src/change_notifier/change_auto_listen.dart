import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

typedef Cs = AlChangeScope;
typedef Al = AlChangeScope;

typedef AV<T> = AutoValueNotifier<T>;

mixin _ChangeMixin {
  final _listenables = <Listenable>{};

  bool get enabled;

  void addListenerItem(Listenable listenable) {
    if (!enabled) return;
    if (_listenables.contains(listenable)) return;
    _listenables.add(listenable);
    listenable.addListener(markDirty);
  }

  void markDirty();

  void removeListenerItem(Listenable listenable) {
    listenable.removeListener(markDirty);
  }

  void clear() {
    _listenables.forEach(removeListenerItem);
    _listenables.clear();
  }

  Function get builder;
  T buildWith<T>(BuildContext context) {
    switch (builder) {
      case T Function(dynamic context) builder:
        return runScope(() => builder(context));
      case T Function(BuildContext context) builder:
        return runScope(() => builder(context));
    }

    assert(builder is Widget Function());
    return runScope<T>(builder as T Function());
  }

  T runScope<T>(T Function() builder) {
    return runZoned(builder, zoneValues: {_ChangeMixin: this});
  }

  static void startListen(Listenable listenable) {
    final state = Zone.current[_ChangeMixin] as _ChangeMixin?;
    if (state != null) {
      state.addListenerItem(listenable);
    }
  }
}

final class AlScope<T> extends ValueListenable<T>
    with ChangeNotifier, _ChangeMixin {
  AlScope(this.builder);

  AlScopeManager? _manager;

  set manager(AlScopeManager manager) {
    if (_manager == manager) return;
    _manager?._unmountScope(this);
    _manager = manager;
    manager._mountScope(this);
    _value = null;
    _value = runScope<T>(builder);
  }

  @override
  void markDirty() {
    if (_closed) return;
    _value = null;
    notifyListeners();
  }

  @override
  final T Function() builder;

  T? _value;
  @override
  T get value {
    autoListen();
    return _value ??= runScope<T>(builder);
  }

  var _closed = false;
  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }

  @override
  bool get enabled => !_closed && _manager?._disposed != true;
}

mixin AlScopeManager {
  final _scopes = <AlScope>[];
  void _unmountScope(AlScope alScope) {
    _scopes.remove(alScope);
  }

  void _mountScope(AlScope alScope) {
    if (_scopes.contains(alScope)) return;
    _scopes.add(alScope);
  }

  void closeScope() {
    for (var scope in _scopes) {
      scope.dispose();
    }
    _scopes.clear();
  }

  var _disposed = false;
  void disposeScope() {
    _disposed = true;
    closeScope();
  }
}

extension type AutoValueNotifier<T>(ValueNotifier<T> target)
    implements ValueNotifier<T> {
  factory AutoValueNotifier.val(T v) => .new(.new(v));

  T get value {
    final v = target.value;
    if (v case ValueNotifier v) {
      v.autoListen();
    } else {
      target.autoListen();
    }
    return v;
  }

  void refresh() {
    // ignore: invalid_use_of_visible_for_testing_member,invalid_use_of_protected_member
    notifyListeners();
  }
}

extension type AutoValueListenable<T>(ValueListenable<T> target)
    implements ValueListenable<T> {
  T get value {
    target.autoListen();
    return target.value;
  }
}

extension AutoListenableExt on Listenable {
  void autoListen() {
    _ChangeMixin.startListen(this);
  }
}

class AlChangeScope extends Widget {
  const new(Widget Function() this.builder, {super.key});
  const new context(
    Widget Function(BuildContext context) this.builder, {
    super.key,
  });
  const new dynamic(Widget Function(dynamic context) this.builder, {super.key});
  final Function builder;

  @override
  Element createElement() => AlChangeScopeElement(this);
}

class AlChangeScopeElement extends ComponentElement with _ChangeMixin {
  new(AlChangeScope super.widget);

  @override
  AlChangeScope get widget => (super.widget as AlChangeScope);

  @override
  Function get builder => widget.builder;

  @override
  Widget build() {
    return buildWith(this);
  }

  @override
  void markDirty() {
    markNeedsBuild();
  }

  @override
  void update(covariant Widget newWidget) {
    clear();
    super.update(newWidget);
    rebuild(force: true);
  }

  @override
  void unmount() {
    clear();
    super.unmount();
  }

  @override
  bool get enabled => mounted;
}
