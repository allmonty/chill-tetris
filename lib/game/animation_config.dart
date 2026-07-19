import 'package:flutter/animation.dart';

/// All game-feel tunables in one place.
///
/// Everything here is deliberately *subtle* — small amplitudes, soft curves,
/// short durations — to keep the game relaxing. Tweak these constants to
/// re-tune the feel of the whole game without touching gameplay logic.
class AnimationConfig {
  const AnimationConfig._();

  // --- Piece lock: a gentle "arrived in place" bounce -----------------------
  /// How long the lock bounce lasts.
  static const Duration lockBounceDuration = Duration(milliseconds: 200);

  /// Peak scale of the bounce (1.0 = no bounce). Keep this close to 1.
  static const double lockBounceScale = 1.08;

  // --- Line clear: soft bounce, then shrink + fade away ---------------------
  /// How long each clearing cell takes to disappear.
  static const Duration clearCellDuration = Duration(milliseconds: 320);

  /// Extra delay per column so the clear ripples left-to-right.
  static const Duration clearStaggerPerColumn = Duration(milliseconds: 25);

  /// Small bounce a clearing cell does before shrinking.
  static const double clearBounceScale = 1.12;

  // --- Rows settling after a clear ------------------------------------------
  /// How long rows above a cleared line take to ease down into place.
  static const Duration rowsSettleDuration = Duration(milliseconds: 220);

  // --- Piece spawn ----------------------------------------------------------
  /// Fade-in time for a freshly spawned piece.
  static const Duration spawnFadeDuration = Duration(milliseconds: 140);

  // --- Curves ---------------------------------------------------------------
  /// Gentle deceleration used for settles and fades.
  static const Curve settleCurve = Curves.easeOut;
}
