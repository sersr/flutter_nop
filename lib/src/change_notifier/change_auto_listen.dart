import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nop/utils.dart';

typedef Cs = ChangeScope;
typedef AV<T> = AutoValueNotifier<T>;

class ChangeScope extends StatefulWidget {
  const ChangeScope(Widget Function() this.builder, {super.key});
  const ChangeScope.context(
    Widget Function(BuildContext context) this.builder, {
    super.key,
  });
  const ChangeScope.dynamic(
    Widget Function(dynamic context) this.builder, {
    super.key,
  });
  final Function builder;
  static bool printEnabled = false;
  @override
  State<ChangeScope> createState() => _ChangeScopeState();
}

class _ChangeScopeState extends State<ChangeScope> {
  final _listenables = <Listenable>{};

  void addListener(Listenable listenable) {
    if (_listenables.contains(listenable)) return;
    assert(
      !ChangeScope.printEnabled ||
          Log.i('${listenable.runtimeType} added', position: 3),
    );
    _listenables.add(listenable);
    listenable.addListener(_listen);
  }

  void _listen() {
    if (mounted) setState(() {});
  }

  void removeListener(Listenable listenable) {
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
    switch (widget.builder) {
      case Widget Function(dynamic context) builder:
        return runZoned(
          () => builder(context),
          zoneValues: {_ChangeScopeState: this},
        );
      case Widget Function(BuildContext context) builder:
        return runZoned(
          () => builder(context),
          zoneValues: {_ChangeScopeState: this},
        );
    }

    assert(widget.builder is Widget Function());
    return runZoned(
      widget.builder as Widget Function(),
      zoneValues: {_ChangeScopeState: this},
    );
  }
}

extension type AutoValueNotifier<T>(ValueNotifier<T> target)
    implements ValueNotifier<T> {
  factory AutoValueNotifier.val(T v) => .new(.new(v));

  T get value {
    target.autoListen();
    return target.value;
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
    final state = Zone.current[_ChangeScopeState] as _ChangeScopeState?;
    if (state != null) {
      state.addListener(this);
    }
  }
}
