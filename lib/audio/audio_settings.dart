import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted audio preferences: separate enable + volume for music and SFX.
///
/// A pure holder so the load/migration logic is unit-testable without
/// touching [SoundService] or any audio plugin.
@immutable
class AudioSettings {
  const AudioSettings({
    required this.musicEnabled,
    required this.sfxEnabled,
    required this.musicVolume,
    required this.sfxVolume,
  });

  static const kMusicEnabled = 'music_enabled';
  static const kSfxEnabled = 'sfx_enabled';
  static const kMusicVolume = 'music_volume';
  static const kSfxVolume = 'sfx_volume';

  /// The single on/off toggle this replaces. Read once for migration, then
  /// removed so it can't reapply on a later load.
  static const kLegacyEnabled = 'sound_enabled';

  /// Music starts quieter than SFX by default — it's meant to sit under the
  /// game, not compete with it.
  static const kDefaultMusicVolume = 0.5;
  static const kDefaultSfxVolume = 1.0;

  final bool musicEnabled;
  final bool sfxEnabled;

  /// 0..1 trim applied on top of [SoundConfig.masterVolume] /
  /// [MusicConfig.masterVolume]; 1.0 reproduces the original loudness.
  final double musicVolume;
  final double sfxVolume;

  /// Reads settings from [prefs], migrating the legacy single toggle the
  /// first time this runs: if neither new key is present but the old
  /// `sound_enabled` is, both channels start at that value and the legacy
  /// key is deleted so it can't be read again.
  static AudioSettings load(SharedPreferences prefs) {
    final hasNewKeys =
        prefs.containsKey(kMusicEnabled) || prefs.containsKey(kSfxEnabled);
    final legacy = prefs.getBool(kLegacyEnabled);

    final defaultEnabled = (!hasNewKeys && legacy != null) ? legacy : true;

    final musicEnabled = prefs.getBool(kMusicEnabled) ?? defaultEnabled;
    final sfxEnabled = prefs.getBool(kSfxEnabled) ?? defaultEnabled;

    if (!hasNewKeys && legacy != null) {
      unawaited(prefs.remove(kLegacyEnabled));
    }

    return AudioSettings(
      musicEnabled: musicEnabled,
      sfxEnabled: sfxEnabled,
      musicVolume: (prefs.getDouble(kMusicVolume) ?? kDefaultMusicVolume)
          .clamp(0.0, 1.0),
      sfxVolume:
          (prefs.getDouble(kSfxVolume) ?? kDefaultSfxVolume).clamp(0.0, 1.0),
    );
  }
}
