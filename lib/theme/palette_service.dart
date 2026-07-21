import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  bool get isPiece => index >= CustomSwatchRole.pieceI.index;

  /// 0..6 into `pieceColors` for the piece roles; -1 for the named roles.
  int get pieceIndex => isPiece ? index - CustomSwatchRole.pieceI.index : -1;

  String get label => switch (this) {
        CustomSwatchRole.background => 'Background',
        CustomSwatchRole.boardBackground => 'Board',
        CustomSwatchRole.accent => 'Accent',
        CustomSwatchRole.pieceI => 'I',
        CustomSwatchRole.pieceO => 'O',
        CustomSwatchRole.pieceT => 'T',
        CustomSwatchRole.pieceS => 'S',
        CustomSwatchRole.pieceZ => 'Z',
        CustomSwatchRole.pieceJ => 'J',
        CustomSwatchRole.pieceL => 'L',
      };
}

/// Owns the active [GamePalette] and the three custom slots, and makes changes
/// reactive: [current] drives the whole-app theme (via `PaletteScope` and a
/// listener in `main.dart`), while [revision] lets the Settings tab rebuild its
/// slot grid and active markers.
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

  /// Bumped on any slot or selection change so the Settings tab rebuilds.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  final List<CustomSlotData?> _slots =
      List<CustomSlotData?>.filled(PaletteSettings.slotCount, null);
  String _activeId = PaletteSettings.defaultActiveId;

  /// Read-only view of the three custom slots (null = empty).
  List<CustomSlotData?> get slots => List.unmodifiable(_slots);

  String get activeId => _activeId;

  bool isPresetActive(GamePalette preset) => _activeId == 'preset:${preset.presetId}';

  bool isCustomSlotActive(int index) => _activeId == 'custom:$index';

  /// Loads persisted personalization state. Safe to call once at startup;
  /// never throws — defaults stand on failure, matching `SoundService.init`.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settings = PaletteSettings.load(prefs);
      for (var i = 0; i < _slots.length; i++) {
        _slots[i] = settings.slots[i];
      }
      _activeId = settings.activeId;
      current.value = _resolveActive();
    } catch (_) {
      // Preferences unavailable — the mid-century default stands.
    }
  }

  GamePalette _resolveActive() {
    if (_activeId.startsWith('custom:')) {
      final idx = int.tryParse(_activeId.substring('custom:'.length));
      if (idx != null && idx >= 0 && idx < _slots.length && _slots[idx] != null) {
        return _derived(idx);
      }
    }
    if (_activeId.startsWith('preset:')) {
      final id = _activeId.substring('preset:'.length);
      for (final preset in GamePalette.presets) {
        if (preset.presetId == id) return preset;
      }
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
    _activeId = 'preset:${preset.presetId}';
    current.value = preset;
    revision.value++;
    await _persistActiveId();
  }

  /// Activate an already-filled custom slot. No-op for an empty slot.
  Future<void> selectCustomSlot(int index) async {
    if (_slots[index] == null) return;
    _activeId = 'custom:$index';
    current.value = _derived(index);
    revision.value++;
    await _persistActiveId();
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
    _activeId = 'custom:$slot';
    current.value = _derived(slot);
    revision.value++;
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
  void previewCustomSwatch(int slot, CustomSwatchRole role, Color color) {
    final d = _slots[slot] ??= _seed();
    _slots[slot] = switch (role) {
      CustomSwatchRole.background => d.copyWith(background: color),
      CustomSwatchRole.boardBackground => d.copyWith(boardBackground: color),
      CustomSwatchRole.accent => d.copyWith(accent: color),
      _ => d.copyWith(
          pieceColors: List<Color>.of(d.pieceColors)..[role.pieceIndex] = color,
        ),
    };
    _activeId = 'custom:$slot';
    current.value = _derived(slot);
    revision.value++;
  }

  /// Persists [slot] and the active selection once — call when the editor
  /// dialog closes.
  Future<void> commitCustomSlot(int slot) async {
    await _persistSlot(slot);
    await _persistActiveId();
  }

  Future<void> _persistActiveId() =>
      _persist((prefs) => prefs.setString(PaletteSettings.kActiveId, _activeId));

  Future<void> _persistSlot(int i) => _persist((prefs) async {
        final d = _slots[i];
        if (d == null) {
          await prefs.setBool(PaletteSettings.slotPresentKey(i), false);
          return;
        }
        await prefs.setBool(PaletteSettings.slotPresentKey(i), true);
        await prefs.setInt(
            PaletteSettings.slotBackgroundKey(i), d.background.toARGB32());
        await prefs.setInt(
            PaletteSettings.slotBoardKey(i), d.boardBackground.toARGB32());
        await prefs.setInt(
            PaletteSettings.slotAccentKey(i), d.accent.toARGB32());
        for (var p = 0; p < 7; p++) {
          await prefs.setInt(
              PaletteSettings.slotPieceKey(i, p), d.pieceColors[p].toARGB32());
        }
      });

  Future<void> _persist(
      Future<void> Function(SharedPreferences prefs) write) async {
    try {
      await write(await SharedPreferences.getInstance());
    } catch (_) {
      // Non-fatal: the change still applies for this session.
    }
  }
}
