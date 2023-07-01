import 'package:flutter/material.dart';

import '../../router.dart';

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

class NRouter implements RouterConfig<RouteQueue> {
  NRouter({
    required this.rootPage,
    String? restorationId,
    Map<String, dynamic> params = const {},
    Map<String, dynamic>? extra,
    Object? groupId,
    this.observers = const [],
  }) {
    routerDelegate = NRouteDelegate(
        restorationId: restorationId, rootPage: rootPage, router: this);
    routerDelegate.init(restorationId, params, extra, groupId);
  }
  final NPageMain rootPage;
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
    return RouteQueueEntry.of(context, this);
  }

  bool removeCurrent(BuildContext context, [dynamic result]) {
    final entry = ofEntry(context);
    if (entry != null) {
      entry.remove(result);
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
  late final NRouteDelegate routerDelegate;

  @pragma('vm:prefer-inline')
  bool canPop() => routerDelegate.canPop();

  /// 在 [MaterialApp].builder 中使用
  @pragma('vm:prefer-inline')
  Widget build(BuildContext context) {
    return routerDelegate.build(context);
  }

  @pragma('vm:prefer-inline')
  RouteQueueEntry go(String location,
      {Map<String, dynamic> params = const {},
      Map<String, dynamic>? extra,
      Object? groupId}) {
    return routerDelegate.go(location,
        params: params, extra: extra, groupId: groupId);
  }

  @pragma('vm:prefer-inline')
  RouteQueueEntry goPage(NPage page,
      {Map<String, dynamic> params = const {},
      Map<String, dynamic>? extra,
      Object? groupId}) {
    return routerDelegate.goPage(page,
        params: params, extra: extra, groupId: groupId);
  }

  @pragma('vm:prefer-inline')
  RouteQueueEntry goUntil(String location, UntilFn until) {
    return routerDelegate.goUntil(location, until);
  }

  @pragma('vm:prefer-inline')
  void popUntil(UntilFn test) {
    routerDelegate.popUntil(test);
  }

  @pragma('vm:prefer-inline')
  void pop([Object? result]) {
    routerDelegate.pop(result);
  }
}
