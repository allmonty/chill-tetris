import 'package:chill_tetris/services/progress_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('a fresh player has no levels won', () async {
    SharedPreferences.setMockInitialValues({});
    final progress = await ProgressService.load();

    expect(progress.isLevelWon(1), isFalse);
    expect(progress.isLevelWon(50), isFalse);
  });

  test('migrates the legacy unlocked_level ceiling into won stars', () async {
    // unlocked_level = 10 means levels 1..9 were cleared to reach 10.
    SharedPreferences.setMockInitialValues({'unlocked_level': 10});
    final progress = await ProgressService.load();

    for (var l = 1; l <= 9; l++) {
      expect(progress.isLevelWon(l), isTrue, reason: 'level $l migrated');
    }
    expect(progress.isLevelWon(10), isFalse, reason: 'the ceiling itself');
    expect(progress.isLevelWon(11), isFalse);
  });

  test('legacy unlocked_level of 1 (or absent) migrates to no stars', () async {
    SharedPreferences.setMockInitialValues({'unlocked_level': 1});
    final progress = await ProgressService.load();

    expect(progress.isLevelWon(1), isFalse);
  });

  test('markLevelWon persists and survives a reload', () async {
    SharedPreferences.setMockInitialValues({});
    final progress = await ProgressService.load();

    await progress.markLevelWon(7);
    expect(progress.isLevelWon(7), isTrue);

    final reloaded = await ProgressService.load();
    expect(reloaded.isLevelWon(7), isTrue);
  });

  test('a new win keeps the migrated stars (no clobber)', () async {
    SharedPreferences.setMockInitialValues({'unlocked_level': 5});
    final progress = await ProgressService.load();

    await progress.markLevelWon(20);

    for (var l = 1; l <= 4; l++) {
      expect(progress.isLevelWon(l), isTrue, reason: 'migrated level $l kept');
    }
    expect(progress.isLevelWon(20), isTrue, reason: 'the new win');
  });

  test('markLevelWon is idempotent — no duplicate entries', () async {
    SharedPreferences.setMockInitialValues({});
    final progress = await ProgressService.load();

    await progress.markLevelWon(3);
    await progress.markLevelWon(3);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('won_levels'), ['3']);
  });

  test('migration does not re-run after a win lowers the effective set',
      () async {
    // Once migrated, the seed is fixed; a later reload must not re-seed from
    // the still-present legacy key and resurrect a set that was diverged from.
    SharedPreferences.setMockInitialValues({'unlocked_level': 3});
    final first = await ProgressService.load();
    expect(first.isLevelWon(1), isTrue);
    expect(first.isLevelWon(2), isTrue);

    await first.markLevelWon(10);

    final reloaded = await ProgressService.load();
    expect(reloaded.isLevelWon(1), isTrue);
    expect(reloaded.isLevelWon(2), isTrue);
    expect(reloaded.isLevelWon(10), isTrue);
    expect(reloaded.isLevelWon(3), isFalse);
  });
}
