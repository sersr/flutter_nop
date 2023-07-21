import 'package:flutter/foundation.dart';
import 'package:nop/utils.dart';

import 'nop_listener.dart';

mixin Node {
  Node? get parent;
  Node? get child;
  bool get popped => false;

  final _groupPointers = <Object?, Map<Type, NopListener>>{};

  int get length => _groupPointers.values.fold(
      0, (previousValue, element) => previousValue + element.values.length);

  bool containsKey(Object? group, Type t) {
    return _groupPointers[group]?.containsKey(t) ?? false;
  }

  bool contains(Node other) {
    bool contains = false;
    visitElement((current) => contains = current == other);

    return contains;
  }

  void addListener(
      Type t, NopListener listener, Object? groupName, int? position) {
    assert(!containsKey(groupName, t), t);
    _groupPointers.putIfAbsent(groupName, () => {})[t] = listener;
    listener.onAddDependence(this);
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());
    assert(listener.length <= 1 ||
        Log.w('${listener.label} Add: ${listener.length}.',
            position: position ?? 0));
  }

  void visitListener(ListenerVisitor visitor) {
    for (var group in _groupPointers.entries) {
      final name = group.key;
      for (var item in group.value.entries) {
        visitor(name, item.value);
      }
    }
  }

  void dispose() {
    _groupPointers.clear();
  }

  bool get isEmpty => _groupPointers.isEmpty;

  // NopListener _createListenerArg(Type t, Object? groupName, int? position) {
  //   var listener = createArg(t, groupName);

  //   assert(!containsKey(groupName, t), t);

  //   listener.initWithFirstDependence(this, position: position);
  //   addListener(t, listener, groupName);

  //   return listener;
  // }

  void visitElement(bool Function(Node current) visitor) {
    if (visitor(this)) return;
    visitOtherElement(visitor);
  }

  void visitOtherElement(bool Function(Node current) visitor) {
    Node? current = parent;
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

  @protected
  NopListener? findTypeElement(Type t, Object? groupName) {
    NopListener? listener;

    visitElement((current) =>
        (listener = current.findCurrentTypeArg(t, groupName)) != null);

    return listener;
  }

  @protected
  NopListener? findTypeOtherElement(Type t, Object? groupName) {
    NopListener? listener;

    visitOtherElement((current) {
      assert(current != this);
      return (listener = current.findCurrentTypeArg(t, groupName)) != null;
    });

    return listener;
  }

  @protected
  NopListener? findCurrentTypeArg(Type t, Object? groupName) {
    return _groupPointers[groupName]?[t];
  }

  NopListener nopListenerCreater(dynamic data, Object? groupName, Type t);

  dynamic build(Type t);

  NopListener _createArg(Type t, Object? groupName) {
    final data = build(t);

    final listener = nopListenerCreater(data, groupName, t);
    if (groupName != null) {
      listener.scope = NopShareScope.group;
    } else {
      listener.scope = NopShareScope.shared;
    }
    return listener;
  }

  @protected
  NopListener createListenerArg(Type t, Object? groupName, int? position) {
    var listener = _createArg(t, groupName);

    assert(!containsKey(groupName, t), t);
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());
    listener.initWithFirstDependence(this, position: position);
    addListener(t, listener, groupName, position);

    return listener;
  }

  NopListener? findListener(Type t, Object? groupName) {
    return findTypeElement(t, groupName);
  }

  NopListener getListener(Type t, Object? groupName, int? position) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());
    return findTypeArgAndAdd(t, groupName, position) ??
        createListenerArg(t, groupName, position);
  }

  NopListener? findTypeArgAndAdd(Type t, Object? groupName, position) {
    var listener = findCurrentTypeArg(t, groupName);
    if (listener != null) return listener;
    listener = findTypeOtherElement(t, groupName);
    if (listener != null) {
      assert(() {
        position = position == null ? null : position! + 1;
        return true;
      }());
      assert(!containsKey(groupName, t));
      addListener(t, listener, groupName, position);
    }

    return listener;
  }

  static T defaultGetData<T>(Type alias, Node? current, Node globalDependence,
      Object? groupName, int? position) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());
    if (current == null || current == globalDependence) {
      return globalDependence.getListener(alias, groupName, position).data;
    }

    var listener = current.findCurrentTypeArg(alias, groupName) ??
        globalDependence.findTypeElement(alias, groupName);

    if (listener == null) {
      listener = current.findTypeOtherElement(alias, groupName); // other

      // other: should add listener
      if (listener != null) {
        current.addListener(alias, listener, groupName, position);
      }
    }

    listener ??= current.createListenerArg(alias, groupName, position);
    return listener.data;
  }

  static T? defaultFindData<T>(
      Type t, Node? current, Node globalDependences, Object? groupName) {
    final listener = current?.findTypeElement(t, groupName) ??
        globalDependences.findTypeElement(t, groupName);
    return listener?.data;
  }
}

typedef ListenerVisitor = void Function(Object? group, NopListener listener);
