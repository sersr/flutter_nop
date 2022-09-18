import 'package:flutter/material.dart';

typedef NopWidgetBuilder = Widget Function(BuildContext context, Widget child);
typedef NopPreInitCallback = void Function(
    T? Function<T>({bool shared}) preInit);
