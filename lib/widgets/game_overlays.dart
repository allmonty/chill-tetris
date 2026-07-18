import 'package:flutter/material.dart';

import '../game/game_mode.dart';
import '../game/tetris_game.dart';
import '../theme/palette.dart';

/// Top bar shown over the board: score, goal/speed, pause and back controls.
class GameHud extends StatelessWidget {
  const GameHud({
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconButton(icon: Icons.arrow_back, onTap: onBack),
            const Spacer(),
            ValueListenableBuilder<int>(
              valueListenable: score,
              builder: (_, value, _) => Column(
                children: [
                  Text(
                    isStage ? 'SCORE / GOAL' : 'SCORE',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.5,
                      color: p.textSecondary,
                    ),
                  ),
                  AnimatedScale(
                    scale: 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Text(
                      isStage ? '$value / ${game.targetScore}' : '$value',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  if (!isStage)
                    Text(
                      'Speed ${game.speedLevel + 1}',
                      style: TextStyle(fontSize: 12, color: p.textSecondary),
                    ),
                ],
              ),
            ),
            const Spacer(),
            _IconButton(icon: Icons.pause, onTap: onPause),
          ],
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap});

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
          color: p.surface,
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
