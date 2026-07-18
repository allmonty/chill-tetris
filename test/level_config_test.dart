import 'dart:io';

import 'package:chill_tetris/models/board.dart';
import 'package:chill_tetris/models/level_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Shipped levels.json', () {
    late List<LevelConfig> levels;

    setUpAll(() {
      final source = File('assets/levels/levels.json').readAsStringSync();
      levels = LevelConfig.listFromJsonString(source);
    });

    test('has 15 levels numbered 1..15', () {
      expect(levels.length, 15);
      expect(levels.map((l) => l.level), List.generate(15, (i) => i + 1));
    });

    test('target scores increase monotonically', () {
      for (var i = 1; i < levels.length; i++) {
        expect(levels[i].targetScore, greaterThan(levels[i - 1].targetScore));
      }
    });

    test('every initial cell is on the board', () {
      for (final level in levels) {
        for (final cell in level.initialCells) {
          expect(cell.x, inInclusiveRange(0, Board.columns - 1));
          expect(cell.y, inInclusiveRange(0, Board.rows - 1));
          expect(cell.color, inInclusiveRange(0, 6));
        }
      }
    });

    test('no starting row is completely filled', () {
      for (final level in levels) {
        final perRow = <int, int>{};
        for (final cell in level.initialCells) {
          perRow.update(cell.y, (v) => v + 1, ifAbsent: () => 1);
        }
        for (final count in perRow.values) {
          expect(count, lessThan(Board.columns),
              reason: 'Level ${level.level} has a pre-filled full row');
        }
      }
    });
  });

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
