import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nop/nop.dart';

import 'delegate.dart';
import 'page.dart';
import 'router.dart';

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
      assert(
          Log.w('path : ${_current!.path} key: ${_current?.pageKey?.value}'));
      SystemNavigator.selectMultiEntryHistory();
      SystemNavigator.routeInformationUpdated(
          uri: Uri.tryParse(_current!.path),
          state: toPrimitives(),
          replace: repalce);
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
    if (data == null) return null;
    final map = Map.from(data as Map);
    final listMap = map['list'] as List;
    return listMap;
  }

  static RouteQueue? fromJson(Object? data, NRouterDelegate delegate) {
    if (data == null || data is! Map) return null;
    final routeQueue = RouteQueue(delegate);
    final list = <RouteQueueEntry>[];

    final listMap = data['list'];

    if (listMap is! List) {
      return null;
    }

    RouteQueueEntry? last;
    for (var item in listMap) {
      final current = RouteQueueEntry.fromJson(item, delegate.rootPage);

      last?._next = current;
      current
        .._parent = routeQueue
        .._pre = last;
      last = current;
      list.add(current);
    }
    routeQueue.initWithValue(list);
    return routeQueue;
  }

  @override
  List<RouteQueueEntry>? fromPrimitives(Object? data) {
    if (data == null) return null;
    final map = Map.from(data as Map);
    final list = <RouteQueueEntry>[];

    final listMap = map['list'];

    RouteQueueEntry? last;
    for (var item in listMap as List) {
      final current = RouteQueueEntry.fromJson(item, delegate.rootPage);

      last?._next = current;
      current
        .._parent = this
        .._pre = last;
      last = current;
      list.add(current);
    }
    return list;
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
  Object? toPrimitives() {
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

  void copyWith(RouteQueue other) {
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
  RouteQueueEntry(
      {String? path,
      required this.params,
      required this.nPage,
      ValueKey? pageKey,
      Object? groupId,
      this.queryParams = const {}})
      : _pageKey = pageKey,
        _groupId = groupId,
        _path = path;

  String? _path;

  String get path {
    if (_path != null) {
      return _path!;
    }
    return _path = nPage.getUrl(params, queryParams);
  }

  final NPage nPage;

  ValueKey? _pageKey;
  ValueKey? get pageKey => _pageKey;

  void replace(ValueKey? key) {
    _pageKey = key;
  }

  /// `/path/to?user=foo` => {'user': 'foo'}
  final Map<dynamic, dynamic> queryParams;

  /// `/path/to/:user` => {'user': \<user\>}
  final Map<dynamic, dynamic> params;

  Object? _groupId;
  Object? get groupId => _groupId;

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
    return RouteQueueEntry(
      path: path,
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

  factory RouteQueueEntry.fromJson(Map json, NPageMain root) {
    final path = json['path']; // String
    final queryParams = json['queryParams']; // Map
    var params = json['params'];
    final id = json['id'];
    final groupId = json['groupId'];
    final pageKey = json['pageKey'];
    final index = json['index'];
    final route = root.getNPageFromIndex(index);
    // final route = NPage.resolve(root, uri.path, params, null);
    if ((params is Map && params.isEmpty) && path is String) {
      params = Uri.parse(path).queryParameters;
    }
    return RouteQueueEntry(
      path: path,
      queryParams: queryParams,
      params: params,
      nPage: route!,
      groupId: groupId,
      pageKey: ValueKey(pageKey),
    )..setId(id);
  }

  void setId(int newId) {
    _id ??= newId;
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
      'groupId': groupId,
      'pageKey': pageKey?.value,
    };
  }
}

mixin RouteQueueEntryMixin {
  int? _id;
  int? get id => _id;
  String? get restorationId => _id == null ? null : 'n_router+$_id';
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
