import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nop/event_queue.dart';
import 'package:nop/utils.dart';

import 'nav_overlay_mixin.dart';
import 'overlay_event.dart';
import 'overlay_pannel.dart';

typedef WidgetGestureBuilder<T> = Widget Function(
    BuildContext context, UserGestureController<T> controller);

class UserGestureController<T> {
  UserGestureController({required this.owner, ValueNotifier<bool>? userGesture})
      : userGesture = userGesture ?? ValueNotifier(false);

  final T owner;
  final ValueNotifier<bool> userGesture;
}

mixin OverlayClose on OverlayMixin {
  Duration? get stay;

  @override
  void onCompleted() {
    super.onCompleted();
    final hold = stay;
    if (hold != null) {
      EventQueue.runOne(this, () => release(hold).whenComplete(hideOrClose));
    }
  }

  bool get closeOndismissed => true;

  void hideOrClose() {
    if (!mounted) {
      close();
      return;
    }
    hide();
  }

  @override
  void onDismissed() {
    super.onDismissed();
    if (closeOndismissed) {
      close();
    }
  }
}

mixin OverlayIgnore on OverlayMixin {
  final _ignore = ValueNotifier(true);

  ValueListenable<bool> get ignore => _ignore;

  @override
  bool show() {
    final value = super.show();
    if (value) _ignore.value = false;

    return value;
  }

  @override
  bool hide() {
    final value = super.hide();
    if (value) _ignore.value = true;

    return value;
  }
}
mixin OverlayShowOnly on OverlayMixin {
  Object? get showKey;
  @override
  FutureOr<bool> showAsync() {
    if (showKey == null) return super.showAsync();

    return EventQueue.run(showKey, () {
      return super.showAsync().then((value) => future.then((_) => value));
    });
  }
}

class OverlayDisposeEntry extends OverlayEntry {
  OverlayDisposeEntry({
    required WidgetBuilder builder,
    bool opaque = false,
    bool maintainState = false,
    required this.overlayMixin,
  }) : super(builder: builder, opaque: opaque, maintainState: maintainState);
  final OverlayMixin overlayMixin;

  @override
  void dispose() {
    overlayMixin.close();
    super.dispose();
  }
}

class OverlayPannelBuilder
    with
        OverlayMixin,
        OverlayEvent,
        OverlayPannel,
        OverlayClose,
        OverlayIgnore,
        OverlayShowOnly {
  OverlayPannelBuilder({
    required WidgetGestureBuilder<OverlayPannelBuilder> builder,
    this.stay,
    bool? closeOndismissed,
    this.showKey,
  }) : closeOnDissmissed = closeOndismissed ?? false {
    addEntry(OverlayDisposeEntry(
        overlayMixin: this,
        builder: (context) => builder(context, _userGestureController)));
  }
  late final _userGestureController = UserGestureController(owner: this);

  @override
  final Duration? stay;
  final bool closeOnDissmissed;
  @override
  final Object? showKey;

  // 当处于用户手势行为中,不进行动画
  // @override
  // bool get shouldHide => !_userGestureController.userGesture.value;
}

/// Widget
class OverlaySideGesture extends StatelessWidget {
  const OverlaySideGesture({
    Key? key,
    this.left = 0,
    this.right = 0,
    this.top = 0,
    this.bottom = 0,
    this.onTap,
    this.useGesture = true,
    required this.sizeKey,
    required this.builder,
    required this.entry,
    this.transition,
  }) : super(key: key);
  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
  final UserGestureController<OverlayMixin> entry;
  final WidgetBuilder builder;
  final Widget Function(Widget child)? transition;
  final VoidCallback? onTap;
  final GlobalKey sizeKey;
  final bool useGesture;

  set user(bool v) {
    entry.userGesture.value = v;
  }

  AnimationController get controller {
    return owner.controller;
  }

  void _userEnter(_) {
    if (closed || showing) return;

    controller.stop(canceled: true);
    user = true;
  }

  void _userleave([DragEndDetails? details]) {
    if (closed || showing) return;
    user = value != 1.0;

    var vHide = false;
    final velocity = details?.primaryVelocity;

    if (velocity != null) {
      if (isTop || isLeft) {
        vHide = velocity < -100;
      } else if (isBottom || isRight) {
        vHide = velocity > 100;
      }
    }

    if (hided || value < 0.5 || vHide) {
      hide();
    } else {
      show();
    }
  }

  void _userUpdate(DragUpdateDetails d) {
    if (closed || showing) return;
    try {
      final localSize = size;
      final offset = d.primaryDelta;

      double? extent;
      if (isVertical) {
        extent = localSize?.height;
      } else if (isHorizontal) {
        extent = localSize?.width;
      }

      if (extent != null && offset != null) {
        // assert(Log.w('....$offset $localSize $value'));
        final delta = offset / extent;
        onUserUpdate(delta);
      }
    } catch (e, s) {
      assert(Log.e('error: $e\n$s'));
    }
  }

  void onUserUpdate(double delta) {
    if (isTop || isLeft) {
      value = value + delta;
    } else if (isBottom || isRight) {
      value = value - delta;
    }
  }

  OverlayMixin get owner => entry.owner;

  bool get closed => owner.closed;
  bool get showing => owner.showing;
  double get value => controller.value;
  set value(double v) {
    controller.value = v.clamp(0.0, 1.0);
  }

  Size? get size {
    try {
      return sizeKey.currentContext?.size;
    } catch (e) {
      Log.i(e);
    }
    return null;
  }

  show() {
    owner.show();
  }

  hide() {
    owner.hide();
  }

  bool get hided => owner.hided;

  bool get topNull => top == null;
  bool get leftNull => left == null;
  bool get rightNull => right == null;
  bool get bottomNull => bottom == null;
  bool get isTop => bottomNull && !topNull && !leftNull && !rightNull;
  bool get isLeft => rightNull && !topNull && !leftNull && !bottomNull;
  bool get isBottom => topNull && !leftNull && !rightNull && !bottomNull;
  bool get isRight => leftNull && !topNull && !rightNull && !bottomNull;
  bool get isHorizontal => isLeft || isRight;
  bool get isVertical => isTop || isBottom;

  @override
  Widget build(BuildContext context) {
    Widget child = builder(context);

    if (transition != null) {
      child = transition!(child);
    }

    if (onTap != null) {
      child = GestureDetector(onTap: onTap, child: child);
    } else if (useGesture) {
      child = GestureDetector(
        onHorizontalDragDown: isHorizontal ? _userEnter : null,
        onHorizontalDragStart: isHorizontal ? _userEnter : null,
        onHorizontalDragUpdate: isHorizontal ? _userUpdate : null,
        onHorizontalDragEnd: isHorizontal ? _userleave : null,
        onHorizontalDragCancel: isHorizontal ? _userleave : null,
        onVerticalDragDown: isVertical ? _userEnter : null,
        onVerticalDragStart: isVertical ? _userEnter : null,
        onVerticalDragUpdate: isVertical ? _userUpdate : null,
        onVerticalDragEnd: isVertical ? _userleave : null,
        onVerticalDragCancel: isVertical ? _userleave : null,
        child: child,
      );
    }
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: child,
    );
  }
}

enum NopOverlayPosition {
  none,
  top,
  right,
  left,
  bottom,
}

class OverlayWidget extends StatelessWidget {
  const OverlayWidget({
    Key? key,
    required this.content,
    required this.sizeKey,
    this.color,
    this.radius,
    this.useMaterial = true,
    this.removeAll = true,
    this.position = NopOverlayPosition.none,
    this.margin,
  }) : super(key: key);

  final Widget content;
  final bool useMaterial;

  final Color? color;
  final BorderRadius? radius;
  final bool removeAll;
  final NopOverlayPosition position;
  final GlobalKey sizeKey;
  final EdgeInsets? margin;

  bool get isTop => position == NopOverlayPosition.top;
  bool get isBottom => position == NopOverlayPosition.bottom;
  bool get isLeft => position == NopOverlayPosition.left;
  bool get isRight => position == NopOverlayPosition.right;
  bool get isHorizontal => isLeft || isRight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final themeColor = colorScheme.surface;
    var padding = MediaQuery.of(context).padding;
    var innerPadding = EdgeInsets.zero;

    if (isTop) {
      innerPadding = EdgeInsets.only(
        left: padding.left,
        right: padding.right,
        top: padding.top,
      );
    } else if (isBottom) {
      innerPadding = EdgeInsets.only(left: padding.left, right: padding.right);
    } else if (isHorizontal) {
      innerPadding = EdgeInsets.only(top: padding.top, bottom: padding.bottom);
    }

    Widget body = Container(
      padding: isTop ? null : innerPadding,
      child: DefaultTextStyle(
        style: TextStyle(
            color: isDark
                ? const Color.fromARGB(255, 221, 221, 221)
                : const Color.fromARGB(255, 44, 44, 44)),
        child: content,
      ),
    );
    if (useMaterial) {
      body = Material(
        color: color ?? themeColor,
        borderRadius: radius,
        child: body,
      );
    }
    if (margin != null) {
      body = Container(padding: margin, child: body);
    }
    return MediaQuery.removePadding(
      context: context,
      removeBottom: removeAll,
      removeLeft: removeAll,
      removeRight: removeAll,
      removeTop: removeAll,
      child: Container(
        key: sizeKey,
        padding: isTop ? innerPadding : null,
        child: body,
      ),
    );
  }
}
