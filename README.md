# Chill Tetris

A relaxing Tetris game for mobile, built with Flutter and the [Flame](https://flame-engine.org) game engine.

## Modes

- **Infinite** — start on an empty board and chase a high score. The fall speed
  graduates upward every few lines until it caps at full speed.
- **Stage** — 15 hand-designed levels, each starting with pre-placed blocks and
  cleared by reaching a target score. Levels unlock in sequence and progress is
  saved between sessions.

## Controls (gestures only)

- **Drag left/right** — move the piece across columns.
- **Drag down** — soft drop.
- **Flick down** — hard drop.
- **Tap** — rotate clockwise (with simple wall kicks).

## Project layout

```
lib/
  theme/palette.dart        Semantic color palette (swap in one line)
  models/                   Pure Dart game rules (board, tetrominoes, levels, scoring)
  game/                     Flame game, rendering, input, and animation
  screens/                  Home, level select, game host
  widgets/                  HUD and modal overlays
  services/                 Progress persistence
assets/levels/levels.json   Stage definitions
```

## Changing the color palette

All colors are referenced by role, never by raw hex. To re-theme the entire
game — menus, board, and pieces — assign a different `GamePalette` to
`Palette.current` in [lib/theme/palette.dart](lib/theme/palette.dart). A second
`GamePalette.dusk` palette is included as an example.

## Configuring levels

Stages are defined in [assets/levels/levels.json](assets/levels/levels.json) as
a list of maps:

```json
{
  "level": 1,
  "targetScore": 300,
  "initialPieces": [
    {"x": 0, "y": 19, "color": 2}
  ]
}
```

- `x` — column, `0`–`9` (left to right)
- `y` — row, `0`–`19` (top to bottom)
- `color` — index into the palette's `pieceColors` (`0`–`6`)

Never fill an entire starting row, or it would clear on the first lock.

## Tuning game feel

Every animation tunable (durations, bounce scale, stagger, curves) lives in
[lib/game/animation_config.dart](lib/game/animation_config.dart). Adjust the
constants there to change the feel without touching gameplay logic.

## Running

```sh
flutter pub get
flutter run          # on a connected device or simulator
flutter test         # unit tests for board, tetrominoes, and level parsing
```
