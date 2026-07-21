import 'package:flutter/material.dart';

import '../audio/sound_config.dart';
import '../audio/sound_service.dart';
import '../game/game_mode.dart';
import '../models/level_config.dart';
import '../services/progress_service.dart';
import '../theme/palette_scope.dart';
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
    final p = PaletteScope.of(context);
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
                return _LevelTile(
                  level: level.level,
                  won: progress.isLevelWon(level.level),
                  onTap: () => _openLevel(level),
                );
              },
            ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.level,
    required this.won,
    required this.onTap,
  });

  final int level;

  /// Whether this level has been cleared — shows a star badge if so.
  final bool won;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: p.accent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                '$level',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: p.textOnAccent,
                ),
              ),
            ),
            if (won)
              Positioned(
                top: 4,
                right: 4,
                child: Icon(Icons.star_rounded, color: p.textOnAccent, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}
