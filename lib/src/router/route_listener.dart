part of 'router.dart';

mixin RouteDependenceMixin on Node {
  NRouter get _router;

  T getRouteData<T>(Object? group, int? position) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());

    final router = _router;
    final global = router.globalDependence;

    return Node.defaultGetData(
        router.getAlias(T), this, global, group, position);
  }

  T? findRouteData<T>(Object? group) {
    final router = _router;
    final global = router.globalDependence;

    return Node.defaultFindData(router.getAlias(T), this, global, group);
  }
}

class RouteListener extends NopListener {
  RouteListener(super.data, super.group, super.t);
  @override
  bool get isGlobal => false;

  RouteDependenceMixin? get entry => getDependence() as RouteDependenceMixin?;

  @override
  T? find<T>({Object? group}) {
    return entry!.findRouteData(group);
  }

  @override
  T get<T>({Object? group, int? position = 0}) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());

    return entry!.getRouteData(group, position);
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
  T? find<T>({Object? group}) {
    return router.find<T>(group: group, useEntryGroup: true);
  }

  @override
  T get<T>({Object? group, int? position = 0}) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());
    return router.grass(group: group, useEntryGroup: true, position: position);
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
