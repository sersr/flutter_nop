import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:nop/nop.dart';

import '../../nav.dart';

typedef UntilFn = bool Function(RouteQueueEntry entry);

class RouteRestorable extends StatefulWidget {
  const RouteRestorable({
    super.key,
    this.restorationId,
    required this.routeQueue,
    required this.child,
  });
  final String? restorationId;
  final Widget child;
  final RouteQueue routeQueue;
  @override
  State<RouteRestorable> createState() => _RouteRestorableState();
}

class _RouteRestorableState extends State<RouteRestorable>
    with RestorationMixin {
  late RouteQueue routeQueue;

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void initState() {
    super.initState();
    routeQueue = widget.routeQueue;
  }

  @override
  void didUpdateWidget(covariant RouteRestorable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (routeQueue != widget.routeQueue) {
      routeQueue = widget.routeQueue;
      if (restorePending) {
        registerForRestoration(routeQueue, '_routes');
      }
    }
  }

  @override
  String? get restorationId => widget.restorationId;

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    assert(Log.w('res: $restorationId'));
    registerForRestoration(routeQueue, '_routes');
  }

  @override
  void activate() {
    if (!routeQueue.isRegistered) {
      registerForRestoration(routeQueue, '_routes');
    }
    super.activate();
  }

  @override
  void deactivate() {
    if (routeQueue.isRegistered) {
      unregisterFromRestoration(routeQueue);
    }
    super.deactivate();
  }
}

class NRouteDelegate extends RouterDelegate<RouteQueue>
    with PopNavigatorRouterDelegateMixin, ChangeNotifier {
  NRouteDelegate(
      {this.restorationId, required this.rootPage, required this.router});
  final String? restorationId;
  final NPageMain rootPage;
  final NRouter router;

  @override
  Widget build(BuildContext context) {
    return RouteRestorable(
      restorationId: restorationId,
      routeQueue: _routeQueue,
      child: AnimatedBuilder(
        animation: _routeQueue,
        builder: (context, child) {
          // 为什么使用 Navigator?
          // flutter 有很多使用`Navigator`的地方，
          // Dialog等都有使用
          return Navigator(
            pages: _routeQueue.pages,
            key: navigatorKey,
            observers: [Nav.observer],
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
      entry?._removeCurrent(null, false);
    }
    return true;
  }

  late final _routeQueue = RouteQueue(this);

  RouteQueueEntry _parse(String location) {
    final uri = Uri.parse(location);
    final path = uri.path;
    final query = uri.queryParameters;
    final params = <String, dynamic>{};
    final route = rootPage.getPageFromLocation(path, params);
    assert(route != null);

    return RouteQueueEntry(
        path: location, page: route!, params: params, queryParams: query);
  }

  void _init(String location) {
    final uri = Uri.parse(location);
    final path = uri.path;
    final query = uri.queryParameters;
    final params = <String, dynamic>{};
    final route = rootPage.getPageFromLocation(path, params);
    assert(route != null);

    final entry = RouteQueueEntry(
        path: path, params: params, page: route!, queryParams: query);
    _routeQueue.insert(entry);
  }

  void _run(RouteQueueEntry entry) {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      // attach
      entry._parent = _routeQueue;
      // delay
      SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
        _routeQueue.insert(entry);
      });
    } else {
      _routeQueue.insert(entry);
    }
  }

  RouteQueueEntry createEntry(NPage page,
      {Map<String, dynamic> params = const {},
      Map<String, dynamic>? extra,
      Object? groupId}) {
    return RouteQueueEntry(
        path: page.fullPath,
        params: params,
        page: page,
        groupId: page.resolveGroupId(groupId),
        pageKey: _newPageKey(),
        fromPage: true);
  }

  @pragma('vm:prefer-inline')
  ValueKey _newPageKey() {
    // ignore: prefer_const_constructors
    return ValueKey(Object());
  }

  RouteQueueEntry go(String location, {Object? extra}) {
    final entry = _parse(location);
    _run(entry);
    return entry;
  }

  RouteQueueEntry goPage(NPage page,
      {Map<String, dynamic> params = const {},
      Map<String, dynamic>? extra,
      Object? groupId}) {
    final entry =
        createEntry(page, params: params, extra: extra, groupId: groupId);
    _run(entry);
    return entry;
  }

  void _until(UntilFn test) {
    RouteQueueEntry? current = _routeQueue._current;

    while (current != null) {
      if (test(current)) break;
      final pre = current._pre;
      current._removeCurrent(null, false);
      current = pre;
    }
    // _routeQueue.refresh();
    final nav = navigatorKey.currentState;
    if (current != null && nav?.mounted == true) {
      nav!.popUntil((route) => route.settings == current!._page);
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
  }

  void _pop([Object? result]) {
    final last = _routeQueue._current;
    if (last != null && last != _routeQueue._root) {
      last._removeCurrent(result);
      notifyListeners();
    }
  }

  // @override
  // RouteQueue get currentConfiguration => _routeQueue;

  @override
  GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Future<void> setNewRoutePath(configuration) {
    _routeQueue.copyWith(configuration);
    return SynchronousFuture(null);
  }
}

typedef PageBuilder<S> = Page<S> Function(RouteQueueEntry entry);

class NPageMain extends NPage {
  NPageMain({
    this.relative = true,
    super.path,
    super.pageBuilder,
    super.pages,
  }) {
    NPage._fullPathToRegExg(this);
    resolveFullPath(this, relative);
  }

  final bool relative;

  static void resolveFullPath(NPage current, bool relative) {
    for (var page in current.pages) {
      String name = page.path;
      if (relative) {
        var parentPath = current.fullPath;

        if (parentPath == '/') {
          parentPath = '';
        }
        if (!name.startsWith('/')) {
          name = '/$name';
        }

        name = '$parentPath$name';
      }

      page._fullPath = name;

      NPage._fullPathToRegExg(page);

      resolveFullPath(page, relative);
    }
  }

  NPage? getPageFromLocation(String location, [Map<String, dynamic>? params]) {
    return NPage.resolve(this, location, params ?? {});
  }
}

class RouterAction {
  RouterAction(NPage page, this.router,
      {Map<String, dynamic> params = const {},
      Map<String, dynamic>? extra,
      Object? groupId})
      : entry = router._routeDelegate
            .createEntry(page, params: params, extra: extra, groupId: groupId);

  final RouteQueueEntry entry;
  final NRouter router;

  void go() {
    router._routeDelegate._run(entry);
  }

  void goUntil(UntilFn test) {
    router._routeDelegate._until(test);
    go();
  }

  void goReplacement([Object? result, bool immediated = false]) {
    if (immediated) {
      entry._pageKey = router._routeDelegate._routeQueue._current?._pageKey;
    }
    router._routeDelegate.pop(result);
    go();
  }
}

class MaterialIgnorePage<T> extends MaterialPage<T> {
  const MaterialIgnorePage({
    required super.child,
    super.maintainState,
    super.fullscreenDialog,
    super.allowSnapshotting,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  @override
  Route<T> createRoute(BuildContext context) {
    return _MaterialIgnorePageRoute(
        page: this, allowSnapshotting: allowSnapshotting);
  }
}

class _MaterialIgnorePageRoute<T> extends PageRoute<T>
    with MaterialRouteTransitionMixin<T> {
  _MaterialIgnorePageRoute({
    required MaterialIgnorePage<T> page,
    super.allowSnapshotting,
  }) : super(settings: page);

  MaterialIgnorePage<T> get _page => settings as MaterialIgnorePage<T>;

  @override
  Widget buildContent(BuildContext context) {
    return _page.child;
  }

  @override
  bool get maintainState => _page.maintainState;

  @override
  bool get fullscreenDialog => _page.fullscreenDialog;

  @override
  String get debugLabel => '${super.debugLabel}(${_page.name})';

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final v = animation.status == AnimationStatus.forward ||
        secondaryAnimation.status == AnimationStatus.forward ||
        secondaryAnimation.status == AnimationStatus.reverse;

    child = IgnorePointer(ignoring: v, child: child);
    return super
        .buildTransitions(context, animation, secondaryAnimation, child);
  }
}

///
/// path:     `/path/to/world`
///           `/user/:id/book/:id/path`
///           `/user?id=123&bookId=456`
class NPage {
  NPage({
    this.isPrimary = false,
    this.path = '/',
    this.pages = const [],
    this.pageBuilder,
    this.groupOwner,
  });

  final bool isPrimary;
  final String path;
  final List<NPage> pages;
  final PageBuilder? pageBuilder;

  String? _fullPath;
  String get fullPath => _fullPath ?? path;

  /// 完整匹配 `^$`
  late final RegExp _pathFullExp;

  /// 从头开始匹配，不保证结尾
  late final RegExp _pathStartExp;

  final _params = <String>[];

  /// [true] or [Npage Function()]
  final Object? groupOwner;

  static int _routeId = 0;
  static int get _incGroupId => _routeId += 1;

  /// groupId token
  static final newGroupKey = Object();

  Object? resolveGroupId(Object? groupId) {
    if (identical(groupId, newGroupKey)) {
      return newGroupId;
    }
    return groupId;
  }

  String? get newGroupId {
    if (groupOwner == true) return '${fullPath}_$_incGroupId';
    if (groupOwner is NPage Function()) {
      return (groupOwner as NPage Function())().newGroupId;
    }
    return null;
  }

  /// 供外部使用
  List<String>? _cache;
  List<String> get params => _cache ??= _params.toList(growable: false);

  static void _fullPathToRegExg(NPage current) {
    final pattern = pathToRegExp(current.fullPath, current._params);
    current._pathFullExp = RegExp('$pattern\$', caseSensitive: false);
    current._pathStartExp = RegExp(pattern, caseSensitive: false);
  }

  static final _regM = RegExp(r':(\w+)');

  static String pathToRegExp(String path, List<String> parameters) {
    final allMatchs = _regM.allMatches(path);

    var start = 0;
    final buffer = StringBuffer();

    buffer.write('^');

    for (var m in allMatchs) {
      if (m.start > start) {
        buffer.write(RegExp.escape(path.substring(start, m.start)));
      }
      final name = m[1];
      buffer.write(r'(\w+)');
      parameters.add('$name');
      start = m.end;
    }

    if (start < path.length) {
      buffer.write(RegExp.escape(path.substring(start)));
    }

    return buffer.toString();
  }

  static NPage? resolve(
      NPageMain root, String location, Map<String, dynamic> params) {
    return _resolve(root, location, root.relative, params);
  }

  static NPage? _resolve(NPage current, String location, bool relative,
      Map<String, dynamic> params) {
    if (current.path == location && current._params.isEmpty) return current;

    /// 全部匹配
    final m = current._pathFullExp.firstMatch(location);
    if (m != null) {
      assert(current._params.length == m.groupCount);
      final keys = current._params;
      for (var i = 0; i < keys.length; i += 1) {
        params[keys[i]] = m[1 + i];
      }
      return current;
    }

    // 如果是路径相对的，不需要匹配结尾
    //
    // note: 绝对路径是无序的，无法通过此法优化
    if (relative && !current._pathStartExp.hasMatch(location)) {
      // assert(Log.w(
      //     '${current.fullPath} $location ${current._pathStartExp.pattern}'));
      return null;
    }

    // final String parent;

    // if (relative && current.path != '/') {
    //   parent = location.replaceFirst(current._pathStartExp, '/');

    //   // 没有修改？
    //   if (parent == location) {
    //     // 判断是否有匹配
    //     if (!current._pathStartExp.hasMatch(location)) {
    //       return null;
    //     }
    //   }
    //   assert(Log.w('$location current: ${current.path} next: $parent'));
    // } else {
    //   parent = location;
    // }

    for (var page in current.pages) {
      final r = _resolve(page, location, relative, params);
      if (r != null) return r;
    }
    return null;
  }

  @override
  String toString() {
    return '$fullPath; params:$_params';
  }
}

// class MyRouteParser extends RouteInformationParser<RouteQueue> {
//   @override
//   Future<RouteQueue> parseRouteInformationWithDependencies(
//       RouteInformation routeInformation, BuildContext context) {
//     return super
//         .parseRouteInformationWithDependencies(routeInformation, context);
//   }

//   @override
//   RouteInformation? restoreRouteInformation(RouteQueue configuration) {
//     return super.restoreRouteInformation(configuration);
//   }
// }

class NRouter implements RouterConfig<RouteQueue> {
  NRouter({required this.rootPage, String? restorationId}) {
    _routeDelegate = NRouteDelegate(
        restorationId: restorationId, rootPage: rootPage, router: this);
    final location = rootPage.path;
    _routeDelegate._init(location);
  }

  final NPageMain rootPage;

  /// 根据给出路径判断是否有效
  bool isValid(String location) {
    return rootPage.getPageFromLocation(location) != null;
  }

  RouteQueueEntry? getEntryFromId(int id) {
    final queue = _routeDelegate._routeQueue;
    RouteQueueEntry? entry;
    queue.forEach((e) {
      if (e._id == id) {
        entry = e;
        return true;
      }
      return false;
    });
    return entry;
  }

  // static NRouter of(BuildContext context) {
  //   final router = Router.maybeOf(context);
  //   final delegate = router?.routerDelegate;
  //   if (delegate is NRouteDelegate) {
  //     return delegate.router;
  //   }

  //   return (delegate as NRouteDelegate).router;
  // }

  // static NRouter? maybeOf(BuildContext context) {
  //   final router = Router.maybeOf(context);
  //   final delegate = router?.routerDelegate;
  //   if (delegate is NRouteDelegate) {
  //     return delegate.router;
  //   }
  //   return null;
  // }

  RouteQueueEntry? ofEntry(BuildContext context) {
    return RouteQueueEntry.of(context, this);
  }

  bool removeCurrent(BuildContext context, [dynamic result]) {
    final entry = ofEntry(context);
    if (entry != null) {
      entry._removeCurrent(result);
      return true;
    }
    return false;
  }

  @override
  BackButtonDispatcher? get backButtonDispatcher => null;

  @override
  RouteInformationParser<RouteQueue>? get routeInformationParser => null;

  @override
  RouteInformationProvider? get routeInformationProvider => null;

  late final NRouteDelegate _routeDelegate;

  @override
  RouterDelegate<RouteQueue> get routerDelegate => _routeDelegate;

  bool canPop() => _routeDelegate.canPop();

  /// 在 [MaterialApp].builder 中使用
  Widget build(BuildContext context) {
    return _routeDelegate.build(context);
  }

  RouteQueueEntry go(String location) {
    return _routeDelegate.go(location);
  }

  RouteQueueEntry goPage(NPage page,
      {Map<String, dynamic> params = const {},
      Map<String, dynamic>? extra,
      Object? groupId}) {
    return _routeDelegate.goPage(page,
        params: params, extra: extra, groupId: groupId);
  }

  RouteQueueEntry goUntil(String location, UntilFn until) {
    return _routeDelegate.goUntil(location, until);
  }

  void popUntil(UntilFn test) {
    _routeDelegate.popUntil(test);
  }

  void pop([Object? result]) {
    _routeDelegate.pop(result);
  }
}

class RouteQueue extends RestorableProperty<List<RouteQueueEntry>?>
    with RouteQueueMixin {
  RouteQueue(this.delegate);
  @override
  bool get isRegistered => super.isRegistered;
  final NRouteDelegate delegate;

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

  @override
  void refresh() {
    _pages = _newPages();
    notifyListeners();
  }

  @override
  List<RouteQueueEntry>? createDefaultValue() {
    return null;
  }

  @override
  List<RouteQueueEntry>? fromPrimitives(Object? data) {
    if (data == null) return null;
    assert(data is List<Map<String, dynamic>>);
    final map = data as Map<String, dynamic>;

    final list = <RouteQueueEntry>[];

    final listMap = map['list'];
    final id = map['id'];
    _id = id;

    RouteQueueEntry? last;
    for (var item in listMap as List<Map<String, dynamic>>) {
      final path = item['path'];
      final queryParams = item['data'];
      final id = item['id'];

      final current =
          RouteQueueEntry.from(path, queryParams, delegate.rootPage);

      current
        .._id = id
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
      'id': _id,
      'list': list,
    };
  }
}

mixin RouteQueueMixin {
  RouteQueueEntry? _root;
  RouteQueueEntry? _current;
  RouteQueueEntry? get current => _current;
  int _id = 0;
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

  RouteQueueEntry? _lastRemoved;

  void _remove(RouteQueueEntryMixin entry, {bool notify = true}) {
    _lastRemoved = entry as RouteQueueEntry;
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

  bool removeFirst() {
    if (_root == null) return false;
    _root!._removeCurrent();
    return true;
  }

  bool removeLast([dynamic result]) {
    if (_current == null) return false;
    _current!._removeCurrent(result);
    return true;
  }

  void _insert(RouteQueueEntry current, RouteQueueEntry entry) {
    ServicesBinding.instance.restorationManager;
    assert(entry.isAlone);
    entry._next = current._next;
    entry._pre = current;
    current._next = entry;
  }

  void refresh();
}

abstract class JsonTransform<T, F> {
  const JsonTransform();

  static final _jsonMap = <int, JsonTransform>{};
  static JsonTransform? getTransformFromId(int regId) {
    return _jsonMap[regId];
  }

  static bool register(JsonTransform transform) {
    if (_jsonMap.containsKey(transform.regId)) {
      return false;
    }
    _jsonMap[transform.regId] = transform;
    return true;
  }

  static void unRegister(JsonTransform transform) {
    _jsonMap.remove(transform.regId);
  }

  int get regId;

  T toJson(F data);
  F fromJson(T value);
}

class RouteQueueEntry with RouteQueueEntryMixin {
  RouteQueueEntry(
      {required this.path,
      required this.params,
      required this.page,
      LocalKey? pageKey,
      this.fromPage = false,
      this.groupId,
      this.queryParams = const {}})
      : _pageKey = pageKey;

  final String path;
  final NPage page;
  final bool fromPage;

  LocalKey? _pageKey;
  LocalKey? get pageKey => _pageKey;

  /// `/path/to?user=foo` => {'user': 'foo'}
  final Map<String, dynamic> queryParams;

  /// `/path/to/:user` => {'user': \<user\>}
  final Map<String, dynamic> params;
  final Object? groupId;

  static RouteQueueEntry? of(BuildContext context, NRouter router) {
    final modal = ModalRoute.of(context);
    if (modal?.settings is! Page<Object?>) {
      return null;
    }
    final page = modal!.settings as Page;
    final lastEntry = router._routeDelegate._routeQueue._lastRemoved;
    if (page == lastEntry?._page) {
      return lastEntry;
    }

    RouteQueueEntry? matchedEntry;
    router._routeDelegate._routeQueue.forEach((entry) {
      if (entry._page == page) {
        matchedEntry = entry;
        return true;
      }
      return false;
    });
    return matchedEntry;
  }

  Page? _page;
  Page? _build() {
    return _page ??= page.pageBuilder?.call(this);
  }

  factory RouteQueueEntry.from(
      String path, Map<String, dynamic> json, NPageMain nPage) {
    final params = <String, dynamic>{};

    final route = NPage.resolve(nPage, path, params);

    return RouteQueueEntry(
        path: path, queryParams: json, params: params, page: route!);
  }

  factory RouteQueueEntry.fromJson(String path, Map<String, dynamic> json,
      Map<String, dynamic> params, NPage page) {
    return RouteQueueEntry(
        path: path, queryParams: json, params: params, page: page);
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'id': _id,
      'data': queryParams,
    };
  }
}

mixin RouteQueueEntryMixin {
  int? _id;
  int? get id => _id;
  RouteQueueMixin? _parent;

  RouteQueueEntry? _pre;
  RouteQueueEntry? _next;

  bool get isAlone => _pre == null && _next == null;
  bool get attached => _parent != null;

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
  String? get entryRestorationId;
  final _id = RestorableIntN(null);
  NRouter get nRouter;

  RouteQueueEntry? _entry;
  RouteQueueEntry? get entry => _entry;

  set entry(RouteQueueEntry? value) {
    _entry = value;
    _id.value = _entry?._id;
  }

  @mustCallSuper
  void onRestoreEntry() {
    assert(_entry != null);
  }

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    _reg();
  }

  void _reg() {
    final restorationId = entryRestorationId;
    if (restorationId != null) {
      registerForRestoration(_id, restorationId);
      final id = _id.value;
      if (id != null) {
        final entry = nRouter.getEntryFromId(id);
        if (entry != null) {
          _entry = entry;
          onRestoreEntry();
        }
      }
    }
  }

  @override
  void activate() {
    super.activate();
    if (entryRestorationId != null) {
      _reg();
    }
  }

  @override
  void deactivate() {
    if (entryRestorationId != null) {
      unregisterFromRestoration(_id);
    }
    super.deactivate();
  }
}
