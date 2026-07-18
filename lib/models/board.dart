import 'tetromino.dart';

/// The playfield grid and the pure rules that operate on it.
///
/// This class knows nothing about Flame, rendering, or animations — it is plain
/// Dart so it can be unit-tested in isolation.
class Board {
  Board() : cells = List.generate(rows, (_) => List<int?>.filled(columns, null));

  static const int columns = 10;
  static const int rows = 20;

  /// `cells[row][col]` holds a palette color index, or null when empty.
  final List<List<int?>> cells;

  bool _inside(int c, int r) => c >= 0 && c < columns && r >= 0 && r < rows;

  bool isEmptyAt(int c, int r) => _inside(c, r) && cells[r][c] == null;

  /// Whether [piece] can occupy its current cells (in bounds and not
  /// overlapping locked cells).
  bool canPlace(Piece piece) => _cellsFree(piece.cells);

  /// Whether [piece] could sit at the given column/row/rotation.
  bool canPlaceAt(Piece piece, {required int col, required int row, int? rotation}) {
    final probe = piece.copy()
      ..col = col
      ..row = row;
    if (rotation != null) probe.rotation = rotation;
    return _cellsFree(probe.cells);
  }

  bool _cellsFree(List<Offset2> cells) {
    for (final cell in cells) {
      if (cell.dx < 0 || cell.dx >= columns || cell.dy < 0 || cell.dy >= rows) {
        return false;
      }
      if (this.cells[cell.dy][cell.dx] != null) return false;
    }
    return true;
  }

  /// Writes [piece]'s cells into the grid using its color index.
  void lock(Piece piece) {
    for (final cell in piece.cells) {
      if (_inside(cell.dx, cell.dy)) {
        cells[cell.dy][cell.dx] = piece.colorIndex;
      }
    }
  }

  /// Directly sets a cell (used to seed stage layouts).
  void setCell(int col, int row, int colorIndex) {
    if (_inside(col, row)) cells[row][col] = colorIndex;
  }

  /// Row indices that are completely filled.
  List<int> fullRows() {
    final full = <int>[];
    for (var r = 0; r < rows; r++) {
      if (cells[r].every((c) => c != null)) full.add(r);
    }
    return full;
  }

  /// Removes the given rows and drops everything above them down. Returns the
  /// number of rows cleared.
  int clearRows(List<int> rowsToClear) {
    if (rowsToClear.isEmpty) return 0;
    final toClear = rowsToClear.toSet();
    final surviving = <List<int?>>[];
    for (var r = rows - 1; r >= 0; r--) {
      if (!toClear.contains(r)) surviving.add(cells[r]);
    }
    // Rebuild from the bottom up, padding the top with empty rows.
    for (var r = rows - 1; r >= 0; r--) {
      final idx = rows - 1 - r;
      cells[r] =
          idx < surviving.length ? surviving[idx] : List<int?>.filled(columns, null);
    }
    return rowsToClear.length;
  }

  /// Convenience: clear all full rows in one step, returning the count.
  int clearFullLines() => clearRows(fullRows());

  /// True when the top rows are occupied, i.e. a new piece cannot spawn.
  bool wouldTopOut(Piece spawn) => !canPlace(spawn);
}
