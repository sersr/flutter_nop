import 'dart:async';

import 'package:flutter/material.dart';
import '../../overlay.dart';
import 'navigator_observer.dart';

final _navToken = Object();

abstract class NavAction {
  void action(NavigatorState state);
  void onFailed() {}
}

mixin NaviActionResult<T> on NavAction {
  Future<T?> get result => _completer.future;
  final _completer = Completer<T?>.sync();

  @protected
  void complete([T? value]) {
    if (!_completer.isCompleted) {
      _completer.complete(value);
    }
  }

  void completeError([_]) {
    complete();
  }

  @override
  void onFailed() {
    complete();
  }
}

class NavPushAction<T> extends NavAction with NaviActionResult<T> {
  NavPushAction(this.route);
  Route<T> route;

  @override
  void action(NavigatorState state) {
    state.push(route).then(complete, onError: completeError);
  }
}

class NavPushNamedAction<T> extends NavAction with NaviActionResult<T> {
  NavPushNamedAction(this.routeName, this.arguments);
  final String routeName;
  final Object? arguments;
  @override
  void action(NavigatorState state) {
    state
        .pushNamed<T>(routeName, arguments: arguments)
        .then(complete, onError: completeError);
  }
}

class NavRePushNamedAction extends NavAction with NaviActionResult<String> {
  NavRePushNamedAction(this.routeName, this.arguments);
  final String routeName;
  final Object? arguments;
  @override
  void action(NavigatorState state) {
    try {
      final id = state.restorablePushNamed(routeName, arguments: arguments);
      complete(id);
    } catch (_) {
      completeError();
    }
  }
}

class NavRePopPushNamedAction<R> extends NavAction
    with NaviActionResult<String> {
  NavRePopPushNamedAction(this.routeName, this.arguments, this.popResult);
  final String routeName;
  final Object? arguments;
  final R? popResult;
  @override
  void action(NavigatorState state) {
    try {
      final id = state.restorablePopAndPushNamed(routeName,
          result: popResult, arguments: arguments);
      complete(id);
    } catch (_) {
      completeError();
    }
  }
}

class NavRePushNamedUntilAction extends NavAction
    with NaviActionResult<String> {
  NavRePushNamedUntilAction(this.routeName, this.arguments, this.predicate);
  final String routeName;
  final Object? arguments;
  final bool Function(Route<dynamic>) predicate;
  @override
  void action(NavigatorState state) {
    try {
      final id = state.restorablePushNamedAndRemoveUntil(routeName, predicate,
          arguments: arguments);
      complete(id);
    } catch (_) {
      completeError();
    }
  }
}

class NavRePushNamedReplaceAction<R> extends NavAction
    with NaviActionResult<String> {
  NavRePushNamedReplaceAction(this.routeName, this.arguments, this.popResult);
  final String routeName;
  final Object? arguments;
  final R? popResult;
  @override
  void action(NavigatorState state) {
    try {
      final id = state.restorablePushReplacementNamed(routeName,
          result: popResult, arguments: arguments);
      complete(id);
    } catch (_) {
      completeError();
    }
  }
}

class NavPushReplaceUntil<T> extends NavAction with NaviActionResult<T> {
  NavPushReplaceUntil(this.routeName, this.predicate, this.arguments);
  final String routeName;
  final bool Function(Route<dynamic>) predicate;
  final Object? arguments;

  @override
  void action(NavigatorState state) {
    state
        .pushNamedAndRemoveUntil<T>(routeName, predicate, arguments: arguments)
        .then(complete, onError: completeError);
  }
}

class NavPopAndPushNamedAction<T, R> extends NavAction
    with NaviActionResult<T> {
  NavPopAndPushNamedAction(this.routeName, this.arguments, this.popResult);
  final String routeName;
  final Object? arguments;

  final R? popResult;
  @override
  void action(NavigatorState state) {
    state
        .popAndPushNamed<T, R>(routeName,
            result: popResult, arguments: arguments)
        .then(complete, onError: completeError);
  }
}

class NavPushReplacementNamedAction<T, R> extends NavAction
    with NaviActionResult<T> {
  NavPushReplacementNamedAction(this.routeName, this.arguments, this.popResult);
  final String routeName;
  final Object? arguments;

  final R? popResult;
  @override
  void action(NavigatorState state) {
    state
        .pushReplacementNamed<T, R>(routeName,
            result: popResult, arguments: arguments)
        .then(complete, onError: completeError);
  }
}

class NavPushReplacementdAction<T, TO> extends NavAction
    with NaviActionResult<T> {
  NavPushReplacementdAction(this.route, this.pushResult);
  Route<T> route;
  TO pushResult;

  @override
  void action(NavigatorState state) {
    state
        .pushReplacement<T, TO>(route, result: pushResult)
        .then(complete, onError: completeError);
  }
}

class NavPopAction<R> extends NavAction {
  NavPopAction(this.value);
  final R value;
  @override
  void action(NavigatorState state) {
    state.pop(value);
  }
}

class NavMaybePopAction<R> extends NavAction with NaviActionResult<bool> {
  NavMaybePopAction(this.value);
  final R value;
  @override
  void action(NavigatorState state) {
    state.maybePop(value).then(complete, onError: completeError);
  }
}

class NavReplaceAction<T> extends NavAction {
  NavReplaceAction(this.oldRoute, this.newRoute);
  Route<T> newRoute;
  Route<dynamic> oldRoute;

  @override
  void action(NavigatorState state) {
    state.replace(oldRoute: oldRoute, newRoute: newRoute);
  }
}

class NavRestorableReplaceAction<T> extends NavAction
    with NaviActionResult<String> {
  NavRestorableReplaceAction(
      this.oldRoute, this.newRouteBuilder, this.arguments);
  final Route<dynamic> oldRoute;
  final RestorableRouteBuilder<T> newRouteBuilder;
  final Object? arguments;
  @override
  void action(NavigatorState state) {
    try {
      final result = state.restorableReplace(
          oldRoute: oldRoute,
          newRouteBuilder: newRouteBuilder,
          arguments: arguments);
      complete(result);
    } catch (_) {
      completeError();
    }
  }
}

class NavReplaceBelowAction<T> extends NavAction {
  NavReplaceBelowAction(this.anchorRoute, this.newRoute);
  Route<T> newRoute;
  Route<dynamic> anchorRoute;

  @override
  void action(NavigatorState state) {
    state.replaceRouteBelow(anchorRoute: anchorRoute, newRoute: newRoute);
  }
}

class NavCanPopAction<T> extends NavAction with NaviActionResult<bool> {
  NavCanPopAction();

  @override
  void action(NavigatorState state) {
    complete(state.canPop());
  }
}

class NavigatorDelegate<T> with StateAsyncGetter<NavigatorState> {
  NavigatorDelegate(this.action);
  NavAction action;
  @override
  Object get key => _navToken;

  NavigatorState? Function()? navigatorStateGetter;

  @override
  NavigatorState? getState() {
    return navigatorStateGetter?.call() ?? Nav.getNavigator();
  }

  @override
  FutureOr<void> initRun(NavigatorState state) {
    assert(state.mounted);
    action.action(state);
  }

  @override
  void onFailed() {
    action.onFailed();
  }
}
