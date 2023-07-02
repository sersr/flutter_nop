import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:nop/utils.dart';

import '../navigation/navigator_observer.dart';
import 'dependences_mixin.dart';
import 'nop_dependencies.dart';
import 'nop_listener.dart';
import 'nop_pre_init.dart';
import 'route.dart';
import 'typedef.dart';

extension GetType on BuildContext {
  /// [group] shared group
  T getType<T>({Object? group, bool global = false}) {
    return Nop.of(this, global: global, position: 1);
  }

  T? findType<T>({Object? group, bool global = false}) {
    return Nop.findwithContext(this, global: global);
  }

  T? getTypeOr<T>({Object? group, bool global = false}) {
    return Nop.maybeOf(this, global: global);
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
      {Object? group, bool global = false, int position = 0}) {
    final nop = context?.dependOnInheritedWidgetOfExactType<_NopScoop>();
    if (nop != null) {
      return nop.state.getType<T>(group, global);
    } else {
      assert(!stricted ||
          context == null ||
          Log.e('Nop.page not found. You need to use Nop.page()') && false);
      final listener = GetTypePointers.defaultGetNopListener(T, null, group,
          position: position += 2);
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
      {Object? group, bool global = false}) {
    final nop = context.dependOnInheritedWidgetOfExactType<_NopScoop>();
    return nop?.state.getType<T>(group, global);
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

class _NopState<C> extends State<Nop<C>> with NopListenerHandle, NopRouteAware {
  final _caches = <Object?, HashMap<Type, NopListener>>{};

  bool containsKey(Object? group, Type t) {
    return _caches[group]?.containsKey(t) ?? false;
  }

  void setLocalListener(NopListener listener, Object? group) {
    assert(_local == null);
    _local = _caches.putIfAbsent(
            group, GetTypePointers.createHashMap)[GetTypePointers.getAlias(C)] =
        listener;
    listener.add(this);
  }

  NopListener? getListener(Type t, Object? group) {
    return _caches.putIfAbsent(
        group, GetTypePointers.createHashMap)[GetTypePointers.getAlias(t)];
  }

  void _addListener(t, Object? group, NopListener listener) {
    t = GetTypePointers.getAlias(t);
    _caches.putIfAbsent(group, GetTypePointers.createHashMap)[t] = listener;
    listener.add(this);
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
  T getType<T>(Object? group, bool global) {
    return getTypeListener(T, group, global: global).data;
  }

  T? findTypeArg<T>(Object? group, bool global) {
    return findTypeListener(T, group, global: global)?.data;
  }

  /// ---

  @override
  NopListener getTypeListener(Type t, Object? group, {bool global = false}) {
    if (!global) {
      group ??= getGroup(t);
    }
    var listener = getListener(t, group);

    if (listener == null) {
      listener = getOrCreateDependence(t, group);
      _addListener(t, group, listener);
    }

    assert(!Nop.printEnabled || Log.i('get $t', position: 3));

    return listener;
  }

  @override
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

  NopListener getOrCreateDependence(Type t, Object? group) {
    final pageState = getPageNopState(this);

    NopListener? listener;
    //  = pageState?.getListener(t, group);
    // assert(listener == null || pageState != this);

    NopDependence? dependence = pageState?.dependence;
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
    } else {
      dependence = pageState.dependence;
    }

    listener ??= GetTypePointers.defaultGetNopListener(t, dependence, group,
        isSelf: isSelf);

    return listener;
  }

  @override
  void update() {
    if (mounted) {
      if (SchedulerBinding.instance.schedulerPhase !=
          SchedulerPhase.persistentCallbacks) {
        setState(() {});
      }
    }
  }

  Object? _group;

  Object? getGroup(Type t) {
    if (widget.groupList.contains(GetTypePointers.getAlias(t))) {
      return _group;
    }
    return null;
  }

  bool isPage = false;
  NopListener? _local;

  @override
  void initState() {
    super.initState();
    isPage = widget.isPage;
    _group = widget.group;
  }

  void _initData(dynamic data) {
    if (data != null) {
      final listener = GetTypePointers.createUniqueListener(data);
      setLocalListener(listener, null);
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

    // get groupId from settings
    if (_group == null) {
      final settings = ModalRoute.of(context)?.settings;
      if (settings is NopRouteSettings) {
        _group = settings.group;
      }
    }

    // init
    if (widget.value != null) {
      _initData(widget.value);
    } else if (widget.create != null &&
        !_caches.containsKey(GetTypePointers.getAlias(C))) {
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
    _clearCache();
    super.dispose();
  }

  bool _popped = false;
  void _popDependence() {
    if (_popped) return;
    _popped = true;
    if (isPage) pop(dependence);
  }

  void _clearCache() {
    if (_caches.isEmpty) return;
    for (var group in _caches.values) {
      for (var item in group.values) {
        if (item == _local) {
          continue;
        }
        item.remove(this);
      }
    }
    _caches.clear();
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
