import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:nop/nop.dart';

import '../dependence/dependence_observer.dart';
import '../dependence/dependence_mixin.dart';
import '../dependence/factory.dart';
import '../dependence/nop_listener.dart';
import 'web/history_state.dart';

part 'delegate.dart';
part 'page.dart';
part 'route_listener.dart';
part 'route_queue.dart';
part 'state.dart';

/// Example:
/// ```dart
/// final router = NRouter( ... );
/// ...
/// final app = MaterialApp(
///   restorationScopeId: 'restore Id', // immutable
///   builder: (context, child) {
///    return router.build(context);
/// },
///  title: 'router demo',
/// );
///
/// or:
///
/// final app = MaterialApp.router(
///   restorationScopeId: 'restore Id', // immutable
///   routerConfig: router,
///   title: 'router demo',
/// );
/// ```

class NRouter
    with DependenceManager<NRouterDependence>, BuildFactoryMixin
    implements RouterConfig<RouteQueue> {
  NRouter({
    required this.rootPage,
    String? restorationId,
    Map<String, dynamic> params = const {},
    Map<String, dynamic>? extra,
    Object? groupId,
    this.observers = const [],
    this.updateLocation = false,
  }) {
    routerDelegate = NRouterDelegate(
        restorationId: restorationId, rootPage: rootPage, router: this);
    routerDelegate.init(params, extra, groupId);
  }
  final NPageMain rootPage;
  final bool updateLocation;
  final List<NavigatorObserver> observers;

  /// 根据给出路径判断是否有效
  bool isValid(String location) {
    return routerDelegate.isValid(location);
  }

  RouteQueueEntry? getEntryFromId(int id) {
    return routerDelegate.routeQueue.getEntryFromId(id);
  }

  static NRouter of(BuildContext context) {
    return maybeOf(context)!;
  }

  static NRouter? maybeOf(BuildContext context) {
    final router = RouteRestorable.maybeOf(context);
    return router?.delegate.router;
  }

  RouteQueueEntry? ofEntry(BuildContext context) {
    final current = RouteQueueEntry.of(context);
    assert(current == null || routerDelegate.routeQueue.isCurrent(current));
    return current;
  }

  bool removeCurrent(BuildContext context, [dynamic result]) {
    final entry = ofEntry(context);
    if (entry != null) {
      entry._removeCurrent(result: result);
      return true;
    }
    return false;
  }

  @override
  final backButtonDispatcher = RootBackButtonDispatcher();

  @override
  RouteInformationParser<RouteQueue>? get routeInformationParser => null;

  @override
  RouteInformationProvider? get routeInformationProvider => null;

  @override
  late final NRouterDelegate routerDelegate;

  bool canPop() => routerDelegate.canPop();

  /// 在 [MaterialApp].builder 中使用
  Widget build(BuildContext context) {
    return routerDelegate.build(context);
  }

  RouteQueueEntry go(String location,
      {Map<String, dynamic> params = const {},
      Map<String, dynamic>? extra,
      Object? groupId}) {
    return routerDelegate.go(location,
        params: params, extra: extra, groupId: groupId);
  }

  RouteQueueEntry goPage(NPage page,
      {Map<String, dynamic> params = const {},
      Map<String, dynamic>? extra,
      Object? groupId}) {
    return routerDelegate.goPage(page,
        params: params, extra: extra, groupId: groupId);
  }

  RouteQueueEntry goUntil(String location, UntilFn until) {
    return routerDelegate.goUntil(location, until);
  }

  void popUntil(UntilFn test, {bool ignore = false}) {
    routerDelegate.popUntil(test, ignore);
  }

  void popUntilNav(UntilFn test, {bool Function(Route route)? routeTest}) {
    routerDelegate.popUntilNav(test, routeTest: routeTest);
  }

  void pop([Object? result]) {
    routerDelegate.pop(result);
  }

  void maybePop([Object? result]) {
    routerDelegate.maybePop();
  }

  /// dependence ------------------------------------
  late final _global = NRouterGlobalDependence(this);

  @override
  void clear() {
    super.clear();
    _global.clear();
  }

  NRouterGlobalDependence get globalDependence => _global;

  T global<T>({Object? group, int? position = 0}) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());

    return Node.defaultGetData(T, null, globalDependence, group, position);
  }

  T grass<T>({
    BuildContext? context,
    Object? group,
    bool useEntryGroup = true,
    int? position = 0,
  }) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());
    final dependence = getRouteDependence(context);

    if (context != null && useEntryGroup) {
      final entry = RouteQueueEntry.of(context);
      group ??= entry?.getGroup(T);
    }

    return Node.defaultGetData(
        getAlias(T), dependence, globalDependence, group, position);
  }

  T? find<T>(
      {BuildContext? context, Object? group, bool useEntryGroup = true}) {
    final dependence = getRouteDependence(context);

    if (context != null && useEntryGroup) {
      final entry = RouteQueueEntry.of(context);
      group ??= entry?.getGroup(T);
    }

    return Node.defaultFindData(
        getAlias(T), dependence, globalDependence, group);
  }

  @override
  NRouterDependence createNode(Route route) {
    return NRouterDependence(this);
  }
}
