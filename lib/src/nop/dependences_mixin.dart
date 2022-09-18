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

  bool get isEmpty => _pointers.isEmpty;

  NopListener getType<T>({bool shared = true}) {
    return _getTypeArg(T, shared);
  }

  NopListener getTypeArg(Type t, {bool shared = true}) {
    return _getTypeArg(t, shared);
  }

  /// shared == false, 不保存引用
  NopListener _getTypeArg(Type t, bool shared) {
    t = getAlias(t);
    var listener = _findTypeArgSet(t);
    listener ??= _createListenerArg(t, shared);
    return listener;
  }

  NopListener? _findTypeArgSet(Type t) {
    var listener = _findCurrentTypeArg(t);
    listener ??= _findTypeOtherElement(t);
    if (listener != null && !_pointers.containsKey(t)) {
      assert(Log.w('sharedxx, create: $t'));
      addListener(t, listener);
    }

    return listener;
  }

  NopListener createListenerArg(Type t, {bool shared = true}) {
    t = getAlias(t);

    return _createListenerArg(t, shared);
  }

  NopListener _createListenerArg(Type t, bool shared) {
    var listener = createArg(t, shared: shared);

    assert(!_pointers.containsKey(t), t);

    assert(Log.w('shared: $shared, create: $t'));
    if (shared) addListener(t, listener); // 只有共享才会添加到共享域中
    return listener;
  }

  void addListener(Type t, NopListener listener) {
    t = getAlias(t);
    assert(!_pointers.containsKey(t), t);
    _pointers[t] = listener;
  }

  NopListener? findType<T>() {
    return _findTypeElement(getAlias(T));
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

  NopListener? _findTypeElement(Type t) {
    NopListener? listener;

    visitElement(
        (current) => (listener = current._findCurrentTypeArg(t)) != null);

    return listener;
  }

  NopListener? findTypeArg(Type t) {
    return _findTypeElement(getAlias(t));
  }

  NopListener? findTypeArgOther(Type t) {
    return _findTypeOtherElement(getAlias(t));
  }

  NopListener? _findTypeOtherElement(Type t) {
    NopListener? listener;

    visitOtherElement((current) {
      assert(current != this);
      return (listener = current._findCurrentTypeArg(t)) != null;
    });

    return listener;
  }

  NopListener? _findCurrentTypeArg(Type t) {
    return _pointers[t];
  }

  NopListener? findCurrentTypeArg(Type t) {
    return _pointers[getAlias(t)];
  }

  static NopListener Function(dynamic data) nopListenerCreater = _defaultCreate;
  static NopListener _defaultCreate(dynamic data) => NopListenerDefault(data);
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

  static NopListener defaultGetNopListener(Type t, GetTypePointers? current,
      {bool shared = true}) {
    NopListener? listener;
    if (shared) {
      listener = current?.findCurrentTypeArg(t);
      if (listener == null) {
        listener = current?.findTypeArgOther(t);
        // 全局查找
        listener ??= globalDependences.findTypeArg(t);
        if (listener != null) {
          current?.addListener(t, listener);
        }
      }
    }

    if (listener == null && current != null) {
      // 页面创建
      listener = current.createListenerArg(t, shared: shared);
      assert(listener.shared == shared);
    }
    assert(listener != null ||
        Log.w('Global Scope: create $t Object', position: 6));
    return listener ?? globalDependences.getTypeArg(t);
  }

  static NopListener? defaultFindNopListener(Type t, GetTypePointers? current) {
    var listener = current?.findCurrentTypeArg(t);
    listener ??= current?.findTypeArgOther(t);
    // 全局查找
    listener ??= globalDependences.findTypeArg(t);
    return listener;
  }

  static NopListener createUniqueListener(dynamic data) {
    final listener = nopListenerCreater(data);
    listener.scope = NopShareScope.unique;
    return listener;
  }

  static NopListener createArg(Type t, {bool shared = true}) {
    final factory = _get(t);
    final data = factory();
    final listener = nopListenerCreater(data);
    if (shared) {
      listener.scope = NopShareScope.shared;
    } else {
      listener.scope = NopShareScope.page;
    }
    return listener;
  }

  static Type Function(Type t) getAlias = Nav.getAlias;

  static _Factory getFactory = Nav.getArg;

  static _Factory? _factory;

  static _Factory get _get {
    if (_factory != null) return _factory!;
    assert(Log.w('init once.'));
    return _factory ??= getFactory;
  }

  static NopListener create<T>({bool shared = true}) {
    return createArg(T, shared: shared);
  }
}

typedef _Factory<T> = BuildFactory<T> Function(Type t);
