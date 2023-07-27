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

    final router = NRouter.of(context);
    return _GreenState.getLocal<T>(context, group, router, position) ??
        router.grass<T>(
            context: context,
            group: group,
            useEntryGroup: useEntryGroup,
            position: position);
  }

  static T? find<T>(BuildContext context,
      {Object? group, bool useEntryGroup = true}) {
    final router = NRouter.of(context);

    return _GreenState.getLocal<T>(context, group, router) ??
        router.find<T>(
            context: context, group: group, useEntryGroup: useEntryGroup);
  }

  @override
  State<Green<C>> createState() => _GreenState<C>();
}

class _GreenState<C> extends State<Green<C>> {
  static T? getLocal<T>(BuildContext context, Object? group, NRouter router,
      [int? position]) {
    if (group != null) return null;

    var state = context.findAncestorStateOfType<_GreenState>();

    while (state != null) {
      if (state.isSameType(T, router)) {
        return state._getLocal(position);
      }
      final context = state.context;
      state = context.findAncestorStateOfType<_GreenState>();
    }
    return null;
  }

  bool isSameType(Type t, NRouter router) {
    return router.getAlias(C) == router.getAlias(t);
  }

  C? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  bool _init = false;

  dynamic _getLocal(int? position) {
    if (_init) return _local?.data;
    _init = true;

    // init
    if (_value != null) {
      _initData(_value, position);
    } else if (widget.create != null) {
      final data = widget.create!(context);
      assert(data != null);
      _initData(data, position);
    }
    return _local?.data;
  }

  NopListener? _local;

  bool _shouldClean = false;
  void _initData(dynamic data, int? position) {
    assert(() {
      position = position == null ? null : position! + 3;
      return true;
    }());
    var listener = NopLifecycle.checkIsNopLisenter(data);
    assert(listener == null || listener is RouteListener);

    _shouldClean = listener == null;
    if (listener == null) {
      final router = NRouter.of(context);
      final dependence = router.currentDependence;
      listener = RouteListener(router, data, null, C);
      listener.scope = NopShareScope.unique;
      listener.initWithFirstDependence(dependence ?? router.globalDependence,
          position: position);
    }

    _local = listener;
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
    return widget.child;
  }
}
