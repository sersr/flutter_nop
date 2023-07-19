import '../dependence/dependences_mixin.dart';
import 'nop_dependencies.dart';
import '../dependence/nop_listener.dart';

class NopListenerDefault extends NopListener {
  NopListenerDefault(super.data, super.group, super.t);
  @override
  bool get isGlobal => contains(GetTypePointers.globalDependences);

  @override
  NopListener getListener(Type t, {Object? group, int? position = 0}) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());

    return getTypeDefault(t, this, group, position);
  }

  @override
  NopListener? findType(Type t, {Object? group}) {
    return getTypeOrNullDefault(t, this, group);
  }

  static NopListener getTypeDefault(
      Type t, NopListener owner, Object? group, int? position) {
    assert(() {
      position = position == null ? null : position! + 1;
      return true;
    }());
    final dependence = owner.getDependence() as GetTypePointers?;
    final listener = Node.defaultGetNopListener(GetTypePointers.getAlias(t),
        dependence, GetTypePointers.globalDependences, group, position);
    assert(listener.isGlobal || listener.contains(dependence));

    return listener;
  }

  static NopListener? getTypeOrNullDefault(
      Type t, NopListener owner, Object? group) {
    final dependence = owner.getDependence() as GetTypePointers?;

    final listener = Node.defaultFindNopListener(GetTypePointers.getAlias(t),
        dependence, GetTypePointers.globalDependences, group);

    assert(
        listener == null || listener.isGlobal || listener.contains(dependence));

    return listener;
  }
}
