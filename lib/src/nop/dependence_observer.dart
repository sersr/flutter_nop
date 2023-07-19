import 'package:flutter/material.dart';

import '../navigation/navigator_observer.dart';
import 'nop_dependencies.dart';

class DependenceManager {
  DependenceManager();

  void didPop(Route route) {
    _pop(route);
  }

  void didPush(Route route) {
    _push(route);
  }

  void didRemove(Route route) {
    _pop(route);
  }

  final _caches = <Route, NopDependence>{};

  NopDependence? currentDependence;

  void clear() {
    _caches.clear();
    currentDependence = null;
  }

  void _pop(Route route) {
    final dependence = _caches[route];
    if (dependence == null) return;

    if (currentDependence == dependence) {
      currentDependence = dependence.child ?? dependence.parent;
    }
    dependence.onPop();
  }

  void _handleCompleted(Route route) {
    if (route is TransitionRoute) {
      route.completed.whenComplete(() {
        final dependence = _caches.remove(route);
        dependence?.completed();
      });
    }
  }

  static DependenceManager get dependenceManager => Nav.dependenceManager;

  NopDependence? getRouteDependence(BuildContext context, {Route? route}) {
    route ??= ModalRoute.of(context);
    if (route == null) return null;
    return dependenceManager._push(route);
  }

  NopDependence _push(Route route) {
    final value = _caches[route];
    if (value != null) return value;

    final currentRouteDep = NopDependence(debugName: route.settings.name);
    _caches[route] = currentRouteDep;
    _handleCompleted(route);

    if (currentDependence != null) {
      currentDependence!.insertChild(currentRouteDep);
    }
    return currentDependence = currentRouteDep;
  }
}
