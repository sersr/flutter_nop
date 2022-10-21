// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_gen.dart';

// **************************************************************************
// RouteGenerator
// **************************************************************************

// ignore_for_file: prefer_const_constructors

class Routes {
  Routes._();
  static final root = NopRoute(
    name: '/',
    fullName: '/',
    children: [page02],
    builder: (context, arguments, group) => const Nop.page(
      child: Page01(),
    ),
  );

  static final page02 = NopRoute(
    name: '/page02',
    fullName: '/page02',
    groupOwner: () => page02,
    groupKey: 'nopIsMain',
    children: [page03],
    builder: (context, arguments, group) => Nop.page(
      initTypesUnique: const [UniqueController],
      group: group,
      child: Page02(),
    ),
  );

  static final page03 = NopRoute(
    name: '/page03',
    fullName: '/page02/page03',
    groupOwner: () => page02,
    groupKey: 'nopIsMain',
    builder: (context, arguments, group) => Nop.page(
      initTypesUnique: const [UniqueController],
      group: group,
      child: Page03(),
    ),
  );
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
      {BuildContext? context, bool nopIsMain = false}) {
    return NopRouteAction(
        context: context,
        route: Routes.page02,
        arguments: {'nopIsMain': nopIsMain});
  }

  static NopRouteAction<T> page03<T>(
      {BuildContext? context, bool nopIsMain = false}) {
    return NopRouteAction(
        context: context,
        route: Routes.page03,
        arguments: {'nopIsMain': nopIsMain});
  }
}
