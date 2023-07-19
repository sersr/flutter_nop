import 'dart:collection';

import '../dependence/dependences_mixin.dart';
import '../dependence/nop_listener.dart';
import '../navigation/navigator_observer.dart';
import 'nop_listener.dart';

/// [GetTypePointers]
mixin GetTypePointers on Node {
  // NopListener? findTypeArg(Type t, Object? groupName) {
  //   return findTypeElement(getAlias(t), groupName);
  // }

  // NopListener? findTypeArgOther(Type t, Object? groupName) {
  //   return findTypeOtherElement(getAlias(t), groupName);
  // }

  // NopListener? findType<T>(Object? groupName) {
  //   return findTypeElement(getAlias(T), groupName);
  // }

  // NopListener? findCurrent(Type t, Object? groupName) {
  //   return findCurrentTypeArg(getAlias(t), groupName);
  // }

  @override
  NopListener nopListenerCreater(dynamic data, Object? groupName, Type t) {
    return NopListenerDefault(data, groupName, t);
  }

  static HashMap<T, V> createHashMap<T, V>() => HashMap<T, V>();

  static (NopListener, bool) createUniqueListener(
      dynamic data, Type t, GetTypePointers? dependence, int? position) {
    var listener = NopLifeCycle.checkIsNopLisenter(data);
    if (listener != null) {
      return (listener, false);
    }
    listener = globalDependences.nopListenerCreater(data, null, t);
    listener.scope = NopShareScope.unique;
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());
    listener.initWithFirstDependence(dependence ?? globalDependences,
        position: position);
    return (listener, true);
  }

  static GetTypePointers? _globalDependences;

  static GetTypePointers globalDependences =
      _globalDependences ??= NopDependence();

  static clear() {
    final dep = _globalDependences;
    _globalDependences = null;
    if (dep is NopDependence) {
      dep.completed();
    }
  }

  static Type Function(Type t) getAlias = Nav.getAlias;

  static GetFactory getFactory = Nav.getArg;

  static GetFactory? _factory;

  @override
  dynamic build(Type t) {
    return (_factory ??= getFactory)(t)();
  }
}

typedef GetFactory<T> = BuildFactory<T> Function(Type t);

class NopDependence with Node, GetTypePointers {
  NopDependence({this.debugName});
  final String? debugName;
  @override
  NopDependence? parent;
  @override
  NopDependence? child;

  bool get isAlone => parent == null && child == null;

  NopDependence? get lastChild {
    NopDependence? last = child;
    while (last != null) {
      final child = last.child;
      if (child == null) break;
      last = child;
    }

    return last;
  }

  bool get isFirst => parent == null;
  bool get isLast => child == null;

  NopDependence? get firstParent {
    NopDependence? first = parent;
    while (first != null) {
      final parent = first.parent;
      if (parent == null) break;
      first = parent;
    }
    return first;
  }

  NopDependence get lastChildOrSelf {
    return lastChild ?? this;
  }

  NopDependence get firstParentOrSelf {
    return firstParent ?? this;
  }

  void updateChild(NopDependence newChild) {
    assert(child == null || child!.parent == this);
    newChild.child = child?.child;
    newChild.child?.parent = newChild;
    child?._remove();
    newChild.parent = this;
    child = newChild;
  }

  void insertChild(NopDependence newChild) {
    newChild.child = child;
    child?.parent = newChild;
    newChild.parent = this;
    child = newChild;
  }

  bool _poped = false;
  @override
  bool get popped => _poped;

  void onPop() {
    if (_poped) return;
    _poped = true;

    _remove();

    visitListener((_, listener) {
      listener.onPop();
    });
  }

  void _remove() {
    parent?.child = child;
    child?.parent = parent;
    parent = null;
    child = null;
  }

  void completed() {
    onPop();

    visitListener((_, item) {
      item.onRemoveDependence(this);
    });

    dispose();
  }

  @override
  String toString() {
    return 'NopDependences#${debugName ?? hashCode}';
  }
}
