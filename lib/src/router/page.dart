import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nop/nop.dart';

import 'delegate.dart';
import 'route_queue.dart';

typedef PageBuilder<S> = Page<S> Function(RouteQueueEntry entry);
typedef RedirectBuilder = RouteQueueEntry Function(RouteQueueEntry entry);

/// ```dart
/// class JsonData {
///
///   // json: call `toJson`
///   String toJson() {
///     return '';
///   }
/// }
/// ```
var jsonDecodeCustom = jsonDecode;

typedef ToJsonFn = (dynamic Function(dynamic data)? toJson,);

abstract interface class NRouterJsonTransfrom {
  dynamic toJson();

  static final _toJsonFns = <Type, ToJsonFn>{};

  static ToJsonFn? get<T>([Type? t]) {
    return _toJsonFns[t ?? T];
  }

  static void putToJsonFn<T>(ToJsonFn fn, [Type? t]) {
    _toJsonFns[t ?? T] = fn;
  }

  static void removeToJsonFn<T>([Type? t]) {
    _toJsonFns.remove(t ?? T);
  }

  static bool shouldTransfrom(dynamic data) {
    return switch (data) {
      NRouterJsonTransfrom || Enum _ => true,
      Map map => map.values.any(shouldTransfrom),
      List list => list.any(shouldTransfrom),
      _ => _toJsonFns.containsKey(data.runtimeType),
    };
  }

  static dynamic encode(dynamic data) {
    switch (data) {
      case NRouterJsonTransfrom value:
        return value.toJson();
      case Enum value:
        return value.index;
      case Map map:
        return encodeMap(map);
      case List list:
        return encodeList(list);
      default:
        final fn = get(data.runtimeType);
        if (fn != null) {
          data = fn.$1?.call(data) ?? data.toJson();
        }
        return data;
    }
  }

  static Map<T, dynamic> encodeMap<T>(Map<T, dynamic> data) {
    // if (!shouldTransfrom(data)) return data;
    return data.map((key, value) => MapEntry(key, encode(value)));
  }

  static List<dynamic> encodeList(List<dynamic> data) {
    // if (!shouldTransfrom(data)) return data;
    return data.map(encode).toList();
  }
}

class NPageMain extends NPage {
  NPageMain({
    this.relative = true,
    super.path,
    super.pageBuilder,
    super.pages,
    super.redirectBuilder,
  }) {
    NPage._fullPathToRegExg(this);
    _index = 0;
    resolveFullPath(this, relative, 1);
  }

  final bool relative;

  static void resolveFullPath(NPage current, bool relative, int index) {
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
      page._index = index;
      index += 1;

      NPage._fullPathToRegExg(page);

      resolveFullPath(page, relative, index);
    }
  }

  NPage? getPageFromLocation(String location,
      [Map<String, dynamic>? params, Map<String, dynamic>? keys]) {
    return NPage.resolve(this, location, params ?? {}, keys);
  }
}

mixin RouteQueueEntryPage<T> on Page<T> {
  RouteQueueEntry get entry;
}

class MaterialIgnorePage<T> extends MaterialPage<T> with RouteQueueEntryPage {
  const MaterialIgnorePage({
    required this.entry,
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
  final RouteQueueEntry entry;

  @override
  Route<T> createRoute(BuildContext context) {
    return _MaterialIgnorePageRoute(
        page: this, allowSnapshotting: allowSnapshotting);
  }

  static Widget wrap(RouteQueueEntry entry, Widget child) {
    return Builder(builder: (context) {
      final bucket = RouteRestorable.maybeOf(context)?.bucket;

      return UnmanagedRestorationScope(
        bucket: bucket,
        child: RestorationScope(
          restorationId: entry.restorationId,
          child: child,
        ),
      );
    });
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
    if (_page.entry.restorationId == null) {
      return _page.child;
    }
    final bucket = RouteRestorable.maybeOf(context)?.bucket;

    return UnmanagedRestorationScope(
      bucket: bucket,
      child: RestorationScope(
        restorationId: _page.entry.restorationId,
        child: _page.child,
      ),
    );
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
    this.redirectBuilder,
  });

  final bool isPrimary;
  final String path;
  final List<NPage> pages;
  final PageBuilder? pageBuilder;

  final RedirectBuilder? redirectBuilder;

  RouteQueueEntry redirect(RouteQueueEntry entry, {RedirectBuilder? builder}) {
    if (redirectBuilder == null) return builder?.call(entry) ?? entry;
    return redirectBuilder!(entry);
  }

  String? _fullPath;
  String get fullPath => _fullPath ?? path;
  late int _index;
  int get index => _index;

  NPage? getNPageFromIndex(int index) {
    if (_index == index) return this;
    for (var page in pages) {
      final nPage = page.getNPageFromIndex(index);
      if (nPage != null) return nPage;
    }
    return null;
  }

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
    final pattern = pathToRegExp(current, current._params);
    current._pathFullExp = RegExp('$pattern\$', caseSensitive: false);
    current._pathStartExp = RegExp(pattern, caseSensitive: false);
  }

  late final List<Match> _matchs;
  static final _regM = RegExp(r':(\w+)');

  static String pathToRegExp(NPage page, List<String> parameters) {
    final path = page.fullPath;
    final allMatchs = _regM.allMatches(path).toList();
    page._matchs = allMatchs;

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

  String getUrl(Map<dynamic, dynamic> params, Map<dynamic, dynamic> extra) {
    final path = fullPath;
    final allMatchs = _matchs;
    var start = 0;
    final buffer = StringBuffer();

    int i = 0;
    for (var m in allMatchs) {
      if (m.start > start) {
        buffer.write(path.substring(start, m.start));
      }

      final data = NRouterJsonTransfrom.encode(params[i]);

      buffer.write(data);
      start = m.end;
      i += 1;
    }

    if (start < path.length) {
      buffer.write(path.substring(start));
    }

    if (extra.isNotEmpty) {
      buffer.write('?');
      bool isFirst = true;
      for (var MapEntry(key: key, value: value) in extra.entries) {
        if (!isFirst) {
          buffer.write('&');
        } else {
          isFirst = false;
        }

        final data = NRouterJsonTransfrom.encode(value);

        buffer.write('$key=$data');
      }
    }

    return buffer.toString();
  }

  static NPage? resolve(NPageMain root, String location,
      Map<String, dynamic> params, Map<String, dynamic>? keys) {
    return _resolve(root, location, root.relative, params, keys);
  }

  static NPage? _resolve(NPage current, String location, bool relative,
      Map<String, dynamic> params, Map<String, dynamic>? keys) {
    final hasKeys = keys != null && keys.isNotEmpty;
    final pathEq = current.fullPath == location;

    if (pathEq && current._params.isEmpty) {
      return current;
    }

    /// 全部匹配
    var m = current._pathFullExp.firstMatch(location);
    if (m == null && hasKeys) {
      if (pathEq) {
        // assert(current._params.every((e) => keys.containsKey(e)));
        params.addAll(keys);
        return current;
      }

      final keysW = '/_' * current._params.length;
      final path = '$location$keysW';
      assert(Log.w('...$path ${current._pathFullExp.pattern}'));

      if (current._pathFullExp.hasMatch(path)) {
        // assert(current._params.every((e) => keys.containsKey(e)));
        params.addAll(keys);
        return current;
      }
    }
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
      return null;
    }

    for (var page in current.pages) {
      final r = _resolve(page, location, relative, params, keys);
      if (r != null) return r;
    }
    return null;
  }

  @override
  String toString() {
    return '$fullPath; params:$_params';
  }
}
