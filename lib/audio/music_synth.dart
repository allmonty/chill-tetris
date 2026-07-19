import 'dart:math' as math;
import 'dart:typed_data';

import 'music_config.dart';
import 'sound_config.dart';
import 'synth_core.dart';

/// Synthesizes [MusicConfig.track] into a single looping WAV buffer.
///
/// The buffer is exactly one loop long. A note whose tail extends past the loop
/// end wraps around and is summed onto the start of the buffer, so when the
/// player repeats the clip the tail continues seamlessly into the next pass —
/// no click, no gap. The result is normalized to use the headroom; final
/// loudness is set by the player's volume ([MusicConfig.masterVolume]).
Uint8List synthesizeMusic() {
  const sr = SoundConfig.sampleRate;
  final secPerBeat = 60.0 / MusicConfig.bpm;
  final total = math.max(1, (MusicConfig.loopBeats * secPerBeat * sr).round());
  final buffer = Float64List(total);

  for (final note in MusicConfig.track) {
    final freq = frequencyForDegree(note.degree);
    final start = (note.startBeat * secPerBeat * sr).round();
    final len = math.max(1, (note.beats * secPerBeat * sr).round());
    for (var s = 0; s < len; s++) {
      final t = s / sr;
      final env = pluckEnvelope(
        s,
        len,
        attack: note.attack,
        release: note.release,
      );
      final idx = (start + s) % total; // wrap the tail for a seamless loop
      buffer[idx] += waveSample(note.waveform, freq, t) * env * note.volume;
    }
  }

  // Normalize to ~0.9 peak so we use the dynamic range without clipping.
  var peak = 0.0;
  for (final v in buffer) {
    final a = v.abs();
    if (a > peak) peak = a;
  }
  if (peak > 0) {
    final norm = 0.9 / peak;
    for (var i = 0; i < total; i++) {
      buffer[i] *= norm;
    }
  }

  return encodeWav(buffer, sr);
}
