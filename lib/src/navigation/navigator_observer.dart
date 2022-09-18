// ignore_for_file: unnecessary_overrides

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:nop/nop.dart';

import 'navigator_getter.dart';

typedef BuildFactory<T> = T Function();

abstract class NavInterface {}

class NavGlobal extends NavInterface {
  NavGlobal._();
  static final _instance = NavGlobal._();
  factory NavGlobal() => _instance;

  final NavObserver observer = NavObserver();

  Route? get currentRoute => observer._currentRoute;
  String? get currentRouteName => observer._currentRoute?.settings.name;
  dynamic get currentRouteArguments =>
      observer._currentRoute?.settings.arguments;

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
  String? get currentRouteName => _currentRoute?.settings.name;
  dynamic get currentRouteArguments => _currentRoute?.settings.arguments;

  @override
  void didPop(Route route, Route? previousRoute) {
    _currentRoute = previousRoute;
    assert(Log.i('${route.settings.name}'));
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    _currentRoute = route;
    assert(Log.i('${route.settings.name}'));
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    _currentRoute = previousRoute;
    assert(Log.i('${route.settings.name}'));
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    _currentRoute = newRoute;
    assert(Log.i('${newRoute?.settings.name}  ${oldRoute?.settings.name}'));
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
