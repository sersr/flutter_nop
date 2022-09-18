import 'package:flutter/material.dart';

import '../navigation/navigator_observer.dart';
import 'nav_overlay_getter.dart';
import 'nav_overlay_mixin.dart';
import 'overlay_pannel.dart';
import 'overlay_side_pannel.dart';

typedef SnackbarDelegate = OverlayMixinDelegate;
typedef BannerDelegate = OverlayMixinDelegate;
typedef ToastDelegate = OverlayMixinDelegate;

late final _snackBarToken = Object();
late final _bannelToken = Object();
late final _toastToken = Object();

extension OverlayExt on NavInterface {
  SnackbarDelegate snackBar(
    Widget content, {
    Duration duration = const Duration(seconds: 3),
    Duration animationDuration = const Duration(milliseconds: 300),
    Duration delayDuration = Duration.zero,
    bool? closeOndismissed,
    Color? color,
    bool autoShow = true,
  }) =>
      showOverlay(
        content,
        showKey: _snackBarToken,
        duration: duration,
        animationDuration: animationDuration,
        delayDuration: delayDuration,
        color: color,
        closeOndismissed: closeOndismissed,
        autoShow: autoShow,
        position: NopOverlayPosition.bottom,
      );

  BannerDelegate banner(
    Widget content, {
    Duration duration = const Duration(seconds: 3),
    Duration animationDuration = const Duration(milliseconds: 300),
    Duration delayDuration = Duration.zero,
    Color? color,
    bool autoShow = true,
    BorderRadius? radius = const BorderRadius.all(Radius.circular(8)),
  }) {
    return showOverlay(
      content,
      top: 0,
      right: 8,
      left: 8,
      margin: const EdgeInsets.only(top: 8),
      showKey: _bannelToken,
      duration: duration,
      animationDuration: animationDuration,
      delayDuration: delayDuration,
      radius: radius,
      color: color,
      autoShow: autoShow,
      position: NopOverlayPosition.top,
    );
  }

  ToastDelegate toast(
    Widget content, {
    Duration duration = const Duration(seconds: 3),
    Duration animationDuration = const Duration(milliseconds: 300),
    BorderRadius? radius = const BorderRadius.all(Radius.circular(8)),
    Color? color,
    double bottomPadding = 80.0,
    EdgeInsets? padding,
    bool? closeOndismissed,
    bool autoShow = true,
  }) {
    return showOverlay(
      Container(padding: padding, child: content),
      duration: duration,
      showKey: _toastToken,
      radius: radius,
      color: color,
      top: null,
      autoShow: autoShow,
      bottom: bottomPadding,
      onTap: (owner) {
        owner.hide();
      },
      closeOndismissed: true,
      transition: (child, self) {
        final owner = self.owner;
        return AnimatedBuilder(
          animation: owner.ignore,
          builder: (context, child) {
            return IgnorePointer(ignoring: owner.ignore.value, child: child);
          },
          child: Center(
            child: IntrinsicWidth(
              child: FadeTransition(
                opacity: owner.controller,
                child: RepaintBoundary(
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<T?> showDialog<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    Color? barrierColor = Colors.black54,
    String? barrierLabel,
    bool useSafeArea = true,
    RouteSettings? routeSettings,
    RouteSettings? settings,
    CapturedThemes? themes,
  }) {
    final route = RawDialogRoute<T>(
      pageBuilder: (BuildContext buildContext, Animation<double> animation,
          Animation<double> secondaryAnimation) {
        final Widget pageChild = Builder(builder: builder);
        Widget dialog = themes?.wrap(pageChild) ?? pageChild;
        if (useSafeArea) {
          dialog = SafeArea(child: dialog);
        }
        return dialog;
      },
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      barrierLabel: barrierLabel,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: _buildMaterialDialogTransitions,
      settings: settings,
    );
    return push(route);
  }
}

Widget _buildMaterialDialogTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child) {
  return FadeTransition(
    opacity: CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
    ),
    child: child,
  );
}

extension Content on BuildContext {
  bool get isDarkMode {
    return Theme.of(this).brightness == Brightness.dark;
  }
}

Tween<Offset>? _getOffsetFrom(NopOverlayPosition position) {
  Tween<Offset>? offset;
  switch (position) {
    case NopOverlayPosition.top:
      offset =
          Tween(begin: const Offset(0.0, -1.0), end: const Offset(0.0, 0.0));
      break;
    case NopOverlayPosition.left:
      offset =
          Tween(begin: const Offset(-1.0, 0.0), end: const Offset(0.0, 0.0));
      break;
    case NopOverlayPosition.bottom:
      offset =
          Tween(begin: const Offset(0.0, 1.0), end: const Offset(0.0, 0.0));
      break;
    case NopOverlayPosition.right:
      offset =
          Tween(begin: const Offset(1.0, 0.0), end: const Offset(0.0, 0.0));
      break;
    default:
  }
  return offset;
}

OverlayMixinDelegate showOverlay(
  Widget content, {
  Duration duration = const Duration(seconds: 3),
  Duration animationDuration = const Duration(milliseconds: 300),
  Duration delayDuration = Duration.zero,
  bool? closeOndismissed,
  Color? color,
  BorderRadius? radius,
  bool removeAll = true,
  double? left = 0,
  double? right = 0,
  double? top = 0,
  double? bottom = 0,
  EdgeInsets? margin,
  NopOverlayPosition position = NopOverlayPosition.none,
  Object? showKey,
  bool autoShow = true,
  void Function(OverlayMixin owner)? onTap,
  Widget Function(BuildContext context, Widget child)? builder,
  Widget Function(
          Widget child, UserGestureController<OverlayPannelBuilder> controller)?
      transition,
}) {
  final offset = _getOffsetFrom(position);

  final controller = OverlayPannelBuilder(
    showKey: showKey,
    closeOndismissed: closeOndismissed ?? true,
    stay: duration,
    builder: (context, self) {
      final key = GlobalKey();

      Widget Function(Widget child)? localTransition;
      if (transition != null) {
        localTransition = (Widget child) {
          return transition(child, self);
        };
      } else if (offset != null) {
        localTransition = (Widget child) {
          return AnimatedBuilder(
            animation: self.userGesture,
            builder: (context, _) {
              if (self.userGesture.value) {
                final position = self.owner.controller.drive(offset);

                return SlideTransition(position: position, child: child);
              }

              return CurvedAnimationWidget(
                builder: (context, animation) {
                  final position = animation.drive(offset);
                  return SlideTransition(position: position, child: child);
                },
                controller: self.owner.controller,
              );
            },
          );
        };
      }

      VoidCallback? _onTap;
      if (onTap != null) {
        _onTap = () {
          onTap(self.owner);
        };
      }
      return OverlaySideGesture(
        sizeKey: key,
        entry: self,
        top: position == NopOverlayPosition.bottom ? null : top,
        left: position == NopOverlayPosition.right ? null : left,
        right: position == NopOverlayPosition.left ? null : right,
        bottom: position == NopOverlayPosition.top ? null : bottom,
        transition: localTransition,
        onTap: _onTap,
        builder: (context) {
          Widget child = OverlayWidget(
            content: content,
            sizeKey: key,
            color: color,
            radius: radius,
            margin: margin,
            removeAll: removeAll,
            position: position,
          );
          if (builder != null) {
            child = builder(context, child);
          }
          return child;
        },
      );
    },
  );

  final overlay = OverlayMixinDelegate(controller, animationDuration,
      delayDuration: delayDuration);
  if (autoShow) overlay.show();
  return overlay;
}
