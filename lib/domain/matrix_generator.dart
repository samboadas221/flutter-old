
import 'dart:math';
import 'matrix_puzzle.dart';
import 'cell.dart';

class MatrixGenerator {
  static final Random _rnd = Random();

  static MatrixPuzzle generate({
    String difficulty = 'easy',
    int minSize = 9,
    int maxSize = 12,
    int cluePercent = 40,
  }) {
    final int size = minSize + _rnd.nextInt(maxSize - minSize + 1);
    final int maxVal = difficulty == 'easy' ? 30 : difficulty == 'medium' ? 60 : 99;

    // Intentamos máximo 50 veces → nunca bucle infinito
    for (int globalAttempt = 0; globalAttempt < 50; globalAttempt++) {
      final MatrixPuzzle puzzle = MatrixPuzzle(size, size, difficulty: difficulty);
      final List<List<bool>> occupied = List.generate(size, (_) => List.filled(size, false));
      final List<_Equation> equations = [];

      // 1. Primera ecuación horizontal en el centro
      int r = size ~/ 2;
      int c = (size - 5) ~/ 2;
      if (_placeEquation(puzzle, occupied, true, r, c, maxVal, difficulty)) {
        equations.add(_Equation(true, r, c));
      } else {
        continue;
      }

      // 2. Añadimos ecuaciones que crucen con las existentes (máximo 30)
      int added;
      do {
        added = 0;
        final List<_Candidate> candidates = _findAllCrossings(equations, size, occupied);
        candidates.shuffle(_rnd);
        for (final cand in candidates) {
          if (equations.length >= 25) break;
          if (_placeEquation(puzzle, occupied, cand.horizontal, cand.r, cand.c, maxVal, difficulty)) {
            equations.add(_Equation(cand.horizontal, cand.r, cand.c));
            added++;
          }
        }
      } while (added > 0 && equations.length < 25);

      // Si tenemos al menos 6 ecuaciones → aceptamos
      if (equations.length >= 6 && _finalizePuzzle(puzzle, occupied, cluePercent, equations)) {
        return puzzle;
      }
    }

    // Fallback seguro (rara vez llega aquí)
    return _generateSimpleFallback(size, maxVal, difficulty, cluePercent);
  }

  // Coloca ecuación con todas las reglas estrictas
  static bool _placeEquation(
    MatrixPuzzle p,
    List<List<bool>> occupied,
    bool horizontal,
    int r,
    int c,
    int maxVal,
    String diff,
  ) {
    // Verificar límites
    if (horizontal && c + 4 >= p.cols) return false;
    if (!horizontal && r + 4 >= p.rows) return false;

    // Verificar que las 5 celdas estén libres
    for (int i = 0; i < 5; i++) {
      int cr = horizontal ? r : r + i;
      int cc = horizontal ? c + i : c;
      if (occupied[cr][cc]) return false;
    }

    // Generar ecuación válida
    final List eq = _goodEquation(maxVal, diff);
    if (eq == null) return false;
    final int A = eq[0];
    final String op = eq[1];
    final int B = eq[2];
    final int C = eq[3];

    // Colocar
    if (horizontal) {
      p.grid[r][c]     = Cell.number(A, fixed: false);
      p.grid[r][c+1]   = Cell.operator(op);
      p.grid[r][c+2]   = Cell.number(B, fixed: false);
      p.grid[r][c+3]   = Cell.equals();
      p.grid[r][c+4]   = Cell.result(C, fixed: false);
    } else {
      p.grid[r][c]     = Cell.number(A, fixed: false);
      p.grid[r+1][c]   = Cell.operator(op);
      p.grid[r+2][c]   = Cell.number(B, fixed: false);
      p.grid[r+3][c]   = Cell.equals();
      p.grid[r+4][c]   = Cell.result(C, fixed: false);
    }

    // Marcar ocupadas
    for (int i = 0; i < 5; i++) {
      int cr = horizontal ? r : r + i;
      int cc = horizontal ? c + i : c;
      occupied[cr][cc] = true;
    }
    return true;
  }

  // Ecuaciones siempre bonitas
  static List _goodEquation(int maxVal, String diff) {
    final List<String> ops = diff == 'easy' ? ['+', '-'] : ['+', '-', '*', '/'];
    for (int t = 0; t < 50; t++) {
      final String op = ops[_rnd.nextInt(ops.length)];
      int A, B, C;
      if (op == '+') {
        A = 2 + _rnd.nextInt(maxVal - 3);
        B = 2 + _rnd.nextInt(maxVal - A);
        C = A + B;
      } else if (op == '-') {
        C = 3 + _rnd.nextInt(maxVal - 4);
        B = 1 + _rnd.nextInt(C - 1);
        A = B + C;
      } else if (op == '*') {
        A = 2 + _rnd.nextInt(10);
        B = 2 + _rnd.nextInt(maxVal ~/ A);
        C = A * B;
        if (C > maxVal) continue;
      } else {
        C = 3 + _rnd.nextInt(maxVal - 2);
        final List<int> divs = [];
        for (int d = 2; d <= C && d * C <= maxVal; d++) if (C % d == 0) divs.add(d);
        if (divs.isEmpty) continue;
        B = divs[_rnd.nextInt(divs.length)];
        A = B * C;
      }
      return [A, op, B, C];
    }
    return [5, '+', 3, 8]; // fallback seguro
  }

  // Encuentra todos los posibles cruces válidos
  static List<_Candidate> _findAllCrossings(List<_Equation> eqs, int size, List<List<bool>> occupied) {
    final Set<String> seen = Set<String>();
    final List<_Candidate> list = [];

    for (final eq in eqs) {
      final List<Coord> cells = [];
      if (eq.horizontal) {
        for (int i = 0; i < 5; i++) cells.add(Coord(eq.row, eq.col + i));
      } else {
        for (int i = 0; i < 5; i++) cells.add(Coord(eq.row + i, eq.col));
      }

      // Solo cruzamos en número o resultado (pos 0,2,4)
      for (int pos in [0, 2, 4]) {
        final Coord cell = cells[pos];

        // Horizontal
        int hc = cell.c - pos;
        if (hc >= 0 && hc + 4 < size) {
          String key = 'h${cell.r}_$hc';
          if (!seen.contains(key)) {
            seen.add(key);
            list.add(_Candidate(true, cell.r, hc));
          }
        }

        // Vertical
        int vr = cell.r - pos;
        if (vr >= 0 && vr + 4 < size) {
          String key = 'v\( {vr}_ \){cell.c}';
          if (!seen.contains(key)) {
            seen.add(key);
            list.add(_Candidate(false, vr, cell.c));
          }
        }
      }
    }
    return list;
  }

  // Finaliza con pistas garantizadas
  static bool _finalizePuzzle(MatrixPuzzle p, List<List<bool>> occupied, int percent, List<_Equation> equations) {
    final List<Coord> numbers = [];
    for (int r = 0; r < p.rows; r++) {
      for (int c = 0; c < p.cols; c++) {
        final Cell cell = p.grid[r][c];
        if ((cell.type == CellType.number || cell.type == CellType.result) && cell.number != null) {
          numbers.add(Coord(r, c));
        }
      }
    }

    if (numbers.length < 20) return false;

    // Mínimo 2 pistas por ecuación
    final Set<Coord> forced = Set<Coord>();
    for (final eq in equations) {
      final List<Coord> nums = eq.horizontal
          ? [Coord(eq.row, eq.col), Coord(eq.row, eq.col + 2), Coord(eq.row, eq.col + 4)]
          : [Coord(eq.row, eq.col), Coord(eq.row + 2, eq.col), Coord(eq.row + 4, eq.col)];
      nums.shuffle(_rnd);
      forced.add(nums[0]);
      forced.add(nums[1]);
    }

    numbers.shuffle(_rnd);
    final int totalClues = (numbers.length * percent / 100).ceil().clamp(forced.length, numbers.length - 5);

    p.bankCounts.clear();
    int placed = 0;
    for (final Coord coord in numbers) {
      final Cell cell = p.grid[coord.r][coord.c];
      if (forced.contains(coord) || placed < totalClues) {
        cell.fixed = true;
        placed++;
      } else {
        p.bankCounts[cell.number] = (p.bankCounts[cell.number] ?? 0) + 1;
        cell.number = null;
      }
    }
    return true;
  }

  // Fallback 100% seguro si todo falla
  static MatrixPuzzle _generateSimpleFallback(int size, int maxVal, String diff, int percent) {
    final MatrixPuzzle p = MatrixPuzzle(size, size, difficulty: diff);
    // Solo una cruz grande en el centro
    final int cr = size ~/ 2;
    final int cc = (size - 5) ~/ 2;
    _placeEquation(p, List.generate(size, (_) => List.filled(size, false)), true, cr, cc, maxVal, diff);
    _placeEquation(p, List.generate(size, (_) => List.filled(size, false)), false, cc, cr, maxVal, diff);
    _finalizePuzzle(p, List.generate(size, (_) => List.filled(size, false)), percent, [_Equation(true, cr, cc)]);
    return p;
  }
}

class _Equation {
  final bool horizontal;
  final int row, col;
  _Equation(this.horizontal, this.row, this.col);
}

class _Candidate {
  final bool horizontal;
  final int r, c;
  _Candidate(this.horizontal, this.r, this.c);
}