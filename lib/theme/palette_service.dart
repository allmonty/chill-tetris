import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/prefs_util.dart';
import 'palette.dart';
import 'palette_derivation.dart';
import 'palette_settings.dart';

/// The nine editable roles of a custom palette: three named colors plus the
/// seven piece colors (ordered I/O/T/S/Z/J/L).
enum CustomSwatchRole {
  background,
  boardBackground,
  accent,
  pieceI,
  pieceO,
  pieceT,
  pieceS,
  pieceZ,
  pieceJ,
  pieceL;

  /// 0..6 into `pieceColors`; only meaningful for the piece roles.
  int get pieceIndex => index - CustomSwatchRole.pieceI.index;

  String get label => switch (this) {
        CustomSwatchRole.background => 'Background',
        CustomSwatchRole.boardBackground => 'Board',
        CustomSwatchRole.accent => 'Accent',
        _ => 'IOTSZJL'[pieceIndex],
      };
}

/// Owns the active [GamePalette] and the three custom slots, and makes changes
/// reactive: [current] drives the whole-app theme (via `PaletteScope` and a
/// listener in `main.dart`) — widgets that read the palette rebuild when it
/// fires.
///
/// A singleton, mirroring `SoundService`: game and UI code read the live
/// palette, and the Settings UI drives changes through the methods here.
/// Persistence uses the drag-vs-commit split (`preview*` updates in memory for
/// live feedback; `commit*` writes once) so a color wheel drag doesn't hammer
/// `SharedPreferences`.
class PaletteService {
  PaletteService._();

  static final PaletteService instance = PaletteService._();

  /// The active palette. The reactive replacement for the old static field.
  final ValueNotifier<GamePalette> current =
      ValueNotifier<GamePalette>(GamePalette.midCenturyModern);

  final List<CustomSlotData?> _slots =
      List<CustomSlotData?>.filled(PaletteSettings.slotCount, null);
  PaletteSelection _selection = PaletteSelection.defaultSelection;

  /// Read-only view of the three custom slots (null = empty).
  List<CustomSlotData?> get slots => List.unmodifiable(_slots);

  bool isPresetActive(GamePalette preset) => switch (_selection) {
        PresetSelection(:final presetId) => presetId == preset.presetId,
        _ => false,
      };

  bool isCustomSlotActive(int index) => switch (_selection) {
        CustomSelection(:final slot) => slot == index,
        _ => false,
      };

  /// Loads persisted personalization state. Safe to call once at startup;
  /// never throws — defaults stand on failure, matching `SoundService.init`.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settings = PaletteSettings.load(prefs);
      _slots.setAll(0, settings.slots);
      _selection = settings.selection;
      current.value = _resolveActive();
    } catch (_) {
      // Preferences unavailable — the mid-century default stands.
    }
  }

  GamePalette _resolveActive() => switch (_selection) {
        CustomSelection(:final slot) => _derived(slot),
        PresetSelection(:final presetId) => _presetById(presetId),
      };

  GamePalette _presetById(String id) {
    for (final preset in GamePalette.presets) {
      if (preset.presetId == id) return preset;
    }
    return GamePalette.midCenturyModern;
  }

  GamePalette _derived(int slot) {
    final d = _slots[slot]!;
    return derivePalette(
      name: 'Custom ${slot + 1}',
      background: d.background,
      boardBackground: d.boardBackground,
      accent: d.accent,
      pieceColors: d.pieceColors,
    );
  }

  /// Activate a built-in preset.
  Future<void> selectPreset(GamePalette preset) async {
    _selection = PresetSelection(preset.presetId);
    current.value = preset;
    await _persistSelection();
  }

  /// Activate an already-filled custom slot. No-op for an empty slot.
  Future<void> selectCustomSlot(int index) async {
    if (_slots[index] == null) return;
    _activateCustom(index);
    await _persistSelection();
  }

  /// Point the active selection and live theme at custom [slot]. [slot] must
  /// be materialized (non-null).
  void _activateCustom(int slot) {
    _selection = CustomSelection(slot);
    current.value = _derived(slot);
  }

  /// The nine editable colors of the currently active palette — the starting
  /// point when a new (empty) slot's editor opens.
  CustomSlotData _seed() {
    final p = current.value;
    return CustomSlotData(
      background: p.background,
      boardBackground: p.boardBackground,
      accent: p.accent,
      pieceColors: List<Color>.of(p.pieceColors),
    );
  }

  /// Opens [slot] for editing: materializes it from the active palette if it's
  /// empty, and makes it the active theme so edits preview live. Persisted on
  /// [commitCustomSlot] when the editor closes.
  void beginEditSlot(int slot) {
    _slots[slot] ??= _seed();
    _activateCustom(slot);
  }

  /// The current color of [role] in [slot] (for rendering editor tiles and
  /// seeding the color picker). [slot] must have been materialized via
  /// [beginEditSlot].
  Color swatchColor(int slot, CustomSwatchRole role) {
    final d = _slots[slot]!;
    return switch (role) {
      CustomSwatchRole.background => d.background,
      CustomSwatchRole.boardBackground => d.boardBackground,
      CustomSwatchRole.accent => d.accent,
      _ => d.pieceColors[role.pieceIndex],
    };
  }

  /// Live, in-memory update of one swatch while the picker is being dragged —
  /// updates [current] so the whole app previews it, without persisting.
  /// The slot is already materialized by [beginEditSlot].
  void previewCustomSwatch(int slot, CustomSwatchRole role, Color color) {
    final d = _slots[slot]!;
    _slots[slot] = switch (role) {
      CustomSwatchRole.background => d.copyWith(background: color),
      CustomSwatchRole.boardBackground => d.copyWith(boardBackground: color),
      CustomSwatchRole.accent => d.copyWith(accent: color),
      _ => d.copyWith(
          pieceColors: List<Color>.of(d.pieceColors)..[role.pieceIndex] = color,
        ),
    };
    _activateCustom(slot);
  }

  /// Persists [slot] and the active selection once — call when the editor
  /// dialog closes.
  Future<void> commitCustomSlot(int slot) async {
    await persistPrefs((prefs) => PaletteSettings.writeSlot(prefs, slot, _slots[slot]));
    await _persistSelection();
  }

  Future<void> _persistSelection() => persistPrefs(
      (prefs) => prefs.setString(PaletteSettings.kActiveId, _selection.storageKey));
}
