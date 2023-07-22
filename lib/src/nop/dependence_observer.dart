import 'package:flutter/material.dart';

import '../navigation/navigator_observer.dart';
import 'nop_dependencies.dart';

typedef OnRouteDisposeFn = void Function(void Function());

class DependenceManager {
  DependenceManager();

  void didPop(Route route) {
    _pop(route);
  }

  void didPush(Route route) {
    // _push(route);
    // _secheduleClean();
  }

  void didRemove(Route route) {
    _pop(route);
  }

  // final _groupIdMap = <Route, Object?>{};

  // var _scheduled = false;

  // void _secheduleClean() {
  //   if (_scheduled) return;

  //   scheduleMicrotask(() {
  //     _scheduled = false;
  //     _groupIdMap.removeWhere((key, value) => key.navigator == null);
  //   });
  //   _scheduled = true;
  // }

  // void addRouteGroupId(Route route, Object? groupId) {
  //   _groupIdMap.putIfAbsent(route, () => groupId);
  // }

  final _caches = <Object, NopDependence>{};

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

  static DependenceManager get dependenceManager => Nav.dependenceManager;

  NopDependence? getRouteDependence(BuildContext? context) {
    if (context == null) return currentDependence;

    final route = ModalRoute.of(context);
    if (route == null) return currentDependence;

    final value = _caches[route];
    if (value != null) return value;
    final currentRouteDep = NopDependence(debugName: route.settings.name);
    _caches[route] = currentRouteDep;

    route.completed.whenComplete(() {
      final dependence = _caches.remove(route);
      dependence?.completed();
    });

    if (currentDependence != null) {
      currentDependence!.insertChild(currentRouteDep);
    }
    return currentDependence = currentRouteDep;
  }
}
