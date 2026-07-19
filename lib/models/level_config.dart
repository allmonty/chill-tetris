import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'board.dart';

/// A single pre-placed cell in a stage's starting layout.
@immutable
class InitialCell {
  const InitialCell({required this.x, required this.y, required this.color});

  /// Column, 0..[Board.columns]-1 (left to right).
  final int x;

  /// Row, 0..[Board.rows]-1 (top to bottom).
  final int y;

  /// Index into the palette's `pieceColors`.
  final int color;

  bool get isValid =>
      x >= 0 &&
      x < Board.columns &&
      y >= 0 &&
      y < Board.rows &&
      color >= 0 &&
      color < 7;

  factory InitialCell.fromJson(Map<String, dynamic> json) => InitialCell(
        x: json['x'] as int,
        y: json['y'] as int,
        color: json['color'] as int,
      );
}

/// One playable stage, configured from JSON.
@immutable
class LevelConfig {
  const LevelConfig({
    required this.level,
    required this.targetScore,
    required this.initialCells,
  });

  final int level;
  final int targetScore;
  final List<InitialCell> initialCells;

  factory LevelConfig.fromJson(Map<String, dynamic> json) {
    final rawCells = (json['initialPieces'] as List<dynamic>? ?? const [])
        .map((e) => InitialCell.fromJson(e as Map<String, dynamic>))
        .toList();

    // Drop out-of-range cells so a bad config can't crash the board; flag it in
    // debug so level authors notice.
    final valid = rawCells.where((c) {
      assert(c.isValid, 'Level ${json['level']}: cell $c is out of range.');
      return c.isValid;
    }).toList();

    return LevelConfig(
      level: json['level'] as int,
      targetScore: json['targetScore'] as int,
      initialCells: valid,
    );
  }
}

/// The full set of stages plus catalog-wide settings from levels.json.
@immutable
class LevelCatalog {
  const LevelCatalog({required this.unlockedAtStart, required this.levels});

  /// How many levels are playable before any progress is made. Clamped to
  /// 1..levels.length so a bad config can't lock level 1 or unlock nothing.
  final int unlockedAtStart;

  final List<LevelConfig> levels;

  factory LevelCatalog.fromJsonString(String source) {
    final data = jsonDecode(source);

    // Legacy format: a bare list of levels, one unlocked at start.
    final (rawLevels, rawUnlocked) = switch (data) {
      final List<dynamic> list => (list, 1),
      final Map<String, dynamic> map => (
          map['levels'] as List<dynamic>? ?? const <dynamic>[],
          map['unlockedAtStart'] as int? ?? 1,
        ),
      _ => throw FormatException('levels.json: expected a list or map'),
    };

    final levels = rawLevels
        .map((e) => LevelConfig.fromJson(e as Map<String, dynamic>))
        .toList();
    return LevelCatalog(
      unlockedAtStart:
          levels.isEmpty ? 1 : rawUnlocked.clamp(1, levels.length),
      levels: levels,
    );
  }

  /// Loads and parses the bundled levels asset.
  static Future<LevelCatalog> load() async {
    final source = await rootBundle.loadString('assets/levels/levels.json');
    return LevelCatalog.fromJsonString(source);
  }
}
