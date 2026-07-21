import 'package:flutter/material.dart';

import 'palette.dart';

GamePalette? _cachedFor;
ThemeData? _cachedTheme;

/// True when [a] and [b] agree on every role [buildAppTheme] actually reads —
/// piece colors, which the ThemeData ignores, are deliberately excluded so a
/// piece-color edit doesn't force a [ColorScheme.fromSeed] rebuild.
bool _sameThemeInputs(GamePalette a, GamePalette b) =>
    a.accent == b.accent &&
    a.background == b.background &&
    a.textOnAccent == b.textOnAccent &&
    a.surface == b.surface &&
    a.textPrimary == b.textPrimary &&
    a.danger == b.danger;

/// Bridges the game's [GamePalette] into a Flutter [ThemeData] so widgets
/// (menus, overlays, HUD) share the same colors as the Flame board.
///
/// Called on every rebuild while a color-picker drag is live, so the result is
/// memoized: [ColorScheme.fromSeed] runs a full tonal-palette generation, and
/// re-running it per drag tick (e.g. while editing piece colors, which don't
/// affect the theme at all) is the heaviest avoidable cost on that path.
ThemeData buildAppTheme() {
  final p = Palette.current;
  final cached = _cachedTheme;
  if (cached != null && _cachedFor != null && _sameThemeInputs(_cachedFor!, p)) {
    return cached;
  }
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

  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    textTheme: Typography.material2021().black.apply(
          bodyColor: p.textPrimary,
          displayColor: p.textPrimary,
        ),
  );
  _cachedFor = p;
  _cachedTheme = theme;
  return theme;
}
