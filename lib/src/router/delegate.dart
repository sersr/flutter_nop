import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:nop/nop.dart';

import '../../nav.dart';
import 'router.dart';
import 'web/history_state.dart';

typedef UntilFn = bool Function(RouteQueueEntry entry);

class RouteRestorable extends StatefulWidget {
  const RouteRestorable({
    super.key,
    this.restorationId,
    required this.delegate,
    required this.child,
  });
  final String? restorationId;
  final Widget child;
  final NRouterDelegate delegate;
  RouteQueue get routeQueue => delegate._routeQueue;

  static RouteRestorableState? maybeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_NRouterScope>();
    return scope?.state;
  }

  @override
  State<RouteRestorable> createState() => RouteRestorableState();
}

class _NRouterScope extends InheritedWidget {
  const _NRouterScope(
      {required this.routeQueue, this.state, required super.child});
  final RouteQueue routeQueue;
  final RouteRestorableState? state;

  @override
  bool updateShouldNotify(covariant _NRouterScope oldWidget) {
    return routeQueue != oldWidget.routeQueue || state != oldWidget.state;
  }
}

class RouteRestorableState extends State<RouteRestorable>
    with WidgetsBindingObserver, RestorationMixin {
  late RouteQueue routeQueue;
  NRouterDelegate get delegate => widget.delegate;

  @override
  Widget build(BuildContext context) {
    return _NRouterScope(
        routeQueue: routeQueue, state: this, child: widget.child);
  }

  @override
  void initState() {
    super.initState();
    routeQueue = widget.routeQueue;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  Future<bool> didPopRoute() {
    return delegate.maybePop();
  }

  /// 浏览器的地址栏和本地的地址可能不相等;
  /// 本地地址没有使用 [Uri] 编码，即使使用也可能出问题，
  /// 如：' '有两种形式 '+'和'%2B'，所以[RouteInformation.uri]不会被使用
  ///
  /// 从[RouteInformation.state]获取`stateEntry`
  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) {
    final state = routeInformation.state;
    final list = RouteQueue.pageList(state) ?? const [];

    assert(Log.e('uri: ${routeInformation.uri}'));

    RouteQueueEntry? stateEntry;
    if (list case [..., Map last]) {
      if (RouteQueueEntry.canParse(last)) {
        stateEntry = RouteQueueEntry.fromJson(last, delegate);
      }
    }

    final pre = routeQueue.pre;
    if (stateEntry != null && stateEntry.eq(pre)) {
      assert(Log.i('pre:'));
      assert(Log.w(pre!.toJson().logPretty()));
      assert(Log.i('state:'));
      assert(Log.w(stateEntry.toJson().logPretty()));
      delegate._pop();
    } else {
      RouteQueueEntry? entry = stateEntry;

      if (entry == null) {
        final uri = routeInformation.uri;
        final realParams = <String, dynamic>{};

        final route =
            delegate.rootPage.getPageFromLocation(uri.path, realParams);
        if (route == null) {
          return SynchronousFuture(false);
        }

        final pageKey = delegate._newPageKey(prefix: 'p+');
        entry = RouteQueueEntry(
          params: realParams,
          nPage: route,
          queryParams: uri.queryParameters,
          pageKey: pageKey,
        );
      }

      routeQueue.insert(entry);
      if (state == null) {
        // 更新当前路由的状态
        routeQueue.updateRouteInfo(true);
      }
    }
    return SynchronousFuture(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RouteRestorable oldWidget) {
    super.didUpdateWidget(oldWidget);
    routeQueue = widget.routeQueue;
  }

  @override
  String? get restorationId => widget.restorationId;

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    assert(Log.w('res: $restorationId'));
    registerForRestoration(routeQueue, '_routes');
  }
}

class NRouterDelegate extends RouterDelegate<RouteQueue>
    with PopNavigatorRouterDelegateMixin, ChangeNotifier {
  NRouterDelegate(
      {this.restorationId, required this.rootPage, required this.router});
  final String? restorationId;
  final NPageMain rootPage;
  final NRouter router;

  void init(
    String? restorationId,
    Map<String, dynamic> params,
    Map<String, dynamic>? extra,
    Object? groupId,
  ) {
    WidgetsFlutterBinding.ensureInitialized();
    if (_restore()) return;

    RouteQueueEntry? entry;
    final defaultName =
        WidgetsBinding.instance.platformDispatcher.defaultRouteName;

    if (defaultName != '/') {
      entry = _parse(defaultName);
    }

    entry ??=
        createEntry(rootPage, params: params, extra: extra, groupId: groupId);

    routeQueue.insert(entry);
    assert(routeQueue.current == entry);
    routeQueue.updateRouteInfo(true);
  }

  bool _restore() {
    if (kDartIsWeb) {
      if (historyState case {'state': Map data}) {
        assert(Log.w('state: ${data.logPretty()}', showTag: false));
        final n = RouteQueue.fromJson(data, this);
        if (n != null) {
          routeQueue.copyFrom(n);
          // ? ? ?
          routeQueue.updateRouteInfo(true);
          return true;
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final navObservers = [
      if (!router.observers.contains(Nav.observer)) Nav.observer,
      ...router.observers,
    ];
    return RouteRestorable(
      restorationId: restorationId,
      delegate: this,
      child: AnimatedBuilder(
        animation: _routeQueue,
        builder: (context, child) {
          return Navigator(
            pages: _routeQueue.pages,
            key: navigatorKey,
            observers: navObservers,
            onPopPage: _onPopPage,
          );
        },
      ),
    );
  }

  bool _onPopPage(Route route, result) {
    if (!route.didPop(result)) {
      return false;
    }
    if (route.settings is Page) {
      final entry = _routeQueue.map.remove(route.settings);
      if (entry != null) {
        entry.remove();
        _updateRouteInfo(false);
      }
    }
    return true;
  }

  late final _routeQueue = RouteQueue(this);

  RouteQueue get routeQueue => _routeQueue;

  void _updateRouteInfo(bool replace) {
    _routeQueue.updateRouteInfo(replace);
  }

  RouteQueueEntry? _parse(String location,
      {Map<String, dynamic> params = const {},
      Map<String, dynamic>? extra,
      Object? groupId}) {
    final uri = Uri.parse(location);

    String? path = location;
    Map<String, dynamic> query = uri.queryParameters;
    if (extra != null && extra.isNotEmpty) {
      query = extra;
      path = null;
    }
    if (path != null && params.isNotEmpty) {
      path = null;
    }

    final realParams = <String, dynamic>{};
    final route = rootPage.getPageFromLocation(uri.path, realParams, params);
    if (route == null) return null;

    return RouteQueueEntry(
      path: path,
      nPage: route,
      params: realParams,
      queryParams: query,
      groupId: groupId,
      pageKey: _newPageKey(),
    );
  }

  RouteQueueEntry _run(RouteQueueEntry entry, {bool update = true}) {
    final newEntry =
        entry.nPage.redirect(entry, builder: rootPage.redirectBuilder);

    assert(newEntry.pageKey == entry.pageKey);

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      // attach
      newEntry.attach(_routeQueue);

      // delay
      SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
        _routeQueue.insert(newEntry);
      });
    } else {
      _routeQueue.insert(newEntry);
    }
    if (update) _updateRouteInfo(false);
    return newEntry;
  }

  RouteQueueEntry createEntry(NPage page,
      {Map<String, dynamic> params = const {},
      Map<String, dynamic>? extra,
      Object? groupId}) {
    return RouteQueueEntry(
      params: params,
      nPage: page,
      queryParams: extra ?? const {},
      groupId: groupId,
      pageKey: _newPageKey(),
    );
  }

  final random = Random();

  ValueKey<String> _newPageKey({String prefix = 'n+'}) {
    final key =
        String.fromCharCodes(List.generate(24, (_) => random.nextInt(97) + 33));

    return ValueKey('$prefix$key');
  }

  bool isValid(String location) {
    final uri = Uri.parse(location);
    final path = uri.path;
    return rootPage.getPageFromLocation(path) != null;
  }

  RouteQueueEntry go(String location,
      {Map<String, dynamic> params = const {},
      Map<String, dynamic>? extra,
      Object? groupId}) {
    final entry =
        _parse(location, params: params, extra: extra, groupId: groupId)!;
    return _run(entry);
  }

  RouteQueueEntry goPage(NPage page,
      {Map<String, dynamic> params = const {},
      Map<String, dynamic>? extra,
      Object? groupId}) {
    final entry =
        createEntry(page, params: params, extra: extra, groupId: groupId);
    return _run(entry);
  }

  void _until(UntilFn test) {
    RouteQueueEntry? current = _routeQueue.current;

    RouteQueueEntry? entry = current;
    while (entry != null) {
      if (test(entry)) break;
      final pre = entry.pre;
      entry = pre;
    }

    final nav = navigatorKey.currentState;
    if (entry != null && entry != current && nav?.mounted == true) {
      final page = entry.page;
      nav!.popUntil((route) => route.settings == page);
    }
  }

  RouteQueueEntry goUntil(String location, UntilFn test) {
    _until(test);
    return go(location);
  }

  RouteQueueEntry goPageUntil(NPage page, UntilFn test,
      {Map<String, dynamic> params = const {},
      Map<String, dynamic>? extra,
      Object? groupId}) {
    _until(test);
    return goPage(page, params: params, extra: extra, groupId: groupId);
  }

  bool canPop() => navigatorKey.currentState?.canPop() ?? !_routeQueue.isSingle;
  Future<bool> maybePop() =>
      navigatorKey.currentState?.maybePop() ?? SynchronousFuture(false);

  void popUntil(UntilFn test) {
    _until(test);
  }

  void pop([Object? result]) {
    _pop(result);
    _updateRouteInfo(false);
  }

  void _pop([Object? result]) {
    final last = _routeQueue.current;
    if (last != null && last != _routeQueue.root) {
      last.remove(result);
    }
  }

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Future<void> setNewRoutePath(configuration) {
    _routeQueue.copyFrom(configuration);
    return SynchronousFuture(null);
  }
}

class RouterAction {
  RouterAction(NPage page, this.router,
      {Map<String, dynamic> params = const {},
      Map<String, dynamic>? extra,
      Object? groupId})
      : entry = router.routerDelegate
            .createEntry(page, params: params, extra: extra, groupId: groupId);

  final RouteQueueEntry entry;
  final NRouter router;

  RouteQueueEntry go() {
    return router.routerDelegate._run(entry);
  }

  RouteQueueEntry goUntil(UntilFn test) {
    router.routerDelegate._until(test);
    return go();
  }

  RouteQueueEntry goReplacement([Object? result, bool immediated = false]) {
    final queue = router.routerDelegate._routeQueue;
    if (immediated && queue.current != null) {
      entry.replace(queue.current!.pageKey);
    }
    queue.removeLast();
    final newEntry = router.routerDelegate._run(entry, update: false);
    queue.updateRouteInfo(true);
    return newEntry;
  }
}
