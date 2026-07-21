import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which palette is active: a built-in preset or one of the custom slots.
/// A small tagged union so the `preset:`/`custom:` storage encoding is parsed
/// and built in exactly one place, instead of string-munged at every call site.
sealed class PaletteSelection {
  const PaletteSelection();

  static const PaletteSelection defaultSelection =
      PresetSelection('midCenturyModern');

  /// The value persisted under [PaletteSettings.kActiveId].
  String get storageKey;

  /// Parses a stored key, falling back to [defaultSelection] for anything
  /// malformed or unrecognized.
  static PaletteSelection parse(String raw) {
    const presetTag = 'preset:';
    const customTag = 'custom:';
    if (raw.startsWith(customTag)) {
      final slot = int.tryParse(raw.substring(customTag.length));
      if (slot != null) return CustomSelection(slot);
    } else if (raw.startsWith(presetTag)) {
      return PresetSelection(raw.substring(presetTag.length));
    }
    return defaultSelection;
  }
}

final class PresetSelection extends PaletteSelection {
  const PresetSelection(this.presetId);

  final String presetId;

  @override
  String get storageKey => 'preset:$presetId';
}

final class CustomSelection extends PaletteSelection {
  const CustomSelection(this.slot);

  final int slot;

  @override
  String get storageKey => 'custom:$slot';
}

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

  /// Exactly [PaletteSettings.pieceCount] colors, ordered I/O/T/S/Z/J/L.
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
/// without touching `PaletteService` or any plugin. [load] and [writeSlot] are
/// the matched read/write pair for the per-slot key layout. Colors are stored
/// as ARGB ints via [Color.toARGB32] / restored via the `Color(int)`
/// constructor.
@immutable
class PaletteSettings {
  const PaletteSettings({required this.selection, required this.slots});

  static const int slotCount = 3;
  static const int pieceCount = 7;

  static const kActiveId = 'palette_active_id';

  /// The active selection.
  final PaletteSelection selection;

  /// [slotCount] entries; a null entry is an empty slot.
  final List<CustomSlotData?> slots;

  static String slotPresentKey(int i) => 'palette_custom_${i}_present';
  static String slotBackgroundKey(int i) => 'palette_custom_${i}_background';
  static String slotBoardKey(int i) => 'palette_custom_${i}_board';
  static String slotAccentKey(int i) => 'palette_custom_${i}_accent';
  static String slotPieceKey(int i, int piece) =>
      'palette_custom_${i}_piece_$piece';

  static PaletteSettings load(SharedPreferences prefs) {
    final slots =
        List<CustomSlotData?>.generate(slotCount, (i) => _readSlot(prefs, i));

    var selection = PaletteSelection.parse(
        prefs.getString(kActiveId) ?? PaletteSelection.defaultSelection.storageKey);
    // Guard against an active id pointing at a now-empty custom slot (e.g. if
    // storage was partially cleared): fall back to the default preset.
    if (selection is CustomSelection) {
      final i = selection.slot;
      if (i < 0 || i >= slotCount || slots[i] == null) {
        selection = PaletteSelection.defaultSelection;
      }
    }

    return PaletteSettings(selection: selection, slots: slots);
  }

  static CustomSlotData? _readSlot(SharedPreferences prefs, int i) {
    if (!(prefs.getBool(slotPresentKey(i)) ?? false)) return null;
    final bg = prefs.getInt(slotBackgroundKey(i));
    final board = prefs.getInt(slotBoardKey(i));
    final accent = prefs.getInt(slotAccentKey(i));
    if (bg == null || board == null || accent == null) return null;
    final pieces = <Color>[];
    for (var p = 0; p < pieceCount; p++) {
      final v = prefs.getInt(slotPieceKey(i, p));
      if (v == null) return null; // Corrupt/partial slot — treat as empty.
      pieces.add(Color(v));
    }
    return CustomSlotData(
      background: Color(bg),
      boardBackground: Color(board),
      accent: Color(accent),
      pieceColors: pieces,
    );
  }

  /// Writes (or clears, when [data] is null) slot [i] using the same key layout
  /// [load] reads.
  static Future<void> writeSlot(
      SharedPreferences prefs, int i, CustomSlotData? data) async {
    if (data == null) {
      await prefs.setBool(slotPresentKey(i), false);
      return;
    }
    await prefs.setBool(slotPresentKey(i), true);
    await prefs.setInt(slotBackgroundKey(i), data.background.toARGB32());
    await prefs.setInt(slotBoardKey(i), data.boardBackground.toARGB32());
    await prefs.setInt(slotAccentKey(i), data.accent.toARGB32());
    for (var p = 0; p < pieceCount; p++) {
      await prefs.setInt(slotPieceKey(i, p), data.pieceColors[p].toARGB32());
    }
  }
}
