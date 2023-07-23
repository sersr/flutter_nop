part of 'router.dart';

class RouteListener extends NopListener {
  RouteListener(this.router, super.data, super.group, super.t)
      : isGlobal = false;
  RouteListener.global(this.router, super.data, super.group, super.t)
      : isGlobal = true;

  @override
  final bool isGlobal;

  final NRouter router;

  Node? get entry => getDependence();

  @override
  T get<T>({Object? group, int? position}) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());

    final global = router.globalDependence;

    return Node.defaultGetData(
        router.getAlias(T), entry, global, group, position);
  }

  @override
  T? find<T>({Object? group}) {
    final global = router.globalDependence;

    return Node.defaultFindData(router.getAlias(T), entry, global, group);
  }
}

class NRouterDependence extends RouteNode {
  NRouterDependence(this.router);

  final NRouter router;

  @override
  dynamic build(Type t) {
    return router.getArg(t)();
  }

  @override
  NopListener nopListenerCreater(data, Object? groupName, Type t) {
    return RouteListener(router, data, groupName, t);
  }
}

class NRouterGlobalDependence with Node {
  NRouterGlobalDependence(this.router);

  final NRouter router;

  @override
  dynamic build(Type t) {
    return router.getArg(t)();
  }

  @override
  Node? get child => null;
  @override
  Node? get parent => null;

  @override
  NopListener nopListenerCreater(data, Object? groupName, Type t) {
    return RouteListener.global(router, data, groupName, t);
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
