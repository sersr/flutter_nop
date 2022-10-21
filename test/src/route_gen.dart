import 'package:flutter/src/widgets/container.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_nop/flutter_nop.dart';
import 'package:nop_annotations/annotation/route_annotation.dart';

part 'route_gen.g.dart';

class Page01 extends StatelessWidget {
  const Page01({super.key});

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class Page02 extends StatelessWidget {
  const Page02({super.key});

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class Page03 extends StatelessWidget {
  const Page03({super.key});

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class UniqueController {}

@NopRouteMain(
  main: Page01,
  private: false,
  pages: [
    RouteItem(
      page: Page02,
      preInitUnique: [UniqueController],
      pages: [
        RouteItem(page: Page03),
      ],
    ),
  ],
)
// ignore: unused_element
class _Routes {
  _Routes._();
}
