import '../models/level_config.dart';

/// Which mode a [TetrisGame] is running.
sealed class GameMode {
  const GameMode();
}

/// Endless play: empty board, gradually increasing speed, chase a high score.
class InfiniteMode extends GameMode {
  const InfiniteMode();
}

/// A single stage: pre-placed blocks, reach [LevelConfig.targetScore] to win.
class StageMode extends GameMode {
  const StageMode(this.level);

  final LevelConfig level;
}
