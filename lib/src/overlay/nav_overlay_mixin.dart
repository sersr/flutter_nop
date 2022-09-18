import 'dart:async';

import 'package:flutter/material.dart';

import 'overlay_observer.dart';

/// 必须先调用[init]初始化
///
/// 提供动画基础
mixin OverlayMixin {
  OverlayState? _overlayState;

  OverlayState get overlay => _overlayState!;
  Future<void> get future => _completer.future;

  late final _completer = Completer<void>();
  void _complete() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  AnimationController get controller => _controller!;
  AnimationController? _controller;

  double get value => controller.value;
  set value(double v) {
    controller.value = v.clamp(0.0, 1.0);
  }

  bool get isAnimating => controller.isAnimating;
  bool get isCompleted => controller.isCompleted;
  bool get isDismissed => controller.isDismissed;

  bool get showing =>
      controller.status == AnimationStatus.forward && isAnimating;

  bool get hiding =>
      controller.status == AnimationStatus.reverse && isAnimating;

  bool get showStatus =>
      controller.status == AnimationStatus.completed ||
      controller.status == AnimationStatus.forward;

  bool get inited => _inited;

  bool _inited = false;
  void init({required OverlayState overlayState, required Duration duration}) {
    if (closed) return;
    if (!mounted) _inited = false;
    if (_inited) return;
    _overlayState = overlayState;
    if (mounted) {
      _inited = true;
      _controller?.dispose();
      _controller =
          AnimationController(vsync: overlayState, duration: duration);
      controller.addStatusListener(listenStatus);
      onCreateOverlayEntry();
    }
  }

  void listenStatus(AnimationStatus status) {
    if (closed) return;
    switch (controller.status) {
      case AnimationStatus.completed:
        onCompleted();
        break;
      case AnimationStatus.dismissed:
        onDismissed();
        break;
      default:
    }
  }

  @protected
  @mustCallSuper
  void onCompleted() {
    onShowEnd?.call();
    _observer?.show(this);
  }

  @protected
  @mustCallSuper
  void onDismissed() {
    onHideEnd?.call();
    _observer?.hide(this);
  }

  VoidCallback? get onHideEnd => null;
  VoidCallback? get onShowEnd => null;

  OverlayObserver? _observer;

  void setObverser(OverlayObserver? observer) {
    if (observer != null) observer.insert(this);

    _observer = observer;
  }

  bool get active => _inited && !_closed;

  FutureOr<bool> showAsync() => show();
  bool show() {
    if (!active || !mounted) return false;
    _hided = false;
    controller.forward();

    return true;
  }

  bool get mounted => _overlayState?.mounted ?? false;

  bool _hided = true;
  bool get hided => _hided;

  FutureOr<bool> hideAsync() => hide();
  bool hide() {
    if (!active || !mounted) return false;
    _hided = true;
    if (!shouldHide) return false;

    controller.reverse();

    return true;
  }

  bool shouldHide = true;

  bool _closed = false;
  bool get closed => _closed;

  /// 如果被调用了，对象将不可用
  void close() {
    if (!active) return;
    _closed = true;
    _observer?.close(this);
    _complete();
    onRemoveOverlayEntry();
    _controller?.dispose();
    _controller = null;
  }

  @protected
  @mustCallSuper
  void onCreateOverlayEntry() {}
  @protected
  @mustCallSuper
  void onRemoveOverlayEntry() {}
}
