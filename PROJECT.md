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
- **Stage** — 50 hand-designed levels, each starting with pre-placed blocks and
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
- Dev: `flutter_test`, `flutter_lints`.

### Key decisions (and why)

- **Flame engine** for the board rendering and game loop (chosen over pure
  CustomPaint) — user preference.
- **Gestures only**, no on-screen buttons — user preference; keeps the screen
  clean.
- **Audio is defined in code, pre-rendered to committed assets** — sound
  effects and music are generated from small data specs, mirroring how the
  color palette works, so they're trivially editable (user asked specifically
  to "code the sounds"). `tool/generate_audio.dart` renders each spec to a WAV
  once at authoring time; the app bundles and plays those files, doing no DSP
  at runtime (see §8/§9).
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
  main.dart                     App entry: portrait lock, routes (/ , /levels, /game,
                                /settings), theme, SoundService.instance.init() before
                                runApp, plus three music keep-alive hooks (see §9): a
                                NavigatorObserver (page transitions), a lifecycle
                                observer (app resumed), and a passthrough pointer
                                Listener (any tap, for web autoplay restrictions).
  theme/
    palette.dart                GamePalette (semantic color roles) + midCenturyModern
                                (default) and dusk (example). Palette.current is the
                                global accessor.
    app_theme.dart              Bridges the GamePalette into Flutter ThemeData for menus.
  models/                       PURE DART, engine-agnostic, unit tested:
    board.dart                  10x20 grid of int? (palette color index). Collision
                                (canPlace/canPlaceAt), lock, fullRows, clearRows.
                                Top-out is just canPlace failing at spawn.
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
    game_mode.dart              sealed GameMode: InfiniteMode | StageMode(LevelConfig).
    animation_config.dart       All game-feel tunables (durations, scales, curves).
    cell_animator.dart          Per-cell tween tracker (scale/opacity/settle) advanced
                                in update(dt), applied in render. Keeps Board anim-free.
  screens/
    home_screen.dart            Title + Stage/Infinite buttons + gear button (Settings).
    level_select_screen.dart    4-col grid of 50 levels; locked/unlocked/complete states.
    game_screen.dart            Hosts GameWidget in a Column under the top bar; wires
                                overlays (pause/gameOver/win) and mode selection.
    settings_screen.dart        Music/SFX sections: enable Switch + volume Slider each,
                                reading/writing SoundService's notifiers.
  widgets/
    game_overlays.dart          GameTopBar (score/goal or score/speed, back, pause),
                                and the pause (Resume/Settings/Quit) / game-over /
                                level-clear modal cards.
  services/
    progress_service.dart       shared_preferences: unlocked level + infinite high score.
  audio/
    sound_config.dart           SFX "palette": Sfx enum, SoundSpec, SoundConfig (master
                                volume, base freq, pentatonic scale, one spec per event).
    music_config.dart           Music "palette": MusicNote, MusicConfig (bpm, loop length,
                                flat note list — bass/pad/melody voices).
    synth_core.dart             Shared DSP: frequencyForDegree, waveSample, pluckEnvelope,
                                declickEdges, encodeWav. Used by both synths.
    tone_synth.dart             synthesize(SoundSpec) -> WAV bytes (one-shot SFX). Only
                                consumer today is tool/generate_audio.dart.
    music_synth.dart            synthesizeMusic() -> one seamless looping WAV. Same.
    audio_settings.dart         Pure prefs model: music/sfx enabled + volume, with
                                one-time migration from the legacy sound_enabled key.
    sound_service.dart          Singleton. Loads AudioSettings; each Sfx gets an AudioPool
                                (preloaded, round-robin players so a retrigger never cuts
                                off the previous play — see §8); music gets one preloaded
                                looping AudioPlayer. Throttling + per-channel enable/volume.
                                Degrades to silence if audio can't init.
tool/
  generate_audio.dart           CLI (`dart run tool/generate_audio.dart`): renders every
                                Sfx + the music loop via tone_synth/music_synth and
                                writes assets/audio/*.wav. Run after editing
                                sound_config.dart / music_config.dart, then commit.
assets/
  levels/levels.json            50 stage definitions + unlockedAtStart.
  audio/*.wav                   Committed, pre-rendered SFX + music.wav (generated,
                                never hand-edited — see tool/generate_audio.dart).
test/
  board_test.dart               Collision, lock, line clear, top-out.
  tetromino_test.dart           Rotation / shapes.
  level_config_test.dart        JSON parse: valid, missing, out-of-range.
  tone_synth_test.dart          WAV header/format/duration/signal for every SFX.
  music_synth_test.dart         WAV validity, loop duration, signal, no clipping.
  audio_assets_test.dart        Guards assets/audio/*.wav against the synth configs;
                                fails with a "run: dart run tool/generate_audio.dart"
                                hint if the committed files are stale.
  audio_settings_test.dart      AudioSettings defaults, legacy-key migration, clamping.
  settings_screen_test.dart     Settings screen renders both sections; toggling and
                                disabling wire through to SoundService.
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

Stages live in [assets/levels/levels.json](assets/levels/levels.json) — an
object with catalog-wide settings and 50 level entries:

```json
{
  "unlockedAtStart": 1,
  "levels": [
    {
      "level": 1,
      "targetScore": 300,
      "initialPieces": [
        { "x": 0, "y": 19, "color": 0 }
      ]
    }
  ]
}
```

- `unlockedAtStart` — how many levels are playable before any progress is
  made (clamped to `1..levels.length`; a legacy bare-list file parses with
  a value of 1).
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

- **Lock bounce:** 200ms, scale 1.08, a smooth sine up-and-back.
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

Sounds are **defined in code, pre-rendered to committed WAV files**. Design
mirrors the color palette so the *definitions* stay data-editable, but nothing
is synthesized at runtime — the app just plays bundled assets.

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
  DSP in `synth_core.dart`. Its only caller today is `tool/generate_audio.dart`.
- **Generating the assets** — `dart run tool/generate_audio.dart` renders every
  `Sfx` (plus the music loop, §9) to `assets/audio/<name>.wav` and commits them.
  Run it after editing `sound_config.dart` / `music_config.dart`, then commit
  the regenerated files. `test/audio_assets_test.dart` byte-compares each
  committed WAV against a fresh `synthesize(...)`/`synthesizeMusic()` call and
  fails with a "run: dart run tool/generate_audio.dart" hint if they've drifted
  (e.g. a config edit was made but the assets weren't regenerated).
- **Playback** — `sound_service.dart` (singleton): each event gets an
  `AudioPool` (audioplayers' own primitive for "extremely quick firing,
  repetitive... sounds"), not a single `AudioPlayer`. A retriggered sound
  starts on a fresh pooled player while the previous one keeps ringing out on
  its own — throttling (move 45ms, rotate 30ms) still paces how often a sound
  can fire, but nothing gets cut off mid-playback anymore. **Explicit fix:**
  the original one-player-per-event design called `stop()` on a retrigger,
  which — since `move`/`rotate`'s throttle window is shorter than the sound's
  own duration — routinely chopped the previous play off at a non-zero
  sample, an audible click on every fast move/rotate. Sources are preloaded
  via `setSource(AssetSource(...))` (no runtime synthesis, no re-buffering —
  see the resolved latency note in §9).
- **Sound timing** (an explicit fix): the land "tock" and line-clear chime used
  to lag because lock detection waited for the next gravity tick and the clear
  sound played after the shrink animation. Now: landing is detected every frame
  (0.12s lock delay), the clear chime plays at the **start** of the clear, and
  the land tock plays **only when nothing clears** (a clearing drop plays just
  the chime, not both).
- **Settings:** a gear button (home screen) and a "Settings" button in the
  pause menu open [lib/screens/settings_screen.dart](lib/screens/settings_screen.dart)
  — separate enable toggle + volume slider for SFX (and music, §9). See §10 for
  the persisted keys and the one-time migration from the old single mute toggle.

Event → sound summary: tap = soft tick; move = subtle blip; rotate = light
pluck; hardDrop = quick descending run; lock = low woody tock; lineClear1..4 =
ascending pentatonic arpeggios that grow with more lines; levelWin = flourish;
gameOver = soft descending sigh.

---

## 9. Audio — background music

A single **looping ambient track**, defined in code and pre-rendered the same
way as the SFX (§8) — `assets/audio/music.wav`, committed, no runtime synthesis.

- **Definition** — [lib/audio/music_config.dart](lib/audio/music_config.dart):
  `masterVolume` (0.22, sits under the SFX), `bpm` (63), `loopBeats` (16 = four
  4/4 bars ≈ **15.24s**), and `track`: a flat `List<MusicNote>`. Three loose
  voices share the list — a low bass (one root/bar), a soft pad wash, and a
  sparse melody. Each `MusicNote(startBeat, beats, degree, {volume, waveform,
  attack, release})`.
- **Seamless loop** — `music_synth.dart` (`synthesizeMusic`): renders one loop;
  any note tail that runs past the loop end **wraps around and sums onto the
  start**, so on repeat the tail flows into the next pass with no click/gap.
  `declickEdges` (`synth_core.dart`) additionally forces the very first/last
  samples of the buffer toward zero, so the loop seam is guaranteed silent
  regardless of what happens to land there. The buffer is normalized to ~0.9
  peak; final loudness comes from the player volume. Only called from
  `tool/generate_audio.dart` now.
- **Playback** — a dedicated looping `AudioPlayer` (`ReleaseMode.loop`) in
  `sound_service.dart`, source preloaded via `AssetSource('audio/music.wav')`,
  started at app launch if enabled, plays app-wide (menus + game). Volume =
  `MusicConfig.masterVolume * musicVolume` where `musicVolume` is the user's
  0–1 slider trim (§8's Settings screen); changes to the slider call
  `AudioPlayer.setVolume` live while the loop keeps playing.
- **Explicit fix:** `setReleaseMode(ReleaseMode.loop)` was originally set via a
  `..` cascade, which fires the platform call but doesn't wait for it —
  `setSource` could then run before looping was actually applied, risking a
  hiccup right at the first loop boundary. It's now properly `await`ed first.
- **Default volume:** music starts at `musicVolume` = **0.5** (`AudioSettings.
  kDefaultMusicVolume`) — half the user-facing slider range — so it sits under
  the SFX by default rather than competing with them; SFX default to `1.0`.
  This is the slider's starting position (§8), layered on top of
  `MusicConfig.masterVolume`, which is the separate mix-level tuning knob.
- **Explicit fix — music not surviving navigation:** `SoundService.
  ensureMusicPlaying()` re-asserts playback (calls `resume()`) whenever music
  is supposed to be on but its player's `state` isn't `playing` — it never
  interrupts an already-looping track, only recovers a stopped/paused one.
  It's called from every [play] (any SFX firing is itself proof of life) and
  from three hooks in `main.dart`: a `NavigatorObserver` on every
  `didPush`/`didPop`/`didReplace`, a `WidgetsBindingObserver` when the app
  returns to the foreground (the OS pauses audio while backgrounded and won't
  restart it), and a passthrough `Listener` that fires on any pointer-down
  anywhere (browsers refuse to start audio before a user gesture, so the
  initial start in `init()` can be silently dropped — the first tap on any
  screen kicks it back on). So music that got paused or dropped by a platform
  quirk picks back up almost immediately rather than staying silent for the
  rest of the session.

### Important pivot: flutter_soloud → audioplayers

The audio engine was first `flutter_soloud`. It compiled in Dart but its native
C++ engine **failed to build via CMake/NDK** (NDK 27 / Clang 18) and broke the
Android APK. It was replaced with **`audioplayers`** (pure platform channels, no
native compile step). **Do not reintroduce a native-compiled audio plugin
without checking the Android build.**

### Resolved: runtime synthesis → pre-rendered assets

Audio was originally synthesized at runtime into in-memory buffers and played
via `BytesSource`, which re-buffers on every `play()` — a documented source of
per-play latency. It's now pre-rendered ahead of time by
`tool/generate_audio.dart` into committed WAVs (`assets/audio/`), preloaded at
`init()` via `AudioPlayer`/`AudioPool.create(source: AssetSource(...))` — no
synthesis and no re-buffering happen at runtime anymore. The synth code
(`tone_synth.dart`, `music_synth.dart`, `synth_core.dart`) is largely unchanged
and stays the editable "source" of the sounds (it gained `declickEdges`, §8/§9);
only its caller moved from `sound_service.dart` to the generator tool.

### Resolved: retrigger clicks and a music loop-mode race

Two follow-up playback bugs, fixed after the pivot above: (1) SFX used one
`AudioPlayer` per event and retriggered it with `stop()` — see §8's pool
explanation for why that clicked. (2) the music player's `setReleaseMode` call
wasn't awaited before `setSource` — see §9. Neither was a synthesis problem;
`declickEdges` was added as well, as cheap insurance against the synth's own
envelopes leaving a non-silent sample at a clip's edges.

---

## 10. Persistence

`lib/services/progress_service.dart` — `shared_preferences`, **local on-device**
storage (Android SharedPreferences / iOS NSUserDefaults / web localStorage — not
cookies, not cloud, no cross-device sync).

- `unlocked_level` (int, default 1) — highest stage the player may enter.
- `high_score_infinite` (int) — infinite-mode best.
- `music_enabled` / `sfx_enabled` (bool, default true) — per-channel audio toggle.
- `music_volume` (double 0–1, default **0.5**) / `sfx_volume` (double 0–1,
  default 1.0) — per-channel volume trim, applied on top of
  `MusicConfig.masterVolume` / `SoundConfig.masterVolume`.

`music_enabled`/`sfx_enabled` replace the old single `sound_enabled` toggle.
[lib/audio/audio_settings.dart](lib/audio/audio_settings.dart) migrates it
once: if neither new key is present yet but `sound_enabled` is, both channels
seed from its value and the legacy key is deleted so it can't reapply later.

Uninstalling the app (or clearing browser data on web) wipes it. Cross-device /
reinstall-safe sync would require an account/cloud backend (not implemented).

---

## 11. Build, run, test

```sh
flutter pub get
dart run tool/generate_audio.dart   # regenerate assets/audio/*.wav after an
                                    # audio config edit; commit the result
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
Remove unused code and refresh PROJECT.md
Add audio settings and keep background music always playing
Expand to 50 pixel-art levels; make starting unlocks configurable
Merge pull request #1 from allmonty/build-chill-tetris
Add PROJECT.md with full context; slim README to a pointer
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

Default branch: `main`; recent work is on the `audio-settings-and-music-fix`
branch.

---

## 13. Possible next steps (not implemented)

- Cloud/account save for cross-device progress (Firebase / Game Center / Google
  Play Games) — current persistence is local only.
- More palettes / a palette picker; more stages.
