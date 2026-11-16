import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

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

extension AutoListenableAlExt<T extends Listenable> on T {
  T get alisten {
    autoListen();
    return this;
  }

  T get al => alisten;
  T get alN => alisten;
  T get alInitNull => alisten;
}

extension AutoListenNotifierAExt<T extends Object?> on AV<T> {
  AV<T> get al => this;
  AV<T?> get alN => this;
  AV<T?> get alInitNull => this;
}

extension AutoWrapLExt<D extends Object?> on ValueNotifier<List<D>> {
  AList<D> get aList {
    return .new(this);
  }
}

extension AutoWrapLAExt<D extends Object?> on AV<List<D>> {
  AList<D> get aList {
    return .new(target);
  }
}

extension AutoWrapMExt<K, V> on ValueNotifier<Map<K, V>> {
  AMap<K, V> get aMap {
    return .new(this);
  }
}

extension AutoWrapMAExt<K, V> on AV<Map<K, V>> {
  AMap<K, V> get aMap {
    return .new(target);
  }
}

extension AutoListExt<E> on List<E> {
  AList<E> get aList {
    return .val(this);
  }
}

extension AutoMapExt<K, V> on Map<K, V> {
  AMap<K, V> get aMap {
    return .val(this);
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

/// ```dart
///  final valid = false.al;
///  final searchText = ''.al;
///
/// final value = () {
///   final isValid = valid.value;
///   final text = searchText.value;
///   if (isValid) {
///     return '';
///   }
///
///   return text;
/// }.al;
///```
extension AlScopeExt<T> on T Function() {
  AlScope<T> get al {
    return .new(this);
  }

  AlScope<T> mount(AlScopeManager manager) {
    return .new(this)..manager = manager;
  }
}

typedef ShouldNotify<T, D extends Listenable> = T Function(D parent);
