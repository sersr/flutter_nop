import 'package:flutter/material.dart';

import '../dependence/dependence_mixin.dart';
import '../dependence/factory.dart';
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
    return 'Nopdependence#${debugName ?? hashCode}';
  }

  @override
  NopListener nopListenerCreater() {
    return NopListenerDefault();
  }

  static (NopListener, bool) createUniqueListener(
      dynamic data, Type t, NopDependence? dependence, int? position) {
    var listener = NopLifecycle.checkIsNopLisenter(data);
    if (listener != null) {
      return (listener, false);
    }
    listener = globalDependence.nopListenerCreater();
    listener.scope = NopShareScope.unique;
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());
    listener.initWithFirstDependence(
        dependence ?? globalDependence, data, null, t, position);
    return (listener, true);
  }

  static final _globalDependence = NopGlobalDependence();

  static NopGlobalDependence get globalDependence => _globalDependence;

  static void clear() {
    _globalDependence.clear();
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
  NopListener nopListenerCreater() {
    return NopListenerDefault();
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
