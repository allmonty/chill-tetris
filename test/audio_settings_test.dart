import 'package:chill_tetris/audio/audio_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AudioSettings.load', () {
    test('defaults to both channels enabled, music at half SFX at full',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final settings = AudioSettings.load(prefs);

      expect(settings.musicEnabled, isTrue);
      expect(settings.sfxEnabled, isTrue);
      expect(settings.musicVolume, 0.5);
      expect(settings.sfxVolume, 1.0);
    });

    test('migrates a disabled legacy toggle to both channels off', () async {
      SharedPreferences.setMockInitialValues({'sound_enabled': false});
      final prefs = await SharedPreferences.getInstance();

      final settings = AudioSettings.load(prefs);

      expect(settings.musicEnabled, isFalse);
      expect(settings.sfxEnabled, isFalse);
      expect(prefs.containsKey(AudioSettings.kLegacyEnabled), isFalse);
    });

    test('migrates an enabled legacy toggle to both channels on', () async {
      SharedPreferences.setMockInitialValues({'sound_enabled': true});
      final prefs = await SharedPreferences.getInstance();

      final settings = AudioSettings.load(prefs);

      expect(settings.musicEnabled, isTrue);
      expect(settings.sfxEnabled, isTrue);
      expect(prefs.containsKey(AudioSettings.kLegacyEnabled), isFalse);
    });

    test('new keys win over a legacy value; legacy is left alone', () async {
      SharedPreferences.setMockInitialValues({
        'sound_enabled': false,
        'music_enabled': true,
      });
      final prefs = await SharedPreferences.getInstance();

      final settings = AudioSettings.load(prefs);

      // music_enabled was explicitly set; sfx_enabled falls back to the
      // (non-migrated, since new keys are present) default of enabled.
      expect(settings.musicEnabled, isTrue);
      expect(settings.sfxEnabled, isTrue);
    });

    test('clamps out-of-range stored volumes', () async {
      SharedPreferences.setMockInitialValues({
        'music_volume': 1.5,
        'sfx_volume': -0.2,
      });
      final prefs = await SharedPreferences.getInstance();

      final settings = AudioSettings.load(prefs);

      expect(settings.musicVolume, 1.0);
      expect(settings.sfxVolume, 0.0);
    });
  });
}
