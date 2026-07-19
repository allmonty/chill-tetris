import 'dart:math';
import 'dart:ui' show Color;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

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

  /// How long a piece rests on the stack before it locks. Long enough to
  /// slide a piece under an overhang at the last moment; checked every frame,
  /// not on the gravity clock, so it behaves the same at any fall speed.
  static const double _lockDelaySeconds = 0.40;

  /// Each successful move/rotate while resting restarts the lock delay
  /// ("move reset"), up to this many times per landing — maneuvering is easy,
  /// but a piece can't hover forever.
  static const int _maxLockResets = 8;

  /// Once a drag has soft-dropped, a column shift needs this many cells of
  /// horizontal travel (instead of 1) — finger wobble during a downward pull
  /// can't push the piece off the aimed column, a deliberate slide still can.
  static const double _softDropDxFactor = 1.5;

  // --- State --------------------------------------------------------------
  final Board board = Board();
  final SevenBag _bag = SevenBag();
  final CellAnimator animator = CellAnimator();
  late BoardComponent boardComponent;

  /// The type that will spawn after the current piece locks (for the preview
  /// in the top bar). Null only before the first spawn.
  final ValueNotifier<TetrominoType?> nextPiece =
      ValueNotifier<TetrominoType?>(null);

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
  double _restElapsed = 0; // time the piece has been unable to descend
  int _lockResets = 0; // lock-delay restarts spent on the current landing

  // Drag accumulators (reset per drag).
  double _accumDx = 0;
  double _accumDy = 0;
  bool _dragDropped = false; // current gesture has soft-dropped

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
    _updateFallAndLock(dt);
  }

  void _updateFallAndLock(double dt) {
    final piece = active!;
    if (board.canPlaceAt(piece, col: piece.col, row: piece.row + 1)) {
      // Still room below: reset any pending lock and fall on the gravity clock.
      _restElapsed = 0;
      _lockResets = 0;
      _fallAccum += dt;
      if (_fallAccum >= _gravityInterval) {
        _fallAccum = 0;
        piece.row += 1;
      }
    } else {
      // Resting on the stack: lock after a short fixed delay, measured every
      // frame so the land/clear sound fires promptly instead of waiting for the
      // next gravity tick.
      _restElapsed += dt;
      if (_restElapsed >= _lockDelaySeconds) {
        _lockActive();
      }
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

  void _lockActive() {
    final locked = active!.cells.map((c) => (c.dx, c.dy)).toList();
    board.lock(active!);
    active = null;
    _restElapsed = 0;
    animator.triggerLockBounce(locked);

    final full = board.fullRows();
    if (full.isEmpty) {
      // Nothing clears: just the soft landing "tock".
      SoundService.instance.play(Sfx.lock);
      _spawn();
      return;
    }
    // Lines clear: play the chime up front (when the shrink starts), not after
    // the animation. Enter the clearing phase; rows stay on the board and
    // shrink away while gravity is paused, then _finishClear removes them.
    _playLineClear(full.length);
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
    _restElapsed = 0;
    _lockResets = 0;
    _spawnElapsed = 0;
    _publishNextPiece();
  }

  /// Updates the [nextPiece] preview. The very first spawn runs inside
  /// [onLoad], which Flame executes during `GameWidget`'s first layout — writing
  /// to the notifier then would mark the already-built top bar dirty mid-build
  /// and throw. In that (build/layout) phase we defer to just after the frame;
  /// every later spawn comes from the game-loop tick, where an inline write is
  /// safe.
  void _publishNextPiece() {
    final next = _bag.peek();
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (isMounted) nextPiece.value = next;
      });
    } else {
      nextPiece.value = next;
    }
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
  /// Restarts the lock delay after a move/rotation that happened while the
  /// piece was resting on the stack, so the player can keep maneuvering — but
  /// only up to [_maxLockResets] times per landing, so a piece can't hover
  /// indefinitely.
  void _bumpLockDelay() {
    final p = active;
    if (p == null) return;
    final resting = !board.canPlaceAt(p, col: p.col, row: p.row + 1);
    if (resting && _lockResets < _maxLockResets) {
      _restElapsed = 0;
      _lockResets++;
    }
  }

  void _tryMove(int dCol) {
    if (!_active) return;
    final p = active!;
    if (board.canPlaceAt(p, col: p.col + dCol, row: p.row)) {
      p.col += dCol;
      SoundService.instance.play(Sfx.move);
      _bumpLockDelay();
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
      _restElapsed = 0;
      _lockResets = 0;
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
        _bumpLockDelay();
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
    _dragDropped = false;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    final cs = boardComponent.cellSize;
    if (cs <= 0) return;
    _accumDx += event.localDelta.x;
    _accumDy += event.localDelta.y;

    // Once the gesture has started pulling the piece down, a sideways shift
    // needs extra travel, so finger wobble during the pull can't nudge the
    // piece off the aimed column.
    final dxStep = _dragDropped ? cs * _softDropDxFactor : cs;
    while (_accumDx >= dxStep) {
      moveRight();
      _accumDx -= dxStep;
      _accumDy = 0; // a real sideways move discards drift on the other axis
    }
    while (_accumDx <= -dxStep) {
      moveLeft();
      _accumDx += dxStep;
      _accumDy = 0;
    }
    while (_accumDy >= cs) {
      softDrop();
      _accumDy -= cs;
      _accumDx = 0; // wobble collected while pulling down can't build a shift
      _dragDropped = true;
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

  @override
  void onRemove() {
    nextPiece.dispose();
    super.onRemove();
  }
}
