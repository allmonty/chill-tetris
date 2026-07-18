import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// Stage-mode level picker. (Full grid + lock/unlock logic added in Session 5.)
class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key});

  static const String route = '/levels';

  @override
  Widget build(BuildContext context) {
    final p = Palette.current;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        foregroundColor: p.textPrimary,
        elevation: 0,
        title: const Text('Select Level'),
      ),
      body: Center(
        child: Text('Levels coming soon', style: TextStyle(color: p.textSecondary)),
      ),
    );
  }
}
