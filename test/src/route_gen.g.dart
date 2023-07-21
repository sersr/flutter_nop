// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_gen.dart';

// **************************************************************************
// RouteGenerator
// **************************************************************************

// ignore_for_file: prefer_const_constructors

class Routes {
  Routes._();

  static Routes? _instance;

  static Routes init({bool newInstance = false}) {
    if (!newInstance && _instance != null) {
      return _instance!;
    }
    final instance = _instance = Routes._();
    instance._init();
    return instance;
  }

  void _init() {
    _page03 = NopRoute(
      name: '/page03',
      fullName: '/page02/page03',
      groupOwnerLate: () => _page02,
      groupKey: 'groupId',
      builder: (context, arguments, group) => Nop.page(
        groupList: const [UniqueController],
        group: group,
        child: const Page03(),
      ),
    );

    _page02 = NopRoute(
      name: '/page02',
      fullName: '/page02',
      groupOwnerLate: () => _page02,
      groupKey: 'groupId',
      children: [_page03],
      builder: (context, arguments, group) => Nop.page(
        groupList: const [UniqueController],
        group: group,
        child: const Page02(),
      ),
    );

    _root = NopRoute(
        name: '/',
        fullName: '/',
        children: [_page02],
        builder: (context, arguments, group) => const Page01());
  }

  late final NopRoute _page03;
  static NopRoute get page03 => _instance!._page03;
  late final NopRoute _page02;
  static NopRoute get page02 => _instance!._page02;
  late final NopRoute _root;
  static NopRoute get root => _instance!._root;
}

class NavRoutes {
  NavRoutes._();
  static NopRouteAction<T> page03<T>(
      {BuildContext? context, required groupId /* bool or String */}) {
    return NopRouteAction(
        context: context,
        route: Routes.page03,
        arguments: {'groupId': groupId});
  }

  static NopRouteAction<T> page02<T>(
      {BuildContext? context, required groupId /* bool or String */}) {
    return NopRouteAction(
        context: context,
        route: Routes.page02,
        arguments: {'groupId': groupId});
  }

  static NopRouteAction<T> root<T>({
    BuildContext? context,
  }) {
    return NopRouteAction(
        context: context, route: Routes.root, arguments: const {});
  }
}
