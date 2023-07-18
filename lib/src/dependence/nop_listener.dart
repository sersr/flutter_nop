import 'package:flutter/foundation.dart';
import 'package:nop/nop.dart';

import 'dependences_mixin.dart';

/// 自动管理生命周期
mixin NopLifeCycle {
  static final _caches = <Object, NopListener>{};
  Object? get groupId => _listener?.group;

  bool get poped => _listener?.popped ?? true;

  @mustCallSuper
  void nopInit() {
    assert(mounted);
  }

  @mustCallSuper
  void nopDispose() {
    assert(!mounted);
  }

  void onPop() {}

  NopListener? _listener;

  bool get mounted => _listener != null && _listener!.mounted;
  bool get isGlobalData => _listener != null && _listener!.isGlobal;

  NopShareScope get scope => _listener?.scope ?? NopShareScope.detached;

  bool get isLocal => scope == NopShareScope.unique;

  bool get isShared =>
      scope == NopShareScope.shared || scope == NopShareScope.group;

  /// 自动创建对象
  T getType<T>({Object? group, int? position = 0}) {
    assert(mounted);
    return _listener!.getType<T>(group: group, position: position);
  }

  /// 查找已存在的共享对象，不会创建对象
  T? getTypeOrNull<T>({Object? group}) {
    assert(mounted);
    return _listener!.getTypeOrNull<T>(group: group);
  }

  void onUniqueListenerRemoved(dynamic data) {}

  String get label => _listener?.label ?? '';

  static void autoInit(NopListener listener) {
    final data = listener.data;
    if (data is! NopLifeCycle) {
      _caches[data] = listener;
    }

    if (data is NopLifeCycle) {
      if (data._listener == null) {
        data._listener = listener;
        data.nopInit();
      }
    }
    assert(Log.w(listener.label));
  }

  static void autoDispose(NopListener listener) {
    final data = listener.data;
    assert(Log.w(listener.label));

    if (data is! NopLifeCycle) {
      _caches.remove(data);
    }
    if (data is NopLifeCycle) {
      data.nopDispose();
      data._listener = null;
    }
  }

  static void autoPop(NopListener listener) {
    final data = listener.data;
    assert(Log.w(listener.label));

    if (data is NopLifeCycle) {
      data.onPop();
    }
  }

  static NopListener? checkIsNopLisenter(dynamic data) {
    if (data is NopLifeCycle) {
      return data._listener;
    }
    return _caches[data];
  }
}

abstract class NopListener {
  NopListener(this.data, this.group, Type t) : _t = t;
  final dynamic data;
  final Object? group;
  final Type _t;

  NopShareScope scope = NopShareScope.shared;

  bool get mounted => _dependenceTree.isNotEmpty;

  T getType<T>({Object? group, int? position = 0}) =>
      getTypeArg(T, group: group, position: position);
  T? getTypeOrNull<T>({Object? group}) => findType(T, group: group)?.data;

  bool get canRemoved => _dependenceTree.isEmpty;

  bool get isGlobal =>
      _dependenceTree.contains(GetTypePointers.globalDependences);

  void onRemove();

  bool _init = false;

  void initWithFirstDependence(GetTypePointers dependence,
      {int? position, int step = 1}) {
    assert(!_init && _dependenceTree.isEmpty);
    _init = true;

    _dependenceTree.add(dependence);

    assert(Log.w('$label created.',
        position: position == null ? 0 : position + step));

    NopLifeCycle.autoInit(this);
  }

  dynamic getTypeArg(Type t, {Object? group, int? position = 0}) {
    assert(mounted);
    return getListener(t, group: group, position: position).data;
  }

  NopListener getListener(Type t, {Object? group, int? position = 0}) {
    return getTypeDefault(t, this, group, position);
  }

  NopListener? findType(Type t, {Object? group}) {
    return getTypeOrNullDefault(t, this, group);
  }

  String get label {
    String? tag;
    if (isGlobal) {
      if (group == null) {
        tag = 'Global';
      } else {
        tag = 'Global::$group';
      }
    }
    if (scope == NopShareScope.unique) {
      tag = 'Local';
    }

    tag ??= group?.toString() ?? '';
    return '[$tag]::$_t';
  }

  bool _popped = false;
  bool get popped {
    if (scope == NopShareScope.unique) {
      return _popped;
    }
    return _dependenceTree.every((e) => e.popped);
  }

  final _dependenceTree = <GetTypePointers>[];

  @Deprecated('use onAddDependence instead.')
  void onDependenceAdd(GetTypePointers value) {
    onAddDependence(value);
  }

  void onAddDependence(GetTypePointers value) {
    if (_dependenceTree.contains(value)) return;
    assert(_init, 'You must call `initWithFirstDependence` first.');

    _dependenceTree.add(value);
    assert(Log.w('$label ${_dependenceTree.length}.'));
  }

  @Deprecated('use onRemoveDependence instead.')
  void onDependenceRemove(GetTypePointers value) {
    onRemoveDependence(value);
  }

  void onRemoveDependence(GetTypePointers value) {
    _dependenceTree.remove(value);
    assert(Log.w('$label ${_dependenceTree.length}.'));

    if (_dependenceTree.isEmpty) {
      onRemove();
    }
  }

  void uniqueDispose() {
    assert(scope == NopShareScope.unique);

    _popped = true;
    onPop();

    assert(_dependenceTree.length == 1);
    _dependenceTree.clear();
    onRemove();
  }

  void onPop() {
    if (popped && mounted) {
      NopLifeCycle.autoPop(this);
    }
  }

  GetTypePointers? getDependence() => _dependenceTree.firstOrNull;

  static NopListener getTypeDefault(Type t, NopListener owner, Object? group,
      [int? position = -4]) {
    assert(owner._dependenceTree.isNotEmpty);
    final dependence = owner.getDependence();
    final listener = GetTypePointers.defaultGetNopListener(t, dependence, group,
        position: position, step: 5);
    assert(listener.isGlobal || listener._dependenceTree.contains(dependence));

    return listener;
  }

  static NopListener? getTypeOrNullDefault(
      Type t, NopListener owner, Object? group) {
    final dependence = owner.getDependence();

    final listener =
        GetTypePointers.defaultFindNopListener(t, dependence, group);

    assert(listener == null ||
        listener.isGlobal ||
        listener._dependenceTree.contains(dependence));

    return listener;
  }
}

/// 指定共享范围
/// 低级的共享域可以通过 [NopListener.list] 让高级的共享域访问
/// 低级共享域可以任意使用高级共享域
enum NopShareScope {
  /// 全局或路由链表共享
  shared,

  /// shared group
  /// 共享组
  group,

  /// 不共享，独立的
  unique,

  /// [NopLifeCycle._listener] is null
  detached,
}

class NopListenerDefault extends NopListener {
  NopListenerDefault(super.data, super.group, super.t);
  @override
  void onRemove() {
    if (mounted) return;
    NopLifeCycle.autoDispose(this);
  }
}
