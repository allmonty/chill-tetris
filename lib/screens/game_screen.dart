import 'package:flutter/material.dart';

import '../game/game_mode.dart';
import '../theme/palette.dart';

/// Hosts the Flame game and its overlays. (Board + gameplay added in Session 3.)
class GameScreen extends StatelessWidget {
  const GameScreen({super.key, required this.mode});

  static const String route = '/game';

  final GameMode mode;

  @override
  Widget build(BuildContext context) {
    final p = Palette.current;
    final label = switch (mode) {
      InfiniteMode() => 'Infinite',
      StageMode(:final level) => 'Level ${level.level}',
    };
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        foregroundColor: p.textPrimary,
        elevation: 0,
        title: Text(label),
      ),
      body: Center(
        child: Text('Game coming soon', style: TextStyle(color: p.textSecondary)),
      ),
    );
  }
}
