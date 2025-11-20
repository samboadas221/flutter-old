
// Compatible with Flutter 1.22 (no null-safety)

import 'dart:math';
import 'matrix_puzzle.dart';
import 'cell.dart';

class MatrixGenerator {
  static final Random _rnd = Random();

  /// difficulty: 'easy'|'medium'|'hard'
  /// sizes: minRows..maxRows, minCols..maxCols
  /// cluePercent: porcentaje de celdas numéricas que quedarán visibles (0-100)
  /// maxAttempts: intentos para colocar ecuaciones antes de rendirse
  static MatrixPuzzle generate({
    String difficulty = 'easy',
    int minRows = 9,
    int maxRows = 12,
    int minCols = 9,
    int maxCols = 12,
    int cluePercent = 40,
    int maxAttempts = 2000,
  }) {
    final rows = minRows + _rnd.nextInt(maxRows - minRows + 1);
    final cols = minCols + _rnd.nextInt(maxCols - minCols + 1);
    final puzzle = MatrixPuzzle(rows, cols, difficulty: difficulty, id: 'gen_${DateTime.now().millisecondsSinceEpoch}');
    final maxVal = _maxForDifficulty(difficulty);

    // initialize empty grid of number/operator/equals/result placeholders
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        puzzle.grid[r][c] = Cell.empty();
      }
    }

    // We'll try to place many small equations of shape len=5: [num][op][num][=][res]
    // randomly horizontal or vertical. We accept overlaps if types match.
    int attempts = 0;
    int placed = 0;
    final targetEquations = ((rows * cols) / 10).floor().clamp(3, (rows*cols~/5));

    while (attempts < maxAttempts && placed < targetEquations) {
      attempts++;
      final horizontal = _rnd.nextBool();
      final r0 = _rnd.nextInt(rows);
      final c0 = _rnd.nextInt(cols);
      final r = horizontal ? r0 : r0;
      final c = horizontal ? c0 : c0;
      // ensure fit
      if (horizontal) {
        if (c + 4 >= cols) continue;
      } else {
        if (r + 4 >= rows) continue;
      }

      // coords for slots
      final a = horizontal ? Coord(r, c) : Coord(r, c);
      final op = horizontal ? Coord(r, c + 1) : Coord(r + 1, c);
      final b = horizontal ? Coord(r, c + 2) : Coord(r + 2, c);
      final eq = horizontal ? Coord(r, c + 3) : Coord(r + 3, c);
      final res = horizontal ? Coord(r, c + 4) : Coord(r + 4, c);

      // Check existing cells: operators must be operator or empty; equals must be equals or empty; result cell must be result or empty; number cells number or empty.
      if (!_slotCompatible(puzzle, a, CellType.number)) continue;
      if (!_slotCompatible(puzzle, op, CellType.operator)) continue;
      if (!_slotCompatible(puzzle, b, CellType.number)) continue;
      if (!_slotCompatible(puzzle, eq, CellType.equals)) continue;
      if (!_slotCompatible(puzzle, res, CellType.result)) continue;

      // pick an operator and operands that satisfy bounds
      final ops = ['+', '-', '*', '/'];
      final opch = ops[_rnd.nextInt(ops.length)];

      // Try to generate operands A,B and result C within constraints.
      bool found = false;
      int A, B, C;
      for (int trial = 0; trial < 60 && !found; trial++) {
        A = _rnd.nextInt(maxVal + 1);
        B = _rnd.nextInt(maxVal + 1);
        if (opch == '+') C = A + B;
        else if (opch == '-') C = A - B;
        else if (opch == '*') C = A * B;
        else {
          if (B == 0) continue;
          if (A % B != 0) continue;
          C = A ~/ B;
        }
        if (C < 0 || C > maxVal) continue;
        // If cells already have numbers, ensure compatibility
        final ca = puzzle.grid[a.r][a.c];
        final cb = puzzle.grid[b.r][b.c];
        final cres = puzzle.grid[res.r][res.c];
        if (ca.number != null && ca.number != A) continue;
        if (cb.number != null && cb.number != B) continue;
        if (cres.number != null && cres.number != C) continue;
        found = true;
      }
      if (!found) continue;

      // Place items
      final cellA = Cell.number(A, fixed: false);
      final cellOp = Cell.operator(opch);
      final cellB = Cell.number(B, fixed: false);
      final cellEq = Cell.equals();
      final cellRes = Cell.result(C, fixed: false);

      // merge placements: if some cells already had numbers we keep them (they matched earlier)
      _placeIfEmpty(puzzle, a, cellA);
      _placeIfEmpty(puzzle, op, cellOp);
      _placeIfEmpty(puzzle, b, cellB);
      _placeIfEmpty(puzzle, eq, cellEq);
      _placeIfEmpty(puzzle, res, cellRes);

      placed++;
    }

    // After placements, collect all number cells to form bank/hints
    final List<Coord> numberCoords = [];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cell = puzzle.grid[r][c];
        if (cell.type == CellType.number || cell.type == CellType.result) {
          numberCoords.add(Coord(r, c));
        }
      }
    }

    // Shuffle and mark some as clues (fixed), hide others to bank
    numberCoords.shuffle(_rnd);
    final keepCount = ((cluePercent.clamp(0, 100) / 100.0) * numberCoords.length).ceil();
    final keepSet = numberCoords.take(keepCount).toSet();

    puzzle.bankCounts.clear();
    for (final coord in numberCoords) {
      final cell = puzzle.grid[coord.r][coord.c];
      final v = cell.number;
      if (keepSet.contains(coord)) {
        cell.fixed = true; // clue visible and fixed
      } else {
        // hide from board
        cell.number = null;
        cell.fixed = false;
        puzzle.bankCounts[v] = (puzzle.bankCounts[v] ?? 0) + 1;
      }
    }

    return puzzle;
  }

  // helpers
  static int _maxForDifficulty(String difficulty) {
    if (difficulty == 'easy') return 30;
    if (difficulty == 'medium') return 60;
    return 100;
  }

  static bool _slotCompatible(MatrixPuzzle p, Coord coord, CellType want) {
    if (!p.inBounds(coord.r, coord.c)) return false;
    final existing = p.grid[coord.r][coord.c];
    if (existing == null) return true;
    // if empty allow
    if (existing.type == CellType.empty) return true;
    // same type acceptable
    if (existing.type == want) return true;
    return false;
  }

  static void _placeIfEmpty(MatrixPuzzle p, Coord coord, Cell newCell) {
    final existing = p.grid[coord.r][coord.c];
    if (existing == null || existing.type == CellType.empty) {
      p.grid[coord.r][coord.c] = newCell.clone();
    } else {
      // If number exists we keep as-is (should already match)
      if (existing.type == CellType.number && newCell.type == CellType.number) {
        // keep existing (prefer visible/fixed if any)
      }
    }
  }
}