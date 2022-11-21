// ignore_for_file: unnecessary_overrides

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:nop/nop.dart';

import '../../flutter_nop.dart';

typedef BuildFactory<T> = T Function();

abstract class NavInterface {}

class NavGlobal extends NavInterface {
  NavGlobal._();
  static final _instance = NavGlobal._();
  factory NavGlobal() => _instance;

  final NavObserver observer = NavObserver();

  Route? get currentRoute => observer.currentRoute;

  NopPageRouteMixin? get nopRoute => observer.nopRoute;

  String? get currentRouteName => observer.currentRouteName;
  dynamic get currentRouteArguments => observer.currentRouteArguments;

  OverlayState? getOverlay() {
    return observer.overlay;
  }

  NavigatorState? getNavigator() {
    return observer.navigator;
  }

  final _factorys = HashMap<Type, BuildFactory>();
  void put<T>(BuildFactory<T> factory) {
    _factorys[T] = factory;
  }

  BuildFactory<T> get<T>() {
    assert(_factorys.containsKey(T), 'You need to call Nav.put<$T>()');
    return _factorys[T] as BuildFactory<T>;
  }

  BuildFactory getArg(Type t) {
    assert(_factorys.containsKey(t), 'You need to call Nav.put<$t>()');
    return _factorys[t] as BuildFactory;
  }

  final _alias = <Type, Type>{};

  void addAliasType(Type parent, Type child) {
    _alias[parent] = child;
  }

  /// 子类可以转化成父类
  void addAlias<P, C extends P>() {
    _alias[P] = C; // 可以根据父类类型获取到子类对象
  }

  Type getAlias(Type t) {
    return _alias[t] ?? t;
  }

  void addAliasAll(Iterable<Type> parents, Type child) {
    for (var item in parents) {
      addAliasType(item, child);
    }
  }
}

class NavObserver extends NavigatorObserver {
  OverlayState? get overlay => navigator?.overlay;

  Route? _currentRoute;
  Route? get currentRoute => _currentRoute;

  NopPageRouteMixin? get nopRoute {
    if (_currentRoute is NopPageRouteMixin) {
      return _currentRoute as NopPageRouteMixin;
    }
    return null;
  }

  String? get currentRouteName {
    final route = _currentRoute;
    if (route is NopPageRouteMixin) {
      return route.nopSettings.name;
    }
    return route?.settings.name;
  }

  dynamic get currentRouteArguments {
    final route = _currentRoute;
    if (route is NopPageRouteMixin) {
      return route.nopSettings.arguments;
    }
    return route?.settings.arguments;
  }

  final Map<Route<dynamic>, Set<NopRouteAware>> _listeners =
      <Route<dynamic>, Set<NopRouteAware>>{};
  void subscribe(NopRouteAware routeAware, Route<dynamic> route) {
    final Set<NopRouteAware> subscribers =
        _listeners.putIfAbsent(route, () => <NopRouteAware>{});
    if (subscribers.add(routeAware)) {}
  }

  void unsubscribe(NopRouteAware routeAware) {
    final routes = _listeners.keys.toList();
    for (final route in routes) {
      final Set<NopRouteAware>? subscribers = _listeners[route];
      if (subscribers != null) {
        subscribers.remove(routeAware);
        if (subscribers.isEmpty) {
          _listeners.remove(route);
        }
      }
    }
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    _currentRoute = previousRoute;
    _popOrRemove(route);
    assert(Log.i(route.settings.name));
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    _currentRoute = route;
    assert(Log.i(route.settings.name));
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    _popOrRemove(route);
    assert(Log.i(route.settings.name));
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    if (newRoute != null) {
      _currentRoute = newRoute;
    }
    if (oldRoute != null) {
      _popOrRemove(oldRoute);
    }
    assert(Log.i('${newRoute?.settings.name}  ${oldRoute?.settings.name}'));
  }

  void _popOrRemove(Route<dynamic> route) {
    final subscribers = _listeners[route]?.toList();

    if (subscribers != null) {
      for (final routeAware in subscribers) {
        routeAware.popDependence();
      }
    }
  }

  void dispose(Route? route) {}
}

class NopRouteAware {
  /// 当前[Route]开始退出,调用`didPop`
  ///
  /// 路由的生命的周期已经结束，但是[State]的生命周期在动画之后才会结束
  ///
  /// 如果调用[Navigator.pushNamedAndRemoveUntil]等方法，且和移除的[Route]使用相同
  /// 的依赖，在不调用此方法前，只依赖于[State]的生命周期管理，对象并不会重新创建:
  /// ```dart
  /// /// route name: '/page'
  /// class Page extends StatelessWidget {
  ///   Widget build(BuildContext context) {
  ///   /// 不会重新创建新的对象
  ///   final controller = context.getType<SomeController>();
  ///  }
  /// }
  /// // ...
  /// /// current route: '/page'
  /// /// 希望: 上一个页面的对象会被释放，并且新的页面会重新创建新的对象
  /// /// `popDependence` 解决这个问题
  /// Navigator.pushNamedAndRemoveUntil(context, '/page',(route)=> false);
  /// ```
  void popDependence() {}
}

// ignore: non_constant_identifier_names
final Nav = NavGlobal();

extension NavigatorExt on NavInterface {
  Future<T?> push<T extends Object?>(
    Route<T> route, {
    NavigatorStateGetter? navigatorStateGetter,
  }) {
    final push = NavPushAction(route);
    _navDelegate(push, navigatorStateGetter);
    return push.result;
  }

  Future<T?> pushNamed<T extends Object?>(
    String routeName, {
    Object? arguments,
    NavigatorStateGetter? navigatorStateGetter,
  }) {
    final action = NavPushNamedAction<T>(routeName, arguments);
    _navDelegate(action, navigatorStateGetter);
    return action.result;
  }

  Future<T?> pushNamedAndRemoveUntil<T extends Object?>(
    String routeName,
    bool Function(Route<dynamic>) predicate, {
    Object? arguments,
    NavigatorStateGetter? navigatorStateGetter,
  }) {
    final action = NavPushReplaceUntil<T>(routeName, predicate, arguments);
    _navDelegate(action, navigatorStateGetter);
    return action.result;
  }

  Future<T?> pushReplacementNamed<T extends Object?, R extends Object?>(
    String routeName, {
    R? result,
    Object? arguments,
    NavigatorStateGetter? navigatorStateGetter,
  }) {
    final action =
        NavPushReplacementNamedAction<T, R>(routeName, arguments, result);
    _navDelegate(action, navigatorStateGetter);
    return action.result;
  }

  Future<T?> popAndPushNamed<T extends Object?, R extends Object?>(
    String routeName, {
    R? result,
    Object? arguments,
    NavigatorStateGetter? navigatorStateGetter,
  }) {
    final action = NavPopAndPushNamedAction<T, R>(routeName, arguments, result);
    _navDelegate(action, navigatorStateGetter);
    return action.result;
  }

  Future<T?> pushReplacement<T extends Object?, TO extends Object?>(
    Route<T> newRoute, {
    TO? result,
    NavigatorStateGetter? navigatorStateGetter,
  }) {
    final action = NavPushReplacementdAction(newRoute, result);
    _navDelegate(action, navigatorStateGetter);
    return action.result;
  }

  void pop<T extends Object?>([
    T? result,
    NavigatorStateGetter? navigatorStateGetter,
  ]) {
    final pop = NavPopAction(result);
    _navDelegate(pop, navigatorStateGetter);
  }

  Future<bool?> maybePop<T extends Object?>([
    T? result,
    NavigatorStateGetter? navigatorStateGetter,
  ]) {
    final pop = NavMaybePopAction(result);
    _navDelegate(pop, navigatorStateGetter);
    return pop.result;
  }

  void replace<T extends Object?>({
    required Route<dynamic> oldRoute,
    required Route<T> newRoute,
    NavigatorStateGetter? navigatorStateGetter,
  }) {
    final replace = NavReplaceAction(oldRoute, newRoute);
    _navDelegate(replace, navigatorStateGetter);
  }

  Future<String?> restorableReplace<T extends Object?>({
    required Route<dynamic> oldRoute,
    required RestorableRouteBuilder<T> newRouteBuilder,
    Object? arguments,
    NavigatorStateGetter? navigatorStateGetter,
  }) {
    final action =
        NavRestorableReplaceAction(oldRoute, newRouteBuilder, arguments);
    _navDelegate(action, navigatorStateGetter);
    return action.result;
  }

  void replaceRouteBelow<T extends Object?>({
    required Route<dynamic> anchorRoute,
    required Route<T> newRoute,
    NavigatorStateGetter? navigatorStateGetter,
  }) {
    final action = NavReplaceBelowAction(anchorRoute, newRoute);
    _navDelegate(action, navigatorStateGetter);
  }

  Future<String?> restorablePushNamed(
    String routeName, {
    Object? arguments,
    NavigatorStateGetter? navigatorStateGetter,
  }) {
    final action = NavRePushNamedAction(routeName, arguments);
    _navDelegate(action, navigatorStateGetter);
    return action.result;
  }

  Future<String?> restorablePopAndPushNamed<T extends Object>(
    String routeName, {
    Object? arguments,
    T? result,
    NavigatorStateGetter? navigatorStateGetter,
  }) {
    final action = NavRePopPushNamedAction(routeName, arguments, result);
    _navDelegate(action, navigatorStateGetter);
    return action.result;
  }

  Future<String?> restorablePushNamedAndRemoveUntil<T extends Object?>(
    String routeName,
    bool Function(Route<dynamic>) predicate, {
    Object? arguments,
    NavigatorStateGetter? navigatorStateGetter,
  }) {
    final action = NavRePushNamedUntilAction(routeName, arguments, predicate);
    _navDelegate(action, navigatorStateGetter);
    return action.result;
  }

  Future<String?> restorablePushReplacementNamed<T extends Object>(
    String routeName, {
    T? result,
    Object? arguments,
    NavigatorStateGetter? navigatorStateGetter,
  }) {
    final action = NavRePushNamedReplaceAction(routeName, arguments, result);
    _navDelegate(action, navigatorStateGetter);
    return action.result;
  }
}

typedef NavigatorStateGetter = NavigatorState? Function();

void _navDelegate(
    NavAction action, NavigatorStateGetter? navigatorStateGetter) {
  NavigatorDelegate(action)
    ..navigatorStateGetter = navigatorStateGetter
    ..init();
}
