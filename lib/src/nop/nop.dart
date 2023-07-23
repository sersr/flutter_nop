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
    final nop = context?.dependOnInheritedWidgetOfExactType<_NopScope>();
    if (nop != null) {
      return nop.state.getType<T>(group, global, position);
    } else {
      return _getFromRouteOrCurrent<T>(context,
          group: group, position: position)!;
    }
  }

  static T? findwithContext<T>(BuildContext context,
      {Object? group, bool global = false}) {
    final nop = context.dependOnInheritedWidgetOfExactType<_NopScope>();
    if (nop != null) return nop.state.findTypeArg<T>(group, global);
    return _findFromRouteOrCurrent<T>(context, group: group);
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
    final nop = context.dependOnInheritedWidgetOfExactType<_NopScope>();
    if (nop != null) return nop.state.getType<T>(group, global, position);
    return _getFromRouteOrCurrent<T>(context, group: group, position: position);
  }

  static T _getFromRouteOrCurrent<T>(BuildContext? context,
      {Type? t, Object? group, int? position = 0}) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());
    t = NopDependence.getAlias(t ?? T);

    NopDependence? dependence;
    if (context != null) {
      dependence = _NopState.getRouteDependence(context);
    }

    return Node.defaultGetData<T>(
        t, dependence, NopDependence.globalDependences, group, position);
  }

  static T? _findFromRouteOrCurrent<T>(BuildContext context,
      {Type? t, Object? group}) {
    final dependence = _NopState.getRouteDependence(context);
    t = NopDependence.getAlias(t ?? T);

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
  T? getLocal<T>(int? position) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());
    if (NopDependence.getAlias(T) == NopDependence.getAlias(C)) {
      _initOnce(position);
      return _local?.data;
    }
    return null;
  }

  /// export
  T getType<T>(Object? group, bool global, int? position) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());

    if (group == null) {
      final data = getLocal<T>(position);
      if (data != null) {
        return data;
      }
    }

    if (!global) {
      group ??= getGroup(T);
    }
    return Nop._getFromRouteOrCurrent<T>(context,
        group: group, position: position);
  }

  T? findTypeArg<T>(Object? group, bool global) {
    if (group == null && _local != null) {
      final data = getLocal<T>(null);
      if (data != null) {
        return data;
      }
    }

    if (!global) {
      group ??= getGroup(T);
    }

    return Nop._findFromRouteOrCurrent<T>(context, group: group);
  }

  bool get isPage => widget.group != null && widget.groupList.isNotEmpty;

  Object? getGroup(Type t) {
    if (isPage) {
      return _getGroup(t, widget.group, widget.groupList);
    }

    final page = context.dependOnInheritedWidgetOfExactType<_NopPageScope>();

    return switch (page) {
      _NopPageScope(:final group, :final groupList) =>
        _getGroup(t, group, groupList),
      _ => null,
    };
  }

  static Object? _getGroup(Type t, Object? group, List<Type> groupList) {
    if (groupList.contains(NopDependence.getAlias(t))) {
      return group;
    }

    return null;
  }

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
