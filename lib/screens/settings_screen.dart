import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../audio/sound_config.dart';
import '../audio/sound_service.dart';
import '../theme/palette.dart';
import '../theme/palette_scope.dart';
import '../theme/palette_service.dart';
import '../theme/palette_settings.dart';

/// Two tabs: Audio (music + SFX) and Personalization (color palettes).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const String route = '/settings';

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: p.background,
        appBar: AppBar(
          backgroundColor: p.background,
          foregroundColor: p.textPrimary,
          elevation: 0,
          title: const Text('Settings'),
          bottom: TabBar(
            labelColor: p.textPrimary,
            unselectedLabelColor: p.textSecondary,
            indicatorColor: p.accent,
            tabs: const [
              Tab(text: 'Audio'),
              Tab(text: 'Personalization'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AudioTab(),
            _PersonalizationTab(),
          ],
        ),
      ),
    );
  }
}

/// Audio settings: separate enable + volume control for music and SFX.
class _AudioTab extends StatelessWidget {
  const _AudioTab();

  @override
  Widget build(BuildContext context) {
    final sound = SoundService.instance;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _AudioSection(
          icon: Icons.music_note_rounded,
          label: 'MUSIC',
          enabled: sound.musicEnabled,
          volume: sound.musicVolume,
          onToggle: sound.setMusicEnabled,
          onVolumeChanged: (v) => sound.setMusicVolume(v),
          onVolumeChangeEnd: (v) => sound.setMusicVolume(v, persist: true),
        ),
        const SizedBox(height: 16),
        _AudioSection(
          icon: Icons.graphic_eq_rounded,
          label: 'SOUND EFFECTS',
          enabled: sound.sfxEnabled,
          volume: sound.sfxVolume,
          onToggle: sound.setSfxEnabled,
          onVolumeChanged: (v) => sound.setSfxVolume(v),
          onVolumeChangeEnd: (v) {
            sound.setSfxVolume(v, persist: true);
            sound.play(Sfx.uiTap);
          },
        ),
      ],
    );
  }
}

class _AudioSection extends StatelessWidget {
  const _AudioSection({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.volume,
    required this.onToggle,
    required this.onVolumeChanged,
    required this.onVolumeChangeEnd,
  });

  final IconData icon;
  final String label;
  final ValueNotifier<bool> enabled;
  final ValueNotifier<double> volume;
  final ValueChanged<bool> onToggle;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<double> onVolumeChangeEnd;

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: ValueListenableBuilder<bool>(
        valueListenable: enabled,
        builder: (_, isEnabled, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: p.textPrimary, size: 20),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                    color: p.textSecondary,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: isEnabled,
                  activeThumbColor: p.accent,
                  onChanged: onToggle,
                ),
              ],
            ),
            ValueListenableBuilder<double>(
              valueListenable: volume,
              builder: (_, value, _) => Row(
                children: [
                  Icon(Icons.volume_down_rounded,
                      color: p.textSecondary, size: 18),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: p.accent,
                        inactiveTrackColor: p.background,
                        thumbColor: p.accent,
                      ),
                      child: Slider(
                        value: value,
                        onChanged: isEnabled ? onVolumeChanged : null,
                        onChangeEnd: isEnabled ? onVolumeChangeEnd : null,
                      ),
                    ),
                  ),
                  Icon(Icons.volume_up_rounded,
                      color: p.textSecondary, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Personalization: pick a preset palette or build your own in one of three
/// custom slots. Rebuilds on [PaletteService.revision] so slot previews and the
/// active-selection markers stay in sync.
class _PersonalizationTab extends StatelessWidget {
  const _PersonalizationTab();

  @override
  Widget build(BuildContext context) {
    final service = PaletteService.instance;
    return AnimatedBuilder(
      animation: service.revision,
      builder: (context, _) {
        final p = PaletteScope.of(context);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SectionCard(
              label: 'PRESET PALETTES',
              child: Column(
                children: [
                  for (var i = 0; i < GamePalette.presets.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _PresetRow(
                      palette: GamePalette.presets[i],
                      active: service.isPresetActive(GamePalette.presets[i]),
                      onTap: () {
                        SoundService.instance.play(Sfx.uiTap);
                        service.selectPreset(GamePalette.presets[i]);
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              label: 'CUSTOM PALETTES',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < PaletteSettings.slotCount; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(
                          child: _SlotCard(
                            slot: i,
                            data: service.slots[i],
                            active: service.isCustomSlotActive(i),
                            onActivate: () {
                              SoundService.instance.play(Sfx.uiTap);
                              service.selectCustomSlot(i);
                            },
                            onEdit: () => _openEditor(context, i),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tap + to build a palette from the one in use. '
                    'Tap a saved slot to use it, or ✎ to edit it.',
                    style: TextStyle(fontSize: 12, color: p.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openEditor(BuildContext context, int slot) async {
    final service = PaletteService.instance;
    SoundService.instance.play(Sfx.uiTap);
    // Materialize + activate the slot so edits preview live; persist on close.
    service.beginEditSlot(slot);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaletteEditorSheet(slot: slot),
    );
    await service.commitCustomSlot(slot);
  }
}

/// A titled rounded card matching the audio sections' look.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
              color: p.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.palette,
    required this.active,
    required this.onTap,
  });

  final GamePalette palette;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: p.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? p.accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            _SwatchStrip(colors: _previewColors(palette)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                palette.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: p.textPrimary,
                ),
              ),
            ),
            if (active) Icon(Icons.check_circle, color: p.accent, size: 22),
          ],
        ),
      ),
    );
  }
}

/// One custom slot: an empty "+" tile, or a filled preview that activates on
/// tap and re-opens the editor via its ✎ button.
class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.data,
    required this.active,
    required this.onActivate,
    required this.onEdit,
  });

  final int slot;
  final CustomSlotData? data;
  final bool active;
  final VoidCallback onActivate;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    final filled = data != null;
    return AspectRatio(
      aspectRatio: 1,
      child: GestureDetector(
        onTap: filled ? onActivate : onEdit,
        child: Container(
          decoration: BoxDecoration(
            color: p.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? p.accent : Colors.transparent,
              width: 2,
            ),
          ),
          child: filled
              ? _SlotPreview(
                  data: data!,
                  active: active,
                  onEdit: onEdit,
                  fg: p.textOnAccent,
                  accent: p.accent,
                )
              : Center(
                  child: Icon(Icons.add, color: p.textSecondary, size: 30),
                ),
        ),
      ),
    );
  }
}

class _SlotPreview extends StatelessWidget {
  const _SlotPreview({
    required this.data,
    required this.active,
    required this.onEdit,
    required this.fg,
    required this.accent,
  });

  final CustomSlotData data;
  final bool active;
  final VoidCallback onEdit;
  final Color fg;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Swatch grid fills the tile.
        Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _colorRow([data.background, data.boardBackground, data.accent]),
              const SizedBox(height: 4),
              _colorRow(data.pieceColors.sublist(0, 4)),
              const SizedBox(height: 4),
              _colorRow(data.pieceColors.sublist(4, 7)),
            ],
          ),
        ),
        if (active)
          Positioned(
            top: 4,
            left: 4,
            child: Icon(Icons.check_circle, color: accent, size: 18),
          ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: onEdit,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.edit, color: fg.withValues(alpha: 0.9), size: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _colorRow(List<Color> colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final c in colors)
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

class _SwatchStrip extends StatelessWidget {
  const _SwatchStrip({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final c in colors)
          Container(
            width: 16,
            height: 24,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

List<Color> _previewColors(GamePalette palette) => [
      palette.background,
      palette.accent,
      ...palette.pieceColors.take(4),
    ];

/// Bottom sheet listing the ten editable swatches. Tapping one opens a color
/// picker whose changes preview live across the app; the sheet's tiles refresh
/// via [PaletteService.revision].
class _PaletteEditorSheet extends StatelessWidget {
  const _PaletteEditorSheet({required this.slot});

  final int slot;

  @override
  Widget build(BuildContext context) {
    final service = PaletteService.instance;
    final p = PaletteScope.of(context);
    return AnimatedBuilder(
      animation: service.revision,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: p.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: p.textSecondary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'EDIT PALETTE',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                    color: p.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final role in CustomSwatchRole.values)
                      _EditorTile(
                        label: role.label,
                        color: service.swatchColor(slot, role),
                        onTap: () => _pickColor(context, slot, role),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () {
                      SoundService.instance.play(Sfx.uiTap);
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.accent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: p.textOnAccent,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _pickColor(BuildContext context, int slot, CustomSwatchRole role) {
    final service = PaletteService.instance;
    final p = PaletteScope.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: p.surface,
        title: Text(role.label, style: TextStyle(color: p.textPrimary)),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: service.swatchColor(slot, role),
            onColorChanged: (c) => service.previewCustomSwatch(slot, role, c),
            enableAlpha: false,
            hexInputBar: true,
            portraitOnly: true,
            pickerAreaHeightPercent: 0.8,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Done', style: TextStyle(color: p.accent)),
          ),
        ],
      ),
    );
  }
}

class _EditorTile extends StatelessWidget {
  const _EditorTile({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: p.textSecondary.withValues(alpha: 0.3),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}
