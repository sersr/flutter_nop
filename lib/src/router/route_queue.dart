part of 'router.dart';

class RouteQueue extends RestorableProperty<List<RouteQueueEntry>?>
    with RouteQueueMixin {
  RouteQueue(this.delegate);
  @override
  bool get isRegistered => super.isRegistered;
  final NRouterDelegate delegate;

  List<Page>? _pages;
  List<Page> get pages => _pages ??= _newPages();

  Map<Page, RouteQueueEntry>? _map;
  Map<Page, RouteQueueEntry> get map => _map ?? const {};

  List<Page> _newPages() {
    final list = <Page>[];
    final map = <Page, RouteQueueEntry>{};
    RouteQueueEntry? r = _root;
    while (r != null) {
      final page = r._build();
      if (page != null) {
        map[page] = r;
        list.add(page);
      }
      r = r._next;
    }
    _map = map;
    return list;
  }

  RouteQueueEntry? _lastInfo;

  void updateRouteInfo(bool repalce) {
    if (kIsWeb) {
      assert(_lastInfo == null || _lastInfo != _current);
      _lastInfo = _current;
      final state = toPrimitives();
      // assert(Log.w('path : ${_current!.path} state: ${state.logPretty()}'));
      SystemNavigator.selectMultiEntryHistory();
      SystemNavigator.routeInformationUpdated(
          uri: Uri.tryParse(_current!.path), state: state, replace: repalce);
    }
  }

  @override
  void refresh() {
    _pages = _newPages();
    notifyListeners();
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

  @override
  List<RouteQueueEntry>? createDefaultValue() {
    return null;
  }

  static List? pageList(Object? data) {
    switch (data) {
      case {'list': List list}:
        return list;
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
        .._parent = parent
        .._pre = last;
      last = current;
      list.add(current);
    }

    return list;
  }

  @override
  List<RouteQueueEntry>? fromPrimitives(Object? data) {
    switch (data) {
      case {'list': List listMap}:
        return fromListMap(listMap, this);
    }
    return null;
  }

  @override
  void initWithValue(List<RouteQueueEntry>? value) {
    if (value != null && value.isNotEmpty) {
      forEach((current) {
        current._parent = null;
        current._pre = null;
        current._next = null;
        current._complete();
        return false;
      });

      final root = value.first;
      final current = value.last;
      assert(root._parent == this && current._parent == this);
      _root = root;
      _current = current;
      _length = value.length;
      refresh();
    }
  }

  @override
  Map toPrimitives() {
    final list = <Map<String, dynamic>>[];
    RouteQueueEntry? r = _root;

    while (r != null) {
      list.add(r.toJson());
      assert(r._next != null || r == _current);
      r = r._next;
    }

    return {
      'list': list,
    };
  }
}

mixin RouteQueueMixin {
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
    RouteQueueEntry? current = reverse ? _current : _root;
    while (current != null) {
      if (test(current)) return;
      if (reverse) {
        current = current._pre;
      } else {
        current = current._next;
      }
    }
  }

  void copyFrom(RouteQueue other) {
    if (other == this) return;

    other.forEach((entry) {
      assert(!entry._disposed);
      entry._parent = this;
      return false;
    });

    forEach((current) {
      current._parent = null;
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
  }

  bool isCurrent(RouteQueueEntry entry) => entry._parent == this;

  void insert(RouteQueueEntry entry, {RouteQueueEntry? after}) {
    assert(after == null || after._parent == this);
    assert(entry.isAlone);
    assert(entry._parent == null || entry._parent == this);

    if (entry._disposed) return;

    if (after != null && after != _current) {
      _insert(after, entry);
    } else {
      if (_current != null) {
        _insert(_current!, entry);
      }
      _current = entry;
    }
    entry._parent = this;
    _root ??= entry;
    _length += 1;
    refresh();
  }

  void _remove(RouteQueueEntryMixin entry, {bool notify = true}) {
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
    _root!._removeCurrent(result);
    return true;
  }

  bool removeLast([dynamic result]) {
    if (_current == null) return false;
    _current!._removeCurrent(result);
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

class RouteQueueEntry with RouteQueueEntryMixin {
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
        _useId = NPage.canUseId(groupId),
        _path = path;

  RouteQueueEntry._json({
    String? path,
    required this.params,
    required this.nPage,
    Object? groupId,
    required int id,
    required bool useId,
    required ValueKey<String> pageKey,
    this.queryParams = const {},
  })  : _pageKey = pageKey,
        _id = id,
        _useId = useId,
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

  ValueKey<String> _pageKey;
  ValueKey<String> get pageKey => _pageKey;

  void replace(ValueKey<String> key) {
    _pageKey = key;
  }

  /// `/path/to?user=foo` => {'user': 'foo'}
  final Map<dynamic, dynamic> queryParams;

  /// `/path/to/:user` => {'user': \<user\>}
  final Map<dynamic, dynamic> params;

  @override
  String get restorationId => nPage.getRestorationId(_id);

  final bool _useId;

  final int _id;

  @override
  int get id => _id;

  final Object? _groupId;
  Object? _cacheGroupId;

  Object? get groupId {
    if (_cacheGroupId != null) return _cacheGroupId!;
    if (!_useId) return _cacheGroupId = _groupId;

    return _cacheGroupId = _groupId ?? nPage.getGroupIdWithId(_id);
  }

  static RouteQueueEntry? of(BuildContext context) {
    final modal = ModalRoute.of(context);
    final page = modal?.settings;
    if (page is RouteQueueEntryPage) {
      return page.entry;
    }
    return null;
  }

  Page? _page;

  Page? get page => _page;
  Page? _build() {
    return _page ??= nPage.pageBuilder?.call(this);
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
          'useId': bool _,
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
          'useId': bool useId,
          'index': int index,
          'id': int id,
          'pageKey': String pageKey,
        }) {
      final root = delegate.rootPage;
      final route = root.getNPageFromIndex(index)!;

      /// reset global ids
      route.resetId(id);

      return RouteQueueEntry._json(
        id: id,
        path: path,
        useId: useId,
        queryParams: queryParams,
        params: params,
        nPage: route,
        groupId: groupId,
        pageKey: ValueKey(pageKey),
      );
    }
    throw RouteQueueFromJosnError(data: json);
  }

  Map<String, dynamic> toJson() {
    var ps = NRouterJsonTransfrom.encodeMap(params);
    final qps = NRouterJsonTransfrom.encodeMap(queryParams);

    return {
      'path': _path,
      'id': _id,
      'index': nPage.index,
      'params': ps,
      'queryParams': qps,
      'groupId': _groupId,
      'useId': _useId,
      'pageKey': pageKey.value,
    };
  }
}

mixin RouteQueueEntryMixin {
  int get id;
  String get restorationId => 'n_router+$id';
  RouteQueueMixin? _parent;

  RouteQueueEntry? _pre;
  RouteQueueEntry? _next;

  RouteQueueEntry? get pre => _pre;
  RouteQueueEntry? get next => _next;

  bool get isAlone => _pre == null && _next == null;
  bool get attached => _parent != null;

  void attach(RouteQueueMixin parent) {
    assert(_parent == null);
    _parent = parent;
  }

  void detach() {
    _parent = null;
  }

  Completer<dynamic>? _completer;

  Future<dynamic> get future => (_completer ??= Completer<dynamic>()).future;

  bool get isCompleted => _completer != null && _completer!.isCompleted;

  bool get isActived => !isCompleted && !_disposed;

  bool _disposed = false;

  void remove([dynamic result]) {
    _removeCurrent(result);
  }

  void _removeCurrent([dynamic result, bool update = true]) {
    if (_disposed) return;

    final root = _parent;
    if (root == null) {
      /// 立即取消
      _complete();
      return;
    }

    _pre?._next = _next;
    _next?._pre = _pre;
    _parent = null;
    root._remove(this, notify: update);
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
    cache.future.whenComplete(() {
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
