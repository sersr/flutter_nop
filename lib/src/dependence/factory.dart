import 'dart:collection';

import 'package:nop/nop.dart';

typedef BuildFactory<T> = T Function();

mixin BuildFactoryMixin {
  final _factorys = HashMap<Type, BuildFactory>();
  void put<T>(BuildFactory<T> factory) {
    assert(!_alias.containsKey(T) || Log.e('${_alias[T]} already exists.'));
    _factorys[T] = factory;
  }

  BuildFactory<T> get<T>() {
    assert(_factorys.containsKey(T), 'You need to call put<$T>().');
    return _factorys[T] as BuildFactory<T>;
  }

  BuildFactory getArg(Type t) {
    assert(_factorys.containsKey(t), 'You need to call put<$t>().');
    return _factorys[t] as BuildFactory;
  }

  final _alias = HashMap<Type, Type>();

  /// 子类可以转化成父类
  void addAlias<P, C extends P>() {
    assert(!_factorys.containsKey(P) || Log.e('$P already exists.'));
    _alias[P] = C; // 可以根据父类类型获取到子类对象
  }

  Type getAlias(Type t) {
    return _alias[t] ?? t;
  }

  void addAliasAll<P extends Type, C extends P>(Iterable<P> parents, C child) {
    for (var item in parents) {
      _alias[item] = child;
    }
  }
}
