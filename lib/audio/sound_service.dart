import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_settings.dart';
import 'music_config.dart';
import 'sound_config.dart';

/// Plays the pre-rendered sound effects and music loop bundled in
/// `assets/audio/` (see `tool/generate_audio.dart`, which renders them from
/// the synth configs — no synthesis happens at runtime).
///
/// A singleton, like [SoundConfig], so game and UI code can fire a sound with
/// `SoundService.instance.play(Sfx.rotate)`. Playback uses `audioplayers`
/// (pure platform channels, no native build step). Each SFX event gets its own
/// [AudioPool] (a small round-robin group of preloaded players) rather than a
/// single player: retriggering a sound before its previous play finished —
/// which happens routinely for `move`/`rotate` during fast input — used to
/// call `stop()` on the one player for that event, chopping the waveform off
/// at a non-zero sample and producing an audible click. A pool lets the new
/// play start on a fresh player while the old one rings out and finishes
/// naturally, so nothing gets cut off mid-sound. If audio fails to initialize
/// it degrades silently — every `play` becomes a no-op rather than throwing.
class SoundService {
  SoundService._();

  static final SoundService instance = SoundService._();

  final ValueNotifier<bool> musicEnabled = ValueNotifier<bool>(true);
  final ValueNotifier<bool> sfxEnabled = ValueNotifier<bool>(true);
  final ValueNotifier<double> musicVolume =
      ValueNotifier<double>(AudioSettings.kDefaultMusicVolume);
  final ValueNotifier<double> sfxVolume =
      ValueNotifier<double>(AudioSettings.kDefaultSfxVolume);

  bool _ready = false;
  final Map<Sfx, AudioPool> _pools = {};
  final Map<Sfx, DateTime> _lastPlayed = {};

  AudioPlayer? _musicPlayer;

  /// Loads saved preferences, wires every sound + the music loop to its
  /// asset, and starts the music if enabled. Safe to call once at startup;
  /// never throws.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settings = AudioSettings.load(prefs);
      musicEnabled.value = settings.musicEnabled;
      sfxEnabled.value = settings.sfxEnabled;
      musicVolume.value = settings.musicVolume;
      sfxVolume.value = settings.sfxVolume;
    } catch (_) {
      // Preferences unavailable — defaults (all on, full volume) stand.
    }

    try {
      // Make our players share the output instead of fighting over it. By
      // default every audioplayers player requests exclusive audio focus
      // (Android `AudioFocus.gain`), so the first SFX to fire evicts the
      // background music (`onAudioFocusChange(-1)` / `AUDIOFOCUS_LOSS`) and it
      // never comes back. `mixWithOthers` drops the focus request entirely on
      // Android and adds the mix option on iOS, so SFX and music coexist — and
      // we stop ducking other apps' audio too, which suits a chill game.
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
            .build(),
      );

      for (final sfx in SoundConfig.sounds.keys) {
        _pools[sfx] = await AudioPool.create(
          source: AssetSource('audio/${sfx.name}.wav'),
          maxPlayers: _poolSize(sfx),
        );
      }

      final music = AudioPlayer();
      // Awaited (unlike a `..` cascade) so the loop mode is actually applied
      // on the platform side before playback starts — otherwise the first
      // loop boundary can be hit while the player is still in its default
      // release-and-stop mode, causing a hiccup right at that seam.
      await music.setReleaseMode(ReleaseMode.loop);
      await music.setSource(AssetSource('audio/music.wav'));
      await music.setVolume(_effectiveMusicVolume);

      // Belt-and-suspenders looping. `ReleaseMode.loop` is honored inconsistently
      // across platforms (notably web), where the track can play through once
      // and then stop instead of looping. When that happens the player fires
      // `onPlayerComplete`; we restart it ourselves so the loop is seamless in
      // practice regardless of whether the platform's native looping worked.
      // Not stored/cancelled: the music player is a singleton that lives for
      // the whole app, so the subscription never needs tearing down.
      music.onPlayerComplete.listen((_) {
        if (musicEnabled.value) _resumeMusic();
      });
      _musicPlayer = music;

      _ready = true;
    } catch (e) {
      _ready = false;
      debugPrint('SoundService: audio disabled ($e)');
    }

    if (musicEnabled.value) _resumeMusic();
  }

  /// A couple of spare players is enough for any of these short one-shots to
  /// overlap with itself; `move`/`rotate` retrigger fastest so they get one
  /// extra.
  int _poolSize(Sfx sfx) => switch (sfx) {
        Sfx.move || Sfx.rotate => 3,
        _ => 2,
      };

  double get _effectiveSfxVolume =>
      SoundConfig.masterVolume * sfxVolume.value;
  double get _effectiveMusicVolume =>
      MusicConfig.masterVolume * musicVolume.value;

  /// (Re)starts the music. `resume()` continues a *paused* player from its
  /// current position, but is a no-op once the track has completed or been
  /// stopped — so in those states we rewind to the start first. Harmless
  /// mid-track (the seek only runs when the player isn't already playing).
  void _resumeMusic() {
    final player = _musicPlayer;
    if (player == null) return;
    unawaited(() async {
      try {
        final state = player.state;
        if (state == PlayerState.completed || state == PlayerState.stopped) {
          await player.seek(Duration.zero);
        }
        await player.resume();
      } catch (_) {
        // Music is optional ambience — a failed (re)start is non-fatal.
      }
    }());
  }

  void _pauseMusic() =>
      unawaited(_musicPlayer?.pause().catchError((Object _) {}));

  /// Pauses the music loop when the app leaves the foreground. Because we run
  /// with `mixWithOthers` (no audio-focus request — see [init]), the OS no
  /// longer stops our playback when the app is backgrounded or minimized, so we
  /// have to do it ourselves. Resumed via [ensureMusicPlaying] when the app
  /// comes back (only if music is still enabled).
  void pauseMusicForBackground() {
    if (_musicPlayer == null) return;
    _pauseMusic();
  }

  /// Re-asserts music playback if it's supposed to be on but isn't currently
  /// playing. Only intervenes when the state genuinely isn't `playing`, so it
  /// never interrupts an already-looping track — it's a self-heal for cases
  /// where a platform quirk (audio focus changes, a route transition, etc.)
  /// paused or dropped the loop out from under us. Called on every navigation
  /// event (see `main.dart`'s `NavigatorObserver`) and every [play], so music
  /// keeps going no matter which screen the player is on.
  void ensureMusicPlaying() {
    final player = _musicPlayer;
    if (!_ready || player == null || !musicEnabled.value) return;
    if (player.state != PlayerState.playing) _resumeMusic();
  }

  /// Plays [sfx] if audio is ready and SFX are enabled. Rapid repeats of the
  /// same sound are throttled so movement never turns into a machine-gun
  /// rattle; whatever gets through plays on its own pooled player, so an
  /// overlapping retrigger never cuts off the previous one.
  void play(Sfx sfx) {
    if (!_ready) return;
    ensureMusicPlaying();
    if (!sfxEnabled.value) return;
    final pool = _pools[sfx];
    if (pool == null) return;

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
    unawaited(pool.start(volume: _effectiveSfxVolume).catchError((Object _) {
      return () async {};
    }));
  }

  int _minGapMs(Sfx sfx) => switch (sfx) {
        Sfx.move => 45,
        Sfx.rotate => 30,
        _ => 0,
      };

  Future<void> setMusicEnabled(bool value) async {
    musicEnabled.value = value;
    if (value) {
      _resumeMusic();
    } else {
      _pauseMusic();
    }
    await _persist((prefs) => prefs.setBool(AudioSettings.kMusicEnabled, value));
  }

  Future<void> setSfxEnabled(bool value) async {
    sfxEnabled.value = value;
    await _persist((prefs) => prefs.setBool(AudioSettings.kSfxEnabled, value));
  }

  /// Applies [volume] to the music player immediately. Pass
  /// `persist: true` (e.g. on a slider's drag-end) to save it — call sites
  /// should avoid persisting on every drag frame.
  Future<void> setMusicVolume(double volume, {bool persist = false}) async {
    musicVolume.value = volume.clamp(0.0, 1.0);
    unawaited(
      _musicPlayer?.setVolume(_effectiveMusicVolume).catchError((Object _) {}),
    );
    if (persist) {
      final value = musicVolume.value;
      await _persist((prefs) => prefs.setDouble(AudioSettings.kMusicVolume, value));
    }
  }

  /// Updates the volume used for the *next* [play] call. SFX are all under a
  /// third of a second, so there's no player to reach back into and adjust
  /// mid-flight — nor any point doing so.
  Future<void> setSfxVolume(double volume, {bool persist = false}) async {
    sfxVolume.value = volume.clamp(0.0, 1.0);
    if (persist) {
      final value = sfxVolume.value;
      await _persist((prefs) => prefs.setDouble(AudioSettings.kSfxVolume, value));
    }
  }

  Future<void> _persist(
      Future<void> Function(SharedPreferences prefs) write) async {
    try {
      await write(await SharedPreferences.getInstance());
    } catch (_) {
      // Non-fatal: the setting still works for this session.
    }
  }
}
