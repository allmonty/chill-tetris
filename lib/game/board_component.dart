import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../models/board.dart';
import '../theme/palette.dart';
import 'animation_config.dart';
import 'tetris_game.dart';

/// Renders the playfield: backdrop, grid lines, locked cells, the active
/// piece, and its landing ghost. Reads all state from the game.
class BoardComponent extends PositionComponent
    with HasGameReference<TetrisGame> {
  double cellSize = 0;

  static const double _margin = 12;
  static const double _cellGap = 1.5;
  static const double _radius = 4;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final availW = size.x - _margin * 2;
    final availH = size.y - _margin * 2;
    cellSize = min(availW / Board.columns, availH / Board.rows);
    this.size = Vector2(cellSize * Board.columns, cellSize * Board.rows);
    position = Vector2(
      (size.x - this.size.x) / 2,
      (size.y - this.size.y) / 2,
    );
  }

  @override
  void render(Canvas canvas) {
    final p = Palette.current;

    // Board backdrop.
    final boardRect = RRect.fromRectAndRadius(
      Offset.zero & Size(size.x, size.y),
      const Radius.circular(8),
    );
    canvas.drawRRect(boardRect, Paint()..color = p.boardBackground);

    // Grid lines.
    final gridPaint = Paint()
      ..color = p.gridLine
      ..strokeWidth = 1;
    for (var c = 1; c < Board.columns; c++) {
      final x = c * cellSize;
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), gridPaint);
    }
    for (var r = 1; r < Board.rows; r++) {
      final y = r * cellSize;
      canvas.drawLine(Offset(0, y), Offset(size.x, y), gridPaint);
    }

    // Locked cells (with lock-bounce scale and post-clear settle offset).
    final clearing = game.clearingRows.toSet();
    for (var r = 0; r < Board.rows; r++) {
      final isClearing = clearing.contains(r);
      for (var c = 0; c < Board.columns; c++) {
        final colorIndex = game.board.cells[r][c];
        if (colorIndex == null) continue;
        final color = p.pieceColors[colorIndex];
        if (isClearing) {
          final (scale, alpha) = _clearAnim(c);
          _drawCell(canvas, c, r, color.withValues(alpha: alpha), scale: scale);
        } else {
          _drawCell(
            canvas,
            c,
            r,
            color,
            scale: game.animator.scaleFor(c, r),
            dy: game.animator.settleDyFor(c, r, cellSize),
          );
        }
      }
    }

    final active = game.active;
    if (active == null) return;

    // Ghost (landing preview).
    final ghostRow = game.ghostRow();
    if (ghostRow != null && ghostRow != active.row) {
      final ghost = active.copy()..row = ghostRow;
      final ghostColor = p.pieceColors[active.colorIndex].withValues(alpha: 0.22);
      for (final cell in ghost.cells) {
        _drawCell(canvas, cell.dx, cell.dy, ghostColor);
      }
    }

    // Active piece (fades in on spawn).
    final color = p.pieceColors[active.colorIndex].withValues(alpha: game.spawnAlpha);
    for (final cell in active.cells) {
      _drawCell(canvas, cell.dx, cell.dy, color);
    }
  }

  /// Scale and opacity for a clearing cell in column [col], based on the
  /// staggered clear progress. Bounces slightly, then shrinks and fades.
  (double, double) _clearAnim(int col) {
    final elapsedMs = game.clearElapsed * 1000 -
        AnimationConfig.clearStaggerPerColumn.inMilliseconds * col;
    if (elapsedMs <= 0) return (1.0, 1.0); // not started yet
    final t =
        (elapsedMs / AnimationConfig.clearCellDuration.inMilliseconds).clamp(0.0, 1.0);
    final double scale;
    if (t < 0.3) {
      scale = _lerp(1.0, AnimationConfig.clearBounceScale, t / 0.3);
    } else {
      scale = _lerp(AnimationConfig.clearBounceScale, 0.0, (t - 0.3) / 0.7);
    }
    return (scale, 1.0 - t);
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  void _drawCell(
    Canvas canvas,
    int col,
    int row,
    Color color, {
    double scale = 1.0,
    double dy = 0,
  }) {
    if (row < 0) return; // cells above the top edge aren't drawn
    if (scale <= 0) return;
    final inner = cellSize - _cellGap * 2;
    final side = inner * scale;
    final center = Offset(
      col * cellSize + cellSize / 2,
      row * cellSize + cellSize / 2 + dy,
    );
    final rect = Rect.fromCenter(center: center, width: side, height: side);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(_radius)),
      Paint()..color = color,
    );
  }
}
