part of 'router.dart';

class RouteListener extends NopListener {
  RouteListener(this.router) : isGlobal = false;
  RouteListener.global(this.router) : isGlobal = true;

  @override
  final bool isGlobal;

  final NRouter router;

  @override
  Type getAlias(Type type) {
    return router.getAlias(type);
  }

  @override
  Node get global => router.globalDependence;
}

class NRouterDependence extends RouteNode {
  NRouterDependence(this.router, this.route);
  @override
  final Route route;
  final NRouter router;

  @override
  dynamic build(Type t) {
    return router.getArg(t)();
  }

  @override
  NopListener nopListenerCreater() {
    return RouteListener(router);
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
  NopListener nopListenerCreater() {
    return RouteListener.global(router);
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
