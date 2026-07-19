import 'package:flutter/material.dart';

import '../audio/sound_config.dart';
import '../audio/sound_service.dart';
import '../theme/palette.dart';

/// Audio settings: separate enable + volume control for music and SFX.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const String route = '/settings';

  @override
  Widget build(BuildContext context) {
    final p = Palette.current;
    final sound = SoundService.instance;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        foregroundColor: p.textPrimary,
        elevation: 0,
        title: const Text('Settings'),
      ),
      body: ListView(
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
      ),
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
    final p = Palette.current;
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
