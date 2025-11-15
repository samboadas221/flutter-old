
// lib/domain/generator.dart
// Compatible with Flutter 1.22 (no null-safety)

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import 'dart:math';
import 'puzzle_model.dart';
import 'rules.dart';
import 'solver.dart';

class Generator {
  static final Random _rnd = Random();

  /// Generate a playable puzzle from a provided *skeleton* Puzzle.
  /// The skeleton must contain:
  ///  - proper cells with CellKind set (number/operator/equals/target positions)
  ///  - Line objects referencing operand/operator/equals coords
  ///
  /// This function fills numbers, computes targets, then hides a subset of numbers
  /// producing a bank (multiset of hidden values). If requireUnique==true the
  /// generator will try different hides until the solver reports uniqueness
  /// (up to some attempts).
  static Puzzle generateFromSkeleton(Puzzle skeleton,
      {Difficulty difficulty,
      int maxFillAttempts = 1000,
      int maxHideAttempts = 300,
      bool requireUnique = true,
      int cluePercent = 40}) {
    difficulty = difficulty ?? skeleton.difficulty ?? Difficulty.easy;
    final maxv = maxForDifficulty(difficulty);

    // Ensure operators exist: if any operator cell empty, assign random op.
    for (var l in skeleton.lines) {
      final opCell = skeleton.cells[l.operatorCoord];
      if (opCell == null || !opCell.isOperator || opCell.value == null) {
        final ops = ['+', '-', '*', '/'];
        final op = ops[_rnd.nextInt(ops.length)];
        if (opCell == null) {
          // Shouldn't happen for well-formed skeleton, but guard:
          skeleton.setCell(Cell(l.operatorCoord, CellKind.operator, value: op, fixed: true));
        } else {
          opCell.value = op;
          opCell.fixed = true;
        }
      }
    }

    final numberCoords = <Coord>[];
    skeleton.cells.forEach((coord, cell) {
      if (cell.isNumber) {
        numberCoords.add(coord);
      }
    });

    if (numberCoords.isEmpty) throw Exception('Skeleton contains no number cells');

    // Attempt to fill all number cells so that every line evaluates validly.
    bool filled = false;
    final filledPuzzle = skeleton.copy();
    for (int attempt = 0; attempt < maxFillAttempts && !filled; attempt++) {
      // assign random values within 0..maxv
      for (var coord in numberCoords) {
        final cell = filledPuzzle.cells[coord];
        final val = _rnd.nextInt(maxv + 1);
        cell.value = val;
        cell.fixed = true; // solution base
      }

      // compute targets and validate each line
      bool ok = true;
      for (var l in filledPuzzle.lines) {
        try {
          final val = evaluateLine(filledPuzzle, l);
          // enforce bounds
          if (!_inBounds(val, difficulty)) {
            ok = false;
            break;
          }
          l.target = val;
        } catch (e) {
          ok = false;
          break;
        }
      }

      if (ok) filled = true;
    }

    if (!filled) throw Exception('Failed to generate valid filled puzzle after attempts');

    // Now we have a full solution in filledPuzzle. Build initial bank from numbers we will hide.
    // Decide which coords to keep as clues (prefilled) based on cluePercent.
    final totalNumbers = numberCoords.length;
    final keepCount = ((cluePercent.clamp(0, 100) / 100.0) * totalNumbers).ceil();
    // generate a list of indices and shuffle
    final indices = List<int>.generate(totalNumbers, (i) => i);
    indices.shuffle(_rnd);

    final keepSet = indices.take(keepCount).toSet();

    // Create puzzle copy for output
    Puzzle outPuzzle = filledPuzzle.copy();

    // Mark all number cells fixed first (they are the solution)
    outPuzzle.cells.forEach((coord, c) {
      if (c.isNumber) c.fixed = true;
    });

    // Hidden values go into bank (counts). We'll hide coords not in keepSet.
    final hiddenValues = <int>[];
    for (int i = 0; i < numberCoords.length; i++) {
      final coord = numberCoords[i];
      final cell = outPuzzle.cells[coord];
      if (!keepSet.contains(i)) {
        hiddenValues.add(cell.value as int);
        // clear the visible value and mark unfixed so player can place
        cell.value = null;
        cell.fixed = false;
      } else {
        // keep as prefilled/clue
        cell.fixed = true;
      }
    }

    // Bank is the multiset of hidden values.
    outPuzzle.bank = Bank.fromList(hiddenValues);
    outPuzzle.difficulty = difficulty;

    // Try to ensure solvability / uniqueness if required
    bool accepted = false;
    for (int hideAttempt = 0; hideAttempt < maxHideAttempts && !accepted; hideAttempt++) {
      // quick solvability check
      final count = Solver.countSolutions(outPuzzle, limit: requireUnique ? 2 : 1);
      if (count >= 1 && (!requireUnique || count == 1)) {
        accepted = true;
        break;
      }
      // If not acceptable, try different hiding selection: reshuffle hides
      indices.shuffle(_rnd);
      final newKeep = indices.take(keepCount).toSet();
      // restore full solution from filledPuzzle, then re-hide
      outPuzzle = filledPuzzle.copy();
      hiddenValues.clear();
      for (int i = 0; i < numberCoords.length; i++) {
        final coord = numberCoords[i];
        final cell = outPuzzle.cells[coord];
        if (!newKeep.contains(i)) {
          hiddenValues.add(cell.value as int);
          cell.value = null;
          cell.fixed = false;
        } else {
          cell.fixed = true;
        }
      }
      outPuzzle.bank = Bank.fromList(hiddenValues);
      outPuzzle.difficulty = difficulty;
    }

    if (!accepted) {
      // fallback: accept solvable but possibly multiple-solution puzzle if at least solvable
      final cnt = Solver.countSolutions(outPuzzle, limit: 1);
      if (cnt == 0) throw Exception('Failed to produce solvable puzzle after hide attempts');
    }

    // set metadata
    outPuzzle.metadata = PuzzleMetadata(id: 'gen-${DateTime.now().millisecondsSinceEpoch}', createdAt: DateTime.now().toIso8601String(), author: 'generator');
    // ensure line targets are set (they were set in filledPuzzle)
    for (var l in outPuzzle.lines) {
      // already present
    }

    return outPuzzle;
  }
  
  
  /// Carga un array de plantillas desde un asset JSON (lista de Puzzle JSONs).
  static Future<List<Puzzle>> loadTemplatesFromAsset(String assetPath) async {
    try {
      final s = await rootBundle.loadString(assetPath);
      final List items = json.decode(s);
      final List<Puzzle> out = [];
      for (var it in items) {
        try {
          final p = Puzzle.fromJson(Map<String, dynamic>.from(it));
          out.add(p);
        } catch (e) {
          // skip invalid template
        }
      }
      return out;
    } catch (e) {
      return <Puzzle>[];
    }
  }
  
}