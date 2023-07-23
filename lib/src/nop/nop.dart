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
  })  : value = null,
        group = null,
        groupList = const [];

  const Nop.value({
    super.key,
    this.value,
    required this.child,
    this.builders,
  })  : create = null,
        group = null,
        groupList = const [];

  const Nop.page({
    super.key,
    required this.child,
    this.builders,
    this.groupList = const [],
    this.group,
  })  : create = null,
        value = null;

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
    final nop = context?.dependOnInheritedWidgetOfExactType<_NopScope<T>>();

    return nop?.state.getLocal(group, position: position) ??
        _getFromRouteOrCurrent<T>(context,
            group: group, global: global, position: position)!;
  }

  static T? findwithContext<T>(BuildContext context,
      {Object? group, bool global = false}) {
    final nop = context.dependOnInheritedWidgetOfExactType<_NopScope<T>>();
    if (nop != null) return nop.state.getLocal(group);
    return _findFromRouteOrCurrent<T>(context, group: group, global: global);
  }

  static T? find<T>({Object? group}) {
    return Node.defaultFindData<T>(
        NopDependence.getAlias(T),
        _NopState.getRouteDependence(null),
        NopDependence.globalDependences,
        group);
  }

  static T? maybeOf<T>(BuildContext context,
      {Object? group, bool global = false, int? position = 0}) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());
    final nop = context.dependOnInheritedWidgetOfExactType<_NopScope<T>>();
    return nop?.state.getLocal(group, position: position) ??
        _getFromRouteOrCurrent<T>(context,
            group: group, global: global, position: position);
  }

  static Object? _getGroup(Type t, BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_NopPageScope>();
    switch (scope) {
      case _NopPageScope(:final group, :final groupList):
        if (groupList.contains(t)) {
          return group;
        }
    }

    return null;
  }

  static T _getFromRouteOrCurrent<T>(BuildContext? context,
      {Type? t, Object? group, bool global = false, int? position = 0}) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());

    t = NopDependence.getAlias(t ?? T);
    if (context != null && !global && group == null) {
      group = _getGroup(t, context);
    }
    final dependence = _NopState.getRouteDependence(context);

    return Node.defaultGetData<T>(
        t, dependence, NopDependence.globalDependences, group, position);
  }

  static T? _findFromRouteOrCurrent<T>(BuildContext context,
      {Type? t, Object? group, bool global = false}) {
    final dependence = _NopState.getRouteDependence(context);
    t = NopDependence.getAlias(t ?? T);

    if (!global && group == null) {
      group = _getGroup(t, context);
    }
    return Node.defaultFindData<T>(
        t, dependence, NopDependence.globalDependences, group);
  }

  /// 链表会自动管理生命周期
  static void clear() {
    Nav.dependenceManager.clear();
    NopDependence.clear();
  }

  @override
  State<Nop<C>> createState() => _NopState<C>();
}

class _NopState<C> extends State<Nop<C>> {
  dynamic getLocal(Object? group, {int? position}) {
    if (group != null) return null;

    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());

    _initOnce(position);
    return _local?.data;
  }

  bool get isPage => widget.group != null && widget.groupList.isNotEmpty;

  NopListener? _local;
  bool _shouldClean = false;

  static NopDependence? getRouteDependence(BuildContext? context) =>
      Nav.dependenceManager.getRouteDependence(context);

  C? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  void _initData(dynamic data, int? position) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());
    final dependence = getRouteDependence(context);
    final (listener, shouldClean) =
        NopDependence.createUniqueListener(data, C, dependence, position);
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
    if (_value != null) {
      _initData(_value, position);
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

    if (isPage) {
      child = _NopPageScope(
        group: widget.group,
        groupList: widget.groupList,
        child: child,
      );
    }

    return _NopScope<C>(state: this, child: child);
  }
}

class _NopPageScope extends InheritedWidget {
  const _NopPageScope({
    required super.child,
    this.group,
    required this.groupList,
  });

  final Object? group;
  final List<Type> groupList;

  @override
  bool updateShouldNotify(covariant _NopPageScope oldWidget) {
    return group != oldWidget.groupList && groupList != oldWidget.groupList;
  }
}

class _NopScope<T> extends InheritedWidget {
  const _NopScope({
    required super.child,
    required this.state,
  });
  final _NopState<T> state;

  @override
  bool updateShouldNotify(covariant _NopScope oldWidget) {
    return state != oldWidget.state;
  }
}
