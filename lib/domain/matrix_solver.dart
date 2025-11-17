
// lib/domain/matrix_solver.dart
// Compatible con Flutter 1.22 (no null-safety)

import 'matrix_puzzle.dart';
import 'cell.dart';

class MatrixSolver {
  static bool isSolved(MatrixPuzzle p) {
    return _allEquationsValid(p) && _noHoles(p);
  }

  static bool _noHoles(MatrixPuzzle p) {
    for (int r = 0; r < p.rows; r++) {
      for (int c = 0; c < p.cols; c++) {
        final cell = p.grid[r][c];

        if (cell.type == CellType.number ||
            cell.type == CellType.result) {
          if (cell.number == null) return false;
        }
      }
    }
    return true;
  }

  static bool _allEquationsValid(MatrixPuzzle p) {
    // horizontales
    for (int r = 0; r < p.rows; r++) {
      for (int c = 0; c <= p.cols - 5; c++) {
        if (_isEquationAt(p, r, c, true)) {
          if (!_checkEquation(p, r, c, true)) return false;
        }
      }
    }

    // verticales
    for (int c = 0; c < p.cols; c++) {
      for (int r = 0; r <= p.rows - 5; r++) {
        if (_isEquationAt(p, r, c, false)) {
          if (!_checkEquation(p, r, c, false)) return false;
        }
      }
    }

    return true;
  }

  static bool _isEquationAt(MatrixPuzzle p, int r, int c, bool h) {
    Coord a  = h ? Coord(r, c)     : Coord(r, c);
    Coord op = h ? Coord(r, c + 1) : Coord(r + 1, c);
    Coord b  = h ? Coord(r, c + 2) : Coord(r + 2, c);
    Coord eq = h ? Coord(r, c + 3) : Coord(r + 3, c);
    Coord rs = h ? Coord(r, c + 4) : Coord(r + 4, c);

    if (!p.inBounds(a.r, a.c) || !p.inBounds(rs.r, rs.c)) return false;

    final ca = p.grid[a.r][a.c];
    final cop = p.grid[op.r][op.c];
    final cb = p.grid[b.r][b.c];
    final ceq = p.grid[eq.r][eq.c];
    final cres = p.grid[rs.r][rs.c];

    return ca.type == CellType.number &&
        cop.type == CellType.operator &&
        cb.type == CellType.number &&
        ceq.type == CellType.equals &&
        cres.type == CellType.result;
  }

  static bool _checkEquation(MatrixPuzzle p, int r, int c, bool h) {
    Coord a  = h ? Coord(r, c)     : Coord(r, c);
    Coord op = h ? Coord(r, c + 1) : Coord(r + 1, c);
    Coord b  = h ? Coord(r, c + 2) : Coord(r + 2, c);
    Coord eq = h ? Coord(r, c + 3) : Coord(r + 3, c);
    Coord rs = h ? Coord(r, c + 4) : Coord(r + 4, c);

    final ca = p.grid[a.r][a.c];
    final cop = p.grid[op.r][op.c];
    final cb = p.grid[b.r][b.c];
    final cres = p.grid[rs.r][rs.c];

    if (ca.number == null || cb.number == null || cres.number == null)
      return false;

    final A = ca.number;
    final B = cb.number;
    final C = cres.number;
    final o = cop.operator;

    int calc;

    if (o == '+') calc = A + B;
    else if (o == '-') calc = A - B;
    else if (o == '*') calc = A * B;
    else if (o == '/') {
      if (B == 0) return false;
      if (A % B != 0) return false;
      calc = A ~/ B;
    } else {
      return false;
    }

    return calc == C;
  }
}