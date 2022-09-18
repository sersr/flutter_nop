import 'package:flutter/material.dart';

import 'nav_overlay_mixin.dart';
import 'state_getter.dart';

abstract class OverlayObserver {
  StateGetter<OverlayState>? get overlayGetter;
  void insert(OverlayMixin entry) {}

  void hide(OverlayMixin entry) {}
  void show(OverlayMixin entry) {}
  void close(OverlayMixin entry) {}
}

class OverlayObserverState extends OverlayObserver {
  OverlayObserverState({this.overlayGetter});
  @override
  StateGetter<OverlayState>? overlayGetter;

  final _entries = <OverlayMixin>{};

  List<OverlayMixin> get entries => _entries.toList(growable: false);

  @override
  void insert(OverlayMixin entry) {
    _entries.add(entry);
  }

  @override
  void close(OverlayMixin entry) {
    _entries.remove(entry);
  }

  final _entriesState = <OverlayMixin>{};

  List<OverlayMixin> get entriesState => _entriesState.toList(growable: false);

  void hideLast() {
    if (_entriesState.isNotEmpty) {
      final last = _entriesState.last;
      last.hide();
    }
  }

  @override
  void hide(OverlayMixin entry) {
    _entriesState.remove(entry);
  }

  @override
  void show(OverlayMixin entry) {
    _entriesState.add(entry);
  }
}
