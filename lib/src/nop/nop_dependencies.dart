import 'dependences_mixin.dart';

class NopDependence with GetTypePointers {
  NopDependence({this.debugName});
  final String? debugName;
  @override
  NopDependence? parent;
  @override
  NopDependence? child;

  bool get isAlone => parent == null && child == null;

  NopDependence? get lastChild {
    NopDependence? last = child;
    while (last != null) {
      final child = last.child;
      if (child == null) break;
      last = child;
    }

    return last;
  }

  bool get isFirst => parent == null;
  bool get isLast => child == null;

  NopDependence? get firstParent {
    NopDependence? first = parent;
    while (first != null) {
      final parent = first.parent;
      if (parent == null) break;
      first = parent;
    }
    return first;
  }

  NopDependence get lastChildOrSelf {
    return lastChild ?? this;
  }

  NopDependence get firstParentOrSelf {
    return firstParent ?? this;
  }

  void updateChild(NopDependence newChild) {
    assert(child == null || child!.parent == this);
    newChild.child = child?.child;
    newChild.child?.parent = newChild;
    child?._remove();
    newChild.parent = this;
    child = newChild;
  }

  void insertChild(NopDependence newChild) {
    newChild.child = child;
    child?.parent = newChild;
    newChild.parent = this;
    child = newChild;
  }

  void removeCurrent() {
    parent?.child = child;
    child?.parent = parent;
    _remove();
  }

  bool _poped = false;
  @override
  bool get popped => _poped;

  void _remove() {
    parent = null;
    child = null;
    _poped = true;
    visitListener((_, item) {
      item.onPop();
      item.onRemoveDependence(this);
    });
  }

  @override
  String toString() {
    return 'NopDependences#${debugName ?? hashCode}';
  }
}
