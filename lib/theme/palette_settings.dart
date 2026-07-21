import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The nine user-editable colors of a custom palette slot. The remaining seven
/// [GamePalette] roles are derived from these (see `derivePalette`), so only
/// these are persisted.
@immutable
class CustomSlotData {
  const CustomSlotData({
    required this.background,
    required this.boardBackground,
    required this.accent,
    required this.pieceColors,
  });

  final Color background;
  final Color boardBackground;
  final Color accent;

  /// Exactly seven, ordered I/O/T/S/Z/J/L.
  final List<Color> pieceColors;

  CustomSlotData copyWith({
    Color? background,
    Color? boardBackground,
    Color? accent,
    List<Color>? pieceColors,
  }) =>
      CustomSlotData(
        background: background ?? this.background,
        boardBackground: boardBackground ?? this.boardBackground,
        accent: accent ?? this.accent,
        pieceColors: pieceColors ?? this.pieceColors,
      );
}

/// Persisted personalization state: which palette is active, and the contents
/// of the three custom slots.
///
/// A pure holder (like `AudioSettings`) so the load logic is unit-testable
/// without touching `PaletteService` or any plugin. Colors are stored as ARGB
/// ints via [Color.toARGB32] / restored via the `Color(int)` constructor.
@immutable
class PaletteSettings {
  const PaletteSettings({required this.activeId, required this.slots});

  static const int slotCount = 3;

  /// Identifies the active selection: `preset:<presetId>` or `custom:<index>`.
  static const kActiveId = 'palette_active_id';
  static const defaultActiveId = 'preset:midCenturyModern';

  /// The active selection id.
  final String activeId;

  /// Three entries; a null entry is an empty slot.
  final List<CustomSlotData?> slots;

  static String slotPresentKey(int i) => 'palette_custom_${i}_present';
  static String slotBackgroundKey(int i) => 'palette_custom_${i}_background';
  static String slotBoardKey(int i) => 'palette_custom_${i}_board';
  static String slotAccentKey(int i) => 'palette_custom_${i}_accent';
  static String slotPieceKey(int i, int piece) =>
      'palette_custom_${i}_piece_$piece';

  static PaletteSettings load(SharedPreferences prefs) {
    final slots = List<CustomSlotData?>.generate(slotCount, (i) {
      if (!(prefs.getBool(slotPresentKey(i)) ?? false)) return null;
      final bg = prefs.getInt(slotBackgroundKey(i));
      final board = prefs.getInt(slotBoardKey(i));
      final accent = prefs.getInt(slotAccentKey(i));
      final pieces = <Color>[];
      for (var p = 0; p < 7; p++) {
        final v = prefs.getInt(slotPieceKey(i, p));
        if (v == null) return null; // Corrupt/partial slot — treat as empty.
        pieces.add(Color(v));
      }
      if (bg == null || board == null || accent == null) return null;
      return CustomSlotData(
        background: Color(bg),
        boardBackground: Color(board),
        accent: Color(accent),
        pieceColors: pieces,
      );
    });

    var activeId = prefs.getString(kActiveId) ?? defaultActiveId;
    // Guard against an active id pointing at a now-empty custom slot (e.g. if
    // storage was partially cleared): fall back to the default preset.
    if (activeId.startsWith('custom:')) {
      final idx = int.tryParse(activeId.substring('custom:'.length));
      if (idx == null || idx < 0 || idx >= slotCount || slots[idx] == null) {
        activeId = defaultActiveId;
      }
    }

    return PaletteSettings(activeId: activeId, slots: slots);
  }
}
