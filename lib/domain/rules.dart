
// lib/domain/rules.dart
// Minimal canPlaceNumber implementation: check any completed equation that includes the coord

import 'puzzle_model.dart';

bool canPlaceNumber(Puzzle puzzle, Coord coord, int value) {
  // copy matrix and place value then validate only equations that include coord
  final tmp = puzzle.copy();
  tmp.placeNumber(coord.r, coord.c, value, markAsFixed: false);

  // check horizontal equations that include this coord
  for (int c = coord.c - 4; c <= coord.c; c++) {
    if (c < 0 || c + 4 >= tmp.cols) continue;
    final a = Coord(coord.r, c);
    final op = Coord(coord.r, c + 1);
    final b = Coord(coord.r, c + 2);
    final eq = Coord(coord.r, c + 3);
    final res = Coord(coord.r, c + 4);
    final ca = tmp.cells[a];
    final cop = tmp.cells[op];
    final cb = tmp.cells[b];
    final cres = tmp.cells[res];
    if (ca == null || cop == null || cb == null || cres == null) continue;
    if (!(ca.isNumber && cop.isOperator && cb.isNumber && cres.isTarget)) continue;
    // if all number positions are filled -> validate
    if (ca.value != null && cb.value != null && cres.value != null) {
      // reuse MatrixSolver logic by creating a small check
      final A = ca.value as int;
      final B = cb.value as int;
      final C = cres.value as int;
      final opch = cop.value?.toString() ?? '';
      int got;
      if (opch == '+') got = A + B;
      else if (opch == '-') got = A - B;
      else if (opch == '*') got = A * B;
      else if (opch == '/') {
        if (B == 0) return false;
        if (A % B != 0) return false;
        got = A ~/ B;
      } else return false;
      if (got != C) return false;
    }
  }

  // vertical
  for (int r = coord.r - 4; r <= coord.r; r++) {
    if (r < 0 || r + 4 >= tmp.rows) continue;
    final a = Coord(r, coord.c);
    final op = Coord(r + 1, coord.c);
    final b = Coord(r + 2, coord.c);
    final eq = Coord(r + 3, coord.c);
    final res = Coord(r + 4, coord.c);
    final ca = tmp.cells[a];
    final cop = tmp.cells[op];
    final cb = tmp.cells[b];
    final cres = tmp.cells[res];
    if (ca == null || cop == null || cb == null || cres == null) continue;
    if (!(ca.isNumber && cop.isOperator && cb.isNumber && cres.isTarget)) continue;
    if (ca.value != null && cb.value != null && cres.value != null) {
      final A = ca.value as int;
      final B = cb.value as int;
      final C = cres.value as int;
      final opch = cop.value?.toString() ?? '';
      int got;
      if (opch == '+') got = A + B;
      else if (opch == '-') got = A - B;
      else if (opch == '*') got = A * B;
      else if (opch == '/') {
        if (B == 0) return false;
        if (A % B != 0) return false;
        got = A ~/ B;
      } else return false;
      if (got != C) return false;
    }
  }

  return true;
}