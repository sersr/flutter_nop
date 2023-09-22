import '../dependence/dependence_mixin.dart';
import 'nop_dependence.dart';
import '../dependence/nop_listener.dart';

class NopListenerDefault extends NopListener {
  NopListenerDefault();

  @override
  bool get isGlobal => contains(NopDependence.globalDependence);

  @override
  T get<T>({Object? group, int? position = 0}) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());

    final dependence = getDependence();
    final data = Node.defaultGetData<T>(NopDependence.getAlias(T), dependence,
        NopDependence.globalDependence, group, position);
    assert(NopLifecycle.checkIsNopLisenter(data) != null);

    return data;
  }

  @override
  T? find<T>({Object? group}) {
    final dependence = getDependence();

    final data = Node.defaultFindData<T>(NopDependence.getAlias(T), dependence,
        NopDependence.globalDependence, group);
    assert(data == null || NopLifecycle.checkIsNopLisenter(data) != null);

    return data;
  }
}
