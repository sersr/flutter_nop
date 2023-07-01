import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:nop/nop.dart';

import '../../nav.dart';
import '../../router.dart';
import 'router.dart';
import 'web/history_state.dart';

export 'dart:convert' show jsonDecode;

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
  final NRouteDelegate delegate;
  RouteQueue get routeQueue => delegate._routeQueue;

  // ignore: library_private_types_in_public_api
  static _RouteRestorableState? maybeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_NRouterScope>();
    return scope?.state;
  }

  @override
  State<RouteRestorable> createState() => _RouteRestorableState();
}

class _NRouterScope extends InheritedWidget {
  const _NRouterScope(
      {required this.routeQueue, this.state, required super.child});
  final RouteQueue routeQueue;
  final _RouteRestorableState? state;

  @override
  bool updateShouldNotify(covariant _NRouterScope oldWidget) {
    return routeQueue != oldWidget.routeQueue || state != oldWidget.state;
  }
}

class _RouteRestorableState extends State<RouteRestorable>
    with WidgetsBindingObserver, RestorationMixin {
  late RouteQueue routeQueue;
  NRouteDelegate get delegate => widget.delegate;

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
  Future<bool> didPopRoute() async {
    final nav = widget.delegate.navigatorKey.currentState;
    if (nav == null) {
      return false;
    }
    return nav.maybePop();
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) {
    final uri = routeInformation.uri;
    final realParams = <String, dynamic>{};
    final route =
        widget.delegate.rootPage.getPageFromLocation(uri.path, realParams);
    if (route == null) {
      return SynchronousFuture(false);
    }

    final pre = routeQueue.pre;
    final state = routeInformation.state;
    final url = uri.toString();
    final list = RouteQueue.pageList(state) ?? const [];
    if (pre?.path == url) {
      widget.delegate._pop();
    } else {
      final isNew = list.isEmpty;

      RouteQueueEntry? entry;
      if (!isNew) {
        entry = RouteQueueEntry.fromJson(list.last, widget.delegate.rootPage);
      }
      if (entry == null || entry.path != url) {
        ValueKey pageKey;
        int id;
        if (isNew) {
          id = widget.delegate.newId;
          pageKey = widget.delegate._newPageKey(prefix: 'p+');
        } else {
          pageKey = ValueKey(list.last['pageKey']);
          id = list.last['id'] as int;
        }
        entry = RouteQueueEntry(
          path: url,
          params: realParams,
          nPage: route,
          queryParams: uri.queryParameters,
          pageKey: pageKey,
        )..setId(id);
      }

      routeQueue.insert(entry);
      if (state == null) {
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

class NRouteDelegate extends RouterDelegate<RouteQueue>
    with PopNavigatorRouterDelegateMixin, ChangeNotifier {
  NRouteDelegate(
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
    if (_restore()) return;

    WidgetsFlutterBinding.ensureInitialized();
    RouteQueueEntry entry;
    final defaultName =
        WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    if (defaultName == '/') {
      entry =
          createEntry(rootPage, params: params, extra: extra, groupId: groupId);
    } else {
      entry = _parse(defaultName)!;
    }
    routeQueue.insert(entry);
    assert(routeQueue.current == entry);
    routeQueue.updateRouteInfo(true);
  }

  bool _restore() {
    if (kDartIsWeb) {
      final state = historyState as dynamic;
      Log.w('state: $state');
      RouteQueue? n;
      if (state is Map) {
        n = RouteQueue.fromJson(state['state'], this);
      }
      if (n != null) {
        routeQueue.copyWith(n);
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return RouteRestorable(
      restorationId: restorationId,
      delegate: this,
      child: AnimatedBuilder(
        animation: _routeQueue,
        builder: (context, child) {
          return Navigator(
            pages: _routeQueue.pages,
            key: navigatorKey,
            observers: [
              if (!router.observers.contains(Nav.observer)) Nav.observer,
              ...router.observers,
            ],
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
    )..setId(newId);
  }

  RouteQueueEntry _run(RouteQueueEntry entry, {bool update = true}) {
    final newEntry =
        entry.nPage.redirect(entry, builder: rootPage.redirectBuilder);
    newEntry.setId(entry.id!);
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
      groupId: page.resolveGroupId(groupId),
      pageKey: _newPageKey(),
    )..setId(newId);
  }

  final random = Random();

  ValueKey _newPageKey({String prefix = 'n+'}) {
    final key =
        String.fromCharCodes(List.generate(32, (_) => random.nextInt(97) + 33));

    return ValueKey('$prefix$key');
  }

  int _id = 0;

  int get newId {
    _id += 1;
    return _id;
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

    while (current != null) {
      if (test(current)) break;
      final pre = current.pre;
      current = pre;
    }

    final nav = navigatorKey.currentState;
    if (current != null && nav?.mounted == true) {
      nav!.popUntil((route) => route.settings == current!.page);
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
    _routeQueue.copyWith(configuration);
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
    if (immediated) {
      entry.replace(queue.current?.pageKey);
    }
    queue.removeLast();
    final newEntry = router.routerDelegate._run(entry, update: false);
    queue.updateRouteInfo(true);
    return newEntry;
  }
}
