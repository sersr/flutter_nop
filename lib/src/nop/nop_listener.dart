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

  static void autoInit(Object lifeCycle, NopListener listener) {
    if (lifeCycle is! NopLifeCycle) {
      _caches[lifeCycle] = listener;
    }

    if (lifeCycle is NopLifeCycle) {
      if (lifeCycle._listener == null) {
        lifeCycle._listener = listener;
        lifeCycle.nopInit();
      }
    }
    assert(Log.w(checkIsNopLisenter(lifeCycle)!.label));
  }

  static void autoDispose(Object lifeCycle) {
    assert(Log.w(checkIsNopLisenter(lifeCycle)!.label));

    if (lifeCycle is! NopLifeCycle) {
      _caches.remove(lifeCycle);
    }
    if (lifeCycle is NopLifeCycle) {
      lifeCycle.nopDispose();
      lifeCycle._listener = null;
    } else if (lifeCycle is ChangeNotifier) {
      lifeCycle.dispose();
    }
  }

  static void autoPop(Object lifeCycle) {
    assert(Log.w(checkIsNopLisenter(lifeCycle)!.label));

    if (lifeCycle is NopLifeCycle) {
      lifeCycle.onPop();
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
  NopListener(this.data, this.group, this._t);
  final dynamic data;
  final Object? group;
  final Type _t;

  NopShareScope scope = NopShareScope.shared;

  bool get mounted => _dependenceTree.isNotEmpty;

  T getType<T>({Object? group, int? position = 0}) =>
      getTypeArg(T, group: group, position: position);
  T? getTypeOrNull<T>({Object? group}) => findType(T, group: group)?.data;

  @protected
  void initIfNeed();

  bool get canRemoved => _dependenceTree.isEmpty;

  bool get isGlobal =>
      _dependenceTree.contains(GetTypePointers.globalDependences);

  void onRemove();

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

    tag ??= group?.toString() ?? '';
    return '[$tag]::$_t';
  }

  bool get popped => _dependenceTree.every((e) => e.popped);

  final _dependenceTree = <GetTypePointers>[];

  @Deprecated('use onAddDependence instead.')
  void onDependenceAdd(GetTypePointers value) {
    onAddDependence(value);
  }

  void onAddDependence(GetTypePointers value) {
    if (_dependenceTree.contains(value)) return;
    _dependenceTree.add(value);
    assert(Log.w('$label ${_dependenceTree.length}'));

    initIfNeed();
  }

  @Deprecated('use onRemoveDependence instead.')
  void onDependenceRemove(GetTypePointers value) {
    onRemoveDependence(value);
  }

  void onRemoveDependence(GetTypePointers value) {
    _dependenceTree.remove(value);
    assert(Log.w('$label ${_dependenceTree.length}'));

    if (_dependenceTree.isEmpty) {
      onRemove();
      return;
    }
  }

  void onPop() {
    if (popped && mounted) {
      NopLifeCycle.autoPop(data);
    }
  }

  GetTypePointers? getDependence() => _dependenceTree.firstOrNull;

  static NopListener getTypeDefault(Type t, NopListener owner, Object? group,
      [int? position = -4]) {
    assert(owner._dependenceTree.isNotEmpty);
    final dependence = owner.getDependence();
    final listener = GetTypePointers.defaultGetNopListener(t, dependence, group,
        position: GetTypePointers.addPosition(position, step: 5));
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

  /// _listener is null
  detached,
}

class NopListenerDefault extends NopListener {
  NopListenerDefault(super.data, super.group, super._t);
  @override
  void onRemove() {
    if (mounted) return;
    NopLifeCycle.autoDispose(data);
    _init = false;
  }

  bool _init = false;

  @override
  void initIfNeed() {
    if (_init) return;

    try {
      NopLifeCycle.autoInit(data, this);
    } catch (e, s) {
      Log.e('${data.runtimeType} init error: $e\n$s', onlyDebug: false);
    }
    _init = true;
  }
}
