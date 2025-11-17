
// lib/domain/matrix_puzzle.dart
// Compatible con Flutter 1.22 (no null-safety)

import 'dart:convert';
import 'cell.dart';

/// Coordenada simple
class Coord {
  final int r;
  final int c;
  Coord(this.r, this.c);
  @override
  bool operator ==(other) => other is Coord && other.r == r && other.c == c;
  @override
  int get hashCode => r.hashCode ^ c.hashCode;
  Map<String, int> toJson() => {'r': r, 'c': c};
  static Coord fromJson(Map j) => Coord(j['r'], j['c']);
}

/// Estado mínimo de una celda usado por la UI.
/// Nota: la clase Cell ya existe en domain/cell.dart; aquí solo la usamos.
/// Asegúrate que domain/cell.dart define CellType y Cell con campos accesibles.
import 'dart:collection';

class MatrixPuzzle {
  final int rows;
  final int cols;
  List<List<Cell>> grid; // grid[r][c]
  /// bank: multiset counts of hidden numbers
  Map<int, int> bankCounts = {};
  String id;
  String difficulty; // "easy","medium","hard"

  MatrixPuzzle(this.rows, this.cols, {this.difficulty = 'easy', this.id}) {
    grid = List.generate(rows, (_) => List.generate(cols, (_) => Cell.empty()));
  }

  // --- getters / helpers ---
  bool inBounds(int r, int c) => r >= 0 && r < rows && c >= 0 && c < cols;

  Cell cellAt(Coord p) => grid[p.r][p.c];

  void setCellAt(Coord p, Cell cell) {
    grid[p.r][p.c] = cell;
  }

  /// Place a number into a cell (player action). Returns true if accepted.
  bool placeNumber(int r, int c, int value, {bool markFixed = false}) {
    if (!inBounds(r, c)) return false;
    final cell = grid[r][c];
    if (cell.type != CellType.number) return false;
    if (cell.fixed) return false;
    cell.number = value;
    if (markFixed) cell.fixed = true;
    // consume from bank if present
    if (bankCounts.containsKey(value) && bankCounts[value] > 0) {
      bankCounts[value] = bankCounts[value] - 1;
      if (bankCounts[value] == 0) bankCounts.remove(value);
    }
    return true;
  }

  /// Remove number from a non-fixed number cell, return it to bank.
  bool removeNumber(int r, int c) {
    if (!inBounds(r, c)) return false;
    final cell = grid[r][c];
    if (cell.type != CellType.number) return false;
    if (cell.fixed) return false;
    if (cell.number == null) return false;
    final v = cell.number;
    cell.number = null;
    bankCounts[v] = (bankCounts[v] ?? 0) + 1;
    return true;
  }

  /// Return a copy (deep) of this puzzle.
  MatrixPuzzle copy() {
    final out = MatrixPuzzle(rows, cols, difficulty: difficulty, id: id);
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        out.grid[r][c] = grid[r][c].clone();
      }
    }
    out.bankCounts = Map<int, int>.from(bankCounts);
    return out;
  }

  // Check all operator-based equations in the grid and return true if all complete & correct.
  // We interpret an equation when pattern [num][op][num][equals][res] exists in-line (horizontal or vertical).
  bool isSolved() {
    // scan horizontal
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c <= cols - 5; c++) {
        if (_isEquationAt(r, c, horizontal: true)) {
          if (!_checkEquationAt(r, c, horizontal: true)) return false;
        }
      }
    }
    // scan vertical
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r <= rows - 5; r++) {
        if (_isEquationAt(r, c, horizontal: false)) {
          if (!_checkEquationAt(r, c, horizontal: false)) return false;
        }
      }
    }
    // If there is at least one equation and all equations pass, considered solved.
    return true;
  }

  // detect if a sequence starting at (r,c) is shaped like num,op,num,equals,res (types)
  bool _isEquationAt(int r, int c, {bool horizontal = true}) {
    Coord a = horizontal ? Coord(r, c) : Coord(r, c);
    Coord op = horizontal ? Coord(r, c + 1) : Coord(r + 1, c);
    Coord b = horizontal ? Coord(r, c + 2) : Coord(r + 2, c);
    Coord eq = horizontal ? Coord(r, c + 3) : Coord(r + 3, c);
    Coord res = horizontal ? Coord(r, c + 4) : Coord(r + 4, c);
    if (!inBounds(a.r, a.c) || !inBounds(res.r, res.c)) return false;
    final ca = grid[a.r][a.c];
    final cop = grid[op.r][op.c];
    final cb = grid[b.r][b.c];
    final ceq = grid[eq.r][eq.c];
    final cres = grid[res.r][res.c];
    return ca.type == CellType.number &&
        cop.type == CellType.operator &&
        cb.type == CellType.number &&
        ceq.type == CellType.equals &&
        cres.type == CellType.result;
  }

  bool _checkEquationAt(int r, int c, {bool horizontal = true}) {
    Coord a = horizontal ? Coord(r, c) : Coord(r, c);
    Coord op = horizontal ? Coord(r, c + 1) : Coord(r + 1, c);
    Coord b = horizontal ? Coord(r, c + 2) : Coord(r + 2, c);
    Coord eq = horizontal ? Coord(r, c + 3) : Coord(r + 3, c);
    Coord res = horizontal ? Coord(r, c + 4) : Coord(r + 4, c);

    final ca = grid[a.r][a.c];
    final cop = grid[op.r][op.c];
    final cb = grid[b.r][b.c];
    final cres = grid[res.r][res.c];

    if (ca.number == null || cb.number == null || cres.number == null) return false;
    final int A = ca.number;
    final int B = cb.number;
    final int C = cres.number;
    final String opch = cop.operator;

    try {
      int got;
      if (opch == '+') got = A + B;
      else if (opch == '-') got = A - B;
      else if (opch == '*') got = A * B;
      else if (opch == '/') {
        if (B == 0) return false;
        if (A % B != 0) return false;
        got = A ~/ B;
      } else return false;
      return got == C;
    } catch (e) {
      return false;
    }
  }

  // bank helpers
  void bankPut(int v) => bankCounts[v] = (bankCounts[v] ?? 0) + 1;
  bool bankContains(int v) => bankCounts.containsKey(v) && bankCounts[v] > 0;
  bool bankUse(int v) {
    if (!bankContains(v)) return false;
    bankCounts[v] = bankCounts[v] - 1;
    if (bankCounts[v] == 0) bankCounts.remove(v);
    return true;
  }

  // Serialization
  Map<String, dynamic> toJson() {
    final cells = <Map>[];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cell = grid[r][c];
        cells.add({
          'pos': {'r': r, 'c': c},
          'type': cell.type.toString().split('.').last,
          'number': cell.number,
          'operator': cell.operator,
          'fixed': cell.fixed
        });
      }
    }
    return {
      'rows': rows,
      'cols': cols,
      'cells': cells,
      'bank': bankCounts,
      'difficulty': difficulty,
      'id': id
    };
  }

  static MatrixPuzzle fromJson(Map j) {
    final int rows = j['rows'];
    final int cols = j['cols'];
    final p = MatrixPuzzle(rows, cols, difficulty: j['difficulty'] ?? 'easy', id: j['id']);
    final List cells = j['cells'] ?? [];
    for (var cj in cells) {
      final pos = cj['pos'];
      final r = pos['r'];
      final c = pos['c'];
      final typeStr = cj['type'];
      final t = CellType.values.firstWhere((e) => e.toString().split('.').last == typeStr, orElse: () => CellType.empty);
      final cell = Cell.fromType(t);
      cell.number = cj['number'];
      cell.operator = cj['operator'];
      cell.fixed = cj['fixed'] ?? false;
      p.grid[r][c] = cell;
    }
    final Map bc = Map<String, dynamic>.from(j['bank'] ?? {});
    p.bankCounts = {};
    bc.forEach((k, v) {
      p.bankCounts[int.parse(k)] = v;
    });
    return p;
  }

  String encode() => json.encode(toJson());
  static MatrixPuzzle decode(String s) => MatrixPuzzle.fromJson(json.decode(s));
}