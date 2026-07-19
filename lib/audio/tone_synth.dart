import 'dart:math' as math;
import 'dart:typed_data';

import 'sound_config.dart';

/// Synthesizes a [SoundSpec] into a 16-bit mono PCM WAV byte buffer.
///
/// Pure Dart, no plugins — easy to unit test. The audio engine loads the
/// returned bytes from memory as if they were a `.wav` file.
Uint8List synthesize(SoundSpec spec) {
  const sr = SoundConfig.sampleRate;
  final noteSamples = math.max(1, (spec.noteDuration * sr).round());
  final gapSamples = (spec.gap * sr).round();
  final n = spec.degrees.length;

  final totalSamples =
      n == 0 ? noteSamples : (n - 1) * gapSamples + noteSamples;
  final buffer = Float64List(totalSamples);

  for (var i = 0; i < n; i++) {
    final freq = _frequencyForDegree(spec.degrees[i]);
    final start = i * gapSamples;
    for (var s = 0; s < noteSamples; s++) {
      final t = s / sr;
      final env = _envelope(s, noteSamples, spec.attack, spec.release);
      buffer[start + s] +=
          _wave(spec.waveform, freq, t) * env * spec.volume;
    }
  }

  return _encodeWav(buffer, sr);
}

/// Maps a pentatonic scale degree to a frequency in Hz. Degrees outside the
/// scale length wrap into adjacent octaves.
double _frequencyForDegree(int degree) {
  final scale = SoundConfig.scale;
  final len = scale.length;
  // Floor division / modulo that work for negative degrees.
  final octave = (degree / len).floor();
  final index = degree - octave * len;
  final semitones = scale[index] + 12 * octave;
  return SoundConfig.baseFrequency * math.pow(2, semitones / 12).toDouble();
}

double _wave(Waveform wave, double freq, double t) {
  final phase = 2 * math.pi * freq * t;
  switch (wave) {
    case Waveform.sine:
      return math.sin(phase);
    case Waveform.triangle:
      return (2 / math.pi) * math.asin(math.sin(phase));
    case Waveform.softSquare:
      // tanh-rounded square: fuller than a sine but without hard edges.
      return _tanh(2.5 * math.sin(phase));
  }
}

/// Soft pluck envelope: quick fade-in, exponential decay, and a fade-out at the
/// very end. The ramps at both ends keep every note click-free.
double _envelope(int s, int total, double attack, double release) {
  const sr = SoundConfig.sampleRate;
  final attackSamples = math.max(1, (attack * sr).round());
  final releaseSamples = math.max(1, (release * sr).round());

  var env = 1.0;
  if (s < attackSamples) {
    env *= s / attackSamples;
  }
  // Exponential decay across the note (to ~5% by the end).
  final decayProgress = (s - attackSamples) / math.max(1, total - attackSamples);
  if (decayProgress > 0) {
    env *= math.exp(-3.0 * decayProgress);
  }
  final fadeStart = total - releaseSamples;
  if (s > fadeStart) {
    env *= (total - s) / releaseSamples;
  }
  return env.clamp(0.0, 1.0);
}

double _tanh(double x) {
  final e2x = math.exp(2 * x);
  return (e2x - 1) / (e2x + 1);
}

/// Wraps normalized [-1, 1] samples in a 16-bit mono PCM WAV container.
Uint8List _encodeWav(Float64List samples, int sampleRate) {
  const bitsPerSample = 16;
  const channels = 1;
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final blockAlign = channels * bitsPerSample ~/ 8;
  final dataBytes = samples.length * blockAlign;

  final out = BytesBuilder();
  void writeString(String s) => out.add(s.codeUnits);
  void writeUint32(int v) {
    final b = ByteData(4)..setUint32(0, v, Endian.little);
    out.add(b.buffer.asUint8List());
  }

  void writeUint16(int v) {
    final b = ByteData(2)..setUint16(0, v, Endian.little);
    out.add(b.buffer.asUint8List());
  }

  writeString('RIFF');
  writeUint32(36 + dataBytes);
  writeString('WAVE');

  writeString('fmt ');
  writeUint32(16); // PCM chunk size
  writeUint16(1); // audio format = PCM
  writeUint16(channels);
  writeUint32(sampleRate);
  writeUint32(byteRate);
  writeUint16(blockAlign);
  writeUint16(bitsPerSample);

  writeString('data');
  writeUint32(dataBytes);

  final pcm = ByteData(dataBytes);
  for (var i = 0; i < samples.length; i++) {
    final clamped = samples[i].clamp(-1.0, 1.0);
    pcm.setInt16(i * 2, (clamped * 32767).round(), Endian.little);
  }
  out.add(pcm.buffer.asUint8List());

  return out.toBytes();
}
