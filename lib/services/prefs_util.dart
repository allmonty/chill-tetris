import 'package:shared_preferences/shared_preferences.dart';

/// Runs [write] against the shared [SharedPreferences] instance, swallowing
/// any failure so a persistence error never breaks the in-memory state that
/// already applied. Shared by the settings services (audio, palette).
Future<void> persistPrefs(
    Future<void> Function(SharedPreferences prefs) write) async {
  try {
    await write(await SharedPreferences.getInstance());
  } catch (_) {
    // Non-fatal: the setting still works for this session.
  }
}
