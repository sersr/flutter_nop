import 'dart:collection';

import 'package:nop/utils.dart';

import '../navigation/navigator_observer.dart';
import 'nop_dependencies.dart';
import 'nop_listener.dart';

/// [GetTypePointers]
mixin GetTypePointers {
  final _pointers = HashMap<Type, NopListener>();

  Iterable<NopListener> get listeners => _pointers.values;
  GetTypePointers? get parent;
  GetTypePointers? get child;

  final _pointersGroup = HashMap<Object, HashMap<Type, NopListener>>();

  void visiteNoListener(void Function(NopListener item) visitor) {
    for (var item in listeners) {
      visitor(item);
    }
    for (var group in _pointersGroup.entries) {
      for (var item in group.value.entries) {
        visitor(item.value);
      }
    }
  }

  bool get isEmpty => _pointers.isEmpty;

  NopListener getType<T>(Object groupName, {bool shared = true}) {
    return _getTypeArg(T, shared, groupName);
  }

  NopListener getTypeArg(Type t, Object? groupName, {bool shared = true}) {
    return _getTypeArg(t, shared, groupName);
  }

  /// shared == false, 不保存引用
  NopListener _getTypeArg(Type t, bool shared, Object? groupName) {
    t = getAlias(t);
    var listener = _findTypeArgSet(t, groupName);
    listener ??= _createListenerArg(t, shared, groupName);
    return listener;
  }

  NopListener? _findTypeArgSet(Type t, Object? groupName) {
    var listener = _findCurrentTypeArg(t, groupName);
    listener ??= _findTypeOtherElement(t, groupName);
    if (listener != null && !_pointers.containsKey(t)) {
      assert(Log.w('shared, create: $t'));
      addListener(t, listener, groupName);
    }

    return listener;
  }

  NopListener createListenerArg(Type t, Object? groupName,
      {bool shared = true}) {
    t = getAlias(t);

    return _createListenerArg(t, shared, groupName);
  }

  NopListener _createListenerArg(Type t, bool shared, Object? groupName) {
    var listener = createArg(t, shared: shared, groupName);

    assert(!_pointers.containsKey(t), t);

    assert(Log.w('shared: $shared, create: $t'));
    if (shared || groupName != null) {
      addListener(t, listener, groupName);
    } // 只有共享才会添加到共享域中
    return listener;
  }

  void addListener(Type t, NopListener listener, Object? groupName) {
    t = getAlias(t);
    if (groupName != null) {
      _pointersGroup.putIfAbsent(groupName, () => HashMap())[t] = listener;
      return;
    }
    assert(!_pointers.containsKey(t), t);
    _pointers[t] = listener;
  }

  NopListener? findType<T>(Object? groupName) {
    return _findTypeElement(getAlias(T), groupName);
  }

  bool contains(GetTypePointers other) {
    bool contains = false;
    visitElement((current) => contains = current == other);

    return contains;
  }

  void visitElement(bool Function(GetTypePointers current) visitor) {
    if (visitor(this)) return;
    visitOtherElement(visitor);
  }

  void visitOtherElement(bool Function(GetTypePointers current) visitor) {
    GetTypePointers? current = parent;
    var success = false;
    while (current != null) {
      if (success = visitor(current)) return;
      current = current.parent;
    }

    if (!success) {
      current = child;
      while (current != null) {
        if (visitor(current)) return;
        current = current.child;
      }
    }
  }

  NopListener? _findTypeElement(Type t, Object? groupName) {
    NopListener? listener;

    visitElement((current) =>
        (listener = current._findCurrentTypeArg(t, groupName)) != null);

    return listener;
  }

  NopListener? findTypeArg(Type t, Object? groupName) {
    return _findTypeElement(getAlias(t), groupName);
  }

  NopListener? findTypeArgOther(Type t, Object? groupName) {
    return _findTypeOtherElement(getAlias(t), groupName);
  }

  NopListener? _findTypeOtherElement(Type t, Object? groupName) {
    NopListener? listener;

    visitOtherElement((current) {
      assert(current != this);
      return (listener = current._findCurrentTypeArg(t, groupName)) != null;
    });

    return listener;
  }

  NopListener? _findCurrentTypeArg(Type t, Object? groupName) {
    if (groupName != null) {
      return _pointersGroup[groupName]?[t];
    }
    return _pointers[t];
  }

  NopListener? findCurrentTypeArg(Type t, Object? groupName) {
    t = getAlias(t);
    if (groupName != null) {
      return _pointersGroup[groupName]?[t];
    }
    return _pointers[t];
  }

  static NopListener Function(dynamic data, Object? groupName)
      nopListenerCreater = _defaultCreate;
  static NopListener _defaultCreate(dynamic data, Object? group) =>
      NopListenerDefault(data, group);
  static GetTypePointers? _globalDependences;
  static GetTypePointers globalDependences =
      _globalDependences ??= NopDependencies();

  static clear() {
    final dep = _globalDependences;
    _globalDependences = null;
    if (dep is NopDependencies) {
      dep.removeCurrent();
    }
  }

  static NopListener defaultGetNopListener(
      Type t, GetTypePointers? current, Object? groupName,
      {bool shared = true}) {
    NopListener? listener;
    if (shared || groupName != null) {
      listener = current?.findCurrentTypeArg(t, groupName);
      if (listener == null) {
        listener = current?.findTypeArgOther(t, groupName);
        // 全局查找
        listener ??= globalDependences.findTypeArg(t, groupName);
        if (listener != null) {
          current?.addListener(t, listener, groupName);
        }
      }
    }

    if (listener == null && current != null) {
      // 页面创建
      listener = current.createListenerArg(t, groupName, shared: shared);
      assert(listener.shared == shared);
    }
    assert(listener != null ||
        Log.w('Global Scope: create $t Object', position: 6));
    return listener ?? globalDependences.getTypeArg(t, groupName);
  }

  static NopListener? defaultFindNopListener(
      Type t, GetTypePointers? current, Object? groupName) {
    var listener = current?.findCurrentTypeArg(t, groupName);
    listener ??= current?.findTypeArgOther(t, groupName);
    // 全局查找
    listener ??= globalDependences.findTypeArg(t, groupName);
    return listener;
  }

  static NopListener createUniqueListener(dynamic data) {
    final listener = nopListenerCreater(data, null);
    listener.scope = NopShareScope.unique;
    return listener;
  }

  static NopListener createArg(Type t, Object? groupName,
      {bool shared = true}) {
    final factory = _get(t);
    final data = factory();
    final listener = nopListenerCreater(data, groupName);
    if (shared) {
      listener.scope = NopShareScope.shared;
    } else if (groupName != null) {
      listener.scope = NopShareScope.group;
    } else {
      listener.scope = NopShareScope.page;
    }
    return listener;
  }

  static Type Function(Type t) getAlias = Nav.getAlias;

  static GetFactory getFactory = Nav.getArg;

  static GetFactory? _factory;

  static GetFactory get _get {
    if (_factory != null) return _factory!;
    assert(Log.w('init once.'));
    return _factory ??= getFactory;
  }

  static NopListener create<T>(Object? groupName, {bool shared = true}) {
    return createArg(T, shared: shared, groupName);
  }
}

typedef GetFactory<T> = BuildFactory<T> Function(Type t);
