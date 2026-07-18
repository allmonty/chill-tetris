import 'package:chill_tetris/models/tetromino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Tetromino shapes', () {
    test('every type has 4 cells in every rotation', () {
      for (final data in tetrominoes.values) {
        for (final rot in data.rotations) {
          expect(rot.length, 4, reason: '${data.type} rotation cell count');
        }
      }
    });

    test('O piece has a single rotation state', () {
      expect(tetrominoes[TetrominoType.o]!.rotationCount, 1);
    });

    test('color index matches enum order', () {
      var i = 0;
      for (final type in TetrominoType.values) {
        expect(tetrominoes[type]!.colorIndex, i);
        i++;
      }
    });
  });

  group('Piece', () {
    test('cells are offset by col/row', () {
      final piece = Piece(TetrominoType.o, col: 4, row: 2);
      final xs = piece.cells.map((c) => c.dx).toSet();
      final ys = piece.cells.map((c) => c.dy).toSet();
      expect(xs, {4, 5});
      expect(ys, {2, 3});
    });

    test('nextRotation wraps around', () {
      final t = Piece(TetrominoType.t);
      expect(t.nextRotation(), 1);
      t.rotation = 3;
      expect(t.nextRotation(), 0);
    });
  });

  group('SevenBag', () {
    test('deals all 7 types before repeating', () {
      final bag = SevenBag(42);
      final first7 = List.generate(7, (_) => bag.next());
      expect(first7.toSet().length, 7);
    });

    test('is deterministic for a given seed', () {
      final a = SevenBag(1);
      final b = SevenBag(1);
      for (var i = 0; i < 20; i++) {
        expect(a.next(), b.next());
      }
    });
  });
}
