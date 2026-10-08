import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../change_notifier.dart';

extension ListenableWidget<T extends Listenable> on T {
  Widget wrap(Widget Function(BuildContext context, T value) builder) {
    return AnimatedBuilder(
      animation: this,
      builder: (context, _) => builder(context, this),
    );
  }

  Widget wr(Widget Function(T value) builder) {
    return AnimatedBuilder(
      animation: this,
      builder: (context, _) => builder(this),
    );
  }
}

extension ListenableWidgetValue<V extends Object> on ValueListenable<V> {
  Widget wrapValue(Widget Function(BuildContext context, V value) builder) {
    return AnimatedBuilder(
      animation: this,
      builder: (context, _) => builder(context, value),
    );
  }

  Widget wv(Widget Function(V value) builder) {
    return AnimatedBuilder(
      animation: this,
      builder: (context, _) => builder(value),
    );
  }
}

extension AutoWrapExt<D extends Object?> on ValueNotifier<D> {
  AutoValueNotifier<D> get al {
    return .new(this);
  }
}

extension AutoWrapListenableExt<D extends Object?> on ValueListenable<D> {
  AutoValueListenable<D> get al {
    return .new(this);
  }
}

extension AutoListenNotifierExt<T extends Object?> on T {
  AV<T> get al {
    return .val(this);
  }

  /// init value = this
  AV<T?> get alN {
    return .val(this);
  }

  /// init value = null
  AV<T?> get alInitNull {
    return .val(null);
  }
}

extension AutoListenNotifierAExt<T extends Object?> on AV<T> {
  AV<T> get al => this;
  AV<T?> get alN => this;
  AV<T?> get alInitNull => this;
}

extension AutoWrapLExt<D extends Object?> on ValueNotifier<List<D>> {
  AList<D> get al {
    if (this case AList<D> v) {
      return v;
    }
    return .new(value, notifierDelegate: this);
  }
}

extension AutoWrapLAExt<D extends Object?> on AV<List<D>> {
  AList<D> get al {
    if (this case AList<D> v) {
      return v;
    }
    return .new(target.value, notifierDelegate: target);
  }
}

extension AutoWrapMExt<K, V> on ValueNotifier<Map<K, V>> {
  AMap<K, V> get al {
    if (this case AMap<K, V> v) {
      return v;
    }
    return .new(value, notifierDelegate: this);
  }
}

extension AutoWrapMAExt<K, V> on AV<Map<K, V>> {
  AMap<K, V> get al {
    if (this case AMap<K, V> v) {
      return v;
    }
    return .new(target.value, notifierDelegate: target);
  }
}

extension AutoListExt<E> on List<E> {
  AList<E> get al {
    if (this case AList<E> v) {
      return v;
    }
    return .new(this);
  }
}

extension AutoMapExt<K, V> on Map<K, V> {
  AMap<K, V> get al {
    if (this case AMap<K, V> v) {
      return v;
    }
    return .new(this);
  }
}

extension CsExt on Widget Function() {
  Cs get cs {
    return .new(this);
  }
}

extension CsContextExt on Widget Function(BuildContext context) {
  Cs get cs {
    return .context(this);
  }
}

extension CsContextDyExt on Widget Function(dynamic context) {
  Cs get cs {
    return .dynamic(this);
  }
}

extension ValueNotifierSelector<D extends Listenable> on D {
  ValueListenable<T> select<T>(ShouldNotify<T, D> notifyValue, {Object? key}) {
    return ChangeNotifierSelector(parent: this, notifyValue: notifyValue);
  }
}
