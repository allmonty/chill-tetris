import 'package:flutter/material.dart';

import 'palette.dart';

/// Exposes the active [GamePalette] to the widget tree and rebuilds dependents
/// when it changes. Wraps the app below the [Navigator] (see `main.dart`'s
/// `MaterialApp.builder`), so every screen can read the live palette with
/// `PaletteScope.of(context)`.
///
/// [InheritedNotifier] subscribes to the notifier and marks itself dirty on
/// `notifyListeners()` regardless of whether the notifier *instance* changed —
/// so it reacts to `ValueNotifier.value` updates even though the same notifier
/// is passed on every rebuild.
class PaletteScope extends InheritedNotifier<ValueNotifier<GamePalette>> {
  const PaletteScope({
    super.key,
    required ValueNotifier<GamePalette> notifier,
    required super.child,
  }) : super(notifier: notifier);

  /// The active palette. Falls back to [Palette.current] when there's no
  /// ancestor scope (e.g. a widget test that pumps a screen in a bare
  /// `MaterialApp`), so callers never need a null check.
  static GamePalette of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<PaletteScope>()
          ?.notifier
          ?.value ??
      Palette.current;
}
