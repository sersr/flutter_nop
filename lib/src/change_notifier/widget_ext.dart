import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../change_notifier.dart';

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

extension ChangeAutoWrapExt<D> on ValueNotifier<D> {
  ValueNotifier<D> get al {
    return AutoListenWrapper(this);
  }
}

extension ChangeAutoWrapListenableExt<D> on ValueListenable<D> {
  ValueListenable<D> get al {
    return AutoListenValueListenable(this);
  }
}

extension AutoListenNotifierExt<T> on T {
  ValueNotifier<T> get al {
    return AutoListenNotifier(this);
  }

  /// init value = this
  ValueNotifier<T?> get alN {
    return AutoListenNotifier(this);
  }

  /// init value = null
  ValueNotifier<T?> get alInitNull {
    return AutoListenNotifier(null);
  }
}

extension ChangeList<E> on List<E> {
  AutoListenList<E> get al {
    return AutoListenList(this);
  }
}

extension AutoMap<K, V> on Map<K, V> {
  AutoListenMap<K, V> get al {
    return AutoListenMap(this);
  }
}

extension CsExt on Widget Function() {
  Cs get cs {
    return Cs(this);
  }
}

extension ValueNotifierSelector<D extends Listenable> on D {
  ValueListenable<T> select<T>(ShouldNotify<T, D> notifyValue, {Object? key}) {
    return ChangeNotifierSelector(parent: this, notifyValue: notifyValue);
  }
}

extension ChangeAutoWrapperSelectorAl<T, D extends ChangeNotifier>
    on ChangeNotifierSelector<T, D> {
  ValueListenable<T> get al {
    return AutoListenValueListenable(this);
  }
}
