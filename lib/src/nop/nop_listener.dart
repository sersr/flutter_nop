import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:nop/nop.dart';

import '../../nop_state.dart';

/// 自动管理生命周期
mixin NopLifeCycle {
  @mustCallSuper
  void nopInit() {
    assert(mounted);
    final parents = attachToParents ?? const [];
    if (parents.isNotEmpty) {
      final listener = _listener!;
      for (var type in parents) {
        final parent = listener.getListener(type);
        parent.addSubListener(nopType, listener);
      }
    }
  }

  Type get nopType => runtimeType;

  @mustCallSuper
  void nopDispose() {
    assert(!mounted);
    final parents = attachToParents ?? const [];
    if (parents.isNotEmpty) {
      final listener = _listener!;
      for (var type in parents) {
        final parent = listener.getListener(type);
        parent.removeSubListener(nopType, listener);
      }
    }
  }

  NopListener? _listener;

  List<Type>? _parents;
  List<Type>? get attachToParents => _parents ??= null;

  bool get mounted => _listener != null && _listener!.mounted;

  /// 自动创建对象
  T getType<T>() {
    assert(mounted);
    return _listener!.getType<T>();
  }

  /// 查找已存在的共享对象，不会创建对象
  T? getTypeOrNull<T>() {
    assert(mounted);
    return _listener!.getTypeOrNull<T>();
  }

  void onDisposeStart() {}
  void onDisposeCancel() {}

  static void autoInit(Object lifeCycle, NopListener listener) {
    assert(Log.w('init: ${lifeCycle.runtimeType}'));
    if (lifeCycle is NopLifeCycle) {
      if (lifeCycle._listener == null) {
        lifeCycle._listener = listener;
        lifeCycle.nopInit();
      }
    }
  }

  static void disopseStart(Object lifeCycle) {
    assert(Log.w('dispose: ${lifeCycle.runtimeType}'));
    if (lifeCycle is NopLifeCycle) {
      lifeCycle.onDisposeStart();
    }
  }

  static void disopseCancel(Object lifeCycle) {
    assert(Log.w('dispose: ${lifeCycle.runtimeType}'));
    if (lifeCycle is NopLifeCycle) {
      lifeCycle.onDisposeCancel();
    }
  }

  static void autoDispse(Object lifeCycle) {
    assert(Log.w('dispose: ${lifeCycle.runtimeType}'));
    if (lifeCycle is NopLifeCycle) {
      lifeCycle.nopDispose();
      lifeCycle._listener = null;
    } else if (lifeCycle is ChangeNotifier) {
      lifeCycle.dispose();
    }
  }
}

mixin NopListenerHandle {
  void update();
  bool get mounted;
  NopListener getTypeListener(Type t);
  NopListener? findTypeListener(Type t);
}

abstract class NopListener {
  NopListener(this.data);
  final dynamic data;

  NopShareScope scope = NopShareScope.shared;

  bool get shared => scope == NopShareScope.shared;

  NopListenerHandle? get handle;
  bool get mounted =>
      _dependenceTree.isNotEmpty || handle != null && handle!.mounted;

  T getType<T>() => getTypeArg(T);
  T? getTypeOrNull<T>() => findType(T)?.data;

  void remove(NopListenerHandle key);

  void add(NopListenerHandle key);

  bool get canRemoved => _dependenceTree.isEmpty;

  void onRemove();

  dynamic getTypeArg(Type t) {
    assert(mounted);
    return getListener(t).data;
  }

  NopListener getListener(Type t) {
    return getTypeDefault(t, this);
  }

  NopListener? findType(Type t) {
    return getTypeOrNullDefault(t, this);
  }

  final Map<Type, NopListener> _subNopListeners = <Type, NopListener>{};
  final Map<Type, NopListener> _attachNopListeners = <Type, NopListener>{};
  final _dependenceTree = <GetTypePointers>[];

  void onDependenceAdd(GetTypePointers value) {
    if (_dependenceTree.contains(value)) return;
    _dependenceTree.add(value);

    assert(Log.w('add: ${data.runtimeType} ${_dependenceTree.length}'));
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

    for (var i in _subNopListeners.entries) {
      final t = GetTypePointers.getAlias(i.key);
      if (first.findCurrentTypeArg(t) != null) continue;
      final subListener = i.value;
      first.addListener(t, subListener);

      if (first is! NopDependencies) subListener.onDependenceAdd(first);
    }
    _syncTypePointers = first;
  }

  static NopListener getTypeDefault(Type t, NopListener owner) {
    t = GetTypePointers.getAlias(t);

    NopListener? listener = owner._subNopListeners[t];
    listener ??= owner._attachNopListeners[t];

    if (listener == null) {
      listener = owner.handle?.getTypeListener(t);
      if (owner.shared) {
        assert(owner._dependenceTree.isNotEmpty);
        listener ??= GetTypePointers.defaultGetNopListener(
            t, owner._dependenceTree.first);
      }
      if (listener != null) {
        owner.addListener(t, listener);
        assert(owner.scope.index >= listener.scope.index);
      }
    }

    return listener!;
  }

  static NopListener? getTypeOrNullDefault(Type t, NopListener owner) {
    t = GetTypePointers.getAlias(t);

    NopListener? listener = owner._subNopListeners[t];
    listener ??= owner._attachNopListeners[t];
    if (listener == null) {
      listener = owner.handle?.findTypeListener(t);
      if (owner._dependenceTree.isNotEmpty) {
        listener ??= GetTypePointers.defaultFindNopListener(
            t, owner._dependenceTree.first);
      }
      if (listener != null) {
        owner.addListener(t, listener);
        assert(owner.scope.index >= listener.scope.index);
      }
    }

    return listener;
  }

  void addListener(Type t, NopListener listener) {
    if (_subNopListeners.containsKey(t)) return;
    _subNopListeners[t] = listener;
    final sync = _syncTypePointers;
    if (sync == null) {
      _updateDependence();
      return;
    }
    if (sync.findCurrentTypeArg(t) != null) return;
    sync.addListener(t, listener);

    if (sync is! NopDependencies) listener.onDependenceAdd(sync);
  }

  void addSubListener(Type t, NopListener listener) {
    if (_attachNopListeners.containsKey(t)) return;
    _attachNopListeners[t] = listener;
  }

  void removeSubListener(Type t, NopListener listener) {
    _attachNopListeners.remove(t);
  }
}

/// 指定共享范围
/// 低级的共享域可以通过 [NopListener.attachToParents] 让高级的共享域访问
/// 低级共享域可以任意使用高级共享域
enum NopShareScope {
  /// 全局或路由链表共享
  shared,

  /// 当前`Page`中共享
  page,

  /// 不共享，独立的
  unique,
}

class NopListenerDefault extends NopListener {
  NopListenerDefault(dynamic data) : super(data);
  final Set<NopListenerHandle> _handles = {};

  @override
  NopListenerHandle? get handle {
    if (_handles.isNotEmpty) return _handles.first;
    return null;
  }

  bool get canDisposed => canRemoved && isEmpty;

  @override
  void onRemove() {
    if (!canDisposed) return;
    if (_secheduled) return;
    NopLifeCycle.disopseStart(data);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _secheduled = false;
      _onRemove();
    });
    _secheduled = true;
  }

  void _onRemove() {
    if (!canDisposed) {
      NopLifeCycle.disopseCancel(data);
      return;
    }
    _dispose = true;
    NopLifeCycle.autoDispse(data);
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
