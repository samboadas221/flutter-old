
// lib/domain/solver.dart
// Compatible with Flutter 1.22 (no null-safety)

import 'dart:collection';
import 'dart:math';

import 'puzzle_model.dart';
import 'rules.dart';

/// Simple backtracking solver for the puzzle model.
/// - Respects fixed cells (cell.fixed == true).
/// - Uses puzzle.bank if present: consumes tiles from bank while searching.
/// - If bank is empty, explores candidate values from 0..maxForDifficulty.
/// - Prunes using canPlaceNumber() and checkLineCorrect() for complete lines.
///
/// Public API:
///  - Solver.solve(puzzle, maxSolutions: 2) -> List<Puzzle>  (returns up to maxSolutions distinct solutions)
///  - Solver.countSolutions(puzzle, limit: 2) -> int
///  - Solver.isUnique(puzzle) -> bool
class Solver {
  /// Find up to [maxSolutions] complete solutions for the given puzzle.
  /// Returns a list of Puzzle copies with filled number cells.
  static List<Puzzle> solve(Puzzle inputPuzzle, {int maxSolutions = 2}) {
    final Puzzle puzzle = inputPuzzle.copy();
    final List<Puzzle> solutions = <Puzzle>[];
    final toFill = _collectEmptyNumberCoords(puzzle);
    // Prepare initial bank (clone)
    final Map<int, int> bankCounts = Map<int, int>.from(puzzle.bank._counts);

    void backtrack(int idx) {
      if (solutions.length >= maxSolutions) return;
      if (idx >= toFill.length) {
        // all placed -> verify all lines correct
        if (isCompleteAndValid(puzzle)) {
          solutions.add(puzzle.copy());
        }
        return;
      }
      final Coord coord = toFill[idx];

      // Candidate generator: if bank has items, use its unique keys; else full range
      final difficulty = puzzle.difficulty ?? Difficulty.easy;
      final maxv = maxForDifficulty(difficulty);

      final Iterable<int> candidates = bankCounts.isNotEmpty
          ? bankCounts.keys.where((k) => bankCounts[k] > 0)
          : List<int>.generate(maxv + 1, (i) => i);

      for (final v in candidates) {
        if (bankCounts.isNotEmpty && (bankCounts[v] ?? 0) <= 0) continue;

        // Quick prune: canPlaceNumber checks immediate line feasibility
        if (!canPlaceNumber(puzzle, coord, v)) continue;

        // apply
        final prev = puzzle.cells[coord].value;
        puzzle.cells[coord].value = v;
        if (bankCounts.isNotEmpty) bankCounts[v] = bankCounts[v] - 1;

        // Additional prune: if any line that became complete is incorrect, reject
        bool anyBad = false;
        for (final l in puzzle.linesForCoord(coord)) {
          if (isLineComplete(puzzle, l)) {
            if (!checkLineCorrect(puzzle, l)) {
              anyBad = true;
              break;
            }
          }
        }

        if (!anyBad) {
          backtrack(idx + 1);
        }

        // undo
        puzzle.cells[coord].value = prev;
        if (bankCounts.isNotEmpty) {
          bankCounts[v] = (bankCounts[v] ?? 0) + 1;
          if (bankCounts[v] == 0) bankCounts.remove(v);
        }
        if (solutions.length >= maxSolutions) return;
      }
    }

    backtrack(0);
    return solutions;
  }

  /// Returns the number of solutions up to [limit]. Stops early when limit reached.
  static int countSolutions(Puzzle puzzle, {int limit = 2}) {
    final sols = solve(puzzle, maxSolutions: limit);
    return sols.length;
  }

  /// True if puzzle has exactly one solution (practical check using solver limit).
  static bool isUnique(Puzzle puzzle) => countSolutions(puzzle, limit: 2) == 1;

  /// Helper: collects coords of number-cells that are not fixed and not already filled.
  static List<Coord> _collectEmptyNumberCoords(Puzzle puzzle) {
    final out = <Coord>[];
    puzzle.cells.forEach((coord, cell) {
      if (cell.isNumber && !cell.fixed) {
        // include both empty and prefilled non-fixed? we only need those that must be assigned
        if (cell.value == null) out.add(coord);
      }
    });
    // Keep deterministic order (by row then col)
    out.sort((a, b) {
      if (a.r != b.r) return a.r - b.r;
      return a.c - b.c;
    });
    return out;
  }

  /// Quick check whether all lines are complete and correct.
  static bool isCompleteAndValid(Puzzle puzzle) {
    for (final l in puzzle.lines) {
      if (!isLineComplete(puzzle, l)) return false;
      if (!checkLineCorrect(puzzle, l)) return false;
    }
    return true;
  }
}