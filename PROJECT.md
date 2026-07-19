# Chill Tetris — Project Context

A relaxing Tetris game for mobile, built with **Flutter** and the
[Flame](https://flame-engine.org) game engine. This document is the single
source of truth for the project: what it is, how it's built, the decisions
behind it, and everything implemented so far. It is written so that a person or
an AI can pick up the project with full context.

---

## 1. Product overview

Chill Tetris is a calm, tactile take on Tetris. Everything — visuals, motion,
and sound — is tuned to feel gentle and relaxing rather than fast and arcade-y.

Two modes, chosen from the home screen:

- **Infinite** — start on an empty board and chase a high score. Fall speed
  graduates upward every 10 cleared lines until it caps at full speed. Ends on
  top-out; the high score persists.
- **Stage** — 15 hand-designed levels, each starting with pre-placed blocks and
  cleared by reaching a target score. Levels unlock in sequence; progress is
  saved between sessions.

**Controls are gestures only:**

- **Drag left/right** — move the piece across columns.
- **Drag down** — soft drop.
- **Flick down** — hard drop.
- **Tap** — rotate clockwise (with simple wall kicks).

---

## 2. Tech stack & environment

- **Flutter** 3.41.4 (stable), **Dart** 3.11.1, installed via **asdf**.
- SDK constraint: `sdk: ^3.11.1`.
- Target platforms: **Android** and **iOS** (portrait only). **Web** is enabled
  for quick local testing.
- Dependencies (`pubspec.yaml`):
  - `flame: ^1.37.0` — game loop, rendering, gesture input.
  - `audioplayers: ^6.7.1` — audio playback (see the pivot note in §9).
  - `shared_preferences: ^2.5.5` — progress + settings persistence.
  - `cupertino_icons` — icon font.
- Dev: `flutter_test`, `flutter_lints`.

### Key decisions (and why)

- **Flame engine** for the board rendering and game loop (chosen over pure
  CustomPaint) — user preference.
- **Gestures only**, no on-screen buttons — user preference; keeps the screen
  clean.
- **All audio is synthesized in code** — no audio asset files. Sound effects and
  music are generated from small data specs, mirroring how the color palette
  works, so they're trivially editable. (User asked specifically to "code the
  sounds.")
- **Palette-driven theming** — colors are referenced by semantic role, so the
  whole game re-themes from one place.
- **Pure Dart game models** kept separate from Flame/Flutter, so rules are unit
  testable without a running engine.

---

## 3. Architecture

Three layers, cleanly separated:

1. **Pure Dart models** (`lib/models/`) — the rules of the game (board,
   tetrominoes, scoring, level parsing). No Flame, no Flutter widgets. Unit
   tested.
2. **Flame game** (`lib/game/`) — the loop, rendering, gesture input, timing,
   and animation. Reads the models; calls the audio service.
3. **Flutter UI** (`lib/screens/`, `lib/widgets/`, `lib/theme/`) — menus, the
   game host, HUD, and modal overlays.

Cross-cutting: `lib/audio/` (synthesized sound + music) and `lib/services/`
(persistence). Both audio and palette are global singletons/statics so any layer
can reach them.

### File map

```
lib/
  main.dart                     App entry: portrait lock, routes (/ , /levels, /game),
                                theme, and SoundService.instance.init() before runApp.
  theme/
    palette.dart                GamePalette (semantic color roles) + midCenturyModern
                                (default) and dusk (example). Palette.current is the
                                global accessor.
    app_theme.dart              Bridges the GamePalette into Flutter ThemeData for menus.
  models/                       PURE DART, engine-agnostic, unit tested:
    board.dart                  10x20 grid of int? (palette color index). Collision
                                (canPlace/canPlaceAt), lock, fullRows, clearRows, top-out.
    tetromino.dart              7 pieces (I,O,T,S,Z,J,L), rotation states, color index,
                                Piece (mutable active piece), SevenBag (fair spawner).
    scoring.dart                lineClearScore(lines): 100/300/500/800 for 1/2/3/4.
    level_config.dart           LevelConfig + InitialCell, loads/parses assets JSON,
                                validates & drops out-of-range cells (asserts in debug).
  game/
    tetris_game.dart            FlameGame. Gravity, spawning (7-bag), scoring, speed
                                graduation, lock delay, line-clear phases, win/lose,
                                gesture handling, fires audio events.
    board_component.dart        Renders board bg, faint grid, locked cells (with lock
                                bounce + settle offsets), ghost piece, active piece.
    piece_component.dart        (Piece rendering helpers, used by board rendering.)
    game_mode.dart              sealed GameMode: InfiniteMode | StageMode(LevelConfig).
    animation_config.dart       All game-feel tunables (durations, scales, curves).
    cell_animator.dart          Per-cell tween tracker (scale/opacity/settle) advanced
                                in update(dt), applied in render. Keeps Board anim-free.
  screens/
    home_screen.dart            Title + Stage/Infinite buttons + SoundToggleButton.
    level_select_screen.dart    4-col grid of 15 levels; locked/unlocked/complete states.
    game_screen.dart            Hosts GameWidget in a Column under the top bar; wires
                                overlays (pause/gameOver/win) and mode selection.
  widgets/
    game_overlays.dart          GameTopBar (score/goal or score/speed, back, pause),
                                and the pause / game-over / level-clear modal cards.
  services/
    progress_service.dart       shared_preferences: unlocked level + infinite high score.
  audio/
    sound_config.dart           SFX "palette": Sfx enum, SoundSpec, SoundConfig (master
                                volume, base freq, pentatonic scale, one spec per event).
    music_config.dart           Music "palette": MusicNote, MusicConfig (bpm, loop length,
                                flat note list — bass/pad/melody voices).
    synth_core.dart             Shared DSP: frequencyForDegree, waveSample, pluckEnvelope,
                                encodeWav. Used by both synths.
    tone_synth.dart             synthesize(SoundSpec) -> WAV bytes (one-shot SFX).
    music_synth.dart            synthesizeMusic() -> one seamless looping WAV.
    sound_service.dart          Singleton. Loads prefs, synthesizes all SFX + music,
                                plays with throttling, mute toggle, loops music. Degrades
                                to silence if audio can't init.
assets/
  levels/levels.json            15 stage definitions.
test/
  board_test.dart               Collision, lock, line clear, top-out.
  tetromino_test.dart           Rotation / shapes.
  level_config_test.dart        JSON parse: valid, missing, out-of-range.
  tone_synth_test.dart          WAV header/format/duration/signal for every SFX.
  music_synth_test.dart         WAV validity, loop duration, signal, no clipping.
  widget_test.dart              Home screen renders title + buttons.
```

---

## 4. Core mechanics

- **Board:** 10 columns × 20 rows. Cells hold an `int?` = palette `pieceColors`
  index (null = empty).
- **Spawning:** 7-bag randomizer (`SevenBag`) for fair piece distribution. Each
  tetromino type maps to a fixed color index (I→0 … L→6).
- **Scoring:** `lineClearScore` — 100 / 300 / 500 / 800 for 1 / 2 / 3 / 4 lines.
- **Speed graduation (infinite):** interval starts at **0.8s** per cell, ×0.85
  every **10** lines, floored at **0.12s** (full speed). Constants:
  `_infiniteStartInterval`, `_infiniteSpeedFactor`, `_linesPerSpeedLevel`,
  `_infiniteMinInterval` in `tetris_game.dart`.
- **Lock delay:** a landed piece locks after a short **0.12s** delay
  (`_lockDelaySeconds`), checked **every frame** (not on the gravity tick). This
  is important: it makes landing feel immediate at any fall speed and lets the
  land/clear sounds fire promptly. A brief window still allows a last nudge.
- **Line-clear phases:** on lock, full rows enter a `GamePhase.clearing` state;
  cells shrink/fade with a left-to-right stagger while gravity pauses, then
  `_finishClear` removes them and eases the rows above down into place.
- **Win/lose:** stage mode wins when `score >= targetScore` (unlocks next level);
  both modes lose on top-out (infinite records high score).

---

## 5. Theming / color palette

Colors are referenced by **semantic role**, never raw hex. Swapping
`Palette.current` in [lib/theme/palette.dart](lib/theme/palette.dart) re-themes
the whole app (menus, board, pieces). A second `GamePalette.dusk` is included as
an example.

Current palette = **mid-century modern** (`GamePalette.midCenturyModern`):

| Role | Hex | Notes |
|---|---|---|
| background | `#F1EFE9` | screen background |
| surface | `#DBD9D4` | cards, top bar, buttons |
| boardBackground | `#4E4243` | **dark walnut** — pieces pop against it |
| gridLine | `#F1EFE9` | drawn at ~7% alpha, a faint grid |
| textPrimary | `#4E4243` | |
| textSecondary | `#536D81` | slate blue |
| textOnAccent | `#4E4243` | |
| accent | `#DDB058` | mustard |
| danger | `#B06757` | terracotta |
| lockedLevel | `#CDCDC9` | locked level tiles |
| pieceColors[0..6] | `#8F9779` sage, `#DDB058` mustard, `#E6D394` pale gold, `#9BB0BC` dusty blue, `#D2A799` clay pink, `#CED5B6` pale sage, `#B06757` terracotta | one per tetromino |

**History note:** the board was originally light grey (`#CDCDC9`), which gave
pieces near-invisible contrast (WCAG ~1.05–1.9). It was changed to dark walnut
(pieces now ~3.1–6.5), and the piece formerly slate-blue was swapped to
terracotta because slate blue disappeared against the dark board.

---

## 6. Level configuration

Stages live in [assets/levels/levels.json](assets/levels/levels.json) — a list
of maps, 15 entries:

```json
{
  "level": 1,
  "targetScore": 300,
  "initialPieces": [
    { "x": 0, "y": 19, "color": 0 }
  ]
}
```

- `level` — 1-based level number.
- `targetScore` — points needed to win.
- `initialPieces` — pre-placed cells (JSON key is `initialPieces`; parsed into
  `InitialCell`s):
  - `x` — column, `0`–`9` (left → right)
  - `y` — row, `0`–`19` (top → bottom)
  - `color` — index into `pieceColors`, `0`–`6`
- Out-of-range cells are dropped (with a debug `assert`) so a bad config can't
  crash the board.
- **Never fill an entire starting row**, or it clears on the first lock.

---

## 7. Game feel / animations

All tunables in [lib/game/animation_config.dart](lib/game/animation_config.dart)
— deliberately subtle to stay relaxing:

- **Lock bounce:** 200ms, scale 1.08, `easeOutBack`.
- **Line clear:** each cell bounces to 1.12 then shrinks/fades over 320ms, with
  a 25ms-per-column left-to-right stagger.
- **Rows settle:** 220ms `easeOut` down into place.
- **Spawn fade:** 140ms fade-in.
- **Ghost piece:** landing preview at low opacity.

`cell_animator.dart` tracks per-cell tweens each frame and the board component
applies them at render time, keeping the pure `Board` model animation-free.

The top bar (`GameTopBar`) is a solid bar **above** the board (in a `Column`),
not a floating overlay, so it never overlaps the playfield; the board area is
wrapped in `SafeArea(top: false)` to stay clear of the Android nav bar.

---

## 8. Audio — sound effects

Everything is **synthesized at runtime** into WAV byte buffers; there are no
audio files. Design mirrors the color palette so it's data-editable.

- **Definition** — [lib/audio/sound_config.dart](lib/audio/sound_config.dart):
  - Global: `masterVolume` (0.4), `baseFrequency` (392 Hz = G4), `scale`
    (major pentatonic `[0,2,4,7,9]`), `sampleRate` (44100).
  - `Sfx` enum events: `uiTap, move, rotate, hardDrop, lock, lineClear1..4,
    levelWin, gameOver`.
  - `SoundConfig.sounds` maps each event → `SoundSpec` (list of pentatonic scale
    **degrees**, waveform, note duration, gap, attack, release, volume). Gap `0`
    = chord; gap > 0 = arpeggio.
- **Relaxing by construction:** every note is a pentatonic degree (never
  dissonant even when retuned), soft sine/triangle waveforms, click-free
  attack/decay envelopes, low volume.
- **Rendering** — `tone_synth.dart` (`synthesize`) builds the buffer using shared
  DSP in `synth_core.dart`.
- **Playback** — `sound_service.dart` (singleton): one `AudioPlayer` per event
  (so sounds overlap), plays `BytesSource`, throttles rapid repeats (move 45ms,
  rotate 30ms) so movement never rattles. Degrades to silence on any failure.
- **Sound timing** (an explicit fix): the land "tock" and line-clear chime used
  to lag because lock detection waited for the next gravity tick and the clear
  sound played after the shrink animation. Now: landing is detected every frame
  (0.12s lock delay), the clear chime plays at the **start** of the clear, and
  the land tock plays **only when nothing clears** (a clearing drop plays just
  the chime, not both).
- **Mute:** speaker button on the home screen; choice persisted in
  shared_preferences (`sound_enabled`). Mutes both SFX and music.

Event → sound summary: tap = soft tick; move = subtle blip; rotate = light
pluck; hardDrop = quick descending run; lock = low woody tock; lineClear1..4 =
ascending pentatonic arpeggios that grow with more lines; levelWin = flourish;
gameOver = soft descending sigh.

---

## 9. Audio — background music

A single **synthesized looping ambient track** — also no file.

- **Definition** — [lib/audio/music_config.dart](lib/audio/music_config.dart):
  `masterVolume` (0.22, sits under the SFX), `bpm` (63), `loopBeats` (16 = four
  4/4 bars ≈ **15.24s**), and `track`: a flat `List<MusicNote>`. Three loose
  voices share the list — a low bass (one root/bar), a soft pad wash, and a
  sparse melody. Each `MusicNote(startBeat, beats, degree, {volume, waveform,
  attack, release})`.
- **Seamless loop** — `music_synth.dart` (`synthesizeMusic`): renders one loop;
  any note tail that runs past the loop end **wraps around and sums onto the
  start**, so on repeat the tail flows into the next pass with no click/gap. The
  buffer is normalized to ~0.9 peak; final loudness comes from the player volume.
- **Playback** — a dedicated looping `AudioPlayer` (`ReleaseMode.loop`) in
  `sound_service.dart`, started at app launch if enabled, plays app-wide (menus
  + game), shares the mute toggle.

### Important pivot: flutter_soloud → audioplayers

The audio engine was first `flutter_soloud`. It compiled in Dart but its native
C++ engine **failed to build via CMake/NDK** (NDK 27 / Clang 18) and broke the
Android APK. It was replaced with **`audioplayers`** (pure platform channels, no
native compile step), which plays the synthesized WAV bytes via `BytesSource`.
All synthesis code was unchanged — only `sound_service.dart` swapped. **Do not
reintroduce a native-compiled audio plugin without checking the Android build.**

**Possible latency note:** `audioplayers` re-buffers a `BytesSource` on each
`play()`, which can add small per-play latency. If on-device SFX feel slightly
late, the planned fix is to preload low-latency file sources (write the WAVs to
a temp/cache dir and use `DeviceFileSource` in low-latency mode). Not yet done.

---

## 10. Persistence

`lib/services/progress_service.dart` — `shared_preferences`, **local on-device**
storage (Android SharedPreferences / iOS NSUserDefaults / web localStorage — not
cookies, not cloud, no cross-device sync).

- `unlocked_level` (int, default 1) — highest stage the player may enter.
- `high_score_infinite` (int) — infinite-mode best.
- `sound_enabled` (bool) — audio mute preference.

Uninstalling the app (or clearing browser data on web) wipes it. Cross-device /
reinstall-safe sync would require an account/cloud backend (not implemented).

---

## 11. Build, run, test

```sh
flutter pub get
flutter run                 # on a connected device or simulator
flutter test                # all unit/widget tests
flutter analyze             # lints
flutter build apk --debug   # Android build (used to verify audioplayers)
```

- VSCode launch configs exist in `.vscode/launch.json`: **Chill Tetris
  (debug / profile / release)**. They don't pin a device — pick the target in
  the VSCode status bar, then F5.
- Portrait orientation is locked in `main.dart`.

### Verification approach used in this environment

- Logic is covered by unit tests (`flutter test`) and `flutter analyze`.
- Audio can't be heard here, so synthesized sounds/music are exported to WAV and
  validated with macOS `afinfo` (format + duration) and unit tests (header,
  duration, signal present, no clipping). Preview WAVs are written to the
  scratchpad on demand.
- Rendering/contrast has been sanity-checked by painting to a PNG in a headless
  test and inspecting it.

### Known environment blockers

- The local **Android emulator's disk is full** (`/data` ~95%, other apps
  installed), so installing/running on it is blocked — builds succeed but
  `adb install` fails with "not enough space". Free space (uninstall an app, or
  wipe/resize the AVD) to run on device.
- Screen capture / on-device audition are not available in this environment, so
  visuals and audio "feel" are verified indirectly (PNG/WAV export + tests),
  not by watching/hearing the running app.

---

## 12. Git history (most recent first)

```
Add synthesized, looping chill background music
Play land and line-clear sounds without delay
Add synthesized, palette-style sound effects
Move game info into a solid top bar, clear of board and system insets
Fix low contrast between pieces and board
Add VSCode launch configs for debug/profile/release
Document game, controls, palette and level config in README
Add stage mode with 15 levels and progression
Add playable infinite mode with HUD and game-feel animations
Add web platform for local testing
Add board/tetromino models, scoring and unit tests
Scaffold app, palette, routes and home screen
Initial commit
```

Work is committed on the `build-chill-tetris` branch (default branch: `main`).

---

## 13. Possible next steps (not implemented)

- Cloud/account save for cross-device progress (Firebase / Game Center / Google
  Play Games) — current persistence is local only.
- Low-latency file-based SFX playback (see §9) if on-device latency is an issue.
- Separate music vs. SFX volume/mute controls (currently one toggle).
- More palettes / a palette picker; more stages; a settings screen.
