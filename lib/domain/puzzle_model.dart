
// lib/domain/puzzle_model.dart
// Adapter layer: expose an API compatible with the old "Puzzle" model
// internally backed by MatrixPuzzle / Cell (matrix_* files).

import 'dart:collection';
import 'matrix_puzzle.dart';
import 'cell.dart';
import 'matrix_solver.dart';
import '../data/json_formats.dart';
import 'puzzle_metadata.dart';

enum Difficulty { easy, medium, hard }

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

/// Light wrapper for underlying matrix Cell to match UI expectations.
class CellWrapper {
  final int r;
  final int c;
  final Cell _inner; // domain/cell.dart Cell
  CellWrapper(this.r, this.c, this._inner);

  Coord get pos => Coord(r, c);

  bool get isNumber => _inner.type == CellType.number;
  bool get isOperator => _inner.type == CellType.operator;
  bool get isEquals => _inner.type == CellType.empty /* equals may be modelled differently */ ? false : (_inner.type == CellType.empty ? false : false);

  // We expect target/equal detection in UI; try to infer from type string if available
  bool get isTarget => _inner.type == CellType.result;
  bool get isEqualsSign => _inner.type == CellType.empty ? false : false;

  dynamic get value {
    if (_inner.type == CellType.operator) return _inner.operator;
    return _inner.number;
  }

  set value(dynamic v) {
    if (_inner.type == CellType.operator) {
      _inner.operator = v?.toString();
    } else {
      if (v == null) _inner.number = null;
      else _inner.number = (v is int) ? v : int.tryParse(v.toString());
    }
  }

  bool get fixed => _inner.fixed;
  set fixed(bool v) => _inner.fixed = v;
}

/// Small Line object used by UI (operandCoords + operator/equal)
class Line {
  final String id;
  final List<Coord> operandCoords;
  final Coord operatorCoord;
  final Coord equalsCoord;
  Line({this.id, this.operandCoords, this.operatorCoord, this.equalsCoord});
}

/// Bank wrapper to provide expected API (fromList, toList, contains, use, put)
class Bank {
  final Map<int, int> _counts;
  Bank._(this._counts);

  factory Bank.fromList(List<int> list) {
    final m = <int, int>{};
    for (var v in list) m[v] = (m[v] ?? 0) + 1;
    return Bank._(m);
  }

  List<int> toList() {
    final out = <int>[];
    _counts.forEach((k, v) {
      for (int i = 0; i < v; i++) out.add(k);
    });
    return out;
  }

  bool contains(int v) => _counts.containsKey(v) && _counts[v] > 0;

  bool use(int v) {
    if (!contains(v)) return false;
    _counts[v] = _counts[v] - 1;
    if (_counts[v] == 0) _counts.remove(v);
    return true;
  }

  void put(int v) {
    _counts[v] = (_counts[v] ?? 0) + 1;
  }

  Map<int,int> toCounts() => Map<int,int>.from(_counts);
}

/// Puzzle wrapper that exposes old API while using MatrixPuzzle internally.
class Puzzle {
  MatrixPuzzle _m;

  Puzzle._(this._m);

  // Convenience factory from MatrixPuzzle
  factory Puzzle.fromMatrix(MatrixPuzzle m) => Puzzle._(m);

  // Create from json string
  factory Puzzle.fromJsonMap(Map j) {
    final mp = MatrixPuzzle.fromJson(j);
    return Puzzle.fromMatrix(mp);
  }

  int get rows => _m.rows;
  int get cols => _m.cols;

  // Difficulty stored as string in matrix puzzle; map to enum
  Difficulty get difficulty {
    final d = (_m.difficulty ?? '').toLowerCase();
    if (d == 'medium') return Difficulty.medium;
    if (d == 'hard') return Difficulty.hard;
    return Difficulty.easy;
  }

  set difficulty(Difficulty d) {
    _m.difficulty = d == Difficulty.medium ? 'medium' : (d == Difficulty.hard ? 'hard' : 'easy');
  }

  Puzzle copy() => Puzzle.fromMatrix(_m.copy());

  // metadata passthrough
  PuzzleMetadata get metadata => _m.id != null ? PuzzleMetadata(id: _m.id, createdAt: _m.difficulty, author: '') : null;
  set metadata(PuzzleMetadata m) {
    if (m == null) return;
    _m.id = m.id;
    _m.difficulty = m.createdAt ?? _m.difficulty;
  }

  // expose cells as Map<Coord, CellWrapper> and allow bracket access
  Map<Coord, CellWrapper> get cells {
    final out = <Coord, CellWrapper>{};
    for (int r = 0; r < _m.rows; r++) {
      for (int c = 0; c < _m.cols; c++) {
        final inner = _m.grid[r][c];
        out[Coord(r, c)] = CellWrapper(r, c, inner);
      }
    }
    return out;
  }

  CellWrapper operator [](Coord coord) {
    if (coord == null) return null;
    if (!_m.inBounds(coord.r, coord.c)) return null;
    return CellWrapper(coord.r, coord.c, _m.grid[coord.r][coord.c]);
  }

  // simple alias used by UI: _puzzle.cells[coord]
  Map<Coord, CellWrapper> get cellMap => cells;

  Bank get bank => Bank._(_m.bankCounts);
  set bank(Bank b) => _m.bankCounts = b.toCounts();

  // lines: detect sequences num op num equals res (horizontal + vertical)
  List<Line> get lines {
    final res = <Line>[];
    int idc = 0;
    for (int r = 0; r < _m.rows; r++) {
      for (int c = 0; c <= _m.cols - 5; c++) {
        if (_isEqAt(r, c, true)) {
          final ops = [
            Coord(r, c),
            Coord(r, c + 1),
            Coord(r, c + 2),
            Coord(r, c + 3),
            Coord(r, c + 4)
          ];
          res.add(Line(
            id: 'h-${idc++}',
            operandCoords: [ops[0], ops[2]],
            operatorCoord: ops[1],
            equalsCoord: ops[3],
          ));
        }
      }
    }
    for (int c = 0; c < _m.cols; c++) {
      for (int r = 0; r <= _m.rows - 5; r++) {
        if (_isEqAt(r, c, false)) {
          final ops = [
            Coord(r, c),
            Coord(r + 1, c),
            Coord(r + 2, c),
            Coord(r + 3, c),
            Coord(r + 4, c)
          ];
          res.add(Line(
            id: 'v-${idc++}',
            operandCoords: [ops[0], ops[2]],
            operatorCoord: ops[1],
            equalsCoord: ops[3],
          ));
        }
      }
    }
    return res;
  }

  bool _isEqAt(int r, int c, bool h) {
    final a = h ? Coord(r, c) : Coord(r, c);
    final op = h ? Coord(r, c + 1) : Coord(r + 1, c);
    final b = h ? Coord(r, c + 2) : Coord(r + 2, c);
    final eq = h ? Coord(r, c + 3) : Coord(r + 3, c);
    final res = h ? Coord(r, c + 4) : Coord(r + 4, c);
    if (!_m.inBounds(a.r, a.c) || !_m.inBounds(res.r, res.c)) return false;
    final ca = _m.grid[a.r][a.c];
    final cop = _m.grid[op.r][op.c];
    final cb = _m.grid[b.r][b.c];
    final ceq = _m.grid[eq.r][eq.c];
    final cres = _m.grid[res.r][res.c];
    return ca.type == CellType.number &&
        cop.type == CellType.operator &&
        cb.type == CellType.number &&
        ceq.type == CellType.empty /* equals placeholder */ ? true : false &&
        cres.type == CellType.result;
  }

  // placement API used by UI (map to matrix.placeNumber)
  bool placeNumber(int r, int c, int value, {bool markAsFixed = false}) {
    return _m.placeNumber(r, c, value, markFixed: markAsFixed);
  }

  bool removeNumber(int r, int c) => _m.removeNumber(r, c);

  // convenience: create from MatrixPuzzle json
  static Puzzle fromJsonString(String s) {
    final mp = MatrixPuzzle.decode(s);
    return Puzzle.fromMatrix(mp);
  }

  Map<String, dynamic> toJson() => _m.toJson();
}