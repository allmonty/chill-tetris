import 'package:shared_preferences/shared_preferences.dart';

/// Persists player progress: which stages have been cleared and the
/// infinite-mode high score. Backed by shared_preferences.
class ProgressService {
  ProgressService._(this._prefs);

  static const _kWonLevels = 'won_levels';
  static const _kHighScoreInfinite = 'high_score_infinite';

  /// Legacy key: the highest level the player could enter, back when levels
  /// unlocked one at a time. Read once to migrate old saves into [_kWonLevels]
  /// (see [load]); no longer written.
  static const _kLegacyUnlockedLevel = 'unlocked_level';

  final SharedPreferences _prefs;

  static Future<ProgressService> load() async {
    final prefs = await SharedPreferences.getInstance();
    _migrateLegacyProgress(prefs);
    return ProgressService._(prefs);
  }

  /// Seeds the won-levels set from the legacy `unlocked_level` ceiling the first
  /// time the new code runs. An `unlocked_level` of K means levels 1..K-1 were
  /// cleared to reach K, so those are the stars an upgrading player keeps.
  /// Writing the (possibly empty) list marks the migration done so it never
  /// re-runs and never clobbers wins recorded afterward.
  static void _migrateLegacyProgress(SharedPreferences prefs) {
    if (prefs.containsKey(_kWonLevels)) return;
    final unlockedLevel = prefs.getInt(_kLegacyUnlockedLevel) ?? 1;
    final won = [for (var l = 1; l < unlockedLevel; l++) '$l'];
    prefs.setStringList(_kWonLevels, won);
  }

  /// Whether [level] has been cleared (drives the star badge in the level list).
  bool isLevelWon(int level) =>
      _prefs.getStringList(_kWonLevels)?.contains('$level') ?? false;

  /// Records that [level] was cleared. Idempotent.
  Future<void> markLevelWon(int level) async {
    final won = _prefs.getStringList(_kWonLevels) ?? <String>[];
    if (won.contains('$level')) return;
    await _prefs.setStringList(_kWonLevels, [...won, '$level']);
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
