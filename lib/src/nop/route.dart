import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nop/nop.dart';

import '../navigation/navigator_observer.dart';

/// 路由跳转行为
class NopRouteAction<T> with NopRouteActionMixin<T> {
  NopRouteAction({
    this.arguments,
    this.context,
    required this.route,
  });
  @override
  final Object? arguments;

  @override
  final BuildContext? context;

  @override
  final NopRoute route;
}

mixin NopRouteActionMixin<T> {
  NopRoute get route;
  Object? get arguments;
  BuildContext? get context;

  Future<T?> get go {
    return NopRoute.pushNamed(
        context: context, fullName: route.fullName, arguments: arguments);
  }

  Future<T?> popAndGo({Object? result}) {
    return NopRoute.popAndPushNamed(
        context: context,
        fullName: route.fullName,
        result: result,
        arguments: arguments);
  }

  Future<T?> goReplacement({Object? result}) {
    return NopRoute.pushReplacementNamed(
        context: context,
        fullName: route.fullName,
        result: result,
        arguments: arguments);
  }

  Future<T?> goAndRemoveUntil(bool Function(Route<dynamic>) predicate) {
    return NopRoute.pushNamedAndRemoveUntil(context, predicate,
        fullName: route.fullName, arguments: arguments);
  }

  FutureOr<String?> get goRs {
    return NopRoute.restorablePushNamed(context,
        fullName: route.fullName, arguments: arguments);
  }

  FutureOr<String?> popAndGoRs({Object? result}) {
    return NopRoute.restorablePopAndPushNamed(context,
        fullName: route.fullName, result: result, arguments: arguments);
  }

  FutureOr<String?> goReplacementRs({Object? result}) {
    return NopRoute.restorablePushReplacementNamed(context,
        fullName: route.fullName, result: result, arguments: arguments);
  }

  FutureOr<String?> goAndRemoveUntilRs(RoutePredicate predicate) {
    return NopRoute.restorablePushNamedAndRemoveUntil(context, predicate,
        fullName: route.fullName, arguments: arguments);
  }
}

class NopRoute {
  final String name;
  final String fullName;
  final List<NopRoute> children;
  final Widget Function(BuildContext context, dynamic arguments, Object? group)
      builder;
  final String desc;
  final NopRoute Function()? _groupOwner;
  final String groupKey;

  const NopRoute({
    required this.name,
    required this.fullName,
    required this.builder,
    NopRoute Function()? groupOwner,
    String? groupKey,
    this.children = const [],
    this.desc = '',
  })  : groupKey = groupKey ?? defaultGroupKey,
        _groupOwner = groupOwner;

  NopRoute? get groupOwner {
    return _groupOwner?.call();
  }

  static const defaultGroupKey = 'nopIsMain';

  bool get isCurrent {
    return identical(groupOwner, this);
  }

  String? get groupName {
    if (isCurrent) {
      return fullName;
    }
    return groupOwner?.fullName;
  }

  // static final groupIds = <NopRoute, int>{};

  static int _routeId = 0;
  static int get _incGroupId => _routeId += 1;
  // static int _incGroupId(NopRoute route) {
  //   final id = groupIds[route] ?? 0;
  //   return groupIds[route] = id + 1;
  // }

  // static int getGroupId(NopRoute route) {
  //   return groupIds.putIfAbsent(route, () => 0);
  // }

  // static void deleteGroupId(NopRoute route) {
  //   groupIds.remove(route);
  // }

  static Object? getGroupIdFromBuildContext(BuildContext? context) {
    if (context == null) return null;
    try {
      final route = ModalRoute.of(context);
      if (route is NopPageRouteMixin) {
        final settings = route.nopSettings;

        return settings.group;
      }
      Log.e('route <${route.runtimeType}> is not NopPageRouteMixin.');
    } catch (_) {}

    return null;
  }

  static List<Route<dynamic>> onGenInitRoutes(
      String name, Route<dynamic>? Function(String name) genRoute) {
    if (name == '/') {
      final route = genRoute(name);
      return route == null ? const [] : [route];
    }

    final routes = <Route<dynamic>>[];
    final splits = name.split('/');

    var currentName = '';
    for (var item in splits) {
      if (currentName.isNotEmpty && item.isEmpty) break;
      currentName += '/$item';

      final route = genRoute(currentName);
      if (route != null) {
        routes.add(route);
      }
    }
    return routes;
  }

  static final NavigationActions navigationActions = NavigationNativeActions(
    pushNamedCallabck: Navigator.pushNamed,
    popAndPushNamedCallabck: Navigator.popAndPushNamed,
    pushReplacementNamedCallabck: Navigator.pushReplacementNamed,
    pushNamedAndRemoveUntilCallback: Navigator.pushNamedAndRemoveUntil,
    restorablePushNamedCallback: Navigator.restorablePushNamed,
    restorablePopAndPushNamedCallback: Navigator.restorablePopAndPushNamed,
    restorablePushReplacementNamedCallback:
        Navigator.restorablePushReplacementNamed,
    restorablePushNamedAndRemoveUntilCallback:
        Navigator.restorablePushNamedAndRemoveUntil,
  );
  static NavigationActions navigationWithoutContext = NavigationNavActions(
    pushNamedCallabck: Nav.pushNamed,
    popAndPushNamedCallabck: Nav.popAndPushNamed,
    pushReplacementNamedCallabck: Nav.pushReplacementNamed,
    pushNamedAndRemoveUntilCallback: Nav.pushNamedAndRemoveUntil,
    restorablePopAndPushNamedCallback: Nav.restorablePopAndPushNamed,
    restorablePushNamedCallback: Nav.restorablePushNamed,
    restorablePushReplacementNamedCallback: Nav.restorablePushReplacementNamed,
    restorablePushNamedAndRemoveUntilCallback:
        Nav.restorablePushNamedAndRemoveUntil,
  );

  static NavigationActions getActions(BuildContext? context) {
    return context == null ? navigationWithoutContext : navigationActions;
  }

  static Future<T?> pushNamed<T extends Object?>(
      {required String fullName, BuildContext? context, Object? arguments}) {
    final action = getActions(context);
    return action.pushNamed(context, fullName, arguments: arguments);
  }

  static Future<T?> popAndPushNamed<T extends Object?, R extends Object?>(
      {required String fullName,
      BuildContext? context,
      R? result,
      Object? arguments}) {
    final action = getActions(context);
    return action.popAndPushNamed(context, fullName,
        result: result, arguments: arguments);
  }

  static Future<T?> pushReplacementNamed<T extends Object?, R extends Object?>(
      {required String fullName,
      BuildContext? context,
      R? result,
      Object? arguments}) {
    final action = getActions(context);
    return action.pushReplacementNamed(context, fullName,
        result: result, arguments: arguments);
  }

  static Future<T?> pushNamedAndRemoveUntil<T extends Object?>(
    BuildContext? context,
    RoutePredicate predicate, {
    required String fullName,
    Object? arguments,
  }) {
    final action = getActions(context);
    return action.pushNamedAndRemoveUntil(context, fullName, predicate,
        arguments: arguments);
  }

  static FutureOr<String?> restorablePushNamed(BuildContext? context,
      {required String fullName, Object? arguments}) {
    final action = getActions(context);
    return action.restorablePushNamed(context, fullName, arguments: arguments);
  }

  static FutureOr<String?> restorablePopAndPushNamed<R extends Object>(
      BuildContext? context,
      {required String fullName,
      Object? arguments,
      R? result}) {
    final action = getActions(context);
    return action.restorablePopAndPushNamed(context, fullName,
        result: result, arguments: arguments);
  }

  static FutureOr<String?> restorablePushReplacementNamed<R extends Object>(
      BuildContext? context,
      {required String fullName,
      Object? arguments,
      R? result}) {
    final action = getActions(context);
    return action.restorablePushReplacementNamed(context, fullName,
        result: result, arguments: arguments);
  }

  static FutureOr<String?> restorablePushNamedAndRemoveUntil(
    BuildContext? context,
    RoutePredicate predicate, {
    required String fullName,
    Object? arguments,
  }) {
    final action = getActions(context);
    return action.restorablePushNamedAndRemoveUntil(
        context, fullName, predicate,
        arguments: arguments);
  }

  NopRouteBuilder? onMatch(RouteSettings settings) {
    var pathName = settings.name ?? '';
    Map<dynamic, dynamic>? query;
    assert(settings.arguments == null || settings.arguments is Map);
    final uri = Uri.tryParse(pathName);
    if (uri != null) {
      pathName = uri.path;
      if (uri.queryParameters.isNotEmpty) {
        query = Map.of(uri.queryParameters);
      }
    }

    final arguments =
        query ?? settings.arguments as Map<dynamic, dynamic>? ?? const {};

    return _onMatch(this, settings, pathName, arguments);
  }

  static NopRouteBuilder? _onMatch(NopRoute current, RouteSettings settings,
      String pathName, Map<dynamic, dynamic>? query) {
    if (!pathName.contains(current.fullName)) return null;

    if (pathName == current.fullName) {
      final groupId = NopRouteSettings.getGroupId(query, current);
      return NopRouteBuilder(
        route: current,
        settings: settings,
        nopSettings: NopRouteSettings(
          name: pathName,
          arguments: query,
          group: groupId,
          route: current,
        ),
      );
    }

    for (var child in current.children) {
      assert(child != current);
      final route = _onMatch(child, settings, pathName, query);
      if (route != null) return route;
    }

    return null;
    // return NopRouteBuilder(
    //     route: current,
    //     settings: settings.copyWith(name: pathName, arguments: query));
  }
}

class NopRouteBuilder {
  final NopRoute route;
  final NopRouteSettings nopSettings;
  final RouteSettings settings;

  NopRouteBuilder(
      {required this.route, required this.nopSettings, required this.settings});

  Widget builder(BuildContext context) {
    return route.builder(context, nopSettings.arguments, nopSettings.group);
  }

  MaterialPageRoute? get wrapMaterial {
    return NopMaterialPageRoute(
      builder: builder,
      nopSettings: nopSettings,
      settings: settings,
    );
  }
}

mixin NopPageRouteMixin<T> on PageRoute<T> {
  NopRouteSettings get nopSettings;
}

class NopMaterialPageRoute<T> extends MaterialPageRoute<T>
    with NopPageRouteMixin {
  NopMaterialPageRoute({
    required super.builder,
    super.fullscreenDialog,
    super.maintainState,
    super.settings,
    required this.nopSettings,
  });
  @override
  final NopRouteSettings nopSettings;
}

class NopRouteSettings extends RouteSettings {
  const NopRouteSettings({
    super.name,
    super.arguments,
    this.group,
    required this.route,
  });
  final NopRoute route;
  final Object? group;

  @override
  NopRouteSettings copyWith({
    String? name,
    Object? arguments,
    Object? group,
    NopRoute? route,
  }) {
    return NopRouteSettings(
      name: name ?? this.name,
      arguments: arguments ?? this.arguments,
      group: group ?? this.group,
      route: route ?? this.route,
    );
  }

  static Object? getGroupId(Map<dynamic, dynamic>? arguments, NopRoute route) {
    if (arguments == null) return null;

    if (route.groupOwner == null) return null;

    Object? group;
    dynamic groupId;
    try {
      groupId = arguments.remove(route.groupKey);
    } catch (_) {}
    // global
    if (groupId == true || groupId == null) return null;

    if (groupId == false) {
      int id = NopRoute._incGroupId;
      group = '${route.groupName}_$id';
    } else {
      group = groupId;
    }

    return group;
  }
}

typedef PushNamedNative = Future<T?>
    Function<T>(BuildContext context, String name, {Object? arguments});
typedef PopAndPushNative = Future<T?> Function<T, R>(
    BuildContext context, String name,
    {Object? arguments, R? result});
typedef PushReplaceNative = Future<T?> Function<T, R>(
    BuildContext context, String name,
    {Object? arguments, R? result});
typedef PushAndRemoveUntilNative = Future<T?> Function<T extends Object?>(
  BuildContext context,
  String newRouteName,
  RoutePredicate predicate, {
  Object? arguments,
});
typedef RePushNamedNative = String
    Function<T>(BuildContext context, String name, {Object? arguments});
typedef RePopAndPushNative = String Function<T, R>(
    BuildContext context, String name,
    {Object? arguments, R? result});
typedef RePushReplaceNative = String Function<T, R>(
    BuildContext context, String name,
    {Object? arguments, R? result});
typedef RePushAndRemoveUntilNative = String Function<T extends Object?>(
  BuildContext context,
  String newRouteName,
  RoutePredicate predicate, {
  Object? arguments,
});

class NavigationNativeActions extends NavigationActions {
  NavigationNativeActions({
    required this.pushNamedCallabck,
    required this.popAndPushNamedCallabck,
    required this.pushReplacementNamedCallabck,
    required this.pushNamedAndRemoveUntilCallback,
    required this.restorablePushNamedCallback,
    required this.restorablePopAndPushNamedCallback,
    required this.restorablePushReplacementNamedCallback,
    required this.restorablePushNamedAndRemoveUntilCallback,
  });

  final RePushNamedNative restorablePushNamedCallback;
  final RePopAndPushNative restorablePopAndPushNamedCallback;
  final RePushReplaceNative restorablePushReplacementNamedCallback;
  final RePushAndRemoveUntilNative restorablePushNamedAndRemoveUntilCallback;

  final PushNamedNative pushNamedCallabck;
  final PopAndPushNative popAndPushNamedCallabck;
  final PushReplaceNative pushReplacementNamedCallabck;
  final PushAndRemoveUntilNative pushNamedAndRemoveUntilCallback;

  @override
  Future<T?> pushNamed<T>(BuildContext? context, String name,
      {Object? arguments}) {
    return pushNamedCallabck(context!, name, arguments: arguments);
  }

  @override
  Future<T?> popAndPushNamed<T, R>(BuildContext? context, String name,
      {Object? arguments, R? result}) {
    return popAndPushNamedCallabck(context!, name,
        arguments: arguments, result: result);
  }

  @override
  Future<T?> pushReplacementNamed<T, R>(BuildContext? context, String name,
      {Object? arguments, R? result}) {
    return pushReplacementNamedCallabck(context!, name,
        arguments: arguments, result: result);
  }

  @override
  Future<T?> pushNamedAndRemoveUntil<T extends Object?>(
      BuildContext? context, String name, RoutePredicate predicate,
      {Object? arguments}) {
    return pushNamedAndRemoveUntilCallback(context!, name, predicate,
        arguments: arguments);
  }

  @override
  String restorablePopAndPushNamed<R extends Object>(
      BuildContext? context, String name,
      {Object? arguments, R? result}) {
    return restorablePopAndPushNamedCallback(context!, name,
        arguments: arguments, result: result);
  }

  @override
  String restorablePushNamed(BuildContext? context, String name,
      {Object? arguments}) {
    return restorablePushNamedCallback(context!, name, arguments: arguments);
  }

  @override
  String restorablePushNamedAndRemoveUntil(
      BuildContext? context, String name, RoutePredicate predicate,
      {Object? arguments}) {
    return restorablePushNamedAndRemoveUntilCallback(context!, name, predicate,
        arguments: arguments);
  }

  @override
  String restorablePushReplacementNamed<R extends Object>(
      BuildContext? context, String name,
      {Object? arguments, R? result}) {
    return restorablePushReplacementNamedCallback(context!, name,
        arguments: arguments, result: result);
  }
}

typedef PushNamed = Future<T?> Function<T>(String name, {Object? arguments});
typedef PopAndPush = Future<T?> Function<T, R>(String name,
    {Object? arguments, R? result});
typedef PushReplace = Future<T?> Function<T, R>(String name,
    {Object? arguments, R? result});
typedef PushAndRemoveUntil = Future<T?> Function<T extends Object?>(
  String newRouteName,
  RoutePredicate predicate, {
  Object? arguments,
});
typedef RePushNamed = Future<String?> Function(String name,
    {Object? arguments});
typedef RePopAndPush = Future<String?> Function<R extends Object>(String name,
    {Object? arguments, R? result});
typedef RePushReplace = Future<String?> Function<R extends Object>(String name,
    {Object? arguments, R? result});
typedef RePushAndRemoveUntil = Future<String?> Function(
  String newRouteName,
  RoutePredicate predicate, {
  Object? arguments,
});

class NavigationNavActions extends NavigationActions {
  NavigationNavActions({
    required this.pushNamedCallabck,
    required this.popAndPushNamedCallabck,
    required this.pushReplacementNamedCallabck,
    required this.pushNamedAndRemoveUntilCallback,
    required this.restorablePushNamedCallback,
    required this.restorablePopAndPushNamedCallback,
    required this.restorablePushReplacementNamedCallback,
    required this.restorablePushNamedAndRemoveUntilCallback,
  });
  final PushNamed pushNamedCallabck;
  final PopAndPush popAndPushNamedCallabck;
  final PushReplace pushReplacementNamedCallabck;
  final PushAndRemoveUntil pushNamedAndRemoveUntilCallback;

  final RePushNamed restorablePushNamedCallback;
  final RePopAndPush restorablePopAndPushNamedCallback;
  final RePushReplace restorablePushReplacementNamedCallback;
  final RePushAndRemoveUntil restorablePushNamedAndRemoveUntilCallback;

  @override
  Future<T?> pushNamed<T>(BuildContext? context, String name,
      {Object? arguments}) {
    return pushNamedCallabck(name, arguments: arguments);
  }

  @override
  Future<T?> popAndPushNamed<T, R>(BuildContext? context, String name,
      {Object? arguments, R? result}) {
    return popAndPushNamedCallabck(name, arguments: arguments, result: result);
  }

  @override
  Future<T?> pushReplacementNamed<T, R>(BuildContext? context, String name,
      {Object? arguments, R? result}) {
    return pushReplacementNamedCallabck(name,
        arguments: arguments, result: result);
  }

  @override
  Future<T?> pushNamedAndRemoveUntil<T extends Object?>(
      BuildContext? context, String name, RoutePredicate predicate,
      {Object? arguments}) {
    return pushNamedAndRemoveUntilCallback(name, predicate,
        arguments: arguments);
  }

  @override
  Future<String?> restorablePopAndPushNamed<R extends Object>(
      BuildContext? context, String name,
      {Object? arguments, R? result}) {
    return restorablePopAndPushNamedCallback(name,
        arguments: arguments, result: result);
  }

  @override
  Future<String?> restorablePushNamed(BuildContext? context, String name,
      {Object? arguments}) {
    return restorablePushNamedCallback(name, arguments: arguments);
  }

  @override
  Future<String?> restorablePushNamedAndRemoveUntil(
      BuildContext? context, String name, RoutePredicate predicate,
      {Object? arguments}) {
    return restorablePushNamedAndRemoveUntilCallback(name, predicate,
        arguments: arguments);
  }

  @override
  Future<String?> restorablePushReplacementNamed<R extends Object>(
      BuildContext? context, String name,
      {Object? arguments, R? result}) {
    return restorablePushReplacementNamedCallback(name,
        arguments: arguments, result: result);
  }
}

abstract class NavigationActions {
  Future<T?> pushNamed<T>(BuildContext? context, String name,
      {Object? arguments});
  Future<T?> popAndPushNamed<T, R>(BuildContext? context, String name,
      {Object? arguments, R? result});
  Future<T?> pushReplacementNamed<T, R>(BuildContext? context, String name,
      {Object? arguments, R? result});

  Future<T?> pushNamedAndRemoveUntil<T extends Object?>(
    BuildContext? context,
    String name,
    RoutePredicate predicate, {
    Object? arguments,
  });
  FutureOr<String?> restorablePushNamed(BuildContext? context, String name,
      {Object? arguments});
  FutureOr<String?> restorablePopAndPushNamed<R extends Object>(
      BuildContext? context, String name,
      {Object? arguments, R? result});
  FutureOr<String?> restorablePushReplacementNamed<R extends Object>(
      BuildContext? context, String name,
      {Object? arguments, R? result});

  FutureOr<String?> restorablePushNamedAndRemoveUntil(
    BuildContext? context,
    String name,
    RoutePredicate predicate, {
    Object? arguments,
  });
}
