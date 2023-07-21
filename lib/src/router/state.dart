part of 'router.dart';

extension Grass on BuildContext {
  /// [group] shared group
  T grass<T>({
    Object? group,
    bool global = false,
    bool useEntryGroup = true,
    int? position = 1,
  }) {
    return Green.of(
      this,
      group: group,
      useEntryGroup: useEntryGroup,
      global: global,
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
    Key? key,
    required this.child,
    this.create,
  })  : value = null,
        super(key: key);

  const Green.value({
    Key? key,
    this.value,
    required this.child,
  })  : create = null,
        super(key: key);

  final Widget child;
  final C Function(BuildContext context)? create;
  final C? value;

  static T of<T>(
    BuildContext context, {
    Object? group,
    bool useEntryGroup = true,
    bool global = false,
    int? position = 0,
  }) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());

    final nop = context.dependOnInheritedWidgetOfExactType<_GreenScope>();
    if (nop != null) {
      return nop.state.getTypeListener(group, global, position: position);
    }

    return NRouter.of(context).grass<T>(
        context: context,
        group: group,
        useEntryGroup: useEntryGroup,
        global: global,
        position: position);
  }

  static T? find<T>(BuildContext context,
      {Object? group, bool useEntryGroup = true}) {
    if (!useEntryGroup) {
      final nop = context.dependOnInheritedWidgetOfExactType<_GreenScope>();
      if (nop != null) {
        return nop.state.findTypeListener<T>(group);
      }
    }

    return NRouter.of(context)
        .find<T>(context: context, group: group, useEntryGroup: useEntryGroup);
  }

  @override
  State<Green<C>> createState() => _GreenState<C>();
}

class _GreenState<C> extends State<Green<C>> {
  T? getLocal<T>(int? position) {
    if (_local == null && _init) return null;
    final router = NRouter.of(context);
    final lt = router.getAlias(T);
    final rt = router.getAlias(C);
    if (lt == rt) {
      assert(() {
        position = position == null ? null : position! + 1;
        return true;
      }());
      _initOnce(position);
      return _local?.data;
    }

    return null;
  }

  T getTypeListener<T>(Object? group, bool global, {int? position}) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());
    if (group == null) {
      final data = getLocal(position);
      if (data != null) {
        return data;
      }
    }

    return NRouter.of(context).grass(
        context: context,
        group: group,
        useEntryGroup: true,
        global: global,
        position: position);
  }

  T? findTypeListener<T>(Object? group) {
    if (group == null && _local != null) {
      final data = getLocal(null);
      if (data != null) {
        return data;
      }
    }

    return NRouter.of(context)
        .find(context: context, group: group, useEntryGroup: true);
  }

  NopListener? _local;

  bool _shouldClean = false;
  void _initData(dynamic data, int? position) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());
    var listener = NopLifeCycle.checkIsNopLisenter(data);
    assert(listener == null ||
        listener is RouteListener ||
        listener is RouteLocalListener);

    _shouldClean = listener == null;
    if (listener == null) {
      final dependence = RouteQueueEntry.of(context);
      listener = dependence?.nopListenerCreater(data, null, C) ??
          RouteLocalListener(data, null, C, NRouter.of(context));
      listener.scope = NopShareScope.unique;
      listener.initWithFirstDependence(
          dependence ?? NRouter.of(context).globalDependence,
          position: position);
    }

    _local = listener;
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
    if (widget.value != null) {
      _initData(widget.value, position);
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
