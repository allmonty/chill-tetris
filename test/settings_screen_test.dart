import 'package:chill_tetris/audio/sound_service.dart';
import 'package:chill_tetris/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Persistence calls in SoundService go through SharedPreferences.getInstance();
  // without a mock backing store the platform channel has no responder in a
  // test environment and the awaiting Future never completes.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows music and SFX sections with a switch and slider each',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    expect(find.text('MUSIC'), findsOneWidget);
    expect(find.text('SOUND EFFECTS'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(2));
    expect(find.byType(Slider), findsNWidgets(2));
  });

  testWidgets('toggling the music switch updates SoundService',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    final musicSwitch = find.byType(Switch).first;
    final wasEnabled = SoundService.instance.musicEnabled.value;

    await tester.tap(musicSwitch);
    await tester.pumpAndSettle();

    expect(SoundService.instance.musicEnabled.value, !wasEnabled);

    // Restore state so other tests in this run see the default.
    await tester.tap(musicSwitch);
    await tester.pumpAndSettle();
  });

  testWidgets('a disabled section greys out its slider', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    await SoundService.instance.setSfxEnabled(false);
    await tester.pumpAndSettle();

    final sfxSlider = tester.widget<Slider>(find.byType(Slider).last);
    expect(sfxSlider.onChanged, isNull);

    await SoundService.instance.setSfxEnabled(true);
    await tester.pumpAndSettle();
  });
}
