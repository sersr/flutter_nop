import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

extension ListenableWidget<T extends Listenable> on T {
  Widget wrap(Widget Function(BuildContext context, T value) builder) {
    return AnimatedBuilder(
        animation: this, builder: (context, _) => builder(context, this));
  }

  Widget wr(Widget Function(T value) builder) {
    return AnimatedBuilder(
        animation: this, builder: (context, _) => builder(this));
  }
}

extension ListenableWidgetValue<V extends Object> on ValueListenable<V> {
  Widget wrapValue(Widget Function(BuildContext context, V value) builder) {
    return AnimatedBuilder(
        animation: this, builder: (context, _) => builder(context, value));
  }

  Widget wv(Widget Function(V value) builder) {
    return AnimatedBuilder(
        animation: this, builder: (context, _) => builder(value));
  }
}
