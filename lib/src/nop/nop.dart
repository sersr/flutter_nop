import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:nop/utils.dart';

import 'dependences_mixin.dart';
import 'nop_dependencies.dart';
import 'nop_listener.dart';
import 'nop_pre_init.dart';
import 'typedef.dart';

extension GetType on BuildContext {
  /// [shared] 即使为 false, 也会在[Nop.page]中共享
  T getType<T>() {
    return Nop.of(this);
  }

  T? findType<T>() {
    return Nop.findwithContext(this);
  }

  T? getTypeOr<T>() {
    return Nop.maybeOf(this);
  }
}

/// 当前共享对象的存储位置
/// page: 指定一个 虚拟 page,并不是所谓的页面，是一片区域；
/// 在一个页面中可以有多个区域，每个区域单独管理，由[shared]指定是否共享；
/// 在全局中有一个依赖链表，里面的对象都是共享的；
/// 在查找过程中，会在当前 page 依赖添加一个引用，即使是从其他 page 依赖获取的；
/// 如果没有 page，那么创建的对象只在特定的上下文共享
class Nop<C> extends StatefulWidget {
  const Nop({
    Key? key,
    required this.child,
    this.builder,
    this.builders,
    this.create,
    this.initTypes = const [],
    this.initTypesUnique = const [],
  })  : value = null,
        isPage = false,
        super(key: key);

  const Nop.value({
    Key? key,
    this.value,
    required this.child,
    this.builder,
    this.builders,
    this.initTypes = const [],
    this.initTypesUnique = const [],
  })  : create = null,
        isPage = false,
        super(key: key);

  /// stricted mode.
  static bool stricted = true;

  /// page 共享域
  /// shared == false, 也会共享
  /// page 与 page 之间存在隔离
  ///
  /// 每个 page 都有一个 [NopDependencies] 依赖节点
  /// [NopDependencies] : 只保存引用，不添加监听，监听由[_NopState]管理
  /// page 释放会自动移除 依赖节点
  /// [NopListener] : 管理监听对象，当没有监听者时释放
  const Nop.page({
    Key? key,
    required this.child,
    this.builder,
    this.builders,
    this.initTypes = const [],
    this.initTypesUnique = const [],
  })  : create = null,
        isPage = true,
        value = null,
        super(key: key);

  final Widget child;
  final NopWidgetBuilder? builder;
  final List<NopWidgetBuilder>? builders;
  final C Function(BuildContext context)? create;
  final List<Type> initTypes;
  final List<Type> initTypesUnique;
  final C? value;
  final bool isPage;

  static bool print = false;

  static T of<T>(BuildContext context) {
    final nop = context.dependOnInheritedWidgetOfExactType<_NopScoop>();
    if (nop != null) {
      return nop.state.getType<T>();
    } else {
      assert(
          Log.e('Nop.page not found. You need to use Nop.page()') && stricted);
      final listener = GetTypePointers.defaultGetNopListener(T, null);
      return listener.data;
    }
  }

  static T? findwithContext<T>(BuildContext context) {
    final nop = context.dependOnInheritedWidgetOfExactType<_NopScoop>()!;
    return nop.state.findTypeArg<T>();
  }

  static T? find<T>() {
    NopListener? listener = GetTypePointers.globalDependences.findType<T>();
    listener ??= _NopState.currentDependences?.findType<T>();
    return listener?.data;
  }

  static T? maybeOf<T>(BuildContext context) {
    final nop = context.dependOnInheritedWidgetOfExactType<_NopScoop>();
    return nop?.state.getType<T>();
  }

  static _NopState? _maybeOf(BuildContext context) {
    final nop = context.dependOnInheritedWidgetOfExactType<_NopScoop>();
    return nop?.state;
  }

  /// 链表会自动管理生命周期
  static void clear() {
    _NopState.currentDependences = null;
    GetTypePointers.clear();
  }

  /// 内部使用
  /// [t] 是 [T] 类型
  static dynamic _ofType(Type t, BuildContext context, {bool shared = true}) {
    final nop = context.dependOnInheritedWidgetOfExactType<_NopScoop>()!;
    return nop.state.getTypeArg(t, shared: shared);
  }

  @override
  State<Nop<C>> createState() => _NopState<C>();
}

class _NopState<C> extends State<Nop<C>> with NopListenerHandle {
  final _caches = HashMap<Type, NopListener>();
  late final dependences = NopDependencies();

  T getType<T>({bool shared = true}) {
    return getTypeListener(T, shared: shared).data;
  }

  T? findTypeArg<T>() {
    return findTypeListener(T)?.data;
  }

  @override
  NopListener getTypeListener(Type t, {bool shared = true}) {
    var listener = _getOrCreateCurrent(t);

    if (listener == null) {
      listener = getOrCreateDependence(t, shared: shared);
      _addListener(t, listener);
    }

    assert(!Nop.print || Log.i('get $t', position: 3));

    return listener;
  }

  dynamic getTypeArg(Type t, {bool shared = true}) {
    var listener = getTypeListener(t, shared: shared);
    return listener.data;
  }

  @override
  NopListener? findTypeListener(Type t) {
    NopListener? listener = _getOrCreateCurrent(t);
    if (listener != null) return listener;

    final pageState = getPageNopState(this);

    listener = pageState?.getListener(t);
    final pageDependence = pageState?.dependences;

    assert(listener == null || pageState != this);
    return GetTypePointers.defaultFindNopListener(t, pageDependence);
  }

  NopListener getOrCreateDependence(Type t, {bool shared = true}) {
    final pageState = getPageNopState(this);

    NopListener? listener = pageState?.getListener(t);
    final pageDependence = pageState?.dependences;

    assert(listener == null || pageState != this);

    listener ??= GetTypePointers.defaultGetNopListener(
      t,
      pageDependence,
      shared: shared,
    );

    // 如果不是共享那么在 page 添加一个监听引用
    if (!shared && pageState != null) {
      pageState._addListener(t, listener);
    }
    return listener;
  }

  NopListener? _getOrCreateCurrent(Type t) {
    var listener = getListener(t);

    if (listener == null) {
      listener = _create(t);
      if (listener != null) {
        _addListener(t, listener);
      }
    }
    return listener;
  }

  NopListener? _create(Type t) {
    if (widget.create != null && t == C) {
      final data = widget.create!(context);
      if (data != null) {
        final listener = GetTypePointers.createUniqueListener(data);

        return listener;
      }
    }
    return null;
  }

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

  NopListener? getListener(Type t) {
    return _caches[GetTypePointers.getAlias(t)];
  }

  void _addListener(t, NopListener listener) {
    listener.add(this);
    _caches[GetTypePointers.getAlias(t)] = listener;
  }

  @override
  void update() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    isPage = widget.isPage;
    if (isPage) {
      push(dependences, parent: getPageNopState(this)?.dependences);
    }
    _initState();
  }

  bool isPage = false;
  void _initState() {
    if (widget.value != null) {
      final listener = GetTypePointers.createUniqueListener(widget.value);

      _addListener(C, listener);
    }
  }

  @override
  void dispose() {
    _dispose();
    if (isPage) {
      pop(dependences);
    }
    super.dispose();
  }

  void _dispose() {
    for (var item in _caches.values) {
      item.remove(this);
    }
    _caches.clear();
  }

  @override
  Widget build(BuildContext context) {
    final child = NopPreInit(
      child: widget.child,
      builder: widget.builder,
      builders: widget.builders,
      init: _init,
      initTypes: widget.initTypes,
      initTypesUnique: widget.initTypesUnique,
    );

    return _NopScoop(child: child, state: this);
  }

  static dynamic _init(Type t, context, {bool shared = true}) {
    return Nop._ofType(t, context, shared: shared);
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
