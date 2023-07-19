// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_gen.dart';

// **************************************************************************
// RouteGenerator
// **************************************************************************

// ignore_for_file: prefer_const_constructors

class Routes {
  Routes._() {
    _init();
  }

  static Routes? _instance;

  factory Routes({bool newInstance = false}) {
    if (!newInstance && _instance != null) {
      return _instance!;
    }
    return _instance = Routes._();
  }

  void _init() {
    _root = NopRoute(
      name: '/',
      fullName: '/',
      childrenLate: () => [_page02],
      builder: (context, arguments, group) => const Nop(
        child: Page01(),
      ),
    );

    _page02 = NopRoute(
      name: '/page02',
      fullName: '/page02',
      groupOwnerLate: () => _page02,
      groupKey: 'groupId',
      childrenLate: () => [_page03],
      builder: (context, arguments, group) => Nop(
        groupList: const [UniqueController],
        group: group,
        child: Page02(),
      ),
    );

    _page03 = NopRoute(
      name: '/page03',
      fullName: '/page02/page03',
      groupOwnerLate: () => _page02,
      groupKey: 'groupId',
      builder: (context, arguments, group) => Nop(
        groupList: const [UniqueController],
        group: group,
        child: Page03(),
      ),
    );
  }

  late final NopRoute _root;
  static NopRoute get root => Routes()._root;
  late final NopRoute _page02;
  static NopRoute get page02 => Routes()._page02;
  late final NopRoute _page03;
  static NopRoute get page03 => Routes()._page03;
}

class NavRoutes {
  NavRoutes._();
  static NopRouteAction<T> root<T>({
    BuildContext? context,
  }) {
    return NopRouteAction(
        context: context, route: Routes.root, arguments: const {});
  }

  static NopRouteAction<T> page02<T>(
      {BuildContext? context, required groupId /* bool or String */}) {
    return NopRouteAction(
        context: context,
        route: Routes.page02,
        arguments: {'groupId': groupId});
  }

  static NopRouteAction<T> page03<T>(
      {BuildContext? context, required groupId /* bool or String */}) {
    return NopRouteAction(
        context: context,
        route: Routes.page03,
        arguments: {'groupId': groupId});
  }
}
