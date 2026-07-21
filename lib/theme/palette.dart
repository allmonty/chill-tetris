import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'palette_service.dart';

/// A semantic color palette for the whole game.
///
/// Colors are referenced by *role* (background, accent, piece colors, ...)
/// rather than by raw hex value, so swapping the look of the entire game is a
/// matter of pointing the app at a different [GamePalette] (see
/// [PaletteService], which owns the active one and makes changes reactive).
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
    this.presetId = '',
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

  /// Stable id for the three built-in presets, so a persisted / re-derived
  /// palette can be matched back to the preset that produced it by value rather
  /// than by reference (see [operator ==]). Empty for custom palettes.
  final String presetId;

  /// Mid-century modern palette (the initial theme).
  ///
  /// Source swatches:
  /// #8F9779 #DBD9D4 #DDB058 #CDCDC9 #E6D394 #9BB0BC
  /// #D2A799 #F1EFE9 #4E4243 #CED5B6 #536D81 #B06757
  static const GamePalette midCenturyModern = GamePalette(
    name: 'Mid-Century Modern',
    presetId: 'midCenturyModern',
    background: Color(0xFFF1EFE9), // soft off-white
    surface: Color(0xFFDBD9D4), // warm light grey
    boardBackground: Color(0xFF4E4243), // dark walnut — pieces pop against it
    gridLine: Color(0xFFF1EFE9), // light lines, drawn faint on the dark board
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
      Color(0xFFB06757), // terracotta — L (was slate blue: too dark on the walnut board)
    ],
  );

  /// Dusk — a calm, cool nightfall palette: deep slate-blues under soft muted
  /// pastels, easy on the eyes in a dark room.
  static const GamePalette dusk = GamePalette(
    name: 'Dusk',
    presetId: 'dusk',
    background: Color(0xFF272A3B), // deep indigo slate
    surface: Color(0xFF353A52), // raised slate
    boardBackground: Color(0xFF1D2030), // near-black playfield
    gridLine: Color(0xFF353A52),
    textPrimary: Color(0xFFECEAF2),
    textSecondary: Color(0xFFA6ABC8), // muted periwinkle-grey
    textOnAccent: Color(0xFF1D2030),
    accent: Color(0xFF8FB3D9), // soft dusk blue
    danger: Color(0xFFD98A76), // muted coral
    lockedLevel: Color(0xFF353A52),
    pieceColors: [
      Color(0xFF7FC0A9), // seafoam — I
      Color(0xFFE6C07A), // soft amber — O
      Color(0xFFB49BD8), // lavender — T
      Color(0xFF81A1C1), // steel blue — S
      Color(0xFFD98FA8), // dusty rose — Z
      Color(0xFF9FC08A), // sage — J
      Color(0xFF6E8FC0), // periwinkle — L
    ],
  );

  /// Ember — a warm, cozy dark palette: espresso browns lit by amber and
  /// coral, the counterweight to [dusk]'s cool tones.
  static const GamePalette ember = GamePalette(
    name: 'Ember',
    presetId: 'ember',
    background: Color(0xFF2A211E), // deep espresso
    surface: Color(0xFF3A2E29), // raised warm brown
    boardBackground: Color(0xFF1F1815), // near-black walnut
    gridLine: Color(0xFF3A2E29),
    textPrimary: Color(0xFFF0E6DD), // warm off-white
    textSecondary: Color(0xFFB89A86), // muted tan
    textOnAccent: Color(0xFF2A211E),
    accent: Color(0xFFE0925A), // warm amber
    danger: Color(0xFFD46A5A), // ember red
    lockedLevel: Color(0xFF3A2E29),
    pieceColors: [
      Color(0xFF6FA8A0), // teal — I (cool balance)
      Color(0xFFE0B15A), // amber — O
      Color(0xFFE0876A), // coral — T
      Color(0xFF9DB08A), // olive sage — S
      Color(0xFFCE8A94), // dusty rose — Z
      Color(0xFF7C97B0), // slate blue — J
      Color(0xFFE0925A), // warm orange — L
    ],
  );

  /// The presets shown in the Personalization tab, in display order.
  static const List<GamePalette> presets = [midCenturyModern, dusk, ember];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GamePalette &&
          other.name == name &&
          other.presetId == presetId &&
          other.background == background &&
          other.surface == surface &&
          other.boardBackground == boardBackground &&
          other.gridLine == gridLine &&
          other.textPrimary == textPrimary &&
          other.textSecondary == textSecondary &&
          other.textOnAccent == textOnAccent &&
          other.accent == accent &&
          other.danger == danger &&
          other.lockedLevel == lockedLevel &&
          listEquals(other.pieceColors, pieceColors);

  @override
  int get hashCode => Object.hash(
        name,
        presetId,
        background,
        surface,
        boardBackground,
        gridLine,
        textPrimary,
        textSecondary,
        textOnAccent,
        accent,
        danger,
        lockedLevel,
        Object.hashAll(pieceColors),
      );
}

/// Low-level accessor for the active palette, for the two call sites that can't
/// take a [BuildContext] (the Flame board component, which re-reads every
/// frame, and `buildAppTheme()`, a pure function). Widgets should instead read
/// `PaletteScope.of(context)` so they rebuild when the palette changes.
class Palette {
  const Palette._();

  static GamePalette get current => PaletteService.instance.current.value;
}
