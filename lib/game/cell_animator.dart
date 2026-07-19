import 'dart:math' as math;

import '../models/board.dart';
import 'animation_config.dart';

/// One cell that has shifted down after a line clear and is easing into place.
class SettleSpec {
  const SettleSpec(this.col, this.row, this.deltaRows);
  final int col;
  final int row;
  final int deltaRows;
}

class _Settle {
  _Settle(this.deltaRows);
  final int deltaRows;
  double elapsed = 0;
}

/// Tracks lightweight per-cell tweens for locked cells (lock bounce, settle).
///
/// It holds no board state of its own — the board model stays animation-free.
/// Advance it every frame with [update] and query [scaleFor] / [settleDyFor]
/// while rendering.
class CellAnimator {
  final Map<int, double> _lockElapsed = {}; // key -> seconds since bounce start
  final Map<int, _Settle> _settle = {};

  static int _key(int col, int row) => row * Board.columns + col;

  /// Start a gentle bounce on each of the given (col, row) cells.
  void triggerLockBounce(Iterable<(int, int)> cells) {
    for (final (col, row) in cells) {
      _lockElapsed[_key(col, row)] = 0;
    }
  }

  /// Start the settle animation for cells that dropped after a clear.
  void triggerSettle(Iterable<SettleSpec> specs) {
    for (final s in specs) {
      _settle[_key(s.col, s.row)] = _Settle(s.deltaRows);
    }
  }

  void update(double dt) {
    final lockDur = AnimationConfig.lockBounceDuration.inMilliseconds / 1000;
    _lockElapsed.updateAll((_, v) => v + dt);
    _lockElapsed.removeWhere((_, v) => v >= lockDur);

    final settleDur = AnimationConfig.rowsSettleDuration.inMilliseconds / 1000;
    for (final s in _settle.values) {
      s.elapsed += dt;
    }
    _settle.removeWhere((_, s) => s.elapsed >= settleDur);
  }

  /// Scale multiplier for a locked cell (1.0 when it isn't bouncing).
  double scaleFor(int col, int row) {
    final elapsed = _lockElapsed[_key(col, row)];
    if (elapsed == null) return 1.0;
    final dur = AnimationConfig.lockBounceDuration.inMilliseconds / 1000;
    final t = (elapsed / dur).clamp(0.0, 1.0);
    // Smooth up-and-back: 0 at the ends, peak in the middle.
    return 1.0 + (AnimationConfig.lockBounceScale - 1.0) * math.sin(math.pi * t);
  }

  /// Vertical pixel offset for a settling cell (0 when it isn't settling).
  double settleDyFor(int col, int row, double cellSize) {
    final s = _settle[_key(col, row)];
    if (s == null) return 0;
    final dur = AnimationConfig.rowsSettleDuration.inMilliseconds / 1000;
    final raw = (s.elapsed / dur).clamp(0.0, 1.0);
    final p = AnimationConfig.settleCurve.transform(raw);
    // Starts lifted up by deltaRows and eases down to 0.
    return -s.deltaRows * cellSize * (1 - p);
  }
}
