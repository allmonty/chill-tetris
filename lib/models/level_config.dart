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

  /// Parses the full list of levels from a JSON string.
  static List<LevelConfig> listFromJsonString(String source) {
    final data = jsonDecode(source) as List<dynamic>;
    return data
        .map((e) => LevelConfig.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Loads and parses the bundled levels asset.
  static Future<List<LevelConfig>> loadAll() async {
    final source = await rootBundle.loadString('assets/levels/levels.json');
    return listFromJsonString(source);
  }
}
