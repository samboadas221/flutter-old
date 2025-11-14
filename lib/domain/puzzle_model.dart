
// lib/domain/puzzle_model.dart
// Compatible with Flutter 1.22 (no null-safety)

import 'dart:convert';
import 'dart:math';

enum CellKind { number, operator, equals, target }

String _cellKindToString(CellKind k) {
  switch (k) {
    case CellKind.number:
      return 'number';
    case CellKind.operator:
      return 'operator';
    case CellKind.equals:
      return 'equals';
    case CellKind.target:
      return 'target';
  }
  return 'number';
}

CellKind _cellKindFromString(String s) {
  switch (s) {
    case 'operator':
      return CellKind.operator;
    case 'equals':
      return CellKind.equals;
    case 'target':
      return CellKind.target;
    default:
      return CellKind.number;
  }
}

class Coord {
  final int r;
  final int c;
  Coord(this.r, this.c);
  @override
  String toString() => '($r,$c)';
  Map<String, int> toJson() => {'r': r, 'c': c};
  static Coord fromJson(Map<String, dynamic> j) => Coord(j['r'], j['c']);
  @override
  bool operator ==(other) => other is Coord && other.r == r && other.c == c;
  @override
  int get hashCode => r * 31 + c;
}

/// Represents a cell in the board.
/// - number: draggable/placeable numbers (value is int or null)
/// - operator: fixed operator cell, value is '+','-','*','/' (String)
/// - equals: visual '=' placeholder (non-interactive)
/// - target: holds the expected result for the line (value is int)
class Cell {
  final Coord pos;
  final CellKind kind;
  bool fixed; // true for operators & targets & prefilled numbers
  dynamic value; // int for numbers/targets, String for operator
  Cell(this.pos, this.kind, {this.value, this.fixed = false});

  bool get isNumber => kind == CellKind.number;
  bool get isOperator => kind == CellKind.operator;
  bool get isEquals => kind == CellKind.equals;
  bool get isTarget => kind == CellKind.target;

  Cell copy() => Cell(Coord(pos.r, pos.c), kind, value: value, fixed: fixed);

  Map<String, dynamic> toJson() {
    return {
      'pos': pos.toJson(),
      'kind': _cellKindToString(kind),
      'fixed': fixed,
      'value': value
    };
  }

  static Cell fromJson(Map<String, dynamic> j) {
    final pos = Coord.fromJson(j['pos']);
    final kind = _cellKindFromString(j['kind']);
    return Cell(pos, kind, value: j['value'], fixed: j['fixed'] ?? false);
  }

  @override
  String toString() => 'Cell${pos.toString()}: ${_cellKindToString(kind)}=$value'
      ' fixed=$fixed';
}

/// A line (clue) corresponds to an equation (across or down).
/// It contains exactly two operand cell coordinates and one operator cell coord,
/// and a target value stored here for convenience.
class Line {
  final String id;
  final List<Coord> operandCoords; // exactly two coords, left-to-right or top-to-bottom
  final Coord operatorCoord;
  final Coord equalsCoord; // position of '=' cell (for rendering)
  int target;

  Line(this.id, this.operandCoords, this.operatorCoord, this.equalsCoord,
      this.target);

  Map<String, dynamic> toJson() => {
        'id': id,
        'operands': operandCoords.map((c) => c.toJson()).toList(),
        'operator': operatorCoord.toJson(),
        'equals': equalsCoord.toJson(),
        'target': target
      };

  static Line fromJson(Map<String, dynamic> j) {
    List operands = j['operands'];
    return Line(
      j['id'],
      operands.map((x) => Coord.fromJson(x)).toList(),
      Coord.fromJson(j['operator']),
      Coord.fromJson(j['equals']),
      j['target'],
    );
  }

  @override
  String toString() =>
      'Line($id) ${operandCoords[0]} ${operatorCoord} ${operandCoords[1]} = $target';
}

/// Multiset bank of available numeric tiles.
class Bank {
  final Map<int, int> _counts = {};

  Bank();

  Bank.fromList(List<int> items) {
    for (var i in items) _counts[i] = (_counts[i] ?? 0) + 1;
  }

  List<int> toList() {
    final out = <int>[];
    _counts.forEach((k, v) {
      for (var i = 0; i < v; i++) out.add(k);
    });
    return out;
  }
  
  Map<int, int> get counts => Map.unmodifiable(_counts);

  bool contains(int value) => (_counts[value] ?? 0) > 0;
  int count(int value) => _counts[value] ?? 0;

  bool use(int value) {
    if (!contains(value)) return false;
    _counts[value] = _counts[value] - 1;
    if (_counts[value] <= 0) _counts.remove(value);
    return true;
  }

  void put(int value) {
    _counts[value] = (_counts[value] ?? 0) + 1;
  }

  Map<String, dynamic> toJson() {
    return _counts.map((k, v) => MapEntry(k.toString(), v));
  }

  static Bank fromJson(Map<String, dynamic> j) {
    final b = Bank();
    j.forEach((k, v) {
      b._counts[int.parse(k)] = v;
    });
    return b;
  }

  @override
  String toString() => 'Bank(${toList().toString()})';
}

enum Difficulty { easy, medium, hard }

String difficultyToString(Difficulty d) {
  switch (d) {
    case Difficulty.easy:
      return 'easy';
    case Difficulty.medium:
      return 'medium';
    case Difficulty.hard:
      return 'hard';
  }
  return 'easy';
}

Difficulty difficultyFromString(String s) {
  switch (s) {
    case 'medium':
      return Difficulty.medium;
    case 'hard':
      return Difficulty.hard;
    default:
      return Difficulty.easy;
  }
}

class PuzzleMetadata {
  String id;
  String createdAt; // ISO 8601
  String author;
  PuzzleMetadata({this.id, this.createdAt, this.author});

  Map<String, dynamic> toJson() =>
      {'id': id, 'createdAt': createdAt, 'author': author};

  static PuzzleMetadata fromJson(Map<String, dynamic> j) {
    return PuzzleMetadata(id: j['id'], createdAt: j['createdAt'], author: j['author']);
  }
}

/// Represents the whole board and game data.
class Puzzle {
  final int rows;
  final int cols;
  final Map<Coord, Cell> cells = {};
  List<Line> lines = [];
  Bank bank;
  Difficulty difficulty;
  PuzzleMetadata metadata;

  Puzzle(this.rows, this.cols,
      {this.lines, Bank bank, this.difficulty, this.metadata}) {
    this.bank = bank ?? Bank();
    this.lines = lines ?? [];
  }

  void setCell(Cell cell) {
    cells[cell.pos] = cell;
  }

  Cell getCell(int r, int c) {
    final coord = Coord(r, c);
    return cells[coord];
  }

  /// Place a number on a number-cell; returns previous value (int or null).
  dynamic placeNumber(int r, int c, int number, {bool markAsFixed = false}) {
    final coord = Coord(r, c);
    final cell = cells[coord];
    if (cell == null || !cell.isNumber) return null;
    final old = cell.value;
    cell.value = number;
    if (markAsFixed) cell.fixed = true;
    return old;
  }

  /// Clears a number cell and returns previous value.
  dynamic clearNumberCell(int r, int c) {
    final cell = getCell(r, c);
    if (cell == null || !cell.isNumber) return null;
    final old = cell.value;
    if (!cell.fixed) cell.value = null;
    return old;
  }

  List<Cell> getAllCells() => cells.values.toList();

  Map<String, dynamic> toJson() {
    return {
      'rows': rows,
      'cols': cols,
      'cells': cells.values.map((c) => c.toJson()).toList(),
      'lines': lines.map((l) => l.toJson()).toList(),
      'bank': bank.toJson(),
      'difficulty': difficultyToString(difficulty ?? Difficulty.easy),
      'metadata': metadata != null ? metadata.toJson() : null
    };
  }

  static Puzzle fromJson(Map<String, dynamic> j) {
    final p = Puzzle(j['rows'], j['cols'],
        difficulty: difficultyFromString(j['difficulty'] ?? 'easy'),
        metadata:
            j['metadata'] != null ? PuzzleMetadata.fromJson(j['metadata']) : null);
    final cellsJson = j['cells'] as List;
    for (var cj in cellsJson) {
      final cell = Cell.fromJson(cj);
      p.setCell(cell);
    }
    final linesJson = j['lines'] as List;
    p.lines = linesJson.map((l) => Line.fromJson(l)).toList();
    p.bank = j['bank'] != null ? Bank.fromJson(Map<String, dynamic>.from(j['bank'])) : Bank();
    return p;
  }

  Puzzle copy() {
    final p = Puzzle(rows, cols,
        difficulty: difficulty, metadata: metadata == null ? null : PuzzleMetadata(id: metadata.id, createdAt: metadata.createdAt, author: metadata.author));
    cells.forEach((k, v) {
      p.setCell(v.copy());
    });
    p.lines = lines.map((l) => Line.fromJson(l.toJson())).toList();
    p.bank = Bank.fromList(bank.toList());
    return p;
  }

  /// Helper: find line(s) that reference a given coordinate (operand or operator).
  List<Line> linesForCoord(Coord coord) {
    return lines.where((l) {
      if (l.operatorCoord == coord) return true;
      if (l.equalsCoord == coord) return true;
      for (var oc in l.operandCoords) if (oc == coord) return true;
      return false;
    }).toList();
  }

  @override
  String toString() {
    return 'Puzzle ${metadata?.id ?? ''} ${rows}x${cols} lines=${lines.length} bank=${bank.toList().length}';
  }
}

/// Utilities
class PuzzleUtils {
  /// Converts a Puzzle to a compact JSON string
  static String serialize(Puzzle p) => json.encode(p.toJson());

  static Puzzle deserialize(String s) => Puzzle.fromJson(json.decode(s));

  /// Returns a random unused number from bank (or null)
  static int randomFromBank(Bank b, {Random rnd}) {
    final list = b.toList();
    if (list.isEmpty) return null;
    final r = (rnd ?? Random()).nextInt(list.length);
    return list[r];
  }
}