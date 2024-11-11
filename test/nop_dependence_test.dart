import 'dart:async';

import 'package:flutter_nop/flutter_nop.dart';
import 'package:flutter_nop/src/nop/nop_listener.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nop/nop.dart';

void main() {
  test('nop dependence insert', () {
    Zone.root.run(() {
      final first = create('first');
      final second = create('second');
      final third = create('third');
      first.insertChild(second);
      second.insertChild(third);
      forEach(first);
      final four = create('four');
      first.insertChild(four);
      forEach(first);

      second.completed();
      forEach(first);
    });
  });
}

void forEach(RouteNode root) {
  RouteNode? child = root;
  Log.i('_'.padLeft(50, '_'));
  while (child != null) {
    Log.i('$child parent: ${child.parent}');
    child = child.child;
  }
}

TestNode create(String name) {
  return TestNode(debugName: name);
}

class TestNode extends RouteNode {
  TestNode({required this.debugName});
  final String debugName;
  @override
  build(Type t) {}

  @override
  NopListener nopListenerCreater() {
    return NopListenerDefault();
  }

  @override
  String toString() {
    return 'TestNode: $debugName';
  }
}
