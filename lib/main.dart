import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio/sound_service.dart';
import 'game/game_mode.dart';
import 'screens/game_screen.dart';
import 'screens/home_screen.dart';
import 'screens/level_select_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/app_theme.dart';
import 'theme/palette_scope.dart';
import 'theme/palette_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // Load the saved palette (so the app opens in the right theme) and warm up
  // audio in parallel — both are independent one-shot preference reads, and
  // audio degrades silently if the platform has no output.
  await Future.wait([
    PaletteService.instance.init(),
    SoundService.instance.init(),
  ]);
  runApp(const ChillTetrisApp());
}

class ChillTetrisApp extends StatefulWidget {
  const ChillTetrisApp({super.key});

  @override
  State<ChillTetrisApp> createState() => _ChillTetrisAppState();
}

class _ChillTetrisAppState extends State<ChillTetrisApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Rebuild so `buildAppTheme()` (below) recomputes when the palette changes.
    // The screens themselves react via PaletteScope; this is only for the
    // top-level ThemeData, which is built above the scope.
    PaletteService.instance.current.addListener(_onPaletteChanged);
  }

  @override
  void dispose() {
    PaletteService.instance.current.removeListener(_onPaletteChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onPaletteChanged() => setState(() {});

  /// Keep music in step with foreground/background. We run audio with
  /// `mixWithOthers` (no audio focus), so the OS no longer pauses our playback
  /// when the app is minimized or switched away from — we have to do it
  /// ourselves, then restart on return.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        SoundService.instance.ensureMusicPlaying();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        SoundService.instance.pauseMusicForBackground();
    }
  }

  @override
  Widget build(BuildContext context) {
    // A top-level pointer listener re-asserts music on any tap, anywhere. This
    // is what makes playback survive across screens: browsers (and some
    // platforms) refuse to start audio until a user gesture, so the initial
    // start in `init()` can be silently dropped — the first interaction on any
    // screen then kicks it back on. Passthrough (HitTestBehavior.deferToChild)
    // so it never eats taps meant for the UI beneath it.
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: (_) => SoundService.instance.ensureMusicPlaying(),
      child: MaterialApp(
        title: 'Chill Tetris',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        // Wrap the Navigator (not individual routes) so every screen can read
        // the live palette via PaletteScope.of(context) and rebuild on change.
        builder: (context, child) => PaletteScope(
          notifier: PaletteService.instance.current,
          child: child!,
        ),
        home: const HomeScreen(),
        navigatorObservers: [_MusicKeepAliveObserver()],
        routes: {
          LevelSelectScreen.route: (_) => const LevelSelectScreen(),
          SettingsScreen.route: (_) => const SettingsScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == GameScreen.route) {
            final mode =
                settings.arguments as GameMode? ?? const InfiniteMode();
            return MaterialPageRoute(builder: (_) => GameScreen(mode: mode));
          }
          return null;
        },
      ),
    );
  }
}

/// Re-asserts background music on every page transition — see
/// [SoundService.ensureMusicPlaying] for why this is needed rather than
/// assumed: it's a cheap self-heal, not something navigation should ever have
/// to do on its own.
class _MusicKeepAliveObserver extends NavigatorObserver {
  void _ensure() => SoundService.instance.ensureMusicPlaying();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _ensure();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _ensure();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _ensure();
}
