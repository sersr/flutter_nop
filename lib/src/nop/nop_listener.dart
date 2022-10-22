import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:nop/nop.dart';

import '../../nop_state.dart';

/// 自动管理生命周期
mixin NopLifeCycle {
  @mustCallSuper
  void nopInit() {
    assert(mounted);
  }

  Type get nopType => runtimeType;

  @mustCallSuper
  void nopDispose() {
    assert(!mounted);
  }

  NopListener? _listener;

  bool get mounted => _listener != null && _listener!.mounted;

  /// 自动创建对象
  T getType<T>({Object? group}) {
    assert(mounted);
    return _listener!.getType<T>(group: group);
  }

  /// 查找已存在的共享对象，不会创建对象
  T? getTypeOrNull<T>({Object? group}) {
    assert(mounted);
    return _listener!.getTypeOrNull<T>(group: group);
  }

  void onDisposeStart() {}
  void onDisposeCancel() {}

  static void autoInit(Object lifeCycle, NopListener listener) {
    assert(Log.w(lifeCycle is NopLifeCycle
        ? '${GetTypePointers.getGroupName(listener.group)}: ${lifeCycle.runtimeType}'
        : '${lifeCycle.runtimeType}'));

    if (lifeCycle is NopLifeCycle) {
      if (lifeCycle._listener == null) {
        lifeCycle._listener = listener;
        lifeCycle.nopInit();
      }
    }
  }

  static void disposeStart(Object lifeCycle) {
    if (lifeCycle is NopLifeCycle) {
      lifeCycle.onDisposeStart();
    }
  }

  static void disposeCancel(Object lifeCycle) {
    if (lifeCycle is NopLifeCycle) {
      lifeCycle.onDisposeCancel();
    }
  }

  static void autoDispose(Object lifeCycle) {
    assert(Log.w(lifeCycle is NopLifeCycle
        ? '${GetTypePointers.getGroupName(lifeCycle._listener?.group)}: ${lifeCycle.runtimeType}'
        : '${lifeCycle.runtimeType}'));

    if (lifeCycle is NopLifeCycle) {
      lifeCycle.nopDispose();
      lifeCycle._listener = null;
    } else if (lifeCycle is ChangeNotifier) {
      lifeCycle.dispose();
    }
  }

  static NopListener? checkIsNopLisenter(dynamic data) {
    if (data is NopLifeCycle) {
      return data._listener;
    }
    return null;
  }
}

mixin NopListenerHandle {
  void update();
  bool get mounted;
  NopListener getTypeListener(Type t, Object? group);
  NopListener? findTypeListener(Type t, Object? group);
}

abstract class NopListener {
  NopListener(this.data, this.group);
  final dynamic data;
  final Object? group;

  NopShareScope scope = NopShareScope.shared;

  NopListenerHandle? get handle;
  bool get mounted => _dependenceTree.isNotEmpty || handle != null && handle!.mounted;

  T getType<T>({Object? group}) => getTypeArg(T, group: group);
  T? getTypeOrNull<T>({Object? group}) => findType(T, group: group)?.data;

  void remove(NopListenerHandle key);

  void add(NopListenerHandle key);

  bool get canRemoved => _dependenceTree.isEmpty;

  void onRemove();

  dynamic getTypeArg(Type t, {Object? group}) {
    assert(mounted);
    return getListener(t, group: group).data;
  }

  NopListener getListener(Type t, {Object? group}) {
    return getTypeDefault(t, this, group);
  }

  NopListener? findType(Type t, {Object? group}) {
    return getTypeOrNullDefault(t, this, group);
  }

  final _dependenceGroups = <Object?, HashMap<Type, NopListener>>{};
  final _dependenceTree = <GetTypePointers>[];

  void onDependenceAdd(GetTypePointers value) {
    if (_dependenceTree.contains(value)) return;
    _dependenceTree.add(value);

    assert(Log.w(data is NopLifeCycle
        ? '${GetTypePointers.getGroupName(data._listener?.group)}:'
            ' ${data.runtimeType} length: ${_dependenceTree.length}'
        : '${data.runtimeType} length: ${_dependenceTree.length}'));
    _updateDependence();
  }

  GetTypePointers? _syncTypePointers;

  void onDependenceRemove(GetTypePointers value) {
    final result = _dependenceTree.remove(value);
    if (_dependenceTree.isEmpty) {
      onRemove();
      return;
    }
    if (!result) return;
    _updateDependence();
  }

  void _updateDependence() {
    if (_dependenceTree.isEmpty) return;
    final first = _dependenceTree.first;
    if (first == _syncTypePointers) return;

    for (var group in _dependenceGroups.entries) {
      for (var entry in group.value.entries) {
        final t = GetTypePointers.getAlias(entry.key);
        if (first.findCurrentTypeArg(t, group.key) != null) continue;
        final subListener = entry.value;
        first.addListener(t, subListener, group.key);

        if (first is! NopDependencies) subListener.onDependenceAdd(first);
      }
    }
    _syncTypePointers = first;
  }

  static NopListener getTypeDefault(Type t, NopListener owner, Object? group) {
    t = GetTypePointers.getAlias(t);

    NopListener? listener = owner._dependenceGroups[group]?[t];

    if (listener == null) {
      listener = owner.handle?.getTypeListener(t, group);
      assert(owner._dependenceTree.isNotEmpty);
      listener ??= GetTypePointers.defaultGetNopListener(t, owner._dependenceTree.first, group);
      owner.addListener(t, listener, group);
      assert(owner.scope.index >= listener.scope.index);
    }

    return listener;
  }

  static NopListener? getTypeOrNullDefault(Type t, NopListener owner, Object? group) {
    t = GetTypePointers.getAlias(t);

    NopListener? listener = owner._dependenceGroups[group]?[t];
    if (listener == null) {
      listener = owner.handle?.findTypeListener(t, group);
      listener ??= GetTypePointers.defaultFindNopListener(t, owner._dependenceTree.first, group);
      if (listener != null) {
        owner.addListener(t, listener, group);
        assert(owner.scope.index >= listener.scope.index);
      }
    }

    return listener;
  }

  void addListener(Type t, NopListener listener, Object? group) {
    if (_dependenceGroups.containsKey(t)) return;
    _dependenceGroups.putIfAbsent(group, () => HashMap())[t] = listener;
    final sync = _syncTypePointers;
    if (sync == null) {
      _updateDependence();
      return;
    }
    if (sync.findCurrentTypeArg(t, group) != null) return;
    sync.addListener(t, listener, group);

    if (sync is! NopDependencies) listener.onDependenceAdd(sync);
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
}

class NopListenerDefault extends NopListener {
  NopListenerDefault(dynamic data, Object? group) : super(data, group);
  final Set<NopListenerHandle> _handles = {};

  @override
  NopListenerHandle? get handle {
    if (_handles.isNotEmpty) return _handles.first;
    return null;
  }

  @override
  void onRemove() {
    if (mounted) return;
    if (_secheduled) return;
    NopLifeCycle.disposeStart(data);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _secheduled = false;
      _onRemove();
    });
    _secheduled = true;
  }

  void _onRemove() {
    if (mounted) {
      NopLifeCycle.disposeCancel(data);
      return;
    }
    _dispose = true;
    NopLifeCycle.autoDispose(data);
    _init = false;
  }

  bool get isEmpty => _handles.isEmpty;

  bool _secheduled = false;

  bool _dispose = false;

  @override
  void remove(NopListenerHandle key) {
    assert(!_dispose);
    assert(_handles.contains(key));
    _handles.remove(key);

    final local = data;
    if (local is Listenable) {
      local.removeListener(key.update);
    }
    onRemove();
  }

  bool _init = false;

  @override
  void add(NopListenerHandle key) {
    assert(!_dispose);
    assert(!_handles.contains(key));

    _handles.add(key);
    if (!_init) {
      try {
        NopLifeCycle.autoInit(data, this);
      } catch (e, s) {
        Log.e('${data.runtimeType} init error: $e\n$s', onlyDebug: false);
      }
      _init = true;
    }
    final local = data;
    if (local is Listenable) {
      local.addListener(key.update);
    }
  }
}
