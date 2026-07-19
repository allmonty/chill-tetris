/// The "sound palette" — every sound effect defined as data you can tweak.
///
/// Sounds are synthesized at runtime from these specs (see `tone_synth.dart`),
/// so there are no audio files to manage. To keep the game relaxing, every
/// note is a *degree of a pentatonic scale*: pentatonic notes never clash, so
/// you can freely retune a sound and it will still sound pleasant. Prefer soft
/// waveforms, short durations, and low volumes.
///
/// This mirrors the color palette in `theme/palette.dart`: to reshape the
/// game's audio, edit the constants here — nothing else.
library;

/// Waveform timbre, softest first.
enum Waveform { sine, triangle, softSquare }

/// The game events that make a sound.
enum Sfx {
  uiTap,
  move,
  rotate,
  hardDrop,
  lock,
  lineClear1,
  lineClear2,
  lineClear3,
  lineClear4,
  levelWin,
  gameOver,
}

/// One sound: a short sequence (or chord) of pentatonic notes with a soft
/// pluck envelope.
class SoundSpec {
  const SoundSpec({
    required this.degrees,
    this.waveform = Waveform.sine,
    this.noteDuration = 0.14,
    this.gap = 0.07,
    this.attack = 0.006,
    this.release = 0.05,
    this.volume = 0.5,
  });

  /// Notes as scale degrees (indices into [SoundConfig.scale]). Values outside
  /// the scale length wrap into higher/lower octaves, so any integer is
  /// consonant. Played in sequence; use [gap] `0` to play them as a chord.
  final List<int> degrees;

  final Waveform waveform;

  /// Seconds each note sounds.
  final double noteDuration;

  /// Seconds between note starts. `0` overlaps them into a chord.
  final double gap;

  /// Fade-in seconds (prevents clicks).
  final double attack;

  /// Fade-out seconds (prevents clicks).
  final double release;

  /// Per-sound loudness, `0`–`1`, before the master volume.
  final double volume;
}

/// Global audio tuning. Change these to reshape the whole game's sound.
class SoundConfig {
  const SoundConfig._();

  /// Overall loudness, `0`–`1`. Kept low so the game stays gentle.
  static double masterVolume = 0.4;

  /// Frequency of scale degree 0, in Hz. G4 (392) is mellow and mid-range.
  static double baseFrequency = 392.0;

  /// Major pentatonic (C-D-E-G-A pattern). Consonant in every combination.
  static const List<int> scale = [0, 2, 4, 7, 9];

  static const int sampleRate = 44100;

  /// One spec per event. Tweak freely — it all stays pentatonic.
  static const Map<Sfx, SoundSpec> sounds = {
    // Soft, quiet UI tick.
    Sfx.uiTap: SoundSpec(
      degrees: [2],
      noteDuration: 0.10,
      release: 0.06,
      volume: 0.30,
    ),
    // Very subtle move blip (throttled in the service so it never spams).
    Sfx.move: SoundSpec(
      degrees: [0],
      noteDuration: 0.05,
      attack: 0.003,
      release: 0.03,
      volume: 0.16,
    ),
    // Light upward pluck when rotating.
    Sfx.rotate: SoundSpec(
      degrees: [4],
      noteDuration: 0.08,
      release: 0.05,
      volume: 0.24,
    ),
    // Quick soft descending run for a hard drop ("release").
    Sfx.hardDrop: SoundSpec(
      degrees: [4, 2, 0],
      noteDuration: 0.05,
      gap: 0.028,
      release: 0.03,
      volume: 0.26,
    ),
    // Low, woody "tock" when a piece lands.
    Sfx.lock: SoundSpec(
      degrees: [-3],
      waveform: Waveform.triangle,
      noteDuration: 0.12,
      release: 0.07,
      volume: 0.38,
    ),
    // Line clears: gentle ascending arpeggios, bigger for more lines.
    Sfx.lineClear1: SoundSpec(degrees: [0, 2, 4], gap: 0.06, volume: 0.38),
    Sfx.lineClear2: SoundSpec(degrees: [0, 2, 4, 5], gap: 0.06, volume: 0.40),
    Sfx.lineClear3: SoundSpec(degrees: [0, 2, 4, 5, 7], gap: 0.06, volume: 0.42),
    Sfx.lineClear4:
        SoundSpec(degrees: [0, 2, 4, 7, 9, 11], gap: 0.055, volume: 0.46),
    // Happy little flourish on a level win.
    Sfx.levelWin: SoundSpec(
      degrees: [0, 2, 4, 7, 9, 12],
      noteDuration: 0.16,
      gap: 0.10,
      release: 0.08,
      volume: 0.42,
    ),
    // Soft descending sigh on game over.
    Sfx.gameOver: SoundSpec(
      degrees: [4, 2, 0, -3],
      waveform: Waveform.triangle,
      noteDuration: 0.22,
      gap: 0.13,
      release: 0.12,
      volume: 0.36,
    ),
  };
}
