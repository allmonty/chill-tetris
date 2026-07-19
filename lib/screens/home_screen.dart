import 'package:flutter/material.dart';

import '../audio/sound_config.dart';
import '../audio/sound_service.dart';
import '../game/game_mode.dart';
import '../theme/palette.dart';
import 'game_screen.dart';
import 'level_select_screen.dart';
import 'settings_screen.dart';

/// Landing screen: the game title and the two mode buttons.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.current;
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _SettingsButton(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Chill',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 2,
                      color: p.textPrimary,
                    ),
                  ),
                  Text(
                    'TETRIS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 10,
                      color: p.accent,
                    ),
                  ),
                  const SizedBox(height: 64),
                  _MenuButton(
                    label: 'Stage',
                    filled: true,
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(LevelSelectScreen.route),
                  ),
                  const SizedBox(height: 16),
                  _MenuButton(
                    label: 'Infinite',
                    filled: false,
                    onTap: () => Navigator.of(context).pushNamed(
                      GameScreen.route,
                      arguments: const InfiniteMode(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatefulWidget {
  const _MenuButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p = Palette.current;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () {
        SoundService.instance.play(Sfx.uiTap);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Container(
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.filled ? p.accent : p.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: widget.filled ? p.textOnAccent : p.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// A gear icon opening the audio settings screen.
class _SettingsButton extends StatelessWidget {
  const _SettingsButton();

  @override
  Widget build(BuildContext context) {
    final p = Palette.current;
    return GestureDetector(
      onTap: () {
        SoundService.instance.play(Sfx.uiTap);
        Navigator.of(context).pushNamed(SettingsScreen.route);
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.settings_rounded, color: p.textPrimary, size: 22),
      ),
    );
  }
}
