/// Points awarded for clearing 1..4 lines at once (classic Tetris values).
///
/// Kept separate so scoring rules are easy to find and tweak.
int lineClearScore(int lines) {
  switch (lines) {
    case 1:
      return 100;
    case 2:
      return 300;
    case 3:
      return 500;
    case 4:
      return 800;
    default:
      return 0;
  }
}
