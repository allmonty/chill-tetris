import 'dart:io';

import 'package:chill_tetris/audio/music_synth.dart';
import 'package:chill_tetris/audio/sound_config.dart';
import 'package:chill_tetris/audio/tone_synth.dart';
import 'package:flutter_test/flutter_test.dart';

const _regenerateHint = 'run: dart run tool/generate_audio.dart';

void main() {
  group('Committed audio assets', () {
    test('every Sfx wav matches its synth output', () {
      for (final entry in SoundConfig.sounds.entries) {
        final path = 'assets/audio/${entry.key.name}.wav';
        final file = File(path);
        expect(file.existsSync(), isTrue,
            reason: 'Missing $path — $_regenerateHint');
        expect(file.readAsBytesSync(), synthesize(entry.value),
            reason: 'Stale $path — $_regenerateHint');
      }
    });

    test('music.wav matches its synth output', () {
      final file = File('assets/audio/music.wav');
      expect(file.existsSync(), isTrue,
          reason: 'Missing assets/audio/music.wav — $_regenerateHint');
      expect(file.readAsBytesSync(), synthesizeMusic(),
          reason: 'Stale assets/audio/music.wav — $_regenerateHint');
    });
  });
}
