import 'package:shared_preferences/shared_preferences.dart';

/// Persists player progress: the highest unlocked stage and the infinite-mode
/// high score. Backed by shared_preferences.
class ProgressService {
  ProgressService._(this._prefs);

  static const _kUnlockedLevel = 'unlocked_level';
  static const _kHighScoreInfinite = 'high_score_infinite';

  final SharedPreferences _prefs;

  static Future<ProgressService> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ProgressService._(prefs);
  }

  /// Highest level the player may enter (1-based). Level 1 is always unlocked.
  int get unlockedLevel => _prefs.getInt(_kUnlockedLevel) ?? 1;

  bool isLevelUnlocked(int level) => level <= unlockedLevel;

  /// Records that [level] was cleared, unlocking the next one.
  Future<void> completeLevel(int level) async {
    final next = level + 1;
    if (next > unlockedLevel) {
      await _prefs.setInt(_kUnlockedLevel, next);
    }
  }

  int get highScoreInfinite => _prefs.getInt(_kHighScoreInfinite) ?? 0;

  /// Stores [score] if it beats the stored best. Returns true if it was a
  /// new record.
  Future<bool> recordInfiniteScore(int score) async {
    if (score > highScoreInfinite) {
      await _prefs.setInt(_kHighScoreInfinite, score);
      return true;
    }
    return false;
  }
}
