// Renders the app icon to committed PNG assets.
//
// The icon is a 4x4 square assembled from four tetromino pieces (two Z, two
// L), drawn exactly like the in-game board: rounded cells with a small gap on
// the dark-walnut board background, colored from the mid-century palette in
// lib/theme/palette.dart. Edit the constants below, re-run, then re-stamp the
// platform icons:
//
//   dart run tool/generate_icon.dart
//   dart run flutter_launcher_icons
//
// Outputs:
//   assets/icon/app_icon.png            full-bleed base icon (Android legacy,
//                                       iOS, web favicon + PWA icons)
//   assets/icon/app_icon_foreground.png transparent foreground for Android
//                                       adaptive icons (background color lives
//                                       in flutter_launcher_icons.yaml)
import 'dart:io';

import 'package:image/image.dart' as img;

// --- Palette (mirrors GamePalette.midCenturyModern) -------------------------
final _boardBackground = img.ColorRgba8(0x4E, 0x42, 0x43, 0xFF); // dark walnut
final _mustard = img.ColorRgba8(0xDD, 0xB0, 0x58, 0xFF);
final _sage = img.ColorRgba8(0x8F, 0x97, 0x79, 0xFF);
final _dustyBlue = img.ColorRgba8(0x9B, 0xB0, 0xBC, 0xFF);
final _terracotta = img.ColorRgba8(0xB0, 0x67, 0x57, 0xFF);

// --- The motif: a 4x4 square tiled by four tetrominoes ----------------------
// A = Z piece, B = L piece, C = L piece, D = Z piece. Same-colored adjacent
// cells read as one piece, just like on the game board.
const _tiles = [
  'AABB', //
  'CAAB',
  'CDDB',
  'CCDD',
];

final _pieceColors = {
  'A': _mustard,
  'B': _sage,
  'C': _dustyBlue,
  'D': _terracotta,
};

// --- Geometry (fractions mirror BoardComponent's cell rendering) ------------
const _outSize = 1024; // final PNG side
const _renderScale = 4; // supersample, then downscale for smooth edges
const _cellGapFrac = 0.045; // gap on each side of a cell, as fraction of cell
const _cellRadiusFrac = 0.16; // cell corner radius, as fraction of cell

/// Grid side as a fraction of the canvas. The base icon must survive a
/// maskable-icon circle crop (safe zone: central 80%), so its diagonal stays
/// inside that; the adaptive foreground must fit Android's 66/108 safe zone.
const _baseGridFrac = 0.56;
const _foregroundGridFrac = 0.44;

void main() {
  final dir = Directory('assets/icon')..createSync(recursive: true);
  _write('${dir.path}/app_icon.png',
      _render(gridFrac: _baseGridFrac, background: _boardBackground));
  _write('${dir.path}/app_icon_foreground.png',
      _render(gridFrac: _foregroundGridFrac, background: null));
}

img.Image _render({required double gridFrac, required img.Color? background}) {
  final side = _outSize * _renderScale;
  final canvas = img.Image(width: side, height: side, numChannels: 4);
  if (background != null) {
    img.fill(canvas, color: background);
  }

  final grid = side * gridFrac;
  final cell = grid / _tiles.length;
  final origin = (side - grid) / 2;
  final gap = cell * _cellGapFrac;
  final radius = cell * _cellRadiusFrac;

  for (var r = 0; r < _tiles.length; r++) {
    for (var c = 0; c < _tiles[r].length; c++) {
      final color = _pieceColors[_tiles[r][c]]!;
      final x = origin + c * cell;
      final y = origin + r * cell;
      img.fillRect(
        canvas,
        x1: (x + gap).round(),
        y1: (y + gap).round(),
        x2: (x + cell - gap).round(),
        y2: (y + cell - gap).round(),
        color: color,
        radius: radius,
      );
    }
  }

  return img.copyResize(
    canvas,
    width: _outSize,
    height: _outSize,
    interpolation: img.Interpolation.cubic,
  );
}

void _write(String path, img.Image image) {
  final bytes = img.encodePng(image);
  File(path).writeAsBytesSync(bytes);
  final kb = (bytes.length / 1024).toStringAsFixed(1);
  stdout.writeln('$path  ($kb KB)');
}
