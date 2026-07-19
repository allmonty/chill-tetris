import 'dart:math' as math;
import 'dart:typed_data';

import 'sound_config.dart';
import 'synth_core.dart';

/// Synthesizes a [SoundSpec] into a 16-bit mono PCM WAV byte buffer.
///
/// Pure Dart, no plugins — easy to unit test. The audio engine loads the
/// returned bytes from memory as if they were a `.wav` file. The actual DSP
/// (pitch, waveforms, envelope, WAV encoding) lives in `synth_core.dart`, which
/// is shared with the background-music synth.
Uint8List synthesize(SoundSpec spec) {
  const sr = SoundConfig.sampleRate;
  final noteSamples = math.max(1, (spec.noteDuration * sr).round());
  final gapSamples = (spec.gap * sr).round();
  final n = spec.degrees.length;

  final totalSamples =
      n == 0 ? noteSamples : (n - 1) * gapSamples + noteSamples;
  final buffer = Float64List(totalSamples);

  for (var i = 0; i < n; i++) {
    final freq = frequencyForDegree(spec.degrees[i]);
    final start = i * gapSamples;
    for (var s = 0; s < noteSamples; s++) {
      final t = s / sr;
      final env = pluckEnvelope(
        s,
        noteSamples,
        attack: spec.attack,
        release: spec.release,
      );
      buffer[start + s] +=
          waveSample(spec.waveform, freq, t) * env * spec.volume;
    }
  }

  declickEdges(buffer);
  return encodeWav(buffer, sr);
}
