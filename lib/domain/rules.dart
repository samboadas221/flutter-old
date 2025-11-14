
// lib/domain/rules.dart
// Compatible with Flutter 1.22 (no null-safety)

import 'dart:core';
import 'puzzle_model.dart';

/// Limits per difficulty (max allowed result / operand)
const Map<Difficulty, int> _difficultyMax = {
  Difficulty.easy: 30,
  Difficulty.medium: 60,
  Difficulty.hard: 100
};

/// Supported operator symbols
const List<String> _ops = const ['+', '-', '*', '/'];

/// Evaluate a single binary operation. Throws FormatException on invalid op
/// or Integer division not exact.
int evalOp(int a, String op, int b) {
  if (!_ops.contains(op)) throw FormatException('Invalid operator: $op');
  if (op == '+') return a + b;
  if (op == '-') return a - b;
  if (op == '*') return a * b;
  if (op == '/') {
    if (b == 0) throw FormatException('Division by zero');
    if (a % b != 0) throw FormatException('Non-integer division');
    return a ~/ b;
  }
  throw FormatException('Unknown operator');
}

/// Returns maximum allowed number for a difficulty.
int maxForDifficulty(Difficulty d) => _difficultyMax[d];

/// Checks whether a value is within allowed bounds for difficulty.
/// Accepts negative results only if allowNegative is true (default false).
bool _inBounds(int value, Difficulty difficulty, {bool allowNegative = false}) {
  if (!allowNegative && value < 0) return false;
  final maxv = maxForDifficulty(difficulty);
  if (value > maxv) return false;
  return true;
}

/// Checks if a line has both operands present (i.e., placeable numbers).
bool isLineComplete(Puzzle puzzle, Line line) {
  for (var coord in line.operandCoords) {
    final cell = puzzle.cells[coord];
    if (cell == null) return false;
    if (!cell.isNumber) return false;
    if (cell.value == null) return false;
  }
  return true;
}

/// Safely read operator string from operator cell; returns null if not present
String operatorForLine(Puzzle puzzle, Line line) {
  final opCell = puzzle.cells[line.operatorCoord];
  if (opCell == null) return null;
  if (!opCell.isOperator) return null;
  return opCell.value;
}

/// Evaluate a line using puzzle cell values. Throws FormatException on invalid.
int evaluateLine(Puzzle puzzle, Line line) {
  if (!isLineComplete(puzzle, line)) throw FormatException('Line incomplete');
  final aCell = puzzle.cells[line.operandCoords[0]];
  final bCell = puzzle.cells[line.operandCoords[1]];
  final op = operatorForLine(puzzle, line);
  if (op == null) throw FormatException('Operator missing');
  final a = aCell.value as int;
  final b = bCell.value as int;
  return evalOp(a, op, b);
}

/// Returns true if the given line currently matches its target (and is complete).
bool checkLineCorrect(Puzzle puzzle, Line line) {
  try {
    final val = evaluateLine(puzzle, line);
    return val == line.target;
  } catch (e) {
    return false;
  }
}

/// Validate all lines; returns Map from line.id to bool correctness.
Map<String, bool> validateAllLines(Puzzle puzzle) {
  final Map<String, bool> out = {};
  for (var l in puzzle.lines) {
    out[l.id] = checkLineCorrect(puzzle, l);
  }
  return out;
}

/// Returns true if entire puzzle is solved (all lines correct and complete).
bool isPuzzleSolved(Puzzle puzzle) {
  for (var l in puzzle.lines) {
    if (!checkLineCorrect(puzzle, l)) return false;
  }
  return true;
}

/// Checks if a proposed operation (a op b) is valid under difficulty rules
/// (division exactness, bound checks). Returns true if allowed.
bool isOperationValidForDifficulty(int a, String op, int b, Difficulty difficulty) {
  try {
    final res = evalOp(a, op, b);
    if (!_inBounds(res, difficulty)) return false;
    // Also ensure operands themselves are within bounds (non-negative & <= max)
    if (!_inBounds(a, difficulty) || !_inBounds(b, difficulty)) return false;
    return true;
  } catch (e) {
    return false;
  }
}

/// Checks if placing `number` at coordinate `coord` is allowed w.r.t. immediate
/// line constraints (won't produce an impossible immediate contradiction).
/// This is a light-weight check (it does not solve the whole puzzle).
bool canPlaceNumber(Puzzle puzzle, Coord coord, int number) {
  final lines = puzzle.linesForCoord(coord);
  final difficulty = puzzle.difficulty ?? Difficulty.easy;
  for (var line in lines) {
    // Only consider lines where operator exists and target exists.
    final op = operatorForLine(puzzle, line);
    if (op == null) continue;
    final target = line.target;
    // Determine other operand value if present
    Coord otherCoord;
    if (line.operandCoords[0] == coord)
      otherCoord = line.operandCoords[1];
    else if (line.operandCoords[1] == coord) otherCoord = line.operandCoords[0];
    else otherCoord = null;

    final otherCell = otherCoord != null ? puzzle.cells[otherCoord] : null;
    final otherVal = otherCell != null ? otherCell.value : null;

    // If other operand is filled -> result must equal target (exact check)
    if (otherVal != null) {
      // compute op between number and otherVal (order matters: left-to-right/top-to-bottom)
      int a, b;
      if (line.operandCoords[0] == coord) {
        a = number;
        b = otherVal as int;
      } else {
        a = otherVal as int;
        b = number;
      }
      // Validate operation (division exactness & bounds & equal target)
      try {
        final res = evalOp(a, op, b);
        if (res != target) return false;
        if (!_inBounds(res, difficulty)) return false;
      } catch (e) {
        return false;
      }
    } else {
      // other operand empty -> check possibility: is there any value (from 0..max)
      // that combined with `number` can produce target under op and difficulty.
      final maxv = maxForDifficulty(difficulty);
      bool possible = false;
      for (int candidate = 0; candidate <= maxv; candidate++) {
        int a, b;
        if (line.operandCoords[0] == coord) {
          a = number;
          b = candidate;
        } else {
          a = candidate;
          b = number;
        }
        try {
          final res = evalOp(a, op, b);
          if (res == target && _inBounds(res, difficulty)) {
            possible = true;
            break;
          }
        } catch (e) {
          // skip invalid candidate
        }
      }
      if (!possible) return false;
    }
  }
  return true;
}