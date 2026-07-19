import 'sound_config.dart';

/// The background music — one gentle, looping ambient track, defined as data in
/// the same spirit as the color palette and the sound effects.
///
/// It's a slow, sparse "music box" loop: a soft low bass, a warm pad wash, and
/// a sparse melody, all in the pentatonic [SoundConfig.scale] so nothing ever
/// clashes. Notes decay, and any note whose tail runs past the loop end wraps
/// back to the start (see `music_synth.dart`), so the loop has no audible seam.
///
/// To reshape the music, edit the constants here — tempo, loop length, and the
/// flat list of notes. Each note is one line: when it starts, how long it
/// lasts (in beats), and which scale degree it plays.
class MusicNote {
  const MusicNote(
    this.startBeat,
    this.beats,
    this.degree, {
    this.volume = 0.4,
    this.waveform = Waveform.sine,
    this.attack = 0.01,
    this.release = 0.15,
  });

  /// Beat the note begins on (0-based, within the loop).
  final double startBeat;

  /// Length in beats.
  final double beats;

  /// Pitch as a scale degree (index into [SoundConfig.scale]); negatives and
  /// values past the scale length drop/raise by octaves.
  final int degree;

  final double volume;
  final Waveform waveform;
  final double attack;
  final double release;
}

class MusicConfig {
  const MusicConfig._();

  /// Music loudness, `0`–`1`. Sits below the sound effects so they stay clear.
  static double masterVolume = 0.22;

  /// Tempo. Low and unhurried keeps it calm.
  static double bpm = 63;

  /// Length of the loop in beats (16 = four 4/4 bars).
  static double loopBeats = 16;

  /// The whole track as a flat list of notes. Three loose "voices" share the
  /// list: a low bass, a soft pad wash, and a sparse melody.
  static const List<MusicNote> track = [
    // --- Bass: one warm low root per bar --------------------------------
    MusicNote(0, 3.6, -7, waveform: Waveform.triangle, volume: 0.5, attack: 0.03),
    MusicNote(4, 3.6, -5, waveform: Waveform.triangle, volume: 0.5, attack: 0.03),
    MusicNote(8, 3.6, -6, waveform: Waveform.triangle, volume: 0.5, attack: 0.03),
    MusicNote(12, 3.6, -5, waveform: Waveform.triangle, volume: 0.5, attack: 0.03),

    // --- Pad: a soft swelling chord wash each bar ------------------------
    MusicNote(0, 3.8, 0, volume: 0.20, attack: 0.18, release: 0.5),
    MusicNote(0, 3.8, 2, volume: 0.18, attack: 0.18, release: 0.5),
    MusicNote(0, 3.8, 4, volume: 0.16, attack: 0.18, release: 0.5),
    MusicNote(4, 3.8, -3, volume: 0.20, attack: 0.18, release: 0.5),
    MusicNote(4, 3.8, 0, volume: 0.18, attack: 0.18, release: 0.5),
    MusicNote(4, 3.8, 2, volume: 0.16, attack: 0.18, release: 0.5),
    MusicNote(8, 3.8, -1, volume: 0.20, attack: 0.18, release: 0.5),
    MusicNote(8, 3.8, 2, volume: 0.18, attack: 0.18, release: 0.5),
    MusicNote(8, 3.8, 4, volume: 0.16, attack: 0.18, release: 0.5),
    MusicNote(12, 3.8, -3, volume: 0.20, attack: 0.18, release: 0.5),
    MusicNote(12, 3.8, 0, volume: 0.18, attack: 0.18, release: 0.5),
    MusicNote(12, 3.8, 2, volume: 0.16, attack: 0.18, release: 0.5),

    // --- Melody: sparse, unhurried, with space to breathe ---------------
    MusicNote(1.0, 1.4, 4, volume: 0.30, release: 0.2),
    MusicNote(2.5, 1.2, 2, volume: 0.28, release: 0.2),
    MusicNote(5.0, 1.4, 5, volume: 0.30, release: 0.2),
    MusicNote(6.5, 1.4, 4, volume: 0.28, release: 0.2),
    MusicNote(9.0, 1.0, 7, volume: 0.28, release: 0.2),
    MusicNote(10.0, 1.0, 4, volume: 0.28, release: 0.2),
    MusicNote(11.0, 1.2, 2, volume: 0.28, release: 0.2),
    MusicNote(13.0, 1.4, 4, volume: 0.30, release: 0.2),
    // Final long note; its tail wraps around to the loop start seamlessly.
    MusicNote(14.5, 2.0, 0, volume: 0.30, release: 0.3),
  ];
}
