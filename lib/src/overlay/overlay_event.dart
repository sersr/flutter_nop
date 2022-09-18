import 'dart:async';

import 'package:nop/event_queue.dart';

import 'nav_overlay_mixin.dart';

mixin OverlayEvent on OverlayMixin {
  Completer<void>? _completer;

  @pragma('vm:prefer-inline')
  void _complete() {
    if (_completer?.isCompleted == false) {
      _completer?.complete();
      _completer = null;
    }
  }

  Future<void> get fut {
    _completer ??= Completer();
    return _completer!.future;
  }

  @override
  void onCompleted() {
    super.onCompleted();
    _completedShow();
  }

  @override
  void onDismissed() {
    super.onDismissed();
    _completedHide();
  }

  @pragma('vm:prefer-inline')
  void _completedShow() {
    if (_show) {
      _complete();
      _show = false;
    }
  }

  @pragma('vm:prefer-inline')
  void _completedHide() {
    if (_hide) {
      _complete();
      _hide = false;
    }
  }

  bool _show = false;
  @override
  FutureOr<bool> showAsync() {
    if (showing) return true;
    return super.showAsync().then((value) {
      if (showing) {
        _completedHide();
        _show = true;
        return fut.then((_) => value);
      }
      return value;
    });
  }

  bool _hide = false;

  @override
  FutureOr<bool> hideAsync() {
    if (hiding) return true;
    return super.hideAsync().then((value) {
      if (hiding) {
        _completedShow();
        _hide = true;
        return fut.then((_) => value);
      }

      return value;
    });
  }

  @override
  void onRemoveOverlayEntry() {
    super.onRemoveOverlayEntry();
    assert(!_show || !_hide);
    _completedShow();
    _completedHide();
  }
}
