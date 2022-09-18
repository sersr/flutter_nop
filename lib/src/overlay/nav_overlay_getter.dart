import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nop/event_queue.dart';

import '../../nav.dart';
import 'nav_overlay_mixin.dart';
import 'overlay_observer.dart';
import 'state_getter.dart';

abstract class OverlayDelegate with StateAsyncGetter<OverlayState> {
  OverlayObserver? _overlayObserver;
  set overlay(OverlayObserver? overlayObserver) {
    _overlayObserver = overlayObserver;
  }

  @override
  OverlayState? getState() {
    final getter = _overlayObserver?.overlayGetter;
    if (getter != null) return getter();

    return Nav.getOverlay();
  }

  Future<void> get future;
  bool get active;
  bool get done;
  bool get closed;
  bool get isAnimating;
  bool get showStatus;

  FutureOr<bool> show();
  FutureOr<bool> hide();
  void toggle();
  void showToggle();
  void hideToggle();

  void close();
}

class OverlayMixinDelegate<T extends OverlayMixin> extends OverlayDelegate {
  OverlayMixinDelegate(this._controller, this.duration,
      {this.delayDuration = Duration.zero});
  @override
  Object get key => _controller;
  final T _controller;

  final Duration duration;
  final Duration delayDuration;

  @override
  Future<void> get future => _controller.future;
  @override
  bool get active => _controller.active;
  @override
  bool get done => _controller.inited;

  @override
  bool get closed => _controller.closed;
  @override
  bool get isAnimating => done && _controller.isAnimating;

  @override
  bool get showStatus => done && _controller.showStatus;

  @override
  FutureOr<void> initRun(OverlayState state) async {
    if (active) return;

    assert(state.mounted);
    _controller.init(overlayState: state, duration: duration);
    if (delayDuration != Duration.zero) {
      await release(delayDuration);
    }
    if (closed) return;

    _controller.setObverser(_overlayObserver);
  }

  @override
  Future<bool> show() async {
    if (closed) return false;
    if (done) return _controller.showAsync();
    return init().then((_) => _controller.showAsync());
  }

  @override
  Future<bool> hide() async {
    if (closed) return false;
    if (done) return _controller.hideAsync();
    return init().then((_) => _controller.hideAsync());
  }

  @override
  void toggle() {
    if (showStatus) {
      hide();
    } else {
      show();
    }
  }

  @override
  void showToggle() {
    if (showStatus) return;
    show();
  }

  @override
  void hideToggle() {
    if (!showStatus) return;
    hide();
  }

  @override
  void close() {
    _controller.close();
  }
}
