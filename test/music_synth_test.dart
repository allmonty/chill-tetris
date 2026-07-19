import 'dart:typed_data';

import 'package:chill_tetris/audio/music_config.dart';
import 'package:chill_tetris/audio/music_synth.dart';
import 'package:chill_tetris/audio/sound_config.dart';
import 'package:flutter_test/flutter_test.dart';

String _ascii(Uint8List b, int start, int len) =>
    String.fromCharCodes(b.sublist(start, start + len));

int _u32(Uint8List b, int o) =>
    b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);

void main() {
  group('music synthesis', () {
    final wav = synthesizeMusic();

    test('is a valid WAV', () {
      expect(_ascii(wav, 0, 4), 'RIFF');
      expect(_ascii(wav, 8, 4), 'WAVE');
      expect(_u32(wav, 24), SoundConfig.sampleRate);
    });

    test('buffer length matches the loop duration', () {
      const sr = SoundConfig.sampleRate;
      final secPerBeat = 60.0 / MusicConfig.bpm;
      final expectedSamples = (MusicConfig.loopBeats * secPerBeat * sr).round();
      expect(_u32(wav, 40), expectedSamples * 2); // 16-bit mono data bytes
    });

    test('contains signal and never clips', () {
      final data = wav.buffer.asByteData();
      var peak = 0;
      for (var i = 44; i + 1 < wav.length; i += 2) {
        final v = data.getInt16(i, Endian.little).abs();
        if (v > peak) peak = v;
      }
      expect(peak, greaterThan(3000)); // audible
      expect(peak, lessThanOrEqualTo(32767)); // no clipping
    });
  });
}
