import 'package:flutter/material.dart';

import '../audio/sound_config.dart';
import '../audio/sound_service.dart';
import '../game/game_mode.dart';
import '../models/level_config.dart';
import '../services/progress_service.dart';
import '../theme/palette.dart';
import 'game_screen.dart';

/// Stage-mode level picker: a grid of levels, each locked until the previous
/// one is cleared.
class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  static const String route = '/levels';

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  LevelCatalog? _catalog;
  ProgressService? _progress;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final catalog = await LevelCatalog.load();
    final progress = await ProgressService.load();
    if (!mounted) return;
    setState(() {
      _catalog = catalog;
      _progress = progress;
    });
  }

  Future<void> _openLevel(LevelConfig level) async {
    SoundService.instance.play(Sfx.uiTap);
    await Navigator.of(context).pushNamed(
      GameScreen.route,
      arguments: StageMode(level),
    );
    // Refresh unlock state when returning from a level.
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.current;
    final catalog = _catalog;
    final progress = _progress;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        foregroundColor: p.textPrimary,
        elevation: 0,
        title: const Text('Select Level'),
      ),
      body: (catalog == null || progress == null)
          ? Center(child: CircularProgressIndicator(color: p.accent))
          : GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.85,
              ),
              itemCount: catalog.levels.length,
              itemBuilder: (_, i) {
                final level = catalog.levels[i];
                final unlocked = level.level <= catalog.unlockedAtStart ||
                    progress.isLevelUnlocked(level.level);
                return _LevelTile(
                  level: level.level,
                  unlocked: unlocked,
                  onTap: unlocked ? () => _openLevel(level) : null,
                );
              },
            ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.level,
    required this.unlocked,
    required this.onTap,
  });

  final int level;
  final bool unlocked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.current;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: unlocked ? p.accent : p.lockedLevel,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: unlocked
              ? Text(
                  '$level',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: p.textOnAccent,
                  ),
                )
              : Icon(Icons.lock, color: p.textSecondary, size: 24),
        ),
      ),
    );
  }
}
