import '../dependence/dependences_mixin.dart';
import 'nop_dependencies.dart';
import '../dependence/nop_listener.dart';

class NopListenerDefault extends NopListener {
  NopListenerDefault(super.data, super.group, super.t);
  @override
  bool get isGlobal => contains(GetTypePointers.globalDependences);

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
    final dependence = getDependence() as GetTypePointers?;
    final data = Node.defaultGetData(GetTypePointers.getAlias(T), dependence,
        GetTypePointers.globalDependences, group, position);
    assert(NopLifeCycle.checkIsNopLisenter(data) != null);

    return data;
  }

  @override
  T? find<T>({Object? group}) {
    final dependence = getDependence() as GetTypePointers?;

    final data = Node.defaultFindData(GetTypePointers.getAlias(T), dependence,
        GetTypePointers.globalDependences, group);
    assert(NopLifeCycle.checkIsNopLisenter(data) != null);

    return data;
  }
}
