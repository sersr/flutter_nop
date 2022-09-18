import 'dependences_mixin.dart';
import 'nop_listener.dart';

class NopDependencies with GetTypePointers {
  NopDependencies({this.debugName});
  final String? debugName;
  @override
  NopDependencies? parent;
  @override
  NopDependencies? child;

  NopDependencies? get lastChild {
    NopDependencies? last = child;
    while (last != null) {
      final child = last.child;
      if (child == null) break;
      last = child;
    }

    return last;
  }

  bool get isFirst => parent == null;
  bool get isLast => child == null;

  NopDependencies? get firstParent {
    NopDependencies? first = parent;
    while (first != null) {
      final parent = first.parent;
      if (parent == null) break;
      first = parent;
    }
    return first;
  }

  NopDependencies get lastChildOrSelf {
    return lastChild ?? this;
  }

  NopDependencies get firstParentOrSelf {
    return firstParent ?? this;
  }

  void updateChild(NopDependencies newChild) {
    assert(child == null || child!.parent == this);
    newChild.child = child?.child;
    newChild.child?.parent = newChild;
    child?._remove();
    newChild.parent = this;
    child = newChild;
  }

  void insertChild(NopDependencies newChild) {
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

  @override
  void addListener(Type t, NopListener listener) {
    super.addListener(t, listener);
    listener.onDependenceAdd(this);
  }

  void _remove() {
    parent = null;
    child = null;
    for (var item in listeners) {
      item.onDependenceRemove(this);
    }
  }

  @override
  String toString() {
    return 'NopDependences#${debugName ?? hashCode}';
  }
}
