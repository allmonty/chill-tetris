import 'package:flutter/material.dart';

import 'palette.dart';

/// Builds a full [GamePalette] from the nine colors a user actually edits in
/// the custom-palette editor — [background], [boardBackground], [accent] and
/// the seven [pieceColors] — deriving the remaining seven roles by formula.
///
/// The formulas are calibrated against the hand-authored presets' real HSL
/// relationships and clamped so they stay legible for arbitrary user input
/// (very light/dark backgrounds, desaturated accents, etc.), rather than being
/// passed through raw. Pure and side-effect free, so it can be unit tested in
/// isolation.
GamePalette derivePalette({
  required String name,
  required Color background,
  required Color boardBackground,
  required Color accent,
  required List<Color> pieceColors,
}) {
  final surface = _surfaceFrom(background);
  final textPrimary = _neutralText(background);
  return GamePalette(
    name: name,
    background: background,
    surface: surface,
    boardBackground: boardBackground,
    // Grid lines are drawn at ~7% alpha over the board, so the exact base
    // barely shows; matching the surface tone is enough.
    gridLine: surface,
    textPrimary: textPrimary,
    // Softer than primary but still legible: a 25% blend toward the background
    // (35% drops below a readable contrast ratio on light backgrounds).
    textSecondary: Color.lerp(textPrimary, background, 0.25)!,
    textOnAccent: _neutralText(accent),
    accent: accent,
    danger: _dangerFrom(accent),
    // A small but deliberate shift off the surface so locked tiles stay
    // distinguishable from active ones for any custom palette.
    lockedLevel: Color.lerp(surface, const Color(0xFF808080), 0.18)!,
    pieceColors: pieceColors,
  );
}

/// Cards/buttons sit just off the background: lighter on a dark theme, darker
/// on a light one, by a fixed lightness delta. If the background is so close to
/// black/white that clamping would eat most of that delta, flip the direction
/// so there's still a visible step.
Color _surfaceFrom(Color background) {
  final hsl = HSLColor.fromColor(background);
  final isDark =
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark;
  var delta = isDark ? 0.08 : -0.08;
  var l = (hsl.lightness + delta).clamp(0.0, 1.0);
  if ((l - hsl.lightness).abs() < 0.04) {
    delta = -delta;
    l = (hsl.lightness + delta).clamp(0.0, 1.0);
  }
  return hsl.withLightness(l).toColor();
}

/// A near-black or near-white text color that keeps a faint hint of [base]'s
/// hue (matching the warm off-blacks/whites of the hand-tuned presets) but caps
/// saturation hard so it stays legible. Uses perceptual brightness, not raw HSL
/// lightness, so a vivid low-luminance hue (e.g. pure blue) is correctly read
/// as "dark" and gets light text.
Color _neutralText(Color base) {
  final hsl = HSLColor.fromColor(base);
  final isLight =
      ThemeData.estimateBrightnessForColor(base) == Brightness.light;
  final s = (hsl.saturation * 0.35).clamp(0.0, 0.30);
  final l = isLight ? 0.12 : 0.96;
  return HSLColor.fromAHSL(1.0, hsl.hue, s, l).toColor();
}

/// A warning color that harmonizes with [accent]'s intensity but always reads
/// as a warm mid-tone red: the accent's hue is dropped to a fixed ~9°, and its
/// saturation/lightness are clamped into the band both presets' `danger` values
/// occupy — so even a grey or near-black/white accent yields a usable red.
Color _dangerFrom(Color accent) {
  final a = HSLColor.fromColor(accent);
  final s = a.saturation.clamp(0.40, 0.65);
  final l = a.lightness.clamp(0.45, 0.65);
  return HSLColor.fromAHSL(1.0, 9.0, s, l).toColor();
}
