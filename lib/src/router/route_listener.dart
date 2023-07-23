part of 'router.dart';

class RouteListener extends NopListener {
  RouteListener(this.router, super.data, super.group, super.t);
  @override
  bool get isGlobal => false;

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
    return RouteLocalListener.global(data, null, t, router);
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
