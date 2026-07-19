import 'dart:math';
import 'dart:ui' show Color;

import 'package:flame/events.dart';
import 'package:flame/game.dart';

import '../audio/sound_config.dart';
import '../audio/sound_service.dart';
import '../models/board.dart';
import '../models/scoring.dart';
import '../models/tetromino.dart';
import 'animation_config.dart';
import 'board_component.dart';
import 'cell_animator.dart';
import 'game_mode.dart';

/// Resolution phase: normal play vs. running the line-clear animation.
enum GamePhase { playing, clearing }

/// The Flame game: owns board state, the falling piece, scoring, the gravity
/// clock, speed graduation, win/lose detection, and gesture input.
///
/// Rendering lives in [BoardComponent]; game-feel animation is layered on in a
/// later session and reads the state exposed here.
class TetrisGame extends FlameGame with TapCallbacks, DragCallbacks {
  TetrisGame({
    required this.mode,
    this.onScoreChanged,
    this.onGameOver,
    this.onWin,
  });

  final GameMode mode;

  /// Fired whenever [score] changes.
  final void Function(int score)? onScoreChanged;

  /// Fired once on top-out.
  final void Function(int score)? onGameOver;

  /// Fired once when a stage's target score is reached.
  final void Function(int score)? onWin;

  // --- Speed tuning -------------------------------------------------------
  static const double _infiniteStartInterval = 0.8; // seconds per cell
  static const double _infiniteMinInterval = 0.12; // full speed
  static const double _infiniteSpeedFactor = 0.85; // per speed level
  static const int _linesPerSpeedLevel = 10;

  // --- State --------------------------------------------------------------
  final Board board = Board();
  final SevenBag _bag = SevenBag();
  final CellAnimator animator = CellAnimator();
  late BoardComponent boardComponent;

  Piece? active;
  int score = 0;
  int linesCleared = 0;
  bool isPaused = false;
  bool isOver = false;
  bool hasWon = false;

  GamePhase phase = GamePhase.playing;
  List<int> clearingRows = const [];
  double clearElapsed = 0;
  double _spawnElapsed = 0;

  double _gravityInterval = _infiniteStartInterval;
  double _fallAccum = 0;

  // Drag accumulators (reset per drag).
  double _accumDx = 0;
  double _accumDy = 0;

  int get targetScore =>
      mode is StageMode ? (mode as StageMode).level.targetScore : 0;

  /// 0-based speed tier, for the HUD in infinite mode.
  int get speedLevel => linesCleared ~/ _linesPerSpeedLevel;

  /// Fade-in opacity for a freshly spawned piece (1.0 once settled).
  double get spawnAlpha {
    final dur = AnimationConfig.spawnFadeDuration.inMilliseconds / 1000;
    if (dur <= 0) return 1;
    return (_spawnElapsed / dur).clamp(0.0, 1.0);
  }

  bool get _active =>
      !isPaused && !isOver && !hasWon && active != null && phase == GamePhase.playing;

  // Let the Flutter scaffold background show around the centered board.
  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    _seedBoard();
    _gravityInterval = _initialInterval();
    boardComponent = BoardComponent();
    add(boardComponent);
    _spawn();
  }

  void _seedBoard() {
    final m = mode;
    if (m is StageMode) {
      for (final cell in m.level.initialCells) {
        board.setCell(cell.x, cell.y, cell.color);
      }
    }
  }

  double _initialInterval() {
    if (mode is StageMode) {
      // Slightly quicker on later levels, but always comfortable.
      final lvl = (mode as StageMode).level.level;
      return (0.9 - lvl * 0.03).clamp(0.45, 0.9);
    }
    return _infiniteStartInterval;
  }

  // --- Loop ---------------------------------------------------------------
  @override
  void update(double dt) {
    super.update(dt);
    if (isPaused || isOver) return;
    animator.update(dt);
    _spawnElapsed += dt;

    if (phase == GamePhase.clearing) {
      _advanceClear(dt);
      return;
    }
    if (!_active) return;
    _fallAccum += dt;
    if (_fallAccum >= _gravityInterval) {
      _fallAccum = 0;
      _stepDown();
    }
  }

  /// Total time the staggered clear takes across the whole row width.
  double get _clearTotal =>
      (AnimationConfig.clearCellDuration.inMilliseconds +
          AnimationConfig.clearStaggerPerColumn.inMilliseconds *
              (Board.columns - 1)) /
      1000;

  void _advanceClear(double dt) {
    clearElapsed += dt;
    if (clearElapsed >= _clearTotal) {
      _finishClear();
    }
  }

  void _stepDown() {
    final piece = active!;
    if (board.canPlaceAt(piece, col: piece.col, row: piece.row + 1)) {
      piece.row += 1;
    } else {
      _lockActive();
    }
  }

  void _lockActive() {
    final locked = active!.cells.map((c) => (c.dx, c.dy)).toList();
    board.lock(active!);
    active = null;
    animator.triggerLockBounce(locked);
    SoundService.instance.play(Sfx.lock);

    final full = board.fullRows();
    if (full.isEmpty) {
      _spawn();
      return;
    }
    // Enter the clearing phase; rows stay on the board and shrink away while
    // gravity is paused, then _finishClear removes them and settles the rest.
    clearingRows = full;
    clearElapsed = 0;
    phase = GamePhase.clearing;
  }

  void _finishClear() {
    final cleared = clearingRows.toSet();
    final specs = <SettleSpec>[];
    for (var origR = 0; origR < Board.rows; origR++) {
      if (cleared.contains(origR)) continue;
      final delta = cleared.where((c) => c > origR).length;
      if (delta == 0) continue;
      for (var c = 0; c < Board.columns; c++) {
        if (board.cells[origR][c] != null) {
          specs.add(SettleSpec(c, origR + delta, delta));
        }
      }
    }

    final n = board.clearRows(clearingRows);
    animator.triggerSettle(specs);
    clearingRows = const [];
    phase = GamePhase.playing;

    _playLineClear(n);
    linesCleared += n;
    _addScore(lineClearScore(n));
    _updateSpeed();

    if (!hasWon) _spawn();
  }

  void _playLineClear(int lines) {
    final sfx = switch (lines) {
      1 => Sfx.lineClear1,
      2 => Sfx.lineClear2,
      3 => Sfx.lineClear3,
      _ => Sfx.lineClear4,
    };
    SoundService.instance.play(sfx);
  }

  void _spawn() {
    final piece = Piece(_bag.next());
    if (!board.canPlace(piece)) {
      active = piece; // show the blocked piece
      _gameOver();
      return;
    }
    active = piece;
    _fallAccum = 0;
    _spawnElapsed = 0;
  }

  void _addScore(int delta) {
    score += delta;
    onScoreChanged?.call(score);
    if (mode is StageMode && score >= targetScore) {
      hasWon = true;
      SoundService.instance.play(Sfx.levelWin);
      onWin?.call(score);
    }
  }

  void _updateSpeed() {
    if (mode is InfiniteMode) {
      final tier = speedLevel;
      _gravityInterval = max(
        _infiniteMinInterval,
        _infiniteStartInterval * pow(_infiniteSpeedFactor, tier),
      );
    }
  }

  void _gameOver() {
    isOver = true;
    SoundService.instance.play(Sfx.gameOver);
    onGameOver?.call(score);
  }

  // --- Player actions -----------------------------------------------------
  void _tryMove(int dCol) {
    if (!_active) return;
    final p = active!;
    if (board.canPlaceAt(p, col: p.col + dCol, row: p.row)) {
      p.col += dCol;
      SoundService.instance.play(Sfx.move);
    }
  }

  void moveLeft() => _tryMove(-1);
  void moveRight() => _tryMove(1);

  void softDrop() {
    if (!_active) return;
    final p = active!;
    if (board.canPlaceAt(p, col: p.col, row: p.row + 1)) {
      p.row += 1;
      _fallAccum = 0;
    }
  }

  void hardDrop() {
    if (!_active) return;
    final p = active!;
    SoundService.instance.play(Sfx.hardDrop);
    while (board.canPlaceAt(p, col: p.col, row: p.row + 1)) {
      p.row += 1;
    }
    _lockActive();
  }

  void rotate() {
    if (!_active) return;
    final p = active!;
    final next = p.nextRotation();
    // Simple wall kicks: try in place, then nudge horizontally.
    for (final kick in const [0, -1, 1, -2, 2]) {
      if (board.canPlaceAt(p, col: p.col + kick, row: p.row, rotation: next)) {
        p.col += kick;
        p.rotation = next;
        SoundService.instance.play(Sfx.rotate);
        return;
      }
    }
  }

  /// The row the active piece would land on if hard-dropped (for the ghost).
  int? ghostRow() {
    final p = active;
    if (p == null) return null;
    var row = p.row;
    while (board.canPlaceAt(p, col: p.col, row: row + 1)) {
      row++;
    }
    return row;
  }

  void togglePause() {
    if (isOver || hasWon) return;
    isPaused = !isPaused;
  }

  // --- Input --------------------------------------------------------------
  @override
  void onTapUp(TapUpEvent event) => rotate();

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _accumDx = 0;
    _accumDy = 0;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    final cs = boardComponent.cellSize;
    if (cs <= 0) return;
    _accumDx += event.localDelta.x;
    _accumDy += event.localDelta.y;
    while (_accumDx >= cs) {
      moveRight();
      _accumDx -= cs;
    }
    while (_accumDx <= -cs) {
      moveLeft();
      _accumDx += cs;
    }
    while (_accumDy >= cs) {
      softDrop();
      _accumDy -= cs;
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    // A quick downward flick hard-drops the piece.
    final v = event.velocity;
    if (v.y > 1400 && v.y.abs() > v.x.abs() * 1.5) {
      hardDrop();
    }
  }
}
