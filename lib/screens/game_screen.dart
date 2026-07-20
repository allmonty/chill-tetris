import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/game_mode.dart';
import '../game/tetris_game.dart';
import '../models/level_config.dart';
import '../services/progress_service.dart';
import '../theme/palette.dart';
import '../widgets/game_overlays.dart';
import 'settings_screen.dart';

/// Hosts the Flame game and its Flutter overlays (HUD, pause, game over, win).
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.mode});

  static const String route = '/game';

  final GameMode mode;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const pause = 'pause';
  static const gameOver = 'gameOver';
  static const win = 'win';
  static const confirmExit = 'confirmExit';

  late final TetrisGame _game;
  final ValueNotifier<int> _score = ValueNotifier<int>(0);

  ProgressService? _progress;
  bool _newHighScore = false;
  LevelConfig? _nextLevelConfig;
  bool _isLastLevel = false;

  /// True when the exit prompt itself paused the game, so "Keep Playing" knows
  /// to resume (rather than leaving a game that was already paused paused).
  bool _pausedForExitPrompt = false;

  @override
  void initState() {
    super.initState();
    _game = TetrisGame(
      mode: widget.mode,
      onScoreChanged: (s) => _score.value = s,
      onGameOver: _handleGameOver,
      onWin: _handleWin,
    );
    ProgressService.load().then((p) => _progress = p);
    if (widget.mode case StageMode(:final level)) {
      _resolveNextLevel(level.level);
    }
  }

  Future<void> _resolveNextLevel(int current) async {
    final levels = (await LevelCatalog.load()).levels;
    if (!mounted) return;
    final idx = levels.indexWhere((l) => l.level == current);
    setState(() {
      if (idx >= 0 && idx + 1 < levels.length) {
        _nextLevelConfig = levels[idx + 1];
      } else {
        _isLastLevel = true;
      }
    });
  }

  @override
  void dispose() {
    _score.dispose();
    super.dispose();
  }

  Future<void> _handleGameOver(int score) async {
    if (widget.mode is InfiniteMode) {
      final progress = _progress ??= await ProgressService.load();
      _newHighScore = await progress.recordInfiniteScore(score);
    }
    _game.overlays.add(gameOver);
  }

  Future<void> _handleWin(int score) async {
    if (widget.mode case StageMode(:final level)) {
      final progress = _progress ??= await ProgressService.load();
      await progress.completeLevel(level.level);
    }
    _game.overlays.add(win);
  }

  void _togglePause() {
    _game.togglePause();
    if (_game.isPaused) {
      _game.overlays.add(pause);
    } else {
      _game.overlays.remove(pause);
    }
  }

  void _restart() {
    Navigator.of(
      context,
    ).pushReplacementNamed(GameScreen.route, arguments: widget.mode);
  }

  /// Returns to whatever screen launched the game (level select for stage
  /// mode, home for infinite). Restart/next-level use pushReplacement, so the
  /// screen below is always the original launcher.
  void _exitGame() {
    Navigator.of(context).pop();
  }

  /// Handles a system back gesture/button while the game is up. The Android
  /// edge-swipe is easy to trigger by accident mid-play, so instead of leaving
  /// we pause the run and ask for confirmation. No-op if the prompt is already
  /// showing; if the game is already over/won, we just let the pop through.
  void _requestExit() {
    if (_game.overlays.isActive(confirmExit)) return;
    if (_game.isOver || _game.hasWon) {
      _exitGame();
      return;
    }
    // Freeze the falling piece while the player decides, unless something else
    // (e.g. the pause menu) already paused it.
    if (!_game.isPaused) {
      _game.togglePause();
      _pausedForExitPrompt = true;
    }
    _game.overlays.add(confirmExit);
  }

  void _dismissExitPrompt() {
    _game.overlays.remove(confirmExit);
    if (_pausedForExitPrompt) {
      _game.togglePause();
      _pausedForExitPrompt = false;
    }
  }

  void _nextLevel() {
    final next = _nextLevelConfig;
    if (next == null) {
      _exitGame();
      return;
    }
    Navigator.of(
      context,
    ).pushReplacementNamed(GameScreen.route, arguments: StageMode(next));
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.current;
    return PopScope(
      // We never let the framework pop directly — a back gesture routes through
      // the confirmation prompt instead (which pops itself once confirmed).
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _requestExit();
      },
      child: Scaffold(
        backgroundColor: p.background,
        body: Column(
          children: [
            // A real top bar with its own vertical space — the board lives below
            // it and never overlaps it.
            GameTopBar(
              game: _game,
              score: _score,
              onPause: _togglePause,
              onBack: _exitGame,
            ),
            Expanded(
              // Keep the board clear of the Android system nav bar / home
              // indicator at the bottom (and any side insets).
              child: SafeArea(
                top: false,
                child: GameWidget<TetrisGame>(
                  game: _game,
                  overlayBuilderMap: {
                    pause: (_, _) => PauseOverlay(
                      onResume: _togglePause,
                      onSettings: () =>
                          Navigator.of(context).pushNamed(SettingsScreen.route),
                      onQuit: _exitGame,
                    ),
                    gameOver: (_, game) => GameOverOverlay(
                      score: game.score,
                      isNewHighScore: _newHighScore,
                      onRetry: _restart,
                      onMenu: _exitGame,
                    ),
                    win: (_, game) => LevelClearOverlay(
                      score: game.score,
                      isLastLevel: _isLastLevel,
                      onNext: _nextLevel,
                      onMenu: _exitGame,
                    ),
                    confirmExit: (_, _) => ConfirmQuitOverlay(
                      onKeepPlaying: _dismissExitPrompt,
                      onQuit: _exitGame,
                    ),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
