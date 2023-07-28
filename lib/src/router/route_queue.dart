part of 'router.dart';

/// [RouteQueue]的移除操作并不会触发[Navigator.onPopPage]回调
class _RouteQueueObverser extends NavigatorObserver {
  _RouteQueueObverser(this.router);
  final NRouter router;

  Route? _topRoute;
  Route? get topRoute => _topRoute;

  @override
  void didPush(Route route, Route? previousRoute) {
    if (route.isCurrent) _topRoute = route;
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    if (newRoute?.isCurrent == true) {
      _topRoute = newRoute;
    }
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    if (previousRoute?.isCurrent == true) {
      _topRoute = previousRoute;
    }
    router.didPop(route);
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    router.didRemove(route);
  }
}

class _RouteQueueRestoration
    extends RestorableProperty<List<RouteQueueEntry>?> {
  _RouteQueueRestoration(this.routeQueue) {
    routeQueue._addRestoration(this);
  }
  final RouteQueue routeQueue;

  @override
  List<RouteQueueEntry>? createDefaultValue() {
    return null;
  }

  @override
  List<RouteQueueEntry>? fromPrimitives(Object? data) {
    return routeQueue.fromPrimitives(data);
  }

  @override
  void initWithValue(List<RouteQueueEntry>? value) {
    return routeQueue.initWithValue(value);
  }

  @override
  Object? toPrimitives() {
    return routeQueue.toPrimitives();
  }

  @override
  void dispose() {
    routeQueue._removeRestoration(this);
    super.dispose();
  }
}

class RouteQueue with ChangeNotifier, _RouteQueueMixin {
  RouteQueue(this.delegate);
  final NRouterDelegate delegate;

  final _restorations = <_RouteQueueRestoration>[];

  void _addRestoration(_RouteQueueRestoration value) {
    _restorations.add(value);
  }

  void _removeRestoration(_RouteQueueRestoration value) {
    _restorations.remove(value);
  }

  List<Page>? _pages;
  List<Page> get pages => _pages ??= _newPages();

  List<Page> _newPages() {
    final list = <Page>[];
    RouteQueueEntry? r = _root;
    while (r != null) {
      final page = r._build();
      list.add(page);

      r = r._next;
    }
    return list;
  }

  void _popRoute(Route route, dynamic result) {
    final entry = getEntry(route);

    if (entry != null) {
      entry._removeCurrent(result: result);
    }
  }

  RouteQueueEntry? getEntry(Route route) {
    return switch (route.settings) {
      RouteQueueEntryPage page => page.entry,
      _ => null,
    };
  }

  void _copyFrom(RouteQueue other) {
    if (other == this) return;

    other.forEach((entry) {
      assert(!entry._disposed);
      entry._queue = this;
      return false;
    });

    forEach((current) {
      current._queue = null;
      current._pre = null;
      current._next = null;
      current._complete();
      return false;
    });

    _root = other._root;
    _current = other._current;
    _length = other.length;
    other._root = null;
    other._current = null;

    refresh();
    _updateRouteInfo(true);
  }

  @override
  void insert(RouteQueueEntry entry,
      {RouteQueueEntry? after, bool update = true, bool replace = false}) {
    super.insert(entry, after: after);
    if (update) {
      _updateRouteInfo(replace);
    }
  }

  @override
  void _remove(RouteQueueEntry entry, bool notify, bool update) {
    super._remove(entry, notify, update);
    if (update) _updateRouteInfo();
  }

  RouteQueueEntry? _removeUntil(UntilFn test, bool ignore) {
    final current = _current;
    RouteQueueEntry? entry = current;
    while (entry != null) {
      if (test(entry)) break;
      assert(ignore || entry != _root, 'no pages.\nroot page will be removed.');

      final pre = entry.pre;
      entry._removeCurrent(refresh: false);
      entry = pre;
    }
    if (entry != current) {
      refresh();
      return entry;
    }
    return null;
  }

  RouteQueueEntry? _lastInfo;

  void _updateRouteInfo([bool replace = false]) {
    if (kIsWeb && delegate.updateLocation) {
      replace |= _lastInfo == null || _lastInfo!.eq(_current);

      // maybe: goUntil((entry) => false);
      if (_current == null) return;
      _lastInfo = _current;

      final state = toPrimitives();

      SystemNavigator.selectMultiEntryHistory();
      SystemNavigator.routeInformationUpdated(
          location: _current!.path, state: state, replace: replace);
    }
  }

  @override
  void refresh() {
    _pages = _newPages();
    notifyListeners();
  }

  @override
  void _attach(RouteQueueEntry entry) {
    entry._queue = this;
  }

  @override
  void notifyListeners() {
    for (var e in _restorations) {
      e.notifyListeners();
    }
    super.notifyListeners();
  }

  RouteQueueEntry? getEntryFromId(int id) {
    RouteQueueEntry? entry;
    forEach((e) {
      if (e._id == id) {
        entry = e;
        return true;
      }
      return false;
    });
    return entry;
  }

  static RouteQueueEntry? getLast(Object? data, NRouterDelegate delegate) {
    if (data case {'list': [..., Map last]}) {
      if (RouteQueueEntry.canParse(last)) {
        return RouteQueueEntry.fromJson(last, delegate);
      }
    }

    return null;
  }

  static RouteQueue? fromJson(Object? data, NRouterDelegate delegate) {
    switch (data) {
      case {'list': List listMap}:
        final routeQueue = RouteQueue(delegate);
        final list = fromListMap(listMap, routeQueue);
        routeQueue.initWithValue(list);
        return routeQueue;
    }

    return null;
  }

  static List<RouteQueueEntry> fromListMap(List data, RouteQueue parent) {
    final list = <RouteQueueEntry>[];
    RouteQueueEntry? last;

    for (var item in data) {
      assert(item is Map);
      final current = RouteQueueEntry.fromJson(item, parent.delegate);

      last?._next = current;
      current
        .._queue = parent
        .._pre = last;
      last = current;
      list.add(current);
    }

    return list;
  }

  List<RouteQueueEntry>? fromPrimitives(Object? data) {
    switch (data) {
      case {'list': List listMap}:
        return fromListMap(listMap, this);
    }
    return null;
  }

  void initWithValue(List<RouteQueueEntry>? value) {
    if (value != null && value.isNotEmpty) {
      forEach((current) {
        current
          .._queue = null
          .._pre = null
          .._next = null;
        current._complete();
        return false;
      });

      final root = value.first;
      final current = value.last;
      assert(root._queue == this && current._queue == this);
      _root = root;
      _current = current;
      _length = value.length;
      refresh();
    }
  }

  Map toPrimitives() {
    final list = <Map<String, dynamic>>[];
    RouteQueueEntry? r = _root;

    while (r != null) {
      if (!r.isErrorEntry) list.add(r.toJson());
      assert(r._next != null || r == _current);
      r = r._next;
    }

    return {
      'list': list,
    };
  }
}

mixin _RouteQueueMixin {
  RouteQueueEntry? _root;
  RouteQueueEntry? _current;
  RouteQueueEntry? get root => _root;
  RouteQueueEntry? get current => _current;

  RouteQueueEntry? get pre => _current?._pre;
  RouteQueueEntry? get next => _current?._next;

  int _length = 0;
  int get length => _length;

  bool get isSingle => _root == _current && _root != null && _current != null;

  void forEach(UntilFn test, {bool reverse = false}) {
    RouteQueueEntry? current;

    if (reverse) {
      current = _current;
      while (current != null) {
        if (test(current)) return;
        current = current._pre;
      }
    } else {
      current = _root;
      while (current != null) {
        if (test(current)) return;
        current = current._next;
      }
    }
  }

  bool isCurrent(RouteQueueEntry entry) => entry._queue == this;

  void insert(RouteQueueEntry entry, {RouteQueueEntry? after}) {
    assert(after == null || after._queue == this);
    assert(entry.isAlone);
    assert(entry._queue == null || entry._queue == this);

    if (entry._disposed) return;

    if (after != null && after != _current) {
      _insert(after, entry);
    } else {
      if (_current != null) {
        _insert(_current!, entry);
      }
      _current = entry;
    }
    _attach(entry);
    _root ??= entry;
    _length += 1;
    refresh();
  }

  void _attach(RouteQueueEntry entry);

  void _remove(RouteQueueEntry entry, bool notify, bool update) {
    if (_root == entry) {
      assert(entry._pre == null);
      _root = entry._next;
    }
    if (_current == entry) {
      assert(entry._next == null);
      _current = entry._pre;
    }
    _length -= 1;
    assert(_length >= 0);
    if (notify) refresh();
  }

  bool removeFirst([dynamic result]) {
    if (_root == null) return false;
    _root!._removeCurrent(result: result);
    return true;
  }

  bool removeLast([dynamic result]) {
    if (_current == null) return false;
    _current!._removeCurrent(result: result);
    return true;
  }

  void _insert(RouteQueueEntry current, RouteQueueEntry entry) {
    assert(entry.isAlone);
    entry._next = current._next;
    entry._pre = current;
    current._next = entry;
  }

  void refresh();
}

class RouteQueueEntry with _RouteQueueEntryMixin implements LogPretty {
  RouteQueueEntry({
    String? path,
    required this.params,
    required this.nPage,
    required ValueKey<String> pageKey,
    Object? groupId,
    this.queryParams = const {},
  })  : _pageKey = pageKey,
        _groupId = NPage.ignoreToken(groupId),
        _id = nPage._newRouteId,
        _path = path;

  static RouteQueueEntry error({
    required String path,
    NPage? nPage,
    Map params = const {},
    Object? groupId,
    Map queryParams = const {},
    ValueKey<String> pageKey = const ValueKey('errorPage'),
  }) {
    return RouteQueueEntry._internal(
      path: path,
      nPage: nPage ?? NPage.errorNPage,
      params: params,
      queryParams: queryParams,
      groupId: groupId,
      pageKey: pageKey,
      id: -1,
    );
  }

  RouteQueueEntry._internal({
    String? path,
    required this.params,
    required this.nPage,
    Object? groupId,
    required int id,
    required ValueKey<String> pageKey,
    this.queryParams = const {},
  })  : _pageKey = pageKey,
        _id = id,
        _groupId = groupId,
        _path = path;

  final String? _path;
  String? _cachePath;

  String get path {
    if (_cachePath != null) return _cachePath!;

    return _cachePath = _path ?? nPage.getUrl(params, queryParams);
  }

  bool eq(RouteQueueEntry? other) {
    if (other == null) return false;
    if (identical(this, other)) return true;

    return path == other.path && pageKey == other.pageKey;
  }

  final NPage nPage;
  bool get isErrorEntry => nPage.isErrorPage;

  bool get isTopPage => _queue?._current == this;

  Object? getGroup(Type t) {
    if (nPage.groupList.contains(t)) {
      return groupId;
    }
    return null;
  }

  ValueKey<String> _pageKey;
  ValueKey<String> get pageKey => _pageKey;

  void replace(ValueKey<String> key) {
    assert(!attached);
    _pageKey = key;
  }

  /// `/path/to?user=foo` => {'user': 'foo'}
  final Map<dynamic, dynamic> queryParams;

  /// `/path/to/:user` => {'user': \<user\>}
  final Map<dynamic, dynamic> params;

  @override
  String get restorationId => nPage.getRestorationId(_id);

  final int _id;

  @override
  int get id => _id;

  final Object? _groupId;
  Object? _cacheGroupId;

  Object? get groupId {
    return _cacheGroupId ??= _groupId ?? nPage.getGroupId(_id);
  }

  static RouteQueueEntry? of(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route == null) return null;
    final queue = RouteRestorable.maybeOf(context)?.delegate.routeQueue;

    return queue?.getEntry(route);
  }

  RouteQueueEntryPage? _page;

  RouteQueueEntryPage? get page => _page;
  RouteQueueEntryPage _build() {
    return _page ??= nPage.pageBuilder(this);
  }

  RouteQueueEntry redirect({
    required Map<String, dynamic> params,
    required NPage page,
    Map<String, dynamic> queryParams = const {},
    Object? groupId,
  }) {
    assert(isAlone && !attached);
    _disposed = true;

    return RouteQueueEntry(
      nPage: page,
      params: params,
      queryParams: queryParams,
      groupId: groupId,
      pageKey: _pageKey,
    );
  }

  RouteQueueEntry redirectEntry(RouteQueueEntry entry) {
    return entry.._pageKey = _pageKey;
  }

  static bool canParse(Map? json) {
    if (json
        case {
          'path': String? _,
          'params': Map _,
          'queryParams': Map _,
          'groupId': Object? _,
          'index': int _,
          'id': int _,
          'pageKey': String _,
        }) return true;

    return false;
  }

  static RouteQueueEntry fromJson(Map json, NRouterDelegate delegate) {
    if (json
        case {
          'path': String? path,
          'params': Map params,
          'queryParams': Map queryParams,
          'groupId': Object? groupId,
          'index': int index,
          'id': int id,
          'pageKey': String pageKey,
        }) {
      final root = delegate.rootPage;
      final route = root.getNPageFromIndex(index)!;

      /// reset route id
      route.resetId(id);

      return RouteQueueEntry._internal(
        id: id,
        path: path,
        queryParams: queryParams,
        params: params,
        nPage: route,
        groupId: groupId,
        pageKey: ValueKey(pageKey),
      );
    }
    throw RouteQueueFromJosnError(data: json);
  }

  Map<String, dynamic> toJson({bool detail = false}) {
    var ps = NRouterJsonTransfrom.encodeMap(params);
    final qps = NRouterJsonTransfrom.encodeMap(queryParams);
    if (isErrorEntry) {
      return {
        'page': path,
        'isErrorPage': true,
      };
    }
    return {
      'path': detail ? path : _path,
      'id': _id,
      'index': nPage.index,
      'params': ps,
      'queryParams': qps,
      'groupId': _groupId,
      'pageKey': pageKey.value,
    };
  }

  @override
  (dynamic, int) logPretty(int level) {
    return (toJson(detail: true), level);
  }

  @override
  void _onRemove(RouteQueue root, bool refresh, bool update) {
    root._remove(this, refresh, update);
  }
}

mixin _RouteQueueEntryMixin {
  int get id;
  String get restorationId => 'n_router+$id';
  RouteQueue? _queue;

  RouteQueueEntry? _pre;
  RouteQueueEntry? _next;

  RouteQueueEntry? get pre => _pre;
  RouteQueueEntry? get next => _next;

  bool get isAlone => _pre == null && _next == null;
  bool get attached => _queue != null;

  Completer<dynamic>? _completer;

  @Deprecated('use popped.')
  Future<dynamic> get future => popped;
  Future<dynamic> get popped => (_completer ??= Completer<dynamic>()).future;

  bool get _isCompleted => _completer != null && _completer!.isCompleted;

  bool get isCompleted => _isCompleted || _disposed;

  bool get isActived => !isCompleted;

  bool _disposed = false;

  void remove([dynamic result]) {
    _removeCurrent(result: result);
  }

  void _onRemove(RouteQueue root, bool refresh, bool update);

  void _removeCurrent(
      {dynamic result, bool refresh = true, bool update = true}) {
    if (_disposed) return;

    final root = _queue;
    if (root == null) {
      /// 立即取消
      _complete();
      return;
    }

    _pre?._next = _next;
    _next?._pre = _pre;
    _queue = null;
    _onRemove(root, refresh, update);
    _pre = null;
    _next = null;
    _complete(result);
  }

  void _complete([dynamic result]) {
    _disposed = true;
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(result);
    }
  }
}

mixin RouteQueueEntryStateMixin<T extends StatefulWidget>
    on State<T>, RestorationMixin<T> {
  final _id = RestorableIntN(null);
  NRouter? get nRouter => null;

  RouteQueueEntry? _entry;
  RouteQueueEntry? get entry => _entry;

  set entry(RouteQueueEntry? value) {
    _entry = value;
    _id.value = _entry?._id;
    if (_entry != null) {
      _completed();
    }
  }

  @mustCallSuper
  void onRestoreEntry() {
    assert(_entry != null);
    _completed();
  }

  void _completed() {
    final cache = entry;
    if (cache == null) return;
    cache.popped.whenComplete(() {
      if (cache != entry) return;
      entry = null;
      whenComplete(cache);
    });
  }

  void whenComplete(RouteQueueEntry entry) {}

  String get nRouterRestorationId => '_route_queue_entry';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_id, nRouterRestorationId);
    final id = _id.value;
    final router = nRouter ?? NRouter.of(context);
    if (id != null) {
      final entry = router.getEntryFromId(id);
      if (entry != null) {
        _entry = entry;
        onRestoreEntry();
      }
    }
  }
}

class RouteQueueFromJosnError implements Exception {
  const RouteQueueFromJosnError({this.data});

  final Map? data;

  @override
  String toString() {
    return 'RouteQueueFromJosnError: $data';
  }
}
