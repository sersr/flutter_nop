import 'package:flutter/material.dart';

import '../dependence/dependences_mixin.dart';
import '../dependence/nop_listener.dart';
import '../navigation/navigator_observer.dart';
import 'nop_dependencies.dart';
import 'nop_pre_init.dart';

extension GetType on BuildContext {
  /// [group] shared group
  ///
  /// [useNopGroup] :use [Nop.group] if [group] == null and [Nop.groupList].contains(T).
  T getType<T>({Object? group, bool useNopGroup = true, int? position = 1}) {
    return Nop.of(this,
        group: group, useNopGroup: useNopGroup, position: position);
  }

  T? findType<T>({Object? group, bool useNopGroup = true}) {
    return Nop.findwithContext(this, group: group, useNopGroup: useNopGroup);
  }

  T? getTypeOr<T>({Object? group, bool useNopGroup = true, int? position = 1}) {
    return Nop.maybeOf(this,
        group: group, useNopGroup: useNopGroup, position: position);
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
  final C? value;

  /// see: [_getGroup]
  final List<Type> groupList;
  final Object? group;

  static T of<T>(BuildContext? context,
      {Object? group, bool useNopGroup = true, int? position = 0}) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());

    if (context == null) {
      return _getFromRouteOrCurrent(context,
          group: group, useNopGroup: useNopGroup, position: position);
    }

    return _NopState.getLocal(context, group, position) ??
        _getFromRouteOrCurrent<T>(context,
            group: group, useNopGroup: useNopGroup, position: position)!;
  }

  static T? findwithContext<T>(BuildContext context,
      {Object? group, bool useNopGroup = true}) {
    return _NopState.getLocal(context, group) ??
        _findFromRouteOrCurrent<T>(context,
            group: group, useNopGroup: useNopGroup);
  }

  static T? find<T>({Object? group}) {
    return Node.defaultFindData<T>(
        NopDependence.getAlias(T),
        _NopState.getRouteDependence(null),
        NopDependence.globalDependences,
        group);
  }

  static T? maybeOf<T>(BuildContext context,
      {Object? group, bool useNopGroup = true, int? position = 0}) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());
    return _NopState.getLocal(context, group, position) ??
        _getFromRouteOrCurrent<T>(context,
            group: group, useNopGroup: useNopGroup, position: position);
  }

  static Object? _getGroup(Type alias, BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_NopPageScope>();
    switch (scope) {
      case _NopPageScope(:final group, :final groupList):
        if (groupList.contains(alias)) {
          return group;
        }
    }

    return null;
  }

  static T _getFromRouteOrCurrent<T>(BuildContext? context,
      {Type? t, Object? group, bool useNopGroup = true, int? position = 0}) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());

    t = NopDependence.getAlias(t ?? T);
    if (context != null && useNopGroup && group == null) {
      group = _getGroup(t, context);
    }
    final dependence = _NopState.getRouteDependence(context);

    return Node.defaultGetData<T>(
        t, dependence, NopDependence.globalDependences, group, position);
  }

  static T? _findFromRouteOrCurrent<T>(BuildContext context,
      {Type? t, Object? group, bool useNopGroup = true}) {
    final dependence = _NopState.getRouteDependence(context);
    t = NopDependence.getAlias(t ?? T);

    if (useNopGroup && group == null) {
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
  static T? getLocal<T>(BuildContext context, Object? group, [int? position]) {
    if (group != null) return null;

    var state = context.dependOnInheritedWidgetOfExactType<_NopScope>()?.state;

    while (state != null) {
      if (state.isSameType(T)) {
        return state._getLocal(position);
      }
      final context = state.context;
      state = context.dependOnInheritedWidgetOfExactType<_NopScope>()?.state;
    }
    return null;
  }

  bool isSameType(Type t) {
    return NopDependence.getAlias(C) == NopDependence.getAlias(t);
  }

  bool get isPage => widget.group != null && widget.groupList.isNotEmpty;

  static NopDependence? getRouteDependence(BuildContext? context) =>
      Nav.dependenceManager.getRouteDependence(context);

  C? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  bool _init = false;

  dynamic _getLocal(int? position) {
    if (_init) return _local?.data;
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
    return _local?.data;
  }

  NopListener? _local;

  bool _shouldClean = false;

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

    return _NopScope(state: this, child: child);
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

class _NopScope extends InheritedWidget {
  const _NopScope({
    required super.child,
    required this.state,
  });
  final _NopState state;

  @override
  bool updateShouldNotify(covariant _NopScope oldWidget) {
    return state != oldWidget.state;
  }
}
