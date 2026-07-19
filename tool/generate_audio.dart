// Renders every synthesized sound to a committed WAV asset.
//
// Run from the repo root whenever sound_config.dart or music_config.dart
// changes, then commit the result:
//
//   dart run tool/generate_audio.dart
//
// test/audio_assets_test.dart fails if the committed files drift from the
// synth configs.
import 'dart:io';

import 'package:chill_tetris/audio/music_synth.dart';
import 'package:chill_tetris/audio/sound_config.dart';
import 'package:chill_tetris/audio/tone_synth.dart';

void main() {
  final dir = Directory('assets/audio')..createSync(recursive: true);

  for (final entry in SoundConfig.sounds.entries) {
    _write('${dir.path}/${entry.key.name}.wav', synthesize(entry.value));
  }
  _write('${dir.path}/music.wav', synthesizeMusic());
}

void _write(String path, List<int> bytes) {
  File(path).writeAsBytesSync(bytes);
  final kb = (bytes.length / 1024).toStringAsFixed(1);
  stdout.writeln('$path  ($kb KB)');
}
