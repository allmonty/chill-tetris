import 'package:flutter/material.dart';

import 'palette.dart';

/// Bridges the game's [GamePalette] into a Flutter [ThemeData] so widgets
/// (menus, overlays, HUD) share the same colors as the Flame board.
ThemeData buildAppTheme() {
  final p = Palette.current;
  final scheme = ColorScheme.fromSeed(
    seedColor: p.accent,
    brightness: ThemeData.estimateBrightnessForColor(p.background),
  ).copyWith(
    primary: p.accent,
    onPrimary: p.textOnAccent,
    surface: p.surface,
    onSurface: p.textPrimary,
    error: p.danger,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    textTheme: Typography.material2021().black.apply(
          bodyColor: p.textPrimary,
          displayColor: p.textPrimary,
        ),
  );
}
