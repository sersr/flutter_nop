import 'package:flutter/material.dart';

import 'typedef.dart';

/// 统一初始化对象
class NopPreInit extends StatefulWidget {
  const NopPreInit({
    Key? key,
    this.builder,
    this.builders,
    this.group,
    @Deprecated('will be removed.') required this.init,
    required this.child,
    @Deprecated('will be removed.') this.list = const [],
    @Deprecated('will be removed.') this.groupList = const [],
  }) : super(key: key);

  final NopWidgetBuilder? builder;
  final List<NopWidgetBuilder>? builders;
  final dynamic Function(Type t, BuildContext context, Object? group) init;
  final Widget child;
  final List<Type> list;
  final List<Type> groupList;
  final Object? group;

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
    // if (!_initFirst) {
    //   _initFirst = true;
    //   _init(widget.groupList, widget.group);
    //   _init(widget.list, null);
    // }
  }

  // bool _initFirst = false;

  // void _init(List<Type> types, Object? group) {
  //   for (var item in types) {
  //     widget.init(item, context, group);
  //   }
  // }

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
