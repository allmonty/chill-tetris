import 'package:chill_tetris/models/board.dart';
import 'package:chill_tetris/models/scoring.dart';
import 'package:chill_tetris/models/tetromino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Board placement', () {
    test('new board is empty', () {
      final board = Board();
      for (var r = 0; r < Board.rows; r++) {
        for (var c = 0; c < Board.columns; c++) {
          expect(board.cells[r][c], isNull);
        }
      }
    });

    test('canPlace is false off the left edge', () {
      final board = Board();
      final piece = Piece(TetrominoType.o, col: -1, row: 0);
      expect(board.canPlace(piece), isFalse);
    });

    test('canPlace is false past the floor', () {
      final board = Board();
      final piece = Piece(TetrominoType.o, col: 0, row: Board.rows - 1);
      expect(board.canPlace(piece), isFalse);
    });

    test('canPlace is false when overlapping a locked cell', () {
      final board = Board();
      board.setCell(0, 0, 3);
      final piece = Piece(TetrominoType.o, col: 0, row: 0);
      expect(board.canPlace(piece), isFalse);
    });

    test('lock writes the piece color into the grid', () {
      final board = Board();
      final piece = Piece(TetrominoType.o, col: 4, row: 5);
      board.lock(piece);
      expect(board.cells[5][4], piece.colorIndex);
      expect(board.cells[6][5], piece.colorIndex);
    });
  });

  group('Line clearing', () {
    Board withFullRow(int row) {
      final board = Board();
      for (var c = 0; c < Board.columns; c++) {
        board.setCell(c, row, 1);
      }
      return board;
    }

    test('a full row is detected and cleared', () {
      final board = withFullRow(Board.rows - 1);
      expect(board.fullRows(), [Board.rows - 1]);
      expect(board.clearRows(board.fullRows()), 1);
      expect(board.fullRows(), isEmpty);
    });

    test('cells above a cleared row drop down by one', () {
      final board = withFullRow(Board.rows - 1);
      board.setCell(0, Board.rows - 2, 5); // sits just above the full row
      board.clearRows(board.fullRows());
      // After clearing, the lone cell should have fallen to the bottom row.
      expect(board.cells[Board.rows - 1][0], 5);
    });

    test('clearing an empty board clears nothing', () {
      final board = Board();
      expect(board.clearRows(board.fullRows()), 0);
    });
  });

  group('Top out', () {
    test('spawn is blocked when its cells are occupied', () {
      final board = Board();
      final spawn = Piece(TetrominoType.o, col: 4, row: 0);
      for (final cell in spawn.cells) {
        board.setCell(cell.dx, cell.dy, 2);
      }
      expect(board.canPlace(spawn), isFalse);
    });

    test('spawn fits on an empty board', () {
      expect(Board().canPlace(Piece(TetrominoType.o, col: 4, row: 0)), isTrue);
    });
  });

  group('Scoring', () {
    test('classic line-clear values', () {
      expect(lineClearScore(1), 100);
      expect(lineClearScore(2), 300);
      expect(lineClearScore(3), 500);
      expect(lineClearScore(4), 800);
      expect(lineClearScore(0), 0);
    });
  });
}
