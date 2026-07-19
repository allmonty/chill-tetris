import 'dart:math';

/// The seven standard tetromino types.
enum TetrominoType { i, o, t, s, z, j, l }

/// A single grid coordinate offset (column dx, row dy).
class Offset2 {
  const Offset2(this.dx, this.dy);
  final int dx;
  final int dy;
}

/// Immutable shape data for a tetromino: its rotation states and palette color.
///
/// Each rotation state is a list of 4 cell offsets relative to the piece's
/// pivot origin. Rotation states are ordered clockwise (0, R, 2, L).
class TetrominoData {
  const TetrominoData(this.type, this.colorIndex, this.rotations);

  final TetrominoType type;

  /// Index into the palette's `pieceColors`.
  final int colorIndex;

  /// One entry per rotation state; each is the 4 occupied cells.
  final List<List<Offset2>> rotations;

  int get rotationCount => rotations.length;
}

/// Shape definitions. Offsets are laid out so pieces spawn near the top-center
/// of a 10-wide board. Color index matches the enum order (I=0 ... L=6).
const Map<TetrominoType, TetrominoData> tetrominoes = {
  TetrominoType.i: TetrominoData(TetrominoType.i, 0, [
    [Offset2(0, 1), Offset2(1, 1), Offset2(2, 1), Offset2(3, 1)],
    [Offset2(2, 0), Offset2(2, 1), Offset2(2, 2), Offset2(2, 3)],
    [Offset2(0, 2), Offset2(1, 2), Offset2(2, 2), Offset2(3, 2)],
    [Offset2(1, 0), Offset2(1, 1), Offset2(1, 2), Offset2(1, 3)],
  ]),
  TetrominoType.o: TetrominoData(TetrominoType.o, 1, [
    [Offset2(0, 0), Offset2(1, 0), Offset2(0, 1), Offset2(1, 1)],
  ]),
  TetrominoType.t: TetrominoData(TetrominoType.t, 2, [
    [Offset2(1, 0), Offset2(0, 1), Offset2(1, 1), Offset2(2, 1)],
    [Offset2(1, 0), Offset2(1, 1), Offset2(2, 1), Offset2(1, 2)],
    [Offset2(0, 1), Offset2(1, 1), Offset2(2, 1), Offset2(1, 2)],
    [Offset2(1, 0), Offset2(0, 1), Offset2(1, 1), Offset2(1, 2)],
  ]),
  TetrominoType.s: TetrominoData(TetrominoType.s, 3, [
    [Offset2(1, 0), Offset2(2, 0), Offset2(0, 1), Offset2(1, 1)],
    [Offset2(1, 0), Offset2(1, 1), Offset2(2, 1), Offset2(2, 2)],
    [Offset2(1, 1), Offset2(2, 1), Offset2(0, 2), Offset2(1, 2)],
    [Offset2(0, 0), Offset2(0, 1), Offset2(1, 1), Offset2(1, 2)],
  ]),
  TetrominoType.z: TetrominoData(TetrominoType.z, 4, [
    [Offset2(0, 0), Offset2(1, 0), Offset2(1, 1), Offset2(2, 1)],
    [Offset2(2, 0), Offset2(1, 1), Offset2(2, 1), Offset2(1, 2)],
    [Offset2(0, 1), Offset2(1, 1), Offset2(1, 2), Offset2(2, 2)],
    [Offset2(1, 0), Offset2(0, 1), Offset2(1, 1), Offset2(0, 2)],
  ]),
  TetrominoType.j: TetrominoData(TetrominoType.j, 5, [
    [Offset2(0, 0), Offset2(0, 1), Offset2(1, 1), Offset2(2, 1)],
    [Offset2(1, 0), Offset2(2, 0), Offset2(1, 1), Offset2(1, 2)],
    [Offset2(0, 1), Offset2(1, 1), Offset2(2, 1), Offset2(2, 2)],
    [Offset2(1, 0), Offset2(1, 1), Offset2(0, 2), Offset2(1, 2)],
  ]),
  TetrominoType.l: TetrominoData(TetrominoType.l, 6, [
    [Offset2(2, 0), Offset2(0, 1), Offset2(1, 1), Offset2(2, 1)],
    [Offset2(1, 0), Offset2(1, 1), Offset2(1, 2), Offset2(2, 2)],
    [Offset2(0, 1), Offset2(1, 1), Offset2(2, 1), Offset2(0, 2)],
    [Offset2(0, 0), Offset2(1, 0), Offset2(1, 1), Offset2(1, 2)],
  ]),
};

/// An active, movable piece: a type at a board position and rotation state.
class Piece {
  Piece(this.type, {this.col = 3, this.row = 0, this.rotation = 0});

  final TetrominoType type;

  /// Board column of the piece's origin (its offsets are relative to this).
  int col;

  /// Board row of the piece's origin.
  int row;

  /// Current rotation index into [TetrominoData.rotations].
  int rotation;

  TetrominoData get data => tetrominoes[type]!;
  int get colorIndex => data.colorIndex;

  /// The absolute (column, row) cells this piece currently occupies.
  List<Offset2> get cells => data.rotations[rotation]
      .map((o) => Offset2(col + o.dx, row + o.dy))
      .toList();

  Piece copy() => Piece(type, col: col, row: row, rotation: rotation);

  int nextRotation() => (rotation + 1) % data.rotationCount;
}

/// A "7-bag" randomizer: shuffles all seven types and deals them out before
/// reshuffling, so the player never faces long droughts of a piece.
class SevenBag {
  SevenBag([int? seed]) : _rng = Random(seed);

  final Random _rng;
  final List<TetrominoType> _bag = [];

  TetrominoType next() {
    _refillIfEmpty();
    return _bag.removeLast();
  }

  /// The type [next] will return, without consuming it (for the preview).
  TetrominoType peek() {
    _refillIfEmpty();
    return _bag.last;
  }

  void _refillIfEmpty() {
    if (_bag.isEmpty) {
      _bag.addAll(TetrominoType.values);
      _bag.shuffle(_rng);
    }
  }
}
