
// lib/domain/matrix_generator.dart
// GENERADOR CROSSMATH PROFESIONAL - V10 FINAL - 20 Nov 2025
// Para tu madre, con amor infinito ❤️

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
    final maxVal = difficulty == 'easy' ? 29 : difficulty == 'medium' ? 59 : 99;

    outer: while (true) {
      final puzzle = MatrixPuzzle(size, size, difficulty: difficulty);

      // Usamos una máscara para evitar cualquier solapamiento
      final List<List<bool>> used = List.generate(size, (_) => List.filled(size, false));

      final List<_Equation> equations = [];

      // Colocamos primera ecuación en el centro
      bool firstH = _rnd.nextBool();
      int r = 2 + _rnd.nextInt(size - 6);
      int c = 2 + _rnd.nextInt(size - 6);
      if (_placeEquationSafe(puzzle, used, true, r, c, maxVal, difficulty)) {
        equations.add(_Equation(true, r, c));
      } else continue;

      // Crecemos añadiendo ecuaciones que se crucen con las existentes
      for (int i = 0; i < 800; i++) {
        final candidate = _findGoodCrossingPosition(equations, size, used);
        if (candidate == null) break;

        final placed = _placeEquationSafe(
          puzzle, used, candidate.horizontal, candidate.row, candidate.col, maxVal, difficulty
        );

        if (placed) {
          equations.add(candidate);
        }
      }

      if (equations.length < 7) continue outer;

      // Garantizamos pistas mínimas por ecuación
      if (_finalizeWithMinClues(puzzle, cluePercent, equations)) {
        return puzzle;
      }
    }
  }

  // Coloca una ecuación SIN SOLAPAR NADA y marcando celdas usadas
  static bool _placeEquationSafe(MatrixPuzzle p, List<List<bool>> used,
      bool horizontal, int startR, int startC, int maxVal, String diff) {

    final coords = horizontal
        ? [Coord(startR, startC + i) for i in 0 until 5]
        : [Coord(startR + i, startC) for i in 0 until 5];

    // Verifica no solapamiento
    for (final coord in coords) {
      if (!p.inBounds(coord.r, coord.c) || used[coord.r][coord.c]) return false;
    }

    final data = _makeNiceEquation(maxVal, diff) ;
    if (data == null) return false;

    final A = data[0]; final op = data[1]; final B = data[2]; final C = data[3];

    if (horizontal) {
      p.grid[startR][startC]     = Cell.number(A, fixed: false);
      p.grid[startR][startC+1]   = Cell.operator(op);
      p.grid[startR][startC+2]   = Cell.number(B, fixed: false);
      p.grid[startR][startC+3]   = Cell.equals();
      p.grid[startR][startC+4]   = Cell.result(C, fixed: false);
    } else {
      p.grid[startR][startC]     = Cell.number(A, fixed: false);
      p.grid[startR+1][startC]   = Cell.operator(op);
      p.grid[startR+2][startC]   = Cell.number(B, fixed: false);
      p.grid[startR+3][startC]   = Cell.equals();
      p.grid[startR+4][startC]   = Cell.result(C, fixed: false);
    }

    // Marca como usadas todas las celdas
    for (final coord in coords) {
      used[coord.r][coord.c] = true;
    }

    return true;
  }

  // Genera ecuación bonita y limpia
  static List _makeNiceEquation(int maxVal, String diff) {
    final ops = diff == 'easy' ? ['+', '-'] :
                diff == 'medium' ? ['+', '-', '*'] : ['+', '-', '*', '/'];

    for (int t = 0; t < 80; t++) {
      final op = ops[_rnd.nextInt(ops.length)];
      int A, B, C;

      switch (op) {
        case '+':
          A = 2 + _rnd.nextInt(maxVal - 3);
          B = 2 + _rnd.nextInt(maxVal - A);
          C = A + B;
          break;
        case '-':
          C = 3 + _rnd.nextInt(maxVal - 4);
          B = 1 + _rnd.nextInt(C - 2);
          A = B + C;
          break;
        case '*':
          A = 2 + _rnd.nextInt(15);
          B = 2 + _rnd.nextInt((maxVal ~/ A).clamp(2, 99));
          C = A * B;
          if (C > maxVal) continue;
          break;
        case '/':
          C = 3 + _rnd.nextInt(maxVal - 2);
          final divs = [for (int d = 2; d <= 30 && d <= C; d++) if (C % d == 0) d];
          if (divs.isEmpty) continue;
          final d = divs[_rnd.nextInt(divs.length)];
          B = d;
          A = C * d;
          if (A > maxVal) continue;
          break;
        default:
          continue;
      }
      return [A, op, B, C];
    }
    return null;
  }

  // Encuentra posición perfecta para nueva ecuación que cruce con alguna existente
  static _Equation _findGoodCrossingPosition(List<_Equation> existing, int size, List<List<bool>> used) {
    final List<_Equation> candidates = [];

    for (final eq in existing) {
      final cells = eq.horizontal
          ? [for (int i = 0; i < 5; i++) Coord(eq.row, eq.col + i)]
          : [for (int i = 0; i < 5; i++) Coord(eq.row + i, eq.col)];

      // Solo cruzamos en celdas de número o resultado (índices 0,2,4)
      for (int idx in [0, 2, 4]) {
        final cell = cells[idx];
        if (cell.r < 2 || cell.r >= size - 4 || cell.c < 2 || cell.c >= size - 4) continue;

        // Probar horizontal y vertical pasando por esta celda
        candidates.add(_Equation(true, cell.r, cell.c - idx));     // horizontal
        candidates.add(_Equation(false, cell.r - idx, cell.c));    // vertical
      }
    }

    candidates.shuffle(_rnd);
    for (final cand in candidates) {
      if (_isPositionSafe(cand, size, used)) {
        return cand;
      }
    }
    return null;
  }

  // Verifica que la posición esté libre y con separación mínima
  static bool _isPositionSafe(_Equation eq, int size, List<List<bool>> used) {
    final positions = eq.horizontal
        ? [for (int i = 0; i < 5; i++) Coord(eq.row, eq.col + i)]
        : [for (int i = 0; i < 5; i++) Coord(eq.row + i, eq.col)];

    for (final pos in positions) {
      if (!used[pos.r][pos.c]) continue;
      return false; // ya ocupada
    }

    // Separación mínima de 1 celda con cualquier otra ecuación no cruzada
    for (int dr = -2; dr <= 2; dr++) {
      for (int dc = -2; dc <= 2; dc++) {
        if (dr.abs() <= 1 && dc.abs() <= 1) continue; // permitimos cruce real
        final r = eq.horizontal ? eq.row + dr : eq.row + dr;
        final c = eq.horizontal ? eq.col + dc : eq.col + dc;
        if (r >= 0 && r < size && c >= 0 && c < size && used[r][c]) {
          return false;
        }
      }
    }
    return true;
  }

  // Finaliza con pistas mínimas por ecuación
  static bool _finalizeWithMinClues(MatrixPuzzle p, int percent, List<_Equation> equations) {
    final numberCells = <Coord>[];

    for (int r = 0; r < p.rows; r++) {
      for (int c = 0; c < p.cols; c++) {
        final cell = p.grid[r][c];
        if ((cell.type == CellType.number || cell.type == CellType.result) && cell.number != null) {
          numberCells.add(Coord(r, c));
        }
      }
    }

    if (numberCells.length < 24) return false;

    // Por ecuación, forzamos al menos 2-3 pistas
    final Set<Coord> forcedClues = {};
    for (final eq in equations) {
      final cells = eq.horizontal
          ? [for (int i = 0; i < 5; i += 2) Coord(eq.row, eq.col + i)] // solo números y resultado
          : [for (int i = 0; i < 5; i += 2) Coord(eq.row + i, eq.col)];
      cells.shuffle(_rnd);
      for (int i = 0; i < 2 + _rnd.nextInt(2); i++) { // 2 o 3 pistas
        forcedClues.add(cells[i]);
      }
    }

    numberCells.shuffle(_rnd);
    final totalClues = (numberCells.length * percent / 100).ceil().clamp(forcedClues.length + 5, numberCells.length - 6);

    p.bankCounts.clear();
    int cluesPlaced = 0;
    for (final coord in numberCells) {
      final cell = p.grid[coord.r][coord.c];
      if (forcedClues.contains(coord) || cluesPlaced < totalClues) {
        cell.fixed = true;
        cluesPlaced++;
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