
// lib/domain/matrix_generator.dart
// Versión 3.0 - Generador perfecto para CrossMath - Noviembre 2025
// Compatible con Flutter 1.22 (sin null-safety)

import 'dart:math';
import 'matrix_puzzle.dart';
import 'cell.dart';

class MatrixGenerator {
  static final Random _rnd = Random();

  static MatrixPuzzle generate({
    String difficulty = 'easy',
    int minRows = 9,
    int maxRows = 12,
    int minCols = 9,
    int maxCols = 12,
    int cluePercent = 40,
  }) {
    final rows = minRows + _rnd.nextInt(maxRows - minRows + 1);
    final cols = minCols + _rnd.nextInt(maxCols - minCols + 1);
    final maxVal = _maxForDifficulty(difficulty);

    while (true) { // Reintentamos hasta tener un puzzle perfecto
      final puzzle = MatrixPuzzle(rows, cols, difficulty: difficulty);

      // Limpia todo
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          puzzle.grid[r][c] = Cell.empty();
        }
      }

      final placedEquations = <_Equation>[];

      // Intentamos colocar ecuaciones hasta cubrir bien el tablero
      for (int attempt = 0; attempt < 3000; attempt++) {
        final horizontal = _rnd.nextBool();
        final length = 5;

        int startRow, startCol;
        if (horizontal) {
          startRow = 1 + _rnd.nextInt(rows - 2); // deja margen arriba y abajo
          startCol = _rnd.nextInt(cols - length + 1);
        } else {
          startRow = _rnd.nextInt(rows - length + 1);
          startCol = 1 + _rnd.nextInt(cols - 2); // deja margen izquierda y derecha
        }

        final eq = _Equation(horizontal, startRow, startCol);

        // Verifica que no choque ilegalmente con otras ecuaciones
        if (placedEquations.any((e) => _conflicts(e, eq))) {
          continue;
        }

        // Genera una ecuación válida
        final equationData = _generateValidEquation(maxVal, difficulty);
        if (equationData == null) continue;

        final A = equationData[0];
        final op = equationData[1];
        final B = equationData[2];
        final C = equationData[3];

        // Coloca en el tablero (sin merge: ahora es seguro)
        _placeEquation(puzzle, eq, A, op, B, C);

        placedEquations.add(eq);

        // Si ya tenemos suficiente cobertura, paramos
        if (placedEquations.length >= (rows * cols) ~/ 11) {
          break;
        }
      }

      // Si no hay ecuaciones, reintentar
      if (placedEquations.isEmpty) continue;

      // Ahora ocultamos números y creamos banco
      if (_finalizePuzzle(puzzle, cluePercent)) {
        return puzzle; // ¡Éxito!
      }
      // Si no (por ejemplo, muy pocos números), reintenta todo
    }
  }

  // Genera A op B = C con C >= 1 y sin negativos
  static List _generateValidEquation(int maxVal, String difficulty) {
    final ops = difficulty == 'easy'
        ? ['+', '-', '+', '-'] // más suma y resta
        : difficulty == 'medium'
            ? ['+', '-', '*', '+']
            : ['+', '-', '*', '/'];

    for (int t = 0; t < 80; t++) {
      final op = ops[_rnd.nextInt(ops.length)];
      int A, B, C;

      if (op == '+') {
        A = 1 + _rnd.nextInt(maxVal);
        B = 1 + _rnd.nextInt(maxVal);
        C = A + B;
      } else if (op == '-') {
        C = 1 + _rnd.nextInt(maxVal);
        B = 1 + _rnd.nextInt(maxVal - 1);
        A = C + B;
      } else if (op == '*') {
        final factors = _getFactors(maxVal * 2); // permite más opciones
        if (factors.isEmpty) continue;
        A = factors[_rnd.nextInt(factors.length)];
        B = 2 + _rnd.nextInt(maxVal ~/ A + 1);
        C = A * B;
      } else { // '/'
        C = 1 + _rnd.nextInt(maxVal);
        final divisors = _getDivisors(C * 5); // más opciones
        if (divisors.length < 2) continue;
        B = divisors[1 + _rnd.nextInt(divisors.length - 1)];
        if (B == 0 || B == 1) continue;
        A = C * B;
      }

      if (C > maxVal || A > maxVal || B > maxVal) continue;
      if (C <= 0) continue;

      return [A, op, B, C];
    }
    return null;
  }

  static List<int> _getFactors(int n) {
    List<int> f = [];
    for (int i = 2; i * i <= n; i++) if (n % i == 0) f.add(i);
    return f.isEmpty ? [2] : f;
  }

  static List<int> _getDivisors(int n) {
    List<int> d = [];
    for (int i = 1; i * i <= n; i++) {
      if (n % i == 0) {
        d.add(i);
        if (i != n ~/ i) d.add(n ~/ i);
      }
    }
    d.sort();
    return d;
  }

  static void _placeEquation(MatrixPuzzle p, _Equation eq, int A, String op, int B, int C) {
    final r = eq.row;
    final c = eq.col;
    if (eq.horizontal) {
      p.grid[r][c]   = Cell.number(A, fixed: false);
      p.grid[r][c+1] = Cell.operator(op);
      p.grid[r][c+2] = Cell.number(B, fixed: false);
      p.grid[r][c+3] = Cell.equals();
      p.grid[r][c+4] = Cell.result(C, fixed: false);
    } else {
      p.grid[r][c]   = Cell.number(A, fixed: false);
      p.grid[r+1][c] = Cell.operator(op);
      p.grid[r+2][c] = Cell.number(B, fixed: false);
      p.grid[r+3][c] = Cell.equals();
      p.grid[r+4][c] = Cell.result(C, fixed: false);
    }
  }

  static bool _conflicts(_Equation a, _Equation b) {
    if (a.horizontal == b.horizontal) {
      // Mismo sentido → no pueden estar cerca
      if (a.horizontal) {
        if (a.row.abs() - b.row.abs() <= 1) {
          final left = max(a.col, b.col);
          final right = min(a.col + 4, b.col + 4);
          if (left <= right) return true;
        }
      } else {
        if (a.col.abs() - b.col.abs() <= 1) {
          final top = max(a.row, b.row);
          final bot = min(a.row + 4, b.row + 4);
          if (top <= bot) return true;
        }
      }
    }
    return false;
  }

  static bool _finalizePuzzle(MatrixPuzzle puzzle, int cluePercent) {
    final numberCells = <Coord>[];

    for (int r = 0; r < puzzle.rows; r++) {
      for (int c = 0; c < puzzle.cols; c++) {
        final cell = puzzle.grid[r][c];
        if (cell.type == CellType.number || cell.type == CellType.result) {
          if (cell.number == null) return false; // seguridad
          numberCells.add(Coord(r, c));
        }
      }
    }

    if (numberCells.length < 15) return false; // muy vacío

    numberCells.shuffle(_rnd);
    final keepCount = (numberCells.length * cluePercent / 100).ceil().clamp(5, numberCells.length - 5);

    puzzle.bankCounts.clear();
    for (int i = 0; i < numberCells.length; i++) {
      final coord = numberCells[i];
      final cell = puzzle.grid[coord.r][coord.c];
      if (i < keepCount) {
        cell.fixed = true;
      } else {
        puzzle.bankCounts[cell.number] = (puzzle.bankCounts[cell.number] ?? 0) + 1;
        cell.number = null;
        cell.fixed = false;
      }
    }

    return true;
  }

  static int _maxForDifficulty(String d) {
    if (d == 'easy') return 25;
    if (d == 'medium') return 50;
    return 99;
  }
}

// Clase auxiliar privada
class _Equation {
  final bool horizontal;
  final int row;
  final int col;
  _Equation(this.horizontal, this.row, this.col);
}