part of 'router.dart';

class RouteListener extends NopListener {
  RouteListener(super.data, super.group, super.t);
  @override
  bool get isGlobal => false;
  RouteQueueEntry? get entry => getDependence() as RouteQueueEntry?;
  @override
  NopListener? findType(Type t, {Object? group}) {
    return entry?.findListener(t, group);
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
