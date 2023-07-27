import '../dependence/dependences_mixin.dart';
import 'nop_dependencies.dart';
import '../dependence/nop_listener.dart';

class NopListenerDefault extends NopListener {
  NopListenerDefault(super.data, super.group, super.t);
  @override
  bool get isGlobal => contains(NopDependence.globalDependences);

  @override
  T get<T>({Object? group, int? position = 0}) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());

    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());
    final dependence = getDependence() as NopDependence?;
    final data = Node.defaultGetData<T>(NopDependence.getAlias(T), dependence,
        NopDependence.globalDependences, group, position);
    assert(NopLifecycle.checkIsNopLisenter(data) != null);

    return data;
  }

  @override
  T? find<T>({Object? group}) {
    final dependence = getDependence() as NopDependence?;

    final data = Node.defaultFindData<T>(NopDependence.getAlias(T), dependence,
        NopDependence.globalDependences, group);
    assert(NopLifecycle.checkIsNopLisenter(data) != null);

    return data;
  }
}
