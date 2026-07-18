import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/game_mode.dart';
import 'screens/game_screen.dart';
import 'screens/home_screen.dart';
import 'screens/level_select_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const ChillTetrisApp());
}

class ChillTetrisApp extends StatelessWidget {
  const ChillTetrisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chill Tetris',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomeScreen(),
      routes: {
        LevelSelectScreen.route: (_) => const LevelSelectScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == GameScreen.route) {
          final mode = settings.arguments as GameMode? ?? const InfiniteMode();
          return MaterialPageRoute(builder: (_) => GameScreen(mode: mode));
        }
        return null;
      },
    );
  }
}
