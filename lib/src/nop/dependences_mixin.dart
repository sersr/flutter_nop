import 'dart:collection';

import 'package:nop/utils.dart';

import '../navigation/navigator_observer.dart';
import 'nop_dependencies.dart';
import 'nop_listener.dart';

/// [GetTypePointers]
mixin GetTypePointers {
  GetTypePointers? get parent;
  GetTypePointers? get child;

  bool get popped => false;

  final _groupPointers = HashMap<Object?, HashMap<Type, NopListener>>();

  int get length => _groupPointers.values.fold(
      0, (previousValue, element) => previousValue + element.values.length);

  bool containsKey(Object? group, Type t) {
    return _groupPointers[group]?.containsKey(t) ?? false;
  }

  bool contains(GetTypePointers other) {
    bool contains = false;
    visitElement((current) => contains = current == other);

    return contains;
  }

  void addListener(Type t, NopListener listener, Object? groupName) {
    t = getAlias(t);
    assert(!containsKey(groupName, t), t);
    _groupPointers.putIfAbsent(groupName, createHashMap)[t] = listener;
    listener.onAddDependence(this);
  }

  void visitListener(ListenerVisitor visitor) {
    for (var group in _groupPointers.entries) {
      final name = group.key;
      for (var item in group.value.entries) {
        visitor(name, item.value);
      }
    }
  }

  bool get isEmpty => _groupPointers.isEmpty;

  NopListener? findTypeArg(Type t, Object? groupName) {
    return _findTypeElement(getAlias(t), groupName);
  }

  NopListener? findTypeArgOther(Type t, Object? groupName) {
    return _findTypeOtherElement(getAlias(t), groupName);
  }

  NopListener? findType<T>(Object? groupName) {
    return _findTypeElement(getAlias(T), groupName);
  }

  NopListener _getTypeArg(Type t, Object? groupName, int? position) {
    t = getAlias(t);
    var listener = _findTypeArgAndAdd(t, groupName);
    listener ??= _createListenerArg(t, groupName, position);
    return listener;
  }

  NopListener? _findTypeArgAndAdd(Type t, Object? groupName) {
    var listener = _findCurrentTypeArg(t, groupName);
    if (listener != null) return listener;
    listener = _findTypeOtherElement(t, groupName);
    if (listener != null) {
      assert(!containsKey(groupName, t));
      assert(Log.w('${getLabel(groupName)}: Add $t'));
      addListener(t, listener, groupName);
    }

    return listener;
  }

  NopListener? findCurrentTypeArg(Type t, Object? groupName) {
    t = getAlias(t);
    return _groupPointers[groupName]?[t];
  }

  static HashMap<T, V> createHashMap<T, V>() => HashMap<T, V>();

  static int? addPosition(int? position, {int step = 1}) {
    if (position == null) return null;
    return position + step;
  }

  static NopListener defaultGetNopListener(
      Type t, GetTypePointers? current, Object? groupName,
      {bool isSelf = true, int? position}) {
    if (current == null || current == globalDependences) {
      return globalDependences._getTypeArg(
          t, groupName, addPosition(position, step: 3));
    }

    t = getAlias(t);

    var listener = current._findCurrentTypeArg(t, groupName) ??
        globalDependences._findTypeElement(t, groupName);

    if (listener == null) {
      listener = current._findTypeOtherElement(t, groupName); // other

      // other: should add listener
      if (listener != null && isSelf) {
        current.addListener(t, listener, groupName);
      }
    }

    listener ??= current._createListenerArg(
        t, groupName, addPosition(position, step: 2));

    return listener;
  }

  static NopListener? defaultFindNopListener(
      Type t, GetTypePointers? current, Object? groupName) {
    t = getAlias(t);
    return current?._findTypeElement(t, groupName) ??
        globalDependences._findTypeElement(t, groupName);
  }

  static NopListener createUniqueListener(dynamic data, Type t) {
    var listener = NopLifeCycle.checkIsNopLisenter(data);
    if (listener != null) {
      return listener;
    }
    listener = nopListenerCreater(data, null, t);
    listener.scope = NopShareScope.unique;
    return listener;
  }

  static NopListener createArg(Type t, Object? groupName) {
    final factory = _get(t);
    final data = factory();
    final listener = nopListenerCreater(data, groupName, t);
    if (groupName != null) {
      listener.scope = NopShareScope.group;
    } else {
      listener.scope = NopShareScope.shared;
    }
    return listener;
  }

  static NopListener Function(dynamic data, Object? groupName, Type t)
      nopListenerCreater = _defaultCreate;

  static NopListener _defaultCreate(dynamic data, Object? group, Type t) =>
      NopListenerDefault(data, group, t);

  static GetTypePointers? _globalDependences;

  static GetTypePointers globalDependences =
      _globalDependences ??= NopDependence();

  static clear() {
    final dep = _globalDependences;
    _globalDependences = null;
    if (dep is NopDependence) {
      dep.removeCurrent();
    }
  }

  static Type Function(Type t) getAlias = Nav.getAlias;

  static GetFactory getFactory = Nav.getArg;

  static GetFactory? _factory;

  static GetFactory get _get {
    if (_factory != null) return _factory!;
    assert(Log.w('init once.'));
    return _factory ??= getFactory;
  }

  String getLabel(Object? groupName) {
    if (this == globalDependences) {
      if (groupName == null) {
        return 'Global';
      }
      return 'Global::$groupName';
    }
    return groupName?.toString() ?? '';
  }

  NopListener _createListenerArg(Type t, Object? groupName, int? position) {
    var listener = createArg(t, groupName);

    assert(!containsKey(groupName, t), t);

    assert(Log.w('[${getLabel(groupName)}]::$t created.',
        position: position ?? 0));
    addListener(t, listener, groupName);
    return listener;
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

  NopListener? _findTypeOtherElement(Type t, Object? groupName) {
    NopListener? listener;

    visitOtherElement((current) {
      assert(current != this);
      return (listener = current._findCurrentTypeArg(t, groupName)) != null;
    });

    return listener;
  }

  NopListener? _findCurrentTypeArg(Type t, Object? groupName) {
    return _groupPointers[groupName]?[t];
  }
}

typedef GetFactory<T> = BuildFactory<T> Function(Type t);
typedef ListenerVisitor = void Function(Object? group, NopListener listener);
