import 'dart:typed_data';

import 'package:chill_tetris/audio/sound_config.dart';
import 'package:chill_tetris/audio/tone_synth.dart';
import 'package:flutter_test/flutter_test.dart';

String _ascii(Uint8List b, int start, int len) =>
    String.fromCharCodes(b.sublist(start, start + len));

int _u32(Uint8List b, int o) =>
    b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);

void main() {
  group('WAV synthesis', () {
    final spec = SoundConfig.sounds[Sfx.lineClear1]!;
    final wav = synthesize(spec);

    test('has a valid RIFF/WAVE header', () {
      expect(_ascii(wav, 0, 4), 'RIFF');
      expect(_ascii(wav, 8, 4), 'WAVE');
      expect(_ascii(wav, 12, 4), 'fmt ');
      expect(_ascii(wav, 36, 4), 'data');
    });

    test('declares 16-bit mono PCM at the configured sample rate', () {
      expect(_u32(wav, 24), SoundConfig.sampleRate); // sample rate
      expect(wav[22], 1); // channels (low byte of uint16)
      expect(wav[34], 16); // bits per sample (low byte)
      expect(wav[20], 1); // audio format = PCM
    });

    test('data length matches the note timing', () {
      const sr = SoundConfig.sampleRate;
      final noteSamples = (spec.noteDuration * sr).round();
      final gapSamples = (spec.gap * sr).round();
      final expected =
          ((spec.degrees.length - 1) * gapSamples + noteSamples) * 2;
      expect(_u32(wav, 40), expected); // data chunk size in bytes
    });

    test('contains actual signal (not silence)', () {
      final data = wav.buffer.asByteData();
      var peak = 0;
      for (var i = 44; i + 1 < wav.length; i += 2) {
        peak = peak > data.getInt16(i, Endian.little).abs()
            ? peak
            : data.getInt16(i, Endian.little).abs();
      }
      expect(peak, greaterThan(1000)); // audible amplitude
      expect(peak, lessThanOrEqualTo(32767)); // never clips past int16
    });

    test('every configured sound synthesizes to a non-empty buffer', () {
      for (final entry in SoundConfig.sounds.entries) {
        final bytes = synthesize(entry.value);
        expect(bytes.length, greaterThan(44),
            reason: '${entry.key} produced no audio data');
      }
    });
  });
}
