import 'package:flutter/material.dart';

import 'dependence_mixin.dart';

abstract mixin class DependenceManager<T extends RouteNode> {
  void didPop(Route route) {
    _pop(route);
  }

  void didRemove(Route route) {
    _pop(route);
  }

  final _caches = <Object, T>{};

  T? _currentDependence;

  void clear() {
    _caches.clear();
    _currentDependence = null;
  }

  void _pop(Route route) {
    final dependence = _caches[route];
    if (dependence == null) {
      if (route is TransitionRoute) {
        _caches[route] = createNode(route)..onPop();
        route.completed.whenComplete(() {
          final dependence = _caches.remove(route);
          dependence?.completed();
        });
      }
      return;
    }

    if (identical(_currentDependence, dependence)) {
      _currentDependence = (dependence.child ?? dependence.parent) as T?;
    }
    dependence.onPop();
  }

  T createNode(Route route);

  T? getRouteDependence(BuildContext? context) {
    if (context == null) return _currentDependence;

    final route = ModalRoute.of(context);
    if (route == null) return _currentDependence;

    final value = _caches[route];
    if (value != null) return value;
    final currentRouteDep = createNode(route);

    _caches[route] = currentRouteDep;

    route.completed.whenComplete(() {
      final dependence = _caches.remove(route);
      dependence?.completed();
    });

    if (_currentDependence != null) {
      _currentDependence!.insertChild(currentRouteDep);
    }
    return _currentDependence = currentRouteDep;
  }
}
