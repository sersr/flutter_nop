import 'history_state_stub.dart'
    if (dart.library.js_util) 'history_state_web.dart' as web;

Object? get historyState => web.historyState;
