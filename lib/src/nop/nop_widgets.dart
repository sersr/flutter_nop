import 'package:flutter/material.dart';

import 'nop.dart';

abstract class NopStatelessWidget<T> extends Widget {
  const NopStatelessWidget({super.key});

  @override
  NopStatelessElement<T> createElement() {
    return NopStatelessElement<T>(this);
  }

  void init(BuildContext context, T controller) {}

  Widget build(BuildContext context, T controller);
}

class NopStatelessElement<T> extends ComponentElement {
  NopStatelessElement(NopStatelessWidget<T> super.widget);
  late final T controller;

  @override
  NopStatelessWidget<T> get widget => super.widget as NopStatelessWidget<T>;

  @override
  Widget build() => widget.build(this, controller);

  bool _init = false;

  void _initWidget() {
    if (_init) return;
    _init = true;
    controller = getType();
    widget.init(this, controller);
  }

  @override
  void performRebuild() {
    _initWidget();
    super.performRebuild();
  }
}
