import 'package:chill_tetris/theme/palette_derivation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Seven arbitrary but distinct piece colors for cases where their exact value
/// doesn't matter — only that they pass through untouched.
const _pieces = [
  Color(0xFF112233),
  Color(0xFF445566),
  Color(0xFF778899),
  Color(0xFFAABBCC),
  Color(0xFFDDEEFF),
  Color(0xFF010203),
  Color(0xFF0A0B0C),
];

void main() {
  test('passes the edited colors through unchanged', () {
    const background = Color(0xFF223344);
    const board = Color(0xFF111111);
    const accent = Color(0xFFE0925A);
    final palette = derivePalette(
      name: 'X',
      background: background,
      boardBackground: board,
      accent: accent,
      pieceColors: _pieces,
    );

    expect(palette.name, 'X');
    expect(palette.background, background);
    expect(palette.boardBackground, board);
    expect(palette.accent, accent);
    expect(palette.pieceColors, _pieces);
  });

  test('dark background gets a lighter surface and light text', () {
    final palette = derivePalette(
      name: 'dark',
      background: const Color(0xFF080808),
      boardBackground: const Color(0xFF000000),
      accent: const Color(0xFF88AACC),
      pieceColors: _pieces,
    );

    final bgL = HSLColor.fromColor(palette.background).lightness;
    final surfaceL = HSLColor.fromColor(palette.surface).lightness;
    expect(surfaceL, greaterThan(bgL), reason: 'surface lifts off a dark bg');
    expect(
      ThemeData.estimateBrightnessForColor(palette.textPrimary),
      Brightness.light,
      reason: 'light text on a dark background',
    );
  });

  test('light background gets a darker surface and dark text', () {
    final palette = derivePalette(
      name: 'light',
      background: const Color(0xFFF8F8F8),
      boardBackground: const Color(0xFF303030),
      accent: const Color(0xFFDDB058),
      pieceColors: _pieces,
    );

    final bgL = HSLColor.fromColor(palette.background).lightness;
    final surfaceL = HSLColor.fromColor(palette.surface).lightness;
    expect(surfaceL, lessThan(bgL), reason: 'surface sinks below a light bg');
    expect(
      ThemeData.estimateBrightnessForColor(palette.textPrimary),
      Brightness.dark,
      reason: 'dark text on a light background',
    );
  });

  test('textSecondary sits between textPrimary and the background', () {
    final palette = derivePalette(
      name: 'x',
      background: const Color(0xFFF1EFE9),
      boardBackground: const Color(0xFF4E4243),
      accent: const Color(0xFFDDB058),
      pieceColors: _pieces,
    );

    final primaryL = HSLColor.fromColor(palette.textPrimary).lightness;
    final secondaryL = HSLColor.fromColor(palette.textSecondary).lightness;
    final bgL = HSLColor.fromColor(palette.background).lightness;
    // On a light background, secondary is softened toward the (lighter) bg, so
    // its lightness lands between the dark primary and the light background.
    expect(secondaryL, greaterThan(primaryL));
    expect(secondaryL, lessThan(bgL));
  });

  test('danger reads as a warm red even for a fully desaturated accent', () {
    final palette = derivePalette(
      name: 'grey',
      background: const Color(0xFF202020),
      boardBackground: const Color(0xFF000000),
      accent: const Color(0xFF808080), // zero saturation
      pieceColors: _pieces,
    );

    final danger = HSLColor.fromColor(palette.danger);
    expect(danger.hue, closeTo(9.0, 1.0), reason: 'fixed warm-red hue');
    expect(danger.saturation, greaterThanOrEqualTo(0.40),
        reason: 'clamped into the readable-red saturation band');
    // ±0.01 tolerance for the 8-bit color round-trip in fromColor/toColor.
    expect(danger.lightness, inInclusiveRange(0.44, 0.66));
  });

  test('danger clamps a very light, vivid accent into the red band', () {
    final palette = derivePalette(
      name: 'vivid',
      background: const Color(0xFFFFFFFF),
      boardBackground: const Color(0xFF000000),
      accent: const Color(0xFFFFF0A0), // very light, saturated yellow
      pieceColors: _pieces,
    );

    final danger = HSLColor.fromColor(palette.danger);
    expect(danger.hue, closeTo(9.0, 1.0));
    // ±0.01 tolerance for the 8-bit color round-trip in fromColor/toColor.
    expect(danger.saturation, inInclusiveRange(0.39, 0.66));
    expect(danger.lightness, inInclusiveRange(0.44, 0.66));
  });
}
