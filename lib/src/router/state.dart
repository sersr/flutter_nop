import 'package:flutter/material.dart';

import '../../router.dart';
import '../dependence/dependences_mixin.dart';
import '../dependence/nop_listener.dart';

extension Grass on BuildContext {
  /// [group] shared group
  T grass<T>({Object? group, bool global = false, int? position = 1}) {
    return Green.of(this, group: group, global: global, position: position);
  }

  T? findGrass<T>({Object? group, bool global = false}) {
    return Green.find(context: this, group: group, global: global);
  }
}

/// state manager
class Green<C> extends StatefulWidget {
  const Green({
    Key? key,
    required this.child,
    this.create,
  })  : value = null,
        super(key: key);

  const Green.value({
    Key? key,
    this.value,
    required this.child,
  })  : create = null,
        super(key: key);

  final Widget child;
  final C Function(BuildContext context)? create;
  final C? value;

  static T of<T>(BuildContext? context,
      {Object? group, bool global = false, int? position = 0}) {
    RouteQueueEntry? dependence;
    if (context != null) {
      final nop = context.dependOnInheritedWidgetOfExactType<_GreenScope>();
      if (nop != null) {
        return nop.state.getType<T>(group, global, position);
      }
      dependence = RouteQueueEntry.of(context);
      if (!global) {
        group ??= dependence?.getGroup<T>();
      }
    }

    final listener = GetTypePointers.defaultGetNopListener(T, dependence, group,
        position: GetTypePointers.addPosition(position));
    return listener.data;
  }

  static T? find<T>(
      {BuildContext? context, Object? group, bool global = false}) {
    RouteQueueEntry? dependence;
    if (context != null) {
      final nop = context.dependOnInheritedWidgetOfExactType<_GreenScope>();
      if (nop != null) {
        return nop.state.findTypeArg(group, global);
      }
      dependence = RouteQueueEntry.of(context);
      if (!global) {
        group ??= dependence?.getGroup<T>();
      }
    }

    final listener =
        GetTypePointers.defaultFindNopListener(T, dependence, group);
    return listener?.data;
  }

  @override
  State<Green<C>> createState() => _GreenState<C>();
}

class _GreenState<C> extends State<Green<C>> {
  NopListener? getLocal(Type t, int? position) {
    if (_local == null && _init) return null;

    if (GetTypePointers.getAlias(t) == GetTypePointers.getAlias(C)) {
      _initOnce(position);
      return _local;
    }

    return null;
  }

  /// export
  T getType<T>(Object? group, bool global, int? position) {
    return getTypeListener(T, group, global: global, position: position).data;
  }

  T? findTypeArg<T>(Object? group, bool global) {
    return findTypeListener(T, group, global: global)?.data;
  }

  /// ---
  ///

  NopListener getTypeListener(Type t, Object? group,
      {bool global = false, int? position}) {
    if (group == null) {
      final listener = getLocal(t, position);
      if (listener != null) {
        return listener;
      }
    }

    final dependence = RouteQueueEntry.of(context);

    if (!global) {
      group ??= dependence?.getGroup(t);
    }

    return GetTypePointers.defaultGetNopListener(t, dependence, group,
        position: GetTypePointers.addPosition(position, step: 3));
  }

  NopListener? findTypeListener(Type t, Object? group, {bool global = false}) {
    if (group == null && _local != null) {
      final listener = getLocal(t, null);
      if (listener != null) {
        return listener;
      }
    }

    final dependence = RouteQueueEntry.of(context);

    if (!global) {
      group ??= dependence?.getGroup(t);
    }

    return GetTypePointers.defaultFindNopListener(t, dependence, group);
  }

  NopListener? _local;

  bool _shouldClean = false;
  void _initData(dynamic data, int? position) {
    final dependence = RouteQueueEntry.of(context);
    final (listener, shouldClean) = GetTypePointers.createUniqueListener(
        data, C, dependence, GetTypePointers.addPosition(position, step: 7));
    _local = listener;
    _shouldClean = shouldClean;
  }

  bool _init = false;
  void _initOnce(int? position) {
    if (_init) return;
    _init = true;

    // init
    if (widget.value != null) {
      _initData(widget.value, position);
    } else if (widget.create != null) {
      final data = widget.create!(context);
      assert(data != null);

      _initData(data, position);
    }
  }

  @override
  void dispose() {
    if (_shouldClean && _local != null) {
      final listener = _local!;
      _local = null;
      listener.uniqueDispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _GreenScope(state: this, child: widget.child);
  }
}

class _GreenScope extends InheritedWidget {
  const _GreenScope({
    Key? key,
    required Widget child,
    required this.state,
  }) : super(key: key, child: child);
  final _GreenState state;

  @override
  bool updateShouldNotify(covariant _GreenScope oldWidget) {
    return state != oldWidget.state;
  }
}
