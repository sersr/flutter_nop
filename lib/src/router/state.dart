part of 'router.dart';

extension Grass on BuildContext {
  /// [group] shared group
  T grass<T>({
    Object? group,
    bool useEntryGroup = true,
    int? position = 1,
  }) {
    return Green.of(
      this,
      group: group,
      useEntryGroup: useEntryGroup,
      position: position,
    );
  }

  Object? get groupId {
    return RouteQueueEntry.of(this)?.groupId;
  }

  T? findGrass<T>({Object? group, bool useEntryGroup = true}) {
    return Green.find(this, group: group, useEntryGroup: useEntryGroup);
  }
}

/// state manager
class Green<C> extends StatefulWidget {
  const Green({
    super.key,
    this.create,
    required this.child,
  }) : value = null;

  const Green.value({
    super.key,
    this.value,
    required this.child,
  }) : create = null;

  final Widget child;
  final C Function(BuildContext context)? create;
  final C? value;

  static T of<T>(
    BuildContext context, {
    Object? group,
    bool useEntryGroup = true,
    int? position = 0,
  }) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());

    final nop = context.dependOnInheritedWidgetOfExactType<_GreenScope>();
    final router = NRouter.of(context);
    return nop?.state.getLocal<T>(group, router, position: position) ??
        router.grass<T>(
            context: context,
            group: group,
            useEntryGroup: useEntryGroup,
            position: position);
  }

  static T? find<T>(BuildContext context,
      {Object? group, bool useEntryGroup = true}) {
    final nop = context.dependOnInheritedWidgetOfExactType<_GreenScope>();
    final router = NRouter.of(context);

    return nop?.state.getLocal<T>(group, router) ??
        router.find<T>(
            context: context, group: group, useEntryGroup: useEntryGroup);
  }

  @override
  State<Green<C>> createState() => _GreenState<C>();
}

class _GreenState<C> extends State<Green<C>> {
  T? getLocal<T>(Object? group, NRouter router, {int? position}) {
    if (group != null) return null;
    if (_local == null && _init) return null;

    if (router.getAlias(T) == router.getAlias(C)) {
      assert(() {
        position = position == null ? null : position! + 1;
        return true;
      }());
      _initOnce(position);
      return _local?.data;
    }

    return null;
  }

  NopListener? _local;

  bool _shouldClean = false;
  void _initData(dynamic data, int? position) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());
    var listener = NopLifeCycle.checkIsNopLisenter(data);
    assert(listener == null || listener is RouteListener);

    _shouldClean = listener == null;
    if (listener == null) {
      final router = NRouter.of(context);
      final dependence = router.currentDependence;
      listener = dependence?.nopListenerCreater(data, null, C) ??
          RouteListener(router, data, null, C);
      listener.scope = NopShareScope.unique;
      listener.initWithFirstDependence(dependence ?? router.globalDependence,
          position: position);
    }

    _local = listener;
  }

  C? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  bool _init = false;
  void _initOnce(int? position) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());
    if (_init) return;
    _init = true;

    // init
    if (_value != null) {
      _initData(_value, position);
    } else if (widget.create != null) {
      final data = widget.create!(context);
      assert(data != null);

      _initData(data, position);
    }
  }

  @override
  void dispose() {
    if (_shouldClean && _local != null) {
      final listener = _local!;
      _local = null;
      listener.uniqueDispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _GreenScope(state: this, child: widget.child);
  }
}

class _GreenScope extends InheritedWidget {
  const _GreenScope({
    Key? key,
    required Widget child,
    required this.state,
  }) : super(key: key, child: child);
  final _GreenState state;

  @override
  bool updateShouldNotify(covariant _GreenScope oldWidget) {
    return state != oldWidget.state;
  }
}
