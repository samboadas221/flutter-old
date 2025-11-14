
// lib/data/json_formats.dart
// Compatible with Flutter 1.22 (no null-safety)

import 'dart:convert';
import '../domain/puzzle_model.dart';

class StatsModel {
  int timePlayedSeconds;
  Map<String, int> solvedPerDifficulty; // keys: 'easy','medium','hard'
  Map<String, int> bestTimes; // best time per difficulty (seconds)
  int hintsUsed;
  String lastPlayed; // ISO8601

  StatsModel({
    this.timePlayedSeconds = 0,
    Map<String, int> solvedPerDifficulty,
    Map<String, int> bestTimes,
    this.hintsUsed = 0,
    this.lastPlayed,
  }) {
    this.solvedPerDifficulty = solvedPerDifficulty ??
        {'easy': 0, 'medium': 0, 'hard': 0};
    this.bestTimes = bestTimes ?? {'easy': 0, 'medium': 0, 'hard': 0};
  }

  Map<String, dynamic> toJson() => {
        'timePlayedSeconds': timePlayedSeconds,
        'solvedPerDifficulty': solvedPerDifficulty,
        'bestTimes': bestTimes,
        'hintsUsed': hintsUsed,
        'lastPlayed': lastPlayed
      };

  static StatsModel fromJson(Map<String, dynamic> j) {
    if (j == null) return StatsModel();
    return StatsModel(
      timePlayedSeconds: j['timePlayedSeconds'] ?? 0,
      solvedPerDifficulty:
          Map<String, int>.from(j['solvedPerDifficulty'] ?? {'easy': 0, 'medium': 0, 'hard': 0}),
      bestTimes: Map<String, int>.from(j['bestTimes'] ?? {'easy': 0, 'medium': 0, 'hard': 0}),
      hintsUsed: j['hintsUsed'] ?? 0,
      lastPlayed: j['lastPlayed'],
    );
  }

  String encode() => json.encode(toJson());
  static StatsModel decode(String s) {
    if (s == null || s.isEmpty) return StatsModel();
    return fromJson(json.decode(s));
  }
}

/// Helpers for Puzzle <-> JSON string using Puzzle.toJson/fromJson
String puzzleToJsonString(Puzzle p) {
  return json.encode(p.toJson());
}

Puzzle puzzleFromJsonString(String s) {
  if (s == null || s.isEmpty) return null;
  try {
    final Map<String, dynamic> j = json.decode(s);
    return Puzzle.fromJson(j);
  } catch (e) {
    return null;
  }
}

/// Basic structural validation of puzzle JSON map.
/// Returns null if valid, otherwise a short error string.
String validatePuzzleJsonMap(Map<String, dynamic> j) {
  if (j == null) return 'Null JSON';
  if (!j.containsKey('rows') || !j.containsKey('cols')) return 'Missing rows/cols';
  if (!j.containsKey('cells') || !(j['cells'] is List)) return 'Missing cells array';
  if (!j.containsKey('lines') || !(j['lines'] is List)) return 'Missing lines array';
  // quick cell sanity
  final cells = j['cells'] as List;
  for (var cj in cells) {
    if (cj is Map) {
      if (!cj.containsKey('pos') || !cj.containsKey('kind')) return 'Invalid cell entry';
    } else {
      return 'Cell entry not object';
    }
  }
  return null;
}

/// Validate and parse puzzle JSON string. Returns Puzzle or throws FormatException.
Puzzle parseValidatedPuzzleJsonString(String s) {
  if (s == null || s.isEmpty) throw FormatException('Empty JSON');
  final Map<String, dynamic> j = json.decode(s);
  final String err = validatePuzzleJsonMap(j);
  if (err != null) throw FormatException(err);
  final Puzzle p = Puzzle.fromJson(j);
  return p;
}