
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
    final int size = minSize + _rnd.nextInt(maxSize - minSize + 1);
    final int maxVal = difficulty == 'easy'
        ? 29
        : difficulty == 'medium'
            ? 59
            : 99;

    outerLoop:
    while (true) {
      final MatrixPuzzle puzzle = MatrixPuzzle(size, size, difficulty: difficulty);

      // Máscara de celdas usadas (evita cualquier solapamiento)
      final List<List<bool>> used = List.generate(size, (_) => List.filled(size, false));

      final List<_Equation> equations = [];

      // Primera ecuación en posición segura
      final bool firstHorizontal = _rnd.nextBool();
      final int startR = 2 + _rnd.nextInt(size - 6);
      final int startC = 2 + _rnd.nextInt(size - 6);

      if (!_placeEquationSafe(puzzle, used, firstHorizontal, startR, startC, maxVal, difficulty)) {
        continue outerLoop;
      }
      equations.add(_Equation(firstHorizontal, startR, startC));

      // Añadimos ecuaciones que crucen correctamente con las existentes
      for (int attempts = 0; attempts < 1000; attempts++) {
        final _Equation candidate = _findValidCrossing(equations, size, used);
        if (candidate == null) break;

        final bool placed = _placeEquationSafe(
          puzzle,
          used,
          candidate.horizontal,
          candidate.row,
          candidate.col,
          maxVal,
          difficulty,
        );

        if (placed) {
          equations.add(candidate);
        }
      }

      // Mínimo 7-8 ecuaciones para un buen puzzle
      if (equations.length < 7) continue outerLoop;

      // Finalizamos con pistas mínimas por ecuación
      if (_finalizeWithGuaranteedClues(puzzle, cluePercent, equations)) {
        return puzzle;
      }
    }
  }

  // Coloca una ecuación SIN solapar NADA y respetando distancias
  static bool _placeEquationSafe(
    MatrixPuzzle p,
    List<List<bool>> used,
    bool horizontal,
    int r,
    int c,
    int maxVal,
    String diff,
  ) {
    // Verificar límites
    if (horizontal && c + 4 >= p.cols) return false;
    if (!horizontal && r + 4 >= p.rows) return false;

    // Verificar que ninguna celda esté usada o demasiado cerca (excepto cruce válido)
    for (int i = 0; i < 5; i++) {
      final int cr = horizontal ? r : r + i;
      final int cc = horizontal ? c + i : c;
      if (used[cr][cc]) return false;

      // Separación mínima de 1 celda con cualquier cosa que no sea cruce real
      for (int dr = -1; dr <= 1; dr++) {
        for (int dc = -1; dc <= 1; dc++) {
          if (dr == 0 && dc == 0) continue;
          final int nr = cr + dr;
          final int nc = cc + dc;
          if (nr >= 0 && nr < p.rows && nc >= 0 && nc < p.cols && used[nr][nc]) {
            return false; // demasiado cerca
          }
        }
      }
    }

    final List equation = _generatePerfectEquation(maxVal, diff);
    if (equation == null) return false;

    final int A = equation[0];
    final String op = equation[1];
    final int B = equation[2];
    final int C = equation[3];

    if (horizontal) {
      p.grid[r][c]     = Cell.number(A, fixed: false);
      p.grid[r][c + 1] = Cell.operator(op);
      p.grid[r][c + 2] = Cell.number(B, fixed: false);
      p.grid[r][c + 3] = Cell.equals();
      p.grid[r][c + 4] = Cell.result(C, fixed: false);
    } else {
      p.grid[r][c]     = Cell.number(A, fixed: false);
      p.grid[r + 1][c] = Cell.operator(op);
      p.grid[r + 2][c] = Cell.number(B, fixed: false);
      p.grid[r + 3][c] = Cell.equals();
      p.grid[r + 4][c] = Cell.result(C, fixed: false);
    }

    // Marcar como usadas
    for (int i = 0; i < 5; i++) {
      final int cr = horizontal ? r : r + i;
      final int cc = horizontal ? c + i : c;
      used[cr][cc] = true;
    }

    return true;
  }

  // Genera ecuación perfecta (nunca 0, nunca negativa, bonita)
  static List _generatePerfectEquation(int maxVal, String diff) {
    final List<String> ops = diff == 'easy'
        ? ['+', '-']
        : diff == 'medium'
            ? ['+', '-', '*']
            : ['+', '-', '*', '/'];

    for (int t = 0; t < 100; t++) {
      final String op = ops[_rnd.nextInt(ops.length)];
      int A, B, C;

      if (op == '+') {
        A = 2 + _rnd.nextInt(maxVal - 4);
        B = 2 + _rnd.nextInt(maxVal - A);
        C = A + B;
      } else if (op == '-') {
        C = 4 + _rnd.nextInt(maxVal - 6);
        B = 1 + _rnd.nextInt(C - 2);
        A = B + C;
      } else if (op == '*') {
        A = 2 + _rnd.nextInt(12);
        B = 2 + _rnd.nextInt((maxVal ~/ A).clamp(2, 50));
        C = A * B;
        if (C > maxVal) continue;
      } else { // /
        C = 3 + _rnd.nextInt(maxVal - 3);
        final List<int> divisors = [];
        for (int d = 2; d <= 30; d++) if (C % d == 0 && C * d <= maxVal) divisors.add(d);
        if (divisors.isEmpty) continue;
        B = divisors[_rnd.nextInt(divisors.length)];
        A = B * C;
      }

      if (A > 0 && B > 0 && C > 1 && A <= maxVal && B <= maxVal && C <= maxVal) {
        return [A, op, B, C];
      }
    }
    return null;
  }

  // Encuentra posición que cruce correctamente (solo en número o resultado)
  static _Equation _findValidCrossing(List<_Equation> existing, int size, List<List<bool>> used) {
    final List<_Equation> candidates = [];

    for (final _Equation eq in existing) {
      final List<Coord> cells = [];
      if (eq.horizontal) {
        for (int i = 0; i < 5; i++) cells.add(Coord(eq.row, eq.col + i));
      } else {
        for (int i = 0; i < 5; i++) cells.add(Coord(eq.row + i, eq.col));
      }

      // Solo cruzamos en posiciones 0, 2 o 4 (números y resultado)
      for (int pos in [0, 2, 4]) {
        final Coord cell = cells[pos];
        if (cell.r < 2 || cell.r > size - 5 || cell.c < 2 || cell.c > size - 5) continue;

        // Horizontal pasando por esta celda
        candidates.add(_Equation(true, cell.r, cell.c - pos));
        // Vertical pasando por esta celda
        candidates.add(_Equation(false, cell.r - pos, cell.c));
      }
    }

    candidates.shuffle(_rnd);
    for (final _Equation cand in candidates) {
      final int sr = cand.horizontal ? cand.row : cand.row;
      final int sc = cand.horizontal ? cand.col : cand.col;
      final int er = cand.horizontal ? cand.row : cand.row + 4;
      final int ec = cand.horizontal ? cand.col + 4 : cand.col;

      if (sr >= 0 && er < size && sc >= 0 && ec < size) {
        bool safe = true;
        for (int i = 0; i < 5 && safe; i++) {
          final int cr = cand.horizontal ? sr : sr + i;
          final int cc = cand.horizontal ? sc + i : sc;
          if (used[cr][cc]) safe = false;
        }
        if (safe) return cand;
      }
    }
    return null;
  }

  // Garantiza al menos 2-3 pistas por ecuación
  static bool _finalizeWithGuaranteedClues(MatrixPuzzle p, int percent, List<_Equation> equations) {
    final List<Coord> numberCells = [];

    for (int r = 0; r < p.rows; r++) {
      for (int c = 0; c < p.cols; c++) {
        final Cell cell = p.grid[r][c];
        if ((cell.type == CellType.number || cell.type == CellType.result) && cell.number != null) {
          numberCells.add(Coord(r, c));
        }
      }
    }

    if (numberCells.length < 25) return false;

    // Forzar pistas mínimas por ecuación
    final Set<Coord> forced = Set<Coord>();
    for (final _Equation eq in equations) {
      final List<Coord> nums = [];
      if (eq.horizontal) {
        nums.add(Coord(eq.row, eq.col));
        nums.add(Coord(eq.row, eq.col + 2));
        nums.add(Coord(eq.row, eq.col + 4));
      } else {
        nums.add(Coord(eq.row, eq.col));
        nums.add(Coord(eq.row + 2, eq.col));
        nums.add(Coord(eq.row + 4, eq.col));
      }
      nums.shuffle(_rnd);
      for (int i = 0; i < 2; i++) forced.add(nums[i]); // mínimo 2
      if (_rnd.nextDouble() < 0.6) forced.add(nums[2]); // a veces 3
    }

    // Aplicar pistas
    p.bankCounts.clear();
    int extraClues = (numberCells.length * percent / 100).ceil() - forced.length;
    extraClues = extraClues.clamp(0, numberCells.length - forced.length - 5);

    numberCells.shuffle(_rnd);

    int cluesPlaced = 0;
    for (final Coord coord in numberCells) {
      final Cell cell = p.grid[coord.r][coord.c];
      if (forced.contains(coord) || cluesPlaced < extraClues + forced.length) {
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
  final int row;
  final int col;
  _Equation(this.horizontal, this.row, this.col);
}