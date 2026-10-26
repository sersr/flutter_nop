import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

typedef Cs = AlChangeScope;
typedef Al = AlChangeScope;

typedef AV<T> = AutoValueNotifier<T>;

mixin _ChangeMixin {
  final _listenables = <Listenable>{};

  void addListener(Listenable listenable) {
    if (_listenables.contains(listenable)) return;
    _listenables.add(listenable);
    listenable.addListener(markDirty);
  }

  void markDirty();

  void removeListener(Listenable listenable) {
    listenable.removeListener(markDirty);
  }

  void clear() {
    _listenables.forEach(removeListener);
    _listenables.clear();
  }

  Function get builder;
  Widget buildWith(BuildContext context) {
    switch (builder) {
      case Widget Function(dynamic context) builder:
        return runScope(() => builder(context));
      case Widget Function(BuildContext context) builder:
        return runScope(() => builder(context));
    }

    assert(builder is Widget Function());
    return runScope(builder as Widget Function());
  }

  Widget runScope(Widget Function() builder) {
    return runZoned(builder, zoneValues: {_ChangeMixin: this});
  }

  static void startListen(Listenable listenable) {
    final state = Zone.current[_ChangeMixin] as _ChangeMixin?;
    if (state != null) {
      state.addListener(listenable);
    }
  }
}

extension type AutoValueNotifier<T>(ValueNotifier<T> target)
    implements ValueNotifier<T> {
  factory AutoValueNotifier.val(T v) => .new(.new(v));

  T get value {
    target.autoListen();
    return target.value;
  }

  void refresh() {
    // ignore: invalid_use_of_visible_for_testing_member,invalid_use_of_protected_member
    notifyListeners();
  }
}

extension type AutoValueListenable<T>(ValueListenable<T> target)
    implements ValueListenable<T> {
  T get value {
    autoListen();
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
}
