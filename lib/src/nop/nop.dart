import 'package:flutter/material.dart';

import '../dependence/dependences_mixin.dart';
import '../dependence/nop_listener.dart';
import '../navigation/navigator_observer.dart';
import 'nop_dependencies.dart';
import 'nop_pre_init.dart';

extension GetType on BuildContext {
  /// [group] shared group
  T getType<T>({Object? group, bool global = false, int? position = 1}) {
    return Nop.of(this, group: group, global: global, position: position);
  }

  T? findType<T>({Object? group, bool global = false}) {
    return Nop.findwithContext(this, group: group, global: global);
  }

  T? getTypeOr<T>({Object? group, bool global = false, int? position = 1}) {
    return Nop.maybeOf(this, group: group, global: global, position: position);
  }
}

/// state manager
class Nop<C> extends StatefulWidget {
  const Nop({
    super.key,
    required this.child,
    this.builders,
    this.create,
    this.groupList = const [],
    this.group,
  }) : value = null;

  const Nop.value({
    super.key,
    this.value,
    required this.child,
    this.builders,
    this.groupList = const [],
    this.group,
  }) : create = null;

  final Widget child;
  final List<NopWidgetBuilder>? builders;
  final C Function(BuildContext context)? create;
  final List<Type> groupList;
  final C? value;
  final Object? group;

  static T of<T>(BuildContext? context,
      {Object? group, bool global = false, int? position = 0}) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());
    final nop = context?.dependOnInheritedWidgetOfExactType<_NopScoop>();
    if (nop != null) {
      return nop.state.getType<T>(group, global, position);
    } else {
      return _getFromRouteOrCurrent<T>(context,
          group: group, position: position)!;
    }
  }

  static T? findwithContext<T>(BuildContext context,
      {Object? group, bool global = false}) {
    final nop = context.dependOnInheritedWidgetOfExactType<_NopScoop>();
    if (nop != null) return nop.state.findTypeArg<T>(group, global);
    return _findFromRouteOrCurrent<T>(context, group: group);
  }

  static T? find<T>({Object? group}) {
    final listener = Node.defaultFindNopListener(GetTypePointers.getAlias(T),
        _NopState.currentDependence, GetTypePointers.globalDependences, group);
    return listener?.data;
  }

  static T? maybeOf<T>(BuildContext context,
      {Object? group, bool global = false, int? position = 0}) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());
    final nop = context.dependOnInheritedWidgetOfExactType<_NopScoop>();
    if (nop != null) return nop.state.getType<T>(group, global, position);
    return _getFromRouteOrCurrent(context, group: group, position: position);
  }

  static T _getFromRouteOrCurrent<T>(BuildContext? context,
      {Type? t, Object? group, int? position = 0}) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());
    t = GetTypePointers.getAlias(t ?? T);

    NopDependence? dependence;
    if (context != null) {
      dependence = _NopState.getRouteDependence(context);
    }

    dependence ??= _NopState.currentDependence;

    return Node.defaultGetNopListener(
            t, dependence, GetTypePointers.globalDependences, group, position)
        .data;
  }

  static T? _findFromRouteOrCurrent<T>(BuildContext context,
      {Type? t, Object? group}) {
    final dependence =
        _NopState.getRouteDependence(context) ?? _NopState.currentDependence;
    t = GetTypePointers.getAlias(t ?? T);

    return Node.defaultFindNopListener(
            t, dependence, GetTypePointers.globalDependences, group)
        ?.data;
  }

  /// 链表会自动管理生命周期
  static void clear() {
    Nav.dependenceManager.clear();
    GetTypePointers.clear();
  }

  @override
  State<Nop<C>> createState() => _NopState<C>();
}

class _NopState<C> extends State<Nop<C>> {
  NopListener? getLocal(Type t, Object? group, int? position) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());
    if (group == widget.group &&
        GetTypePointers.getAlias(t) == GetTypePointers.getAlias(C)) {
      _initOnce(position);
      return _local;
    }
    return null;
  }

  // static void push(NopDependence dependence, {NopDependence? parent}) {
  //   assert(dependence.parent == null && dependence.child == null);
  //   if (currentDependence == null) {
  //     currentDependence = dependence;
  //   } else {
  //     if (dependence == parent) {
  //       parent = currentDependence;
  //     } else {
  //       parent ??= currentDependence;
  //     }
  //     parent!.insertChild(dependence);
  //     updateCurrentDependences();
  //   }
  // }

  // static void updateCurrentDependences() {
  //   assert(currentDependence != null);
  //   if (!currentDependence!.isLast) {
  //     currentDependence = currentDependence!.lastChildOrSelf;
  //   }
  // }

  // static void pop(NopDependence dependence) {
  //   if (dependence == currentDependence) {
  //     // dependence.child == null
  //     if (dependence.parent != null) {
  //       currentDependence = dependence.parent;
  //     } else {
  //       currentDependence = dependence.child;
  //     }
  //   }
  //   dependence.removeCurrent();
  // }

  /// export
  T getType<T>(Object? group, bool global, int? position) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());

    if (!global) {
      group ??= getGroup(T);
    }
    final data = getLocal(T, group, position)?.data ??
        Nop._getFromRouteOrCurrent<T>(context,
            group: group, position: position);

    return data;
  }

  T? findTypeArg<T>(Object? group, bool global) {
    if (!global) {
      group ??= getGroup(T);
    }

    return getLocal(T, group, null)?.data ??
        Nop._findFromRouteOrCurrent(context, group: group);
  }

  Object? getGroup(Type t) {
    if (widget.groupList.contains(GetTypePointers.getAlias(t))) {
      return widget.group;
    }
    return null;
  }

  NopListener? _local;
  bool _shouldClean = false;

  static NopDependence? get currentDependence =>
      Nav.dependenceManager.currentDependence;

  static NopDependence? getRouteDependence(BuildContext context) =>
      Nav.dependenceManager.getRouteDependence(context);

  void _initData(dynamic data, int? position) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());
    final dependence = getRouteDependence(context);
    final (listener, shouldClean) =
        GetTypePointers.createUniqueListener(data, C, dependence, position);
    _local = listener;
    _shouldClean = shouldClean;
  }

  bool _init = false;
  void _initOnce(int? position) {
    if (_init) return;
    _init = true;
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());
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
    Widget child = widget.child;
    if (widget.builders != null) {
      child = NopPreInit(
        builders: widget.builders,
        child: widget.child,
      );
    }

    return _NopScoop(state: this, child: child);
  }
}

class _NopScoop extends InheritedWidget {
  const _NopScoop({
    Key? key,
    required Widget child,
    required this.state,
  }) : super(key: key, child: child);
  final _NopState state;

  @override
  bool updateShouldNotify(covariant _NopScoop oldWidget) {
    return state != oldWidget.state;
  }
}
