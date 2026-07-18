import 'package:flutter/material.dart';

/// A semantic color palette for the whole game.
///
/// Colors are referenced by *role* (background, accent, piece colors, ...)
/// rather than by raw hex value, so swapping the look of the entire game is a
/// one-line change: assign a different [GamePalette] to [Palette.current].
@immutable
class GamePalette {
  const GamePalette({
    required this.name,
    required this.background,
    required this.surface,
    required this.boardBackground,
    required this.gridLine,
    required this.textPrimary,
    required this.textSecondary,
    required this.textOnAccent,
    required this.accent,
    required this.danger,
    required this.lockedLevel,
    required this.pieceColors,
  });

  final String name;

  /// App / screen background.
  final Color background;

  /// Cards, buttons, tiles.
  final Color surface;

  /// The playfield backdrop.
  final Color boardBackground;

  /// Subtle grid lines on the playfield.
  final Color gridLine;

  final Color textPrimary;
  final Color textSecondary;

  /// Text/icons drawn on top of [accent].
  final Color textOnAccent;

  /// Primary highlight (buttons, unlocked levels, progress).
  final Color accent;

  /// Warnings, danger zone, game-over.
  final Color danger;

  /// Tint for locked level tiles.
  final Color lockedLevel;

  /// One color per tetromino type (I, O, T, S, Z, J, L). Also indexed by the
  /// `color` field in the level JSON.
  final List<Color> pieceColors;

  /// Mid-century modern palette (the initial theme).
  ///
  /// Source swatches:
  /// #8F9779 #DBD9D4 #DDB058 #CDCDC9 #E6D394 #9BB0BC
  /// #D2A799 #F1EFE9 #4E4243 #CED5B6 #536D81 #B06757
  static const GamePalette midCenturyModern = GamePalette(
    name: 'Mid-Century Modern',
    background: Color(0xFFF1EFE9), // soft off-white
    surface: Color(0xFFDBD9D4), // warm light grey
    boardBackground: Color(0xFFCDCDC9), // muted grey
    gridLine: Color(0xFFDBD9D4), // barely-there lines
    textPrimary: Color(0xFF4E4243), // deep aubergine-brown
    textSecondary: Color(0xFF536D81), // slate blue
    textOnAccent: Color(0xFF4E4243),
    accent: Color(0xFFDDB058), // mustard
    danger: Color(0xFFB06757), // terracotta
    lockedLevel: Color(0xFFCDCDC9),
    pieceColors: [
      Color(0xFF8F9779), // sage — I
      Color(0xFFDDB058), // mustard — O
      Color(0xFFE6D394), // pale gold — T
      Color(0xFF9BB0BC), // dusty blue — S
      Color(0xFFD2A799), // clay pink — Z
      Color(0xFFCED5B6), // pale sage — J
      Color(0xFF536D81), // slate blue — L
    ],
  );

  /// A second palette, used to prove theming is centralized. Not shipped in the
  /// UI yet, but handy for the palette-swap verification step.
  static const GamePalette dusk = GamePalette(
    name: 'Dusk',
    background: Color(0xFF2B2B3A),
    surface: Color(0xFF3A3A4E),
    boardBackground: Color(0xFF23232F),
    gridLine: Color(0xFF3A3A4E),
    textPrimary: Color(0xFFECEAF2),
    textSecondary: Color(0xFFA9A6C4),
    textOnAccent: Color(0xFF23232F),
    accent: Color(0xFFE6B450),
    danger: Color(0xFFD08770),
    lockedLevel: Color(0xFF3A3A4E),
    pieceColors: [
      Color(0xFF88C0A0),
      Color(0xFFE6B450),
      Color(0xFFEBCB8B),
      Color(0xFF81A1C1),
      Color(0xFFD0879A),
      Color(0xFFA3BE8C),
      Color(0xFF5E81AC),
    ],
  );
}

/// Global palette accessor. Change this one line to re-theme the whole game.
class Palette {
  const Palette._();

  static GamePalette current = GamePalette.midCenturyModern;
}
