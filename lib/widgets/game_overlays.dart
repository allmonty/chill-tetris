import 'package:flutter/material.dart';

import '../game/game_mode.dart';
import '../game/tetris_game.dart';
import '../theme/palette.dart';

/// A solid top bar that sits *above* the board (not floating over it): back
/// button, the score/goal or score/speed readout, and a pause button.
class GameTopBar extends StatelessWidget {
  const GameTopBar({
    super.key,
    required this.game,
    required this.score,
    required this.onPause,
    required this.onBack,
  });

  final TetrisGame game;
  final ValueNotifier<int> score;
  final VoidCallback onPause;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final p = Palette.current;
    final isStage = game.mode is StageMode;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
          child: Row(
            children: [
              _RoundIconButton(icon: Icons.arrow_back, onTap: onBack),
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: score,
                  builder: (_, value, _) => isStage
                      ? _StageReadout(
                          score: value,
                          target: game.targetScore,
                        )
                      : _InfiniteReadout(
                          score: value,
                          speed: game.speedLevel + 1,
                        ),
                ),
              ),
              _RoundIconButton(icon: Icons.pause, onTap: onPause),
            ],
          ),
        ),
      ),
    );
  }
}

/// Infinite mode: a centered score with a small speed chip beside it.
class _InfiniteReadout extends StatelessWidget {
  const _InfiniteReadout({required this.score, required this.speed});

  final int score;
  final int speed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Label('SCORE'),
        const SizedBox(height: 2),
        _ScoreNumber(score),
        const SizedBox(height: 6),
        _Chip('Speed $speed'),
      ],
    );
  }
}

/// Stage mode: score over a slim progress bar toward the goal.
class _StageReadout extends StatelessWidget {
  const _StageReadout({required this.score, required this.target});

  final int score;
  final int target;

  @override
  Widget build(BuildContext context) {
    final progress = target <= 0 ? 0.0 : (score / target).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            _ScoreNumber(score),
            const SizedBox(width: 6),
            _Label('/ $target'),
          ],
        ),
        const SizedBox(height: 6),
        _ProgressBar(progress: progress),
      ],
    );
  }
}

class _ScoreNumber extends StatelessWidget {
  const _ScoreNumber(this.value);

  final int value;

  @override
  Widget build(BuildContext context) {
    final p = Palette.current;
    return Text(
      '$value',
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1,
        color: p.textPrimary,
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = Palette.current;
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        letterSpacing: 1.5,
        fontWeight: FontWeight.w600,
        color: p.textSecondary,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = Palette.current;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: p.accent.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: p.textPrimary,
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final p = Palette.current;
    return SizedBox(
      width: 160,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          builder: (_, value, _) => LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor: p.background,
            valueColor: AlwaysStoppedAnimation<Color>(p.accent),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.current;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: p.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: p.textPrimary, size: 22),
      ),
    );
  }
}

/// Shared frame for the modal overlays (pause / game over / win).
class _ModalCard extends StatelessWidget {
  const _ModalCard({required this.title, this.subtitle, required this.actions});

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = Palette.current;
    return Container(
      color: p.background.withValues(alpha: 0.82),
      alignment: Alignment.center,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.92, end: 1.0),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: p.textSecondary),
                ),
              ],
              const SizedBox(height: 24),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}

class OverlayButton extends StatelessWidget {
  const OverlayButton({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final p = Palette.current;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled ? p.accent : p.background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: filled ? p.textOnAccent : p.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({super.key, required this.onResume, required this.onQuit});

  final VoidCallback onResume;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) => _ModalCard(
        title: 'Paused',
        actions: [
          OverlayButton(label: 'Resume', onTap: onResume),
          OverlayButton(label: 'Quit', onTap: onQuit, filled: false),
        ],
      );
}

class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({
    super.key,
    required this.score,
    required this.isNewHighScore,
    required this.onRetry,
    required this.onMenu,
  });

  final int score;
  final bool isNewHighScore;
  final VoidCallback onRetry;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) => _ModalCard(
        title: 'Game Over',
        subtitle: isNewHighScore
            ? 'New high score: $score!'
            : 'Score: $score',
        actions: [
          OverlayButton(label: 'Play Again', onTap: onRetry),
          OverlayButton(label: 'Menu', onTap: onMenu, filled: false),
        ],
      );
}

class LevelClearOverlay extends StatelessWidget {
  const LevelClearOverlay({
    super.key,
    required this.score,
    required this.isLastLevel,
    required this.onNext,
    required this.onMenu,
  });

  final int score;
  final bool isLastLevel;
  final VoidCallback onNext;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) => _ModalCard(
        title: isLastLevel ? 'All Levels Clear!' : 'Level Clear!',
        subtitle: 'Score: $score',
        actions: [
          if (!isLastLevel) OverlayButton(label: 'Next Level', onTap: onNext),
          OverlayButton(
            label: isLastLevel ? 'Menu' : 'Back to Levels',
            onTap: onMenu,
            filled: isLastLevel,
          ),
        ],
      );
}
