import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:nop/utils.dart';

import 'dependences_mixin.dart';
import 'nop_dependencies.dart';
import 'nop_listener.dart';
import 'nop_pre_init.dart';
import 'route.dart';
import 'typedef.dart';

extension GetType on BuildContext {
  /// [group] shared group
  T getType<T>({Object? group}) {
    return Nop.of(this);
  }

  T? findType<T>({Object? group}) {
    return Nop.findwithContext(this);
  }

  T? getTypeOr<T>({Object? group}) {
    return Nop.maybeOf(this);
  }
}

/// state manager
class Nop<C> extends StatefulWidget {
  const Nop({
    Key? key,
    required this.child,
    this.builder,
    this.builders,
    this.create,
    @Deprecated('will be removed.') this.list = const [],
    this.isOwner = true,
  })  : value = null,
        isPage = false,
        group = null,
        groupList = const [],
        super(key: key);

  const Nop.value({
    Key? key,
    this.value,
    required this.child,
    this.builder,
    this.builders,
    @Deprecated('will be removed.') this.list = const [],
    this.isOwner = true,
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
    this.builder,
    this.builders,
    @Deprecated('will be removed.') this.list = const [],
    this.groupList = const [],
    this.group,
  })  : create = null,
        isPage = true,
        value = null,
        isOwner = true,
        super(key: key);

  final Widget child;
  final NopWidgetBuilder? builder;
  final List<NopWidgetBuilder>? builders;
  final C Function(BuildContext context)? create;
  final List<Type> list;
  final List<Type> groupList;
  final C? value;
  final bool isPage;
  final Object? group;

  /// the owner of the state object
  final bool isOwner;

  static bool print = false;

  static T of<T>(BuildContext context, {Object? group}) {
    final nop = context.dependOnInheritedWidgetOfExactType<_NopScoop>();
    if (nop != null) {
      return nop.state.getType<T>(group);
    } else {
      assert(
          Log.e('Nop.page not found. You need to use Nop.page()') && stricted);
      final listener = GetTypePointers.defaultGetNopListener(T, null, null);
      return listener.data;
    }
  }

  static T? findwithContext<T>(BuildContext context, {Object? group}) {
    final nop = context.dependOnInheritedWidgetOfExactType<_NopScoop>()!;
    return nop.state.findTypeArg<T>(group);
  }

  static T? find<T>({Object? group}) {
    NopListener? listener =
        GetTypePointers.globalDependences.findType<T>(group);
    listener ??= _NopState.currentDependences?.findType<T>(group);
    return listener?.data;
  }

  static T? maybeOf<T>(BuildContext context, {Object? group}) {
    final nop = context.dependOnInheritedWidgetOfExactType<_NopScoop>();
    return nop?.state.getType<T>(group);
  }

  /// 链表会自动管理生命周期
  static void clear() {
    _NopState.currentDependences = null;
    GetTypePointers.clear();
  }

  static _NopState? _maybeOf(BuildContext context) {
    final nop = context.dependOnInheritedWidgetOfExactType<_NopScoop>();
    return nop?.state;
  }

  @override
  State<Nop<C>> createState() => _NopState<C>();
}

class _NopState<C> extends State<Nop<C>> with NopListenerHandle {
  final _caches = <Object?, HashMap<Type, NopListener>>{};

  bool containsKey(Object? group, Type t) {
    return _caches[group]?.containsKey(t) ?? false;
  }

  void setLocalListener(NopListener listener, bool isOwner, Object? group) {
    assert(_local == null);
    _local = _caches.putIfAbsent(
            group, GetTypePointers.createHashMap)[GetTypePointers.getAlias(C)] =
        listener;
    if (isOwner) listener.add(this);
  }

  NopListener? getListener(Type t, Object? group) {
    return _caches.putIfAbsent(
        group, GetTypePointers.createHashMap)[GetTypePointers.getAlias(t)];
  }

  void _addListener(t, Object? group, NopListener listener) {
    t = GetTypePointers.getAlias(t);
    listener.add(this);
    _caches.putIfAbsent(group, GetTypePointers.createHashMap)[t] = listener;
  }

  late final dependences = NopDependencies();

  static NopDependencies? currentDependences;

  static void push(NopDependencies dependences, {NopDependencies? parent}) {
    assert(dependences.parent == null && dependences.child == null);
    if (currentDependences == null) {
      currentDependences = dependences;
    } else {
      if (dependences == parent) {
        parent = currentDependences;
      } else {
        parent ??= currentDependences;
      }
      parent!.insertChild(dependences);
      updateCurrentDependences();
    }
  }

  static void updateCurrentDependences() {
    assert(currentDependences != null);
    if (!currentDependences!.isLast) {
      currentDependences = currentDependences!.lastChildOrSelf;
    }
  }

  static void pop(NopDependencies dependences) {
    if (dependences == currentDependences) {
      assert(dependences.child == null);
      currentDependences = dependences.parent;
    }
    dependences.removeCurrent();
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
  T getType<T>(Object? group) {
    return getTypeListener(T, group).data;
  }

  T? findTypeArg<T>(Object? group) {
    return findTypeListener(T, group)?.data;
  }

  /// ---

  @override
  NopListener getTypeListener(Type t, Object? group) {
    group ??= getGroup(t);
    var listener = getListener(t, group);

    if (listener == null) {
      listener = getOrCreateDependence(t, group);
      _addListener(t, group, listener);
    }

    assert(!Nop.print || Log.i('get $t', position: 3));

    return listener;
  }

  @override
  NopListener? findTypeListener(Type t, Object? group) {
    group ??= getGroup(t);
    NopListener? listener = getListener(t, group);
    if (listener != null) return listener;

    final pageState = getPageNopState(this);

    listener = pageState?.getListener(t, group);
    final pageDependence = pageState?.dependences;

    assert(listener == null || pageState != this);
    return GetTypePointers.defaultFindNopListener(t, pageDependence, group);
  }

  NopListener getOrCreateDependence(Type t, Object? group) {
    final pageState = getPageNopState(this);

    NopListener? listener = pageState?.getListener(t, group);
    final pageDependence = pageState?.dependences;

    assert(listener == null || pageState != this);

    listener ??=
        GetTypePointers.defaultGetNopListener(t, pageDependence, group);

    return listener;
  }

  @override
  void update() {
    if (mounted) setState(() {});
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
      var listener = NopLifeCycle.checkIsNopLisenter(data);
      if (listener != null) {
        setLocalListener(listener, true, null);
        return;
      }
      listener = GetTypePointers.createUniqueListener(data);
      setLocalListener(listener, widget.isOwner, null);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initOnce();
  }

  bool _init = false;
  void _initOnce() {
    if (_init) return;
    _init = true;

    if (isPage) {
      final parent = Nop._maybeOf(context);
      push(dependences,
          parent: parent == null ? null : getPageNopState(parent)?.dependences);
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
  void dispose() {
    _dispose();
    if (isPage) pop(dependences);
    super.dispose();
  }

  void _dispose() {
    for (var group in _caches.values) {
      for (var item in group.values) {
        if (item == _local && !widget.isOwner) {
          continue;
        }
        item.remove(this);
      }
    }
    _caches.clear();
  }

  dynamic _initType(Type t, _, group) => getTypeListener(t, group).data;

  @override
  Widget build(BuildContext context) {
    final child = NopPreInit(
      builder: widget.builder,
      builders: widget.builders,
      init: _initType,
      group: widget.group,
      child: widget.child,
    );

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
