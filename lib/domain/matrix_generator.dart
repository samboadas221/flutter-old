
import 'dart:math';
import 'matrix_puzzle.dart';
import 'cell.dart';

class MatrixGenerator {
  static final Random _rnd = Random();

  static MatrixPuzzle generate({
    String difficulty = 'easy',
    int minSize = 9,
    int maxSize = 12,
    int cluePercent = 42,
  }) {
    final size = minSize + _rnd.nextInt(maxSize - minSize + 1);
    final maxVal = difficulty == 'easy' ? 25 : difficulty == 'medium' ? 50 : 99;

    while (true) {
      final puzzle = MatrixPuzzle(size, size, difficulty: difficulty);
      final equations = <_Equation>[];

      // Colocamos la primera ecuación en el centro aproximado
      final firstH = _rnd.nextBool();
      final firstR = 2 + _rnd.nextInt(size - 6);
      final firstC = 2 + _rnd.nextInt(size - 6);
      final first = _Equation(firstH, firstR, firstC);
      if (!_tryPlaceEquation(puzzle, first, maxVal, difficulty)) continue;
      equations.add(first);

      // Crecemos orgánicamente como una red
      for (int i = 0; i < 600 && equations.length < size; i++) {
        final candidate = _generateCandidateNear(equations, size);
        if (candidate == null) continue;

        if (_conflictsStrict(candidate, equations, size)) continue;

        if (_tryPlaceEquation(puzzle, candidate, maxVal, difficulty)) {
          equations.add(candidate);
        }
      }

      if (equations.length < 6) continue; // muy vacío

      if (_finalizePuzzle(puzzle, cluePercent, equations.length)) {
        return puzzle;
      }
    }
  }

  static bool _tryPlaceEquation(MatrixPuzzle p, _Equation eq, int maxVal, String diff) {
    final data = _generateCleanEquation(maxVal, diff) ;
    if (data == null) return false;

    final A = data[0]; final op = data[1]; final B = data[2]; final C = data[3];

    if (eq.horizontal) {
      p.grid[eq.row][eq.col]     = Cell.number(A, fixed: false);
      p.grid[eq.row][eq.col+1]   = Cell.operator(op);
      p.grid[eq.row][eq.col+2]   = Cell.number(B, fixed: false);
      p.grid[eq.row][eq.col+3]   = Cell.equals();
      p.grid[eq.row][eq.col+4]   = Cell.result(C, fixed: false);
    } else {
      p.grid[eq.row][eq.col]     = Cell.number(A, fixed: false);
      p.grid[eq.row+1][eq.col]   = Cell.operator(op);
      p.grid[eq.row+2][eq.col]   = Cell.number(B, fixed: false);
      p.grid[eq.row+3][eq.col]   = Cell.equals();
      p.grid[eq.row+4][eq.col]   = Cell.result(C, fixed: false);
    }
    return true;
  }

  static List _generateCleanEquation(int maxVal, String diff) {
    final ops = diff == 'easy' ? ['+', '-', '+'] :
                diff == 'medium' ? ['+', '-', '*', '+'] :
                ['+', '-', '*', '/'];

    for (int t = 0; t < 100; t++) {
      final op = ops[_rnd.nextInt(ops.length)];
      int A, B, C;

      if (op == '+') { A = 1 + _rnd.nextInt(maxVal-1); B = 1 + _rnd.nextInt(maxVal-A); C = A + B; }
      else if (op == '-') { C = 2 + _rnd.nextInt(maxVal-2); B = 1 + _rnd.nextInt(C-1); A = B + C; }
      else if (op == '*') {
        A = 2 + _rnd.nextInt(12); B = 2 + _rnd.nextInt(maxVal ~/ A); C = A * B;
        if (C > maxVal) continue;
      } else { // división
        C = 2 + _rnd.nextInt(maxVal);
        final divs = <int>[];
        for (int d=2; d<=C; d++) if (C % d == 0) divs.add(d);
        if (divs.isEmpty) continue;
        B = divs[_rnd.nextInt(divs.length)];
        A = B * C;
        if (A > maxVal) continue;
      }

      if (A >= 1 && B >= 1 && C >= 2 && A <= maxVal && B <= maxVal && C <= maxVal) {
        return [A, op, B, C];
      }
    }
    return null;
  }

  static _Equation _generateCandidateNear(List<_Equation> existing, int size) {
    if (existing.isEmpty) return null;
    final base = existing[_rnd.nextInt(existing.length)];

    final candidates = <_Equation>[];
    final offsets = [-3,-2,-1,1,2,3];

    for (int dr in offsets) {
      for (int dc in offsets) {
        if (dr == 0 && dc == 0) continue;
        final h = _rnd.nextBool();
        int r = base.row + (h ? dr : 0);
        int c = base.col + (h ? 0 : dc);
        if (r < 0 || c < 0 || r + (h?0:4) >= size || c + (h?4:0) >= size) continue;
        candidates.add(_Equation(h, r, c));
      }
    }
    return candidates.isNotEmpty ? candidates[_rnd.nextInt(candidates.length)] : null;
  }

  // Regla física estricta: mismo sentido → 2 filas/columnas mínimo, distinto sentido → solo si se cruzan
  static bool _conflictsStrict(_Equation candidate, List<_Equation> existing, int size) {
    for (final e in existing) {
      if (candidate.horizontal == e.horizontal) {
        if (candidate.horizontal) {
          if ((candidate.row - e.row).abs() <= 1) return true;
        } else {
          if ((candidate.col - e.col).abs() <= 1) return true;
        }
      } else {
        // Distinto sentido → solo permitido si se cruzan de verdad
        final h = candidate.horizontal ? candidate : e;
        final v = candidate.horizontal ? e : candidate;
        bool crosses = h.row == v.row || h.row == v.row+1 || h.row == v.row+2 || h.row == v.row+3 || h.row == v.row+4;
        crosses &= (v.col >= h.col && v.col <= h.col+4);
        if (!crosses) {
          // Si no se cruzan → no pueden estar a menos de 2 casillas
          final distR = (h.row - v.row).abs();
          final distC = (h.col - v.col).abs();
          if (distR <= 1 || distC <= 1) return true;
        }
      }
    }
    return false;
  }

  static bool _finalizePuzzle(MatrixPuzzle p, int percent, int eqCount) {
    final cells = <Coord>[];
    for (int r = 0; r < p.rows; r++)
      for (int c = 0; c < p.cols; c++)
        if (p.grid[r][c].type == CellType.number || p.grid[r][c].type == CellType.result)
          if (p.grid[r][c].number != null)
            cells.add(Coord(r, c));

    if (cells.length < 18) return false;

    cells.shuffle(_rnd);
    final clues = (cells.length * percent / 100).ceil().clamp(6, cells.length - 4);

    p.bankCounts.clear();
    for (int i = 0; i < cells.length; i++) {
      final cell = p.grid[cells[i].r][cells[i].c];
      if (i < clues) {
        cell.fixed = true;
      } else {
        p.bankCounts[cell.number] = (p.bankCounts[cell.number] ?? 0) + 1;
        cell.number = null;
      }
    }
    return true;
  }
}

class _Equation {
  final bool horizontal;
  final int row, col;
  _Equation(this.horizontal, this.row, this.col);
}