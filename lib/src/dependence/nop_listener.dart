import 'package:nop/nop.dart';
import 'package:flutter/material.dart';
import 'dependences_mixin.dart';

/// 自动管理生命周期
mixin NopLifeCycle {
  static final _caches = <Object, NopListener>{};
  Object? get groupId => _listener?.group;

  bool get isSingleton => false;

  bool get poped => _listener?.popped ?? true;

  void nopInit() {}

  /// 当前对象的生命周期超出[_listener]时，再次初始化时调用。
  ///
  /// 比如调用[Navigator.pushReplacementNamed]时，新的页面和当前一致，
  /// 此时因为页面动画还未结束并未调用[nopDispose]，也没有从[_caches]移除对象。
  ///
  /// 当初始化[autoInit]时发现[_caches]中还存在对象时调用[nopReInit]，[_listener]也会被替换。
  void nopReInit() {}
  void nopDispose() {}

  void onPop() {}

  NopListener? _listener;

  bool get mounted => _listener != null && _listener!.mounted;
  bool get isGlobal => _listener != null && _listener!.isGlobal;

  NopShareScope get scope => _listener?.scope ?? NopShareScope.detached;

  bool get isLocal => scope == NopShareScope.unique;

  bool get isShared =>
      scope == NopShareScope.shared || scope == NopShareScope.group;

  /// 自动创建对象
  T getType<T>({Object? group, int? position = 0}) {
    assert(mounted);
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());
    return _listener!.get(group: group, position: position);
  }

  /// 查找已存在的共享对象，不会创建对象
  T? getTypeOrNull<T>({Object? group}) {
    assert(mounted);
    return _listener!.find(group: group);
  }

  String get label => _listener?.label ?? '';

  static void autoInit(NopListener listener) {
    final data = listener.data;

    if (data is NopLifeCycle) {
      if (data._listener == null) {
        data._listener = listener;
        data.nopInit();
      } else {
        // `data` may be a static/const object.
        data._listener!._ignore = true;
        data._listener = listener;
        data.nopReInit();
      }
    } else {
      _caches[data]?._ignore = true;
      _caches[data] = listener;
    }
    // assert(Log.w(listener.label));
  }

  static void autoDispose(NopListener listener) {
    final data = listener.data;
    // assert(Log.w(listener.label));

    if (data is NopLifeCycle) {
      data.nopDispose();
      data._listener = null;
    } else {
      _caches.remove(data);
    }
  }

  static void autoPop(NopListener listener) {
    // assert(Log.w(listener.label));
    switch (listener.data) {
      case NopLifeCycle nop:
        nop.onPop();
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

  bool contains(Node? node) => _dependenceTree.contains(node);

  bool get mounted => _dependenceTree.isNotEmpty;

  bool get canRemoved => _dependenceTree.isEmpty;
  int get length => _dependenceTree.length;

  bool get isGlobal;

  bool _init = false;

  void initWithFirstDependence(Node dependence, {int? position}) {
    assert(!_init && _dependenceTree.isEmpty);
    _init = true;

    _dependenceTree.add(dependence);
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());
    assert(Log.w('$label created.', position: position ?? 0));

    NopLifeCycle.autoInit(this);
  }

  T get<T>({Object? group, int? position = 0});

  T? find<T>({Object? group});

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

  final _dependenceTree = <Node>[];

  void onAddDependence(Node value) {
    if (_dependenceTree.contains(value)) return;
    assert(_init, 'You must call `initWithFirstDependence` first.');

    _dependenceTree.add(value);
    // assert(Log.w('$label ${_dependenceTree.length}.'));
  }

  void onRemoveDependence(Node value) {
    _dependenceTree.remove(value);
    assert(Log.w('$label ${_dependenceTree.length}.'));

    if (_dependenceTree.isEmpty) {
      _onRemove();
    }
  }

  void uniqueDispose() {
    assert(scope == NopShareScope.unique && !_popped);

    _popped = true;
    onPop();

    assert(_dependenceTree.length == 1);
    _dependenceTree.clear();
    _onRemove();
  }

  bool _ignore = false;

  void _onRemove() {
    assert(!mounted);
    if (_ignore) return;

    NopLifeCycle.autoDispose(this);
  }

  void onPop() {
    assert(mounted);
    if (!popped || _ignore) return;
    NopLifeCycle.autoPop(this);
  }

  Node? getDependence() => _dependenceTree.firstOrNull;
}

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
