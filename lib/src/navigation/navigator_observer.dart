import 'package:flutter/material.dart';
import 'package:nop/nop.dart';

import '../../flutter_nop.dart';
import '../dependence/factory.dart';
import '../nop/route.dart';

abstract class NavInterface {}

class NavGlobal extends NavInterface with BuildFactoryMixin {
  NavGlobal._();
  static final _instance = NavGlobal._();
  factory NavGlobal() => _instance;

  final NavObserver observer = NavObserver();

  NopDependenceManager get dependenceManager => observer.dependenceManager;

  bool enabledPrint = false;

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
}

class NavObserver extends NavigatorObserver {
  OverlayState? get overlay => navigator?.overlay;

  Route? _currentRoute;
  Route? get currentRoute => _currentRoute;

  final dependenceManager = NopDependenceManager();

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

  @override
  void didPop(Route route, Route? previousRoute) {
    _currentRoute = previousRoute;
    dependenceManager.didPop(route);
    assert(!Nav.enabledPrint || Log.i(route.settings.name));
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    _currentRoute = route;
    assert(!Nav.enabledPrint || Log.i(route.settings.name));
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    assert(!Nav.enabledPrint || Log.i(route.settings.name));
    dependenceManager.didRemove(route);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    if (newRoute != null) {
      _currentRoute = newRoute;
    }
    assert(!Nav.enabledPrint ||
        Log.i('${newRoute?.settings.name}  ${oldRoute?.settings.name}'));
  }
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

  void popUntil<T extends Object?>(bool Function(Route<dynamic>) predicate,
      [NavigatorStateGetter? navigatorStateGetter]) {
    final pop = NopPopUntilAction(predicate);
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
