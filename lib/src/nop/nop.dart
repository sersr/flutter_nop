import 'package:flutter/material.dart';
import 'package:nop/utils.dart';

import '../navigation/navigator_observer.dart';
import 'dependences_mixin.dart';
import 'nop_dependencies.dart';
import 'nop_listener.dart';
import 'nop_pre_init.dart';
import 'typedef.dart';

extension GetType on BuildContext {
  /// [group] shared group
  T getType<T>({Object? group, bool global = false}) {
    return Nop.of(this, group: group, global: global, position: 1);
  }

  T? findType<T>({Object? group, bool global = false}) {
    return Nop.findwithContext(this, group: group, global: global);
  }

  T? getTypeOr<T>({Object? group, bool global = false}) {
    return Nop.maybeOf(this, group: group, global: global);
  }
}

/// state manager
class Nop<C> extends StatefulWidget {
  const Nop({
    Key? key,
    required this.child,
    this.builders,
    this.create,
  })  : value = null,
        isPage = false,
        group = null,
        groupList = const [],
        super(key: key);

  const Nop.value({
    Key? key,
    this.value,
    required this.child,
    this.builders,
  })  : create = null,
        isPage = false,
        group = null,
        groupList = const [],
        super(key: key);

  /// stricted mode.
  static bool stricted = false;

  /// a virtual page
  const Nop.page({
    Key? key,
    required this.child,
    this.builders,
    this.groupList = const [],
    this.group,
  })  : create = null,
        isPage = true,
        value = null,
        super(key: key);

  final Widget child;
  final List<NopWidgetBuilder>? builders;
  final C Function(BuildContext context)? create;
  final List<Type> groupList;
  final C? value;
  final bool isPage;
  final Object? group;

  static bool printEnabled = false;

  static T of<T>(BuildContext? context,
      {Object? group, bool global = false, int? position = 0}) {
    final nop = context?.dependOnInheritedWidgetOfExactType<_NopScoop>();
    if (nop != null) {
      return nop.state.getType<T>(group, global, position);
    } else {
      assert(!stricted ||
          context == null ||
          Log.e('Nop.page not found. You need to use Nop.page()') && false);
      final listener = GetTypePointers.defaultGetNopListener(T, null, group,
          position: GetTypePointers.addPosition(position, step: 2));
      return listener.data;
    }
  }

  static T? findwithContext<T>(BuildContext context,
      {Object? group, bool global = false}) {
    final nop = context.dependOnInheritedWidgetOfExactType<_NopScoop>()!;
    return nop.state.findTypeArg<T>(group, global);
  }

  static T? find<T>({Object? group}) {
    NopListener? listener =
        GetTypePointers.globalDependences.findType<T>(group);
    listener ??= _NopState.currentDependence?.findType<T>(group);
    return listener?.data;
  }

  static T? maybeOf<T>(BuildContext context,
      {Object? group, bool global = false, int? position = 0}) {
    final nop = context.dependOnInheritedWidgetOfExactType<_NopScoop>();
    return nop?.state.getType<T>(group, global, position);
  }

  /// 链表会自动管理生命周期
  static void clear() {
    _NopState.currentDependence = null;
    GetTypePointers.clear();
  }

  static _NopState? _maybeOf(BuildContext context) {
    final nop = context.dependOnInheritedWidgetOfExactType<_NopScoop>();
    return nop?.state;
  }

  @override
  State<Nop<C>> createState() => _NopState<C>();
}

class _NopState<C> extends State<Nop<C>> with NopRouteAware {
  void setLocalListener(NopListener listener) {
    assert(_local == null);
    _local = listener;
  }

  NopListener? getListener(Type t, Object? group) {
    if (group == null &&
        GetTypePointers.getAlias(t) == GetTypePointers.getAlias(C)) {
      return _local;
    }
    return null;
  }

  late final dependence = NopDependence();

  static NopDependence? currentDependence;

  static void push(NopDependence dependence, {NopDependence? parent}) {
    assert(dependence.parent == null && dependence.child == null);
    if (currentDependence == null) {
      currentDependence = dependence;
    } else {
      if (dependence == parent) {
        parent = currentDependence;
      } else {
        parent ??= currentDependence;
      }
      parent!.insertChild(dependence);
      updateCurrentDependences();
    }
  }

  static void updateCurrentDependences() {
    assert(currentDependence != null);
    if (!currentDependence!.isLast) {
      currentDependence = currentDependence!.lastChildOrSelf;
    }
  }

  static void pop(NopDependence dependence) {
    if (dependence == currentDependence) {
      assert(dependence.child == null);
      currentDependence = dependence.parent;
    }
    dependence.removeCurrent();
  }

  static _NopState? getPageNopState(_NopState currentState) {
    _NopState? state;
    _NopState? current = currentState;
    while (current != null) {
      if (current.isPage) {
        state = current;
        break;
      }
      current = Nop._maybeOf(currentState.context);
    }

    return state;
  }

  /// export
  T getType<T>(Object? group, bool global, int? position) {
    return getTypeListener(T, group, global: global, position: position).data;
  }

  T? findTypeArg<T>(Object? group, bool global) {
    return findTypeListener(T, group, global: global)?.data;
  }

  /// ---
  NopListener getTypeListener(Type t, Object? group,
      {int? position, bool global = false}) {
    if (!global) {
      group ??= getGroup(t);
    }
    var listener = getListener(t, group);

    listener ??= getOrCreateDependence(t, group, position);

    assert(!Nop.printEnabled || Log.i('get $t', position: 3));

    return listener;
  }

  NopListener? findTypeListener(Type t, Object? group, {global = false}) {
    if (!global) {
      group ??= getGroup(t);
    }
    NopListener? listener = getListener(t, group);
    if (listener != null) return listener;

    final pageState = getPageNopState(this);

    listener = pageState?.getListener(t, group);

    NopDependence? dependence = pageState?.dependence;

    if (dependence != null) {
      listener = dependence.findCurrentTypeArg(t, group);
      if (listener != null) return listener;
    }

    assert(pageState == null ||
        !pageState._popped ||
        pageState.dependence.isAlone);

    if (pageState == null || pageState._popped) {
      dependence = currentDependence;
    }

    assert(listener == null || pageState != this);
    return GetTypePointers.defaultFindNopListener(t, dependence, group);
  }

  NopListener getOrCreateDependence(Type t, Object? group, int? position) {
    final pageState = getPageNopState(this);

    NopListener? listener;

    var dependence = pageState?.dependence;
    bool isSelf = true;

    assert(pageState == null ||
        !pageState._popped ||
        pageState.dependence.isAlone);

    // [pageState.dependence] 有可能被移除
    if (pageState == null || pageState._popped) {
      if (dependence != null) {
        listener = dependence.findCurrentTypeArg(t, group);
        if (listener != null) return listener;
      }
      isSelf = false;
      dependence = currentDependence;
    }

    listener ??= GetTypePointers.defaultGetNopListener(t, dependence, group,
        isSelf: isSelf,
        position: GetTypePointers.addPosition(position, step: 4));

    return listener;
  }

  Object? getGroup(Type t) {
    if (widget.groupList.contains(GetTypePointers.getAlias(t))) {
      return widget.group;
    }
    return null;
  }

  bool isPage = false;
  NopListener? _local;

  @override
  void initState() {
    super.initState();
    isPage = widget.isPage;
  }

  void _initData(dynamic data) {
    if (data != null) {
      final listener = GetTypePointers.createUniqueListener(data, C);
      setLocalListener(listener);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      Nav.observer.subscribe(this, route);
    }
    _initOnce();
  }

  bool _init = false;
  void _initOnce() {
    if (_init) return;
    _init = true;

    if (isPage) {
      final parent = Nop._maybeOf(context);
      push(dependence,
          parent: parent == null ? null : getPageNopState(parent)?.dependence);
    }

    // init
    if (widget.value != null) {
      _initData(widget.value);
    } else if (widget.create != null) {
      final data = widget.create!(context);
      _initData(data);
    }
  }

  @override
  void popDependence() {
    _popDependence();
    super.popDependence();
  }

  @override
  void dispose() {
    Nav.observer.unsubscribe(this);
    _popDependence();
    super.dispose();
  }

  bool _popped = false;
  void _popDependence() {
    if (_popped) return;
    _popped = true;
    if (isPage) pop(dependence);
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
