状态管理，路由生成

demo: [shudu](https://github.com/sersr/shudu)

## 状态管理


```dart
    Class CounterState {

    }
    //...
    Nav.put(() => CounterState());
    Nav.put((context) => CounterState());
    //...
    runApp(MyApp());
```
获取
```dart
    //...
    Widget build(BuildContext context) {
        // 需要使用 Nop
        final counter = context.getType<CounterState>();
        //...
    }
```
## 路由生成
需要添加依赖：
```yaml
  dependencies:
    nop_annotations:

  dev_dependencies:
    nop_gen:
    build_runner:
```

### 示例

file: routes.dart;
```dart
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
        const SecondPage({Key? key, String? title}): super(key: key);
        //...
    }

```
run: dart run build_runner build  
将会生成 routes.g.dart 文件  
```dart
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
    /// 将默认构造器转换成普通函数
    class NavRoutes {

      // Navigator.pushNamed(context, Routes._secondPage.fullName, arguments: {'title': 'secondTitle'});
      // secondPage(title: 'secondTitle').go;
      static NopRouteAction<T> secondPage<T>({
        BuildContext? context, String? title,
      }) {
        return NopRouteAction(
            context: context, route: Routes._secondPage, arguments:  {'title': title});
      }
    }
```
demo [shudu](https://github.com/sersr/shudu/blob/master/lib/routes/routes.dart)

路由生成注解为 `Nav` 和 `Nop` 提供了支持；路由跳转提供明确的参数(以函数调用提供)

## Nop 状态管理

状态管理依赖于 Nop，而路由生成注解会在每一个页面使用 `Nop.page`,`page` 是一个节点,存储可共享对象，生命周期由`State`管理

```dart
    void main() {
        runApp(Nop(child: MyApp()));
    }
```

在开始之前使用`Nop`,即可任意使用`context.getType`  
创建的对象会自动判断是否是全局或页面，局部共享；  
当共享的对象没有监听者时会被释放

```dart
    class SomeClass {}
    Nav.put(() => SomeClass()));
    // ...
    context.getType<SomeClass>();
```

共享对象的生命周期可以被另一个对象延长