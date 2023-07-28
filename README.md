# state manager & route generator


example: [router_demo](https://github.com/sersr/router_demo)

## state manager

#### nop version:
```dart
    class CounterState {}
    //...
    Nav.put(() => CounterState());
    //...

    final app = MaterialApp(
      ...
      navigatorObservers: [
        ...,
        Nav.observer,
      ]
      ...
    );

    runApp(app);

    //...
    Widget build(BuildContext context) {
        final counter = context.getType<CounterState>();
        //...
    }
```

#### router version:  
example: [router_demo](https://github.com/sersr/router_demo)

```dart
    class CounterState {}

    final router = NRouter( ... );

    //...
    router.put(() => CounterState());
    //...
    
    final app = MaterialApp.router(
      routerConfig: router,
      // ...
    );
    runApp(app);

    //...
    Widget build(BuildContext context) {
        final counter = context.grass<CounterState>();
        //...
    }
```



## route generator

pubspec.yaml:

```yaml
  dependencies:
    nop_annotations:

  dev_dependencies:
    nop_gen:
    build_runner:
```

#### nop version:

link: [route_gen](./test/src/route_gen.dart)  

```dart
//  routes.dart

    import 'package:nop_annotations/nop_annotations.dart';

    part 'routes.g.dart';

    @NopRouteMain(
      main: MyHomePage,
      pages: [
        RouteItem(page: SecondPage),
        RouteItem(page: ThirdPage),
      ],
    )
    class AppRoutes {}

    class SecondPage extends StatelessWidget {
        const SecondPage({super.key, String? title});
        //...
    }

```

    dart run build_runner build  


```dart
// 'routes.g.dart'

    class Routes {
        //...
      static final _secondPage =  NopRoute(
        name: '/secondPage',
        fullName: '/secondPage',
        builder: (context, arguments) => const Nop.page(
        child: SecondPage(title: arguments['title']),
        ),
      );
    }

    class NavRoutes {
      static NopRouteAction<T> secondPage<T>({
        BuildContext? context, String? title,
      }) {
        return NopRouteAction(
            context: context, route: Routes._secondPage, arguments:  {'title': title});
      }
    }
```

#### router version:

[router_demo](https://github.com/sersr/router_demo/tree/main/lib/_routes/route.dart)

    dart run build_runner build --delete-conflicting-outputs
