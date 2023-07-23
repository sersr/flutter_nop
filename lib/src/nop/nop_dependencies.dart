import 'package:flutter/material.dart';

import '../dependence/dependences_mixin.dart';
import '../dependence/nop_listener.dart';
import '../navigation/navigator_observer.dart';
import '../dependence/dependence_observer.dart';
import 'nop_listener.dart';

typedef GetFactory<T> = BuildFactory<T> Function(Type t);

class NopDependenceManager extends DependenceManager<NopDependence> {
  NopDependenceManager();

  @override
  NopDependence createNode(Route route) {
    return NopDependence(debugName: route.settings.name);
  }
}

class NopDependence extends RouteNode {
  NopDependence({this.debugName});
  final String? debugName;

  @override
  String toString() {
    return 'NopDependences#${debugName ?? hashCode}';
  }

  @override
  NopListener nopListenerCreater(dynamic data, Object? groupName, Type t) {
    return NopListenerDefault(data, groupName, t);
  }

  static (NopListener, bool) createUniqueListener(
      dynamic data, Type t, NopDependence? dependence, int? position) {
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

  static final _globalDependences = NopGlobalDependence();

  static NopGlobalDependence get globalDependences => _globalDependences;

  static void clear() {
    _globalDependences.clear();
  }

  static Type Function(Type t) getAlias = Nav.getAlias;

  static GetFactory getFactory = Nav.getArg;

  static GetFactory? _factory;

  static dynamic _build(Type t) {
    return (_factory ??= getFactory)(t)();
  }

  @override
  dynamic build(Type t) {
    return _build(t);
  }
}

class NopGlobalDependence with Node {
  @override
  build(Type t) {
    return NopDependence._build(t);
  }

  @override
  Node? get child => null;
  @override
  Node? get parent => null;

  @override
  NopListener nopListenerCreater(data, Object? groupName, Type t) {
    return NopListenerDefault(data, groupName, t);
  }

  bool _popped = false;
  @override
  bool get popped => _popped;

  void clear() {
    _popped = true;
    visitListener((_, item) {
      item.onPop();
      item.onRemoveDependence(this);
    });

    _popped = false;
  }
}
