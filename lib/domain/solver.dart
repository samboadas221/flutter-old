
// lib/domain/solver.dart
// Minimal solver based on bank permutation (works if number of empties equals bank size)

import 'puzzle_model.dart';

class Solver {
  /// Return up to maxSolutions solutions (list of Puzzle).
  /// Strategy: attempt permutations of bank values assigned to empty number cells.
  static List<Puzzle> solve(Puzzle p, {int maxSolutions = 1}) {
    final base = p.copy();
    final empties = <Coord>[];
    final cells = base.cells;
    cells.forEach((coord, cell) {
      if (cell.isNumber && cell.value == null && !cell.fixed) empties.add(coord);
    });

    final bankList = base.bank.toList();
    final solutions = <Puzzle>[];
    if (empties.isEmpty) {
      if (MatrixSolver.isSolved(base._m)) solutions.add(base);
      return solutions;
    }

    // Quick guard: if counts don't match empties, still try but use bank values only
    if (bankList.length < empties.length) {
      // cannot solve using only bank numbers; give up
      return solutions;
    }

    // generate unique permutations using recursion with counts
    final counts = <int, int>{};
    for (var v in bankList) counts[v] = (counts[v] ?? 0) + 1;

    void dfs(int idx) {
      if (solutions.length >= maxSolutions) return;
      if (idx == empties.length) {
        // test
        if (MatrixSolver.isSolved(base._m)) {
          solutions.add(base.copy());
        }
        return;
      }
      final coord = empties[idx];
      for (var k in counts.keys.toList()) {
        if (counts[k] == 0) continue;
        // assign
        base._m.grid[coord.r][coord.c].number = k;
        counts[k] = counts[k] - 1;
        dfs(idx + 1);
        if (solutions.length >= maxSolutions) return;
        // undo
        base._m.grid[coord.r][coord.c].number = null;
        counts[k] = counts[k] + 1;
      }
    }

    dfs(0);
    return solutions;
  }

  /// Count solutions up to a limit using same approach.
  static int countSolutions(Puzzle p, {int limit = 2}) {
    final sols = solve(p, maxSolutions: limit);
    return sols.length;
  }
}