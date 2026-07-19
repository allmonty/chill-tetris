import 'dart:math' as math;
import 'dart:typed_data';

import 'sound_config.dart';

/// Shared low-level synthesis used by both the sound effects (`tone_synth`) and
/// the background music (`music_synth`): pitch mapping, waveforms, envelopes,
/// and WAV encoding. Keeping these here means both use identical, consonant
/// pitches and timbres.

/// Maps a pentatonic scale degree to a frequency in Hz. Degrees outside the
/// scale length wrap into adjacent octaves, so any integer stays consonant.
double frequencyForDegree(int degree) {
  final scale = SoundConfig.scale;
  final len = scale.length;
  final octave = (degree / len).floor();
  final index = degree - octave * len;
  final semitones = scale[index] + 12 * octave;
  return SoundConfig.baseFrequency * math.pow(2, semitones / 12).toDouble();
}

double waveSample(Waveform wave, double freq, double t) {
  final phase = 2 * math.pi * freq * t;
  switch (wave) {
    case Waveform.sine:
      return math.sin(phase);
    case Waveform.triangle:
      return (2 / math.pi) * math.asin(math.sin(phase));
    case Waveform.softSquare:
      return _tanh(2.5 * math.sin(phase));
  }
}

/// Soft pluck envelope: quick fade-in, exponential decay, and a fade-out at the
/// very end. The ramps at both ends keep every note click-free.
double pluckEnvelope(
  int s,
  int total, {
  required double attack,
  required double release,
}) {
  const sr = SoundConfig.sampleRate;
  final attackSamples = math.max(1, (attack * sr).round());
  final releaseSamples = math.max(1, (release * sr).round());

  var env = 1.0;
  if (s < attackSamples) {
    env *= s / attackSamples;
  }
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

/// Forces the very first and last [fadeSamples] samples of [buffer] toward
/// zero. A [pluckEnvelope]'s release ramp only ever gets *close* to zero (it's
/// an asymptotic decay plus a linear tail), so a clip's last sample can be a
/// small but non-zero value; encoding stops right there with no further
/// ramp-down, which is an audible click. This guarantees a silent start and
/// end regardless — for a one-shot sound that's a true silence pad, and for a
/// looping buffer it also guarantees the loop seam itself is silent.
void declickEdges(Float64List buffer, {int fadeSamples = 32}) {
  final n = math.min(fadeSamples, buffer.length ~/ 2);
  for (var i = 0; i < n; i++) {
    final fade = i / n;
    buffer[i] *= fade;
    buffer[buffer.length - 1 - i] *= fade;
  }
}

/// Wraps normalized [-1, 1] samples in a 16-bit mono PCM WAV container.
Uint8List encodeWav(Float64List samples, int sampleRate) {
  const bitsPerSample = 16;
  const channels = 1;
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final blockAlign = channels * bitsPerSample ~/ 8;
  final dataBytes = samples.length * blockAlign;

  final out = BytesBuilder();
  void writeString(String s) => out.add(s.codeUnits);
  void writeUint32(int v) =>
      out.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void writeUint16(int v) =>
      out.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());

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
