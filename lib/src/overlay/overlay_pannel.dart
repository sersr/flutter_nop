import 'package:flutter/material.dart';

import 'nav_overlay_mixin.dart';
import 'overlay_event.dart';

mixin OverlayPannel on OverlayMixin, OverlayEvent {
  final _entries = <OverlayEntry>[];

  addEntry(OverlayEntry entry) {
    _entries.add(entry);
    if (inited) {
      overlay.insert(entry);
    }
  }

  remove(OverlayEntry entry) {
    _entries.remove(entry);
  }

  @override
  void onCreateOverlayEntry() {
    overlay.insertAll(_entries);
    super.onCreateOverlayEntry();
  }

  @override
  void onRemoveOverlayEntry() {
    super.onRemoveOverlayEntry();
    for (var item in _entries) {
      item.remove();
    }
    _entries.clear();
  }
}

class OverlayVerticalPannels with OverlayMixin, OverlayEvent, OverlayPannel {
  OverlayVerticalPannels({
    List<WidgetBuilder>? builders,
    this.onHideEnd,
    this.onShowEnd,
  }) {
    builders?.map((e) => OverlayEntry(builder: e)).forEach(addEntry);
  }

  @override
  final VoidCallback? onHideEnd;
  @override
  final VoidCallback? onShowEnd;
}

/// [CurvedAnimation]需要调用`dispose`释放资源
class CurvedAnimationWidget extends StatefulWidget {
  const CurvedAnimationWidget({
    Key? key,
    required this.controller,
    required this.builder,
    this.onHide,
    this.curve,
    this.reverseCurve,
  }) : super(key: key);
  final AnimationController controller;
  final VoidCallback? onHide;
  final Curve? curve;
  final Curve? reverseCurve;
  final Widget Function(BuildContext context, Animation<double> animation)
      builder;
  @override
  _CurvedAnimationWidgetState createState() => _CurvedAnimationWidgetState();
}

class _CurvedAnimationWidgetState extends State<CurvedAnimationWidget> {
  @override
  void initState() {
    super.initState();
    update();
  }

  @override
  void dispose() {
    super.dispose();
    curvedAnimation?.dispose();
  }

  @override
  void didUpdateWidget(covariant CurvedAnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    update();
  }

  CurvedAnimation? curvedAnimation;
  void update() {
    curvedAnimation?.dispose();

    final curve = widget.curve ?? Curves.ease;
    curvedAnimation = CurvedAnimation(
      parent: widget.controller,
      curve: curve,
      reverseCurve: widget.reverseCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child: widget.builder(context, curvedAnimation!));
  }
}
