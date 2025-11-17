
// lib/domain/generator.dart
// Minimal adapter for Generator

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'matrix_puzzle.dart';
import 'puzzle_model.dart';

class Generator {
  /// Load templates from asset JSON (array of MatrixPuzzle JSON objects).
  static Future<List<Puzzle>> loadTemplatesFromAsset(String assetPath) async {
    try {
      final s = await rootBundle.loadString(assetPath);
      final List items = json.decode(s);
      final out = <Puzzle>[];
      for (var it in items) {
        try {
          final mp = MatrixPuzzle.fromJson(Map<String, dynamic>.from(it));
          out.add(Puzzle.fromMatrix(mp));
        } catch (e) {
          // skip invalid
        }
      }
      return out;
    } catch (e) {
      return <Puzzle>[];
    }
  }

  /// Generate from skeleton: minimal behavior => return a copy of the provided template.
  /// Keeping signature compatible.
  static Puzzle generateFromSkeleton(Puzzle skeleton,
      {Difficulty difficulty, int maxFillAttempts = 1000, bool requireUnique = true, int cluePercent = 40}) {
    // For compatibility we simply return a copy. This can be extended later.
    return skeleton.copy();
  }
}