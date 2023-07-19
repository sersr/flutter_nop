part of 'router.dart';

mixin RouteDependenceMixin on Node {
  NRouter get _router;

  NopListener getRouteListener(Type t, Object? group, int? position) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());

    final router = _router;
    final global = router.globalDependence;
    t = router.getAlias(t);

    return Node.defaultGetNopListener(t, this, global, group, position);
  }

  NopListener? findRouteListener(Type t, Object? group) {
    final router = _router;
    final global = router.globalDependence;
    t = router.getAlias(t);

    return Node.defaultFindNopListener(t, this, global, group);
  }
}

class RouteListener extends NopListener {
  RouteListener(super.data, super.group, super.t);
  @override
  bool get isGlobal => false;

  RouteDependenceMixin? get entry => getDependence() as RouteDependenceMixin?;

  @override
  NopListener? findType(Type t, {Object? group}) {
    return entry!.findRouteListener(t, group);
  }

  @override
  NopListener getListener(Type t, {Object? group, int? position = 0}) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());

    return entry!.getRouteListener(t, group, position);
  }
}

class RouteLocalListener extends NopListener {
  RouteLocalListener(super.data, super.group, super.t, this.router)
      : isGlobal = false;
  RouteLocalListener.global(super.data, super.group, super.t, this.router)
      : isGlobal = true;
  final NRouter router;
  @override
  final bool isGlobal;

  @override
  NopListener? findType(Type t, {Object? group}) {
    return router._findListener(t: t, group: group, global: true);
  }

  @override
  NopListener getListener(Type t, {Object? group, int? position = 0}) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());
    return router._getListener(
        t: t, group: group, global: true, position: position);
  }
}

class NRouterGlobalDependence with Node, RouteDependenceMixin {
  NRouterGlobalDependence(this.router);

  final NRouter router;

  @override
  NRouter get _router => router;

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
    return RouteLocalListener.global(data, null, t, router);
  }

  bool _poped = false;
  @override
  bool get popped => _poped;

  void clear() {
    _poped = true;
    visitListener((_, item) {
      item.onPop();
      item.onRemoveDependence(this);
    });

    _poped = false;
  }
}
