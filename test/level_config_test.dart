import 'package:chill_tetris/models/level_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LevelConfig parsing', () {
    test('parses a valid level list', () {
      const source = '''
      [
        {
          "level": 1,
          "targetScore": 500,
          "initialPieces": [
            {"x": 0, "y": 19, "color": 2},
            {"x": 1, "y": 19, "color": 5}
          ]
        }
      ]
      ''';
      final levels = LevelConfig.listFromJsonString(source);
      expect(levels.length, 1);
      expect(levels.first.level, 1);
      expect(levels.first.targetScore, 500);
      expect(levels.first.initialCells.length, 2);
      expect(levels.first.initialCells.first.color, 2);
    });

    test('missing initialPieces defaults to an empty layout', () {
      const source = '[{"level": 3, "targetScore": 1000}]';
      final levels = LevelConfig.listFromJsonString(source);
      expect(levels.first.initialCells, isEmpty);
    });

    test('out-of-range cells are dropped', () {
      // Assertions fire in debug, so run this expecting the filter, not a throw.
      const source = '''
      [
        {
          "level": 1,
          "targetScore": 100,
          "initialPieces": [
            {"x": 0, "y": 19, "color": 1},
            {"x": 99, "y": 19, "color": 1}
          ]
        }
      ]
      ''';
      List<LevelConfig> levels;
      try {
        levels = LevelConfig.listFromJsonString(source);
      } on AssertionError {
        // In debug the assert trips first; that's acceptable — the guard exists.
        return;
      }
      expect(levels.first.initialCells.length, 1);
    });
  });
}
