import 'package:flutter/material.dart';

import 'typedef.dart';

/// 统一初始化对象
class NopPreInit extends StatefulWidget {
  const NopPreInit({
    Key? key,
    this.builder,
    this.builders,
    required this.init,
    required this.child,
    this.initTypes = const [],
    this.initTypesUnique = const [],
  }) : super(key: key);

  final NopWidgetBuilder? builder;
  final List<NopWidgetBuilder>? builders;
  final dynamic Function(Type t, BuildContext context, {bool shared}) init;
  final Widget child;
  final List<Type> initTypes;
  final List<Type> initTypesUnique;

  @override
  State<NopPreInit> createState() => _NopPreInitState();
}

class _NopPreInitState extends State<NopPreInit> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initFirst) {
      _initFirst = true;
      _init(widget.initTypesUnique, false);
      _init(widget.initTypes, true);
    }
  }

  bool _initFirst = false;

  void _init(List<Type> types, bool shared) {
    for (var item in types) {
      widget.init(item, context, shared: shared);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child = widget.child;
    if (widget.builder != null) {
      child = widget.builder!(context, child);
    }
    final builders = widget.builders;

    if (builders != null && builders.isNotEmpty) {
      for (var build in builders) {
        child = build(context, child);
      }
    }
    return child;
  }
}
