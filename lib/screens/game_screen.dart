import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/game_mode.dart';
import '../game/tetris_game.dart';
import '../services/progress_service.dart';
import '../theme/palette.dart';
import '../widgets/game_overlays.dart';

/// Hosts the Flame game and its Flutter overlays (HUD, pause, game over, win).
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.mode});

  static const String route = '/game';

  final GameMode mode;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const hud = 'hud';
  static const pause = 'pause';
  static const gameOver = 'gameOver';
  static const win = 'win';

  late final TetrisGame _game;
  final ValueNotifier<int> _score = ValueNotifier<int>(0);

  ProgressService? _progress;
  bool _newHighScore = false;

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
    Navigator.of(context).pushReplacementNamed(
      GameScreen.route,
      arguments: widget.mode,
    );
  }

  void _backToMenu() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _nextLevel() {
    // Wired up fully in Session 5 when the level list is available; for now,
    // returning to the menu is the safe default.
    _backToMenu();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.current;
    return Scaffold(
      backgroundColor: p.background,
      body: GameWidget<TetrisGame>(
        game: _game,
        initialActiveOverlays: const [hud],
        overlayBuilderMap: {
          hud: (_, game) => GameHud(
                game: game,
                score: _score,
                onPause: _togglePause,
                onBack: _backToMenu,
              ),
          pause: (_, _) => PauseOverlay(onResume: _togglePause, onQuit: _backToMenu),
          gameOver: (_, game) => GameOverOverlay(
                score: game.score,
                isNewHighScore: _newHighScore,
                onRetry: _restart,
                onMenu: _backToMenu,
              ),
          win: (_, game) => LevelClearOverlay(
                score: game.score,
                onNext: _nextLevel,
                onMenu: _backToMenu,
              ),
        },
      ),
    );
  }
}
