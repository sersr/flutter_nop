part of 'router.dart';

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
  NRouterDelegate get delegate => widget.delegate;
  RouteQueue get routeQueue => delegate.routeQueue;

  @override
  Widget build(BuildContext context) {
    return _NRouterScope(
        routeQueue: routeQueue, state: this, child: widget.child);
  }

  /// internal state
  late _RouteQueueRestoration _restoration;

  @override
  void initState() {
    super.initState();
    _restoration = _RouteQueueRestoration(routeQueue);
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
    if (!delegate.updateLocation) return SynchronousFuture(false);

    final state = routeInformation.state;
    final list = RouteQueue.pageList(state) ?? const [];

    assert(Log.e('uri: ${routeInformation.location}'));

    RouteQueueEntry? stateEntry;
    if (list case [..., Map last]) {
      if (RouteQueueEntry.canParse(last)) {
        stateEntry = RouteQueueEntry.fromJson(last, delegate);
      }
    }

    final pre = routeQueue.pre;
    if (stateEntry != null && stateEntry.eq(pre)) {
      // assert(Log.i('pre:'));
      // assert(Log.w(pre?.toJson(detail: true).logPretty()));
      // assert(Log.i('state:'));
      // assert(Log.w(stateEntry.toJson(detail: true).logPretty()));
      assert(!routeQueue.isSingle);
      routeQueue._current?._removeCurrent(update: false);
    } else {
      RouteQueueEntry? entry = stateEntry;

      if (entry == null) {
        final uri = Uri.tryParse(routeInformation.location ?? '');
        if (uri == null) return SynchronousFuture(false);

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

      routeQueue.insert(entry, update: false);
    }
    return SynchronousFuture(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restoration.dispose();
    super.dispose();
  }

  @override
  String? get restorationId => widget.restorationId;

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_restoration, '_routes');
  }
}

class NRouterDelegate extends RouterDelegate<RouteQueue>
    with PopNavigatorRouterDelegateMixin, ChangeNotifier {
  NRouterDelegate(
      {this.restorationId, required this.rootPage, required this.router});
  final String? restorationId;
  final NPageMain rootPage;
  final NRouter router;

  bool get updateLocation => router.updateLocation;

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
  }

  bool _restore() {
    if (!updateLocation) return false;
    if (historyState case {'state': Map data}) {
      // assert(Log.w('state: ${data.logPretty()}', showTag: false));
      final n = RouteQueue.fromJson(data, this);
      if (n != null) {
        routeQueue._copyFrom(n);
        return true;
      }
    }

    return false;
  }

  late final _obverser = _RouteQueueObverser(_routeQueue);

  @override
  Widget build(BuildContext context) {
    final navObservers = [_obverser, ...router.observers];
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
    _routeQueue._popRoute(route, result);

    return true;
  }

  late final _routeQueue = RouteQueue(this);

  RouteQueue get routeQueue => _routeQueue;

  RouteQueueEntry _parse(String location,
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
    if (route == null) {
      return rootPage.errorBuild(location, params, extra ?? const {}, groupId);
    }

    return RouteQueueEntry(
      path: path,
      nPage: route,
      params: realParams,
      queryParams: query,
      groupId: groupId,
      pageKey: _newPageKey(),
    );
  }

  RouteQueueEntry _redirect(RouteQueueEntry entry) {
    final newEntry =
        entry.nPage.redirect(entry, builder: rootPage.redirectBuilder);

    assert(newEntry.pageKey == entry.pageKey);
    return newEntry;
  }

  RouteQueueEntry _run(RouteQueueEntry entry) {
    entry = _redirect(entry);
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      // attach
      entry._queue = _routeQueue;

      // delay
      SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
        _routeQueue.insert(entry);
      });
    } else {
      _routeQueue.insert(entry);
    }
    return entry;
  }

  RouteQueueEntry createEntry(NPage page,
      {Map<String, dynamic> params = const {},
      Map<String, dynamic>? extra,
      Object? groupId}) {
    assert(rootPage.contains(page));

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
        _parse(location, params: params, extra: extra, groupId: groupId);

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

  RouteQueueEntry goReplacement(String location,
      {Map<String, dynamic> params = const {},
      Map<String, dynamic>? extra,
      Object? groupId,
      Object? result,
      bool immediated = false}) {
    final entry =
        _parse(location, params: params, extra: extra, groupId: groupId);
    return _goReplacement(entry, immediated, result);
  }

  RouteQueueEntry goPageRepalcement(NPage page, UntilFn test,
      {Map<String, dynamic> params = const {},
      Map<String, dynamic>? extra,
      Object? groupId,
      Object? result,
      bool immediated = false}) {
    final entry =
        createEntry(page, params: params, extra: extra, groupId: groupId);
    return _goReplacement(entry, immediated, result);
  }

  RouteQueueEntry _goReplacement(
      RouteQueueEntry entry, bool immediated, Object? result) {
    final queue = _routeQueue;
    final current = queue.current;
    if (immediated && current != null) {
      entry.replace(current.pageKey);
    }
    current?._removeCurrent(result: result, update: false);
    final newEntry = _redirect(entry);
    queue.insert(newEntry, replace: true);
    return newEntry;
  }

  void _until(UntilFn test, {bool ignore = false}) {
    _routeQueue.removeUntil(test, ignore);
  }

  RouteQueueEntry goUntil(String location, UntilFn test) {
    _until(test, ignore: true);
    return go(location);
  }

  RouteQueueEntry goPageUntil(NPage page, UntilFn test,
      {Map<String, dynamic> params = const {},
      Map<String, dynamic>? extra,
      Object? groupId}) {
    _until(test, ignore: true);
    return goPage(page, params: params, extra: extra, groupId: groupId);
  }

  bool canPop() => navigatorKey.currentState?.canPop() ?? !_routeQueue.isSingle;
  Future<bool> maybePop() =>
      navigatorKey.currentState?.maybePop() ?? SynchronousFuture(false);

  void popUntil(UntilFn test, bool ignore) {
    _until(test, ignore: ignore);
  }

  void pop([Object? result]) {
    _pop(result);
  }

  void _pop([Object? result]) {
    final last = _routeQueue.current;
    if (last != null && last != _routeQueue.root) {
      last._removeCurrent(result: result);
    }
  }

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Future<void> setNewRoutePath(configuration) {
    _routeQueue._copyFrom(configuration);
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
    router.routerDelegate._until(test, ignore: true);
    return go();
  }

  RouteQueueEntry goReplacement({Object? result, bool immediated = false}) {
    return router.routerDelegate._goReplacement(entry, immediated, result);
  }
}
