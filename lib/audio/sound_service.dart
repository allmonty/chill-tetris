import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sound_config.dart';
import 'tone_synth.dart';

/// Plays the synthesized sound effects.
///
/// A singleton, like [SoundConfig], so game and UI code can fire a sound with
/// `SoundService.instance.play(Sfx.rotate)`. Playback uses `audioplayers`
/// (pure platform channels, no native build step). Each event gets its own
/// player so different sounds overlap naturally. If audio fails to initialize
/// it degrades silently — every `play` becomes a no-op rather than throwing.
class SoundService {
  SoundService._();

  static final SoundService instance = SoundService._();

  static const _kEnabledKey = 'sound_enabled';

  final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);

  bool _ready = false;
  final Map<Sfx, AudioPlayer> _players = {};
  final Map<Sfx, Uint8List> _bytes = {};
  final Map<Sfx, DateTime> _lastPlayed = {};

  /// Loads the saved on/off preference and synthesizes every sound into a
  /// ready-to-play buffer. Safe to call once at startup; never throws.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled.value = prefs.getBool(_kEnabledKey) ?? true;
    } catch (_) {
      // Preferences unavailable — default to on.
    }

    try {
      for (final entry in SoundConfig.sounds.entries) {
        _bytes[entry.key] = synthesize(entry.value);
        _players[entry.key] = AudioPlayer()
          ..setReleaseMode(ReleaseMode.stop);
      }
      _ready = true;
    } catch (e) {
      _ready = false;
      debugPrint('SoundService: audio disabled ($e)');
    }
  }

  /// Plays [sfx] if audio is ready and enabled. Rapid repeats of the same sound
  /// are throttled so movement never turns into a machine-gun rattle.
  void play(Sfx sfx) {
    if (!_ready || !enabled.value) return;
    final player = _players[sfx];
    final bytes = _bytes[sfx];
    if (player == null || bytes == null) return;

    final minGapMs = _minGapMs(sfx);
    if (minGapMs > 0) {
      final last = _lastPlayed[sfx];
      final now = DateTime.now();
      if (last != null && now.difference(last).inMilliseconds < minGapMs) {
        return;
      }
      _lastPlayed[sfx] = now;
    }

    // Fire and forget; a missed or errored blip is harmless.
    unawaited(
      player
          .play(BytesSource(bytes), volume: SoundConfig.masterVolume)
          .catchError((Object _) {}),
    );
  }

  int _minGapMs(Sfx sfx) => switch (sfx) {
        Sfx.move => 45,
        Sfx.rotate => 30,
        _ => 0,
      };

  Future<void> setEnabled(bool value) async {
    enabled.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabledKey, value);
    } catch (_) {
      // Non-fatal: the toggle still works for this session.
    }
  }

  void toggle() => setEnabled(!enabled.value);
}
