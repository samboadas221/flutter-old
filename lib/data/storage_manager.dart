
/*
// lib/data/storage_manager.dart
// Compatible with Flutter 1.22 (no null-safety)

import 'dart:io';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'json_formats.dart';
import '../domain/puzzle_model.dart';

class StorageManager {
  // Keys for SharedPreferences
  static const String _kStatsKey = 'cm_stats_v1';
  static const String _kLastPuzzleKey = 'cm_last_puzzle_v1';

  // Directory and file naming for saved puzzles/templates
  static const String _puzzlesDirName = 'crossmath_puzzles';
  static const String _puzzleFilePrefix = 'puzzle_'; // puzzle_<id>.json

  // ----------------- Stats -----------------
  static Future<StatsModel> loadStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_kStatsKey);
      if (s == null || s.isEmpty) return StatsModel();
      return StatsModel.decode(s);
    } catch (e) {
      return StatsModel();
    }
  }

  static Future<bool> saveStats(StatsModel stats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_kStatsKey, stats.encode());
    } catch (e) {
      return false;
    }
  }

  // ----------------- Last progress (single slot) -----------------
  static Future<bool> saveLastPuzzle(Puzzle p) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = puzzleToJsonString(p);
      return await prefs.setString(_kLastPuzzleKey, s);
    } catch (e) {
      return false;
    }
  }

  static Future<Puzzle> loadLastPuzzle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_kLastPuzzleKey);
      if (s == null || s.isEmpty) return null;
      return puzzleFromJsonString(s);
    } catch (e) {
      return null;
    }
  }

  static Future<bool> clearLastPuzzle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_kLastPuzzleKey);
    } catch (e) {
      return false;
    }
  }

  // ----------------- File storage for puzzles/templates -----------------
  static Future<Directory> _ensurePuzzlesDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_puzzlesDirName');
    if (!(await dir.exists())) await dir.create(recursive: true);
    return dir;
  }

  static String _puzzleFilenameForId(String id) => '$_puzzleFilePrefix$id.json';

  static Future<bool> savePuzzleToFile(Puzzle p) async {
    try {
      final dir = await _ensurePuzzlesDir();
      final fname = _puzzleFilenameForId(p.metadata?.id ?? DateTime.now().millisecondsSinceEpoch.toString());
      final file = File('${dir.path}/$fname');
      await file.writeAsString(puzzleToJsonString(p), flush: true);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<Puzzle> loadPuzzleFromFileById(String id) async {
    try {
      final dir = await _ensurePuzzlesDir();
      final file = File('${dir.path}/${_puzzleFilenameForId(id)}');
      if (!(await file.exists())) return null;
      final s = await file.readAsString();
      return puzzleFromJsonString(s);
    } catch (e) {
      return null;
    }
  }

  static Future<List<Puzzle>> listAllSavedPuzzles() async {
    try {
      final dir = await _ensurePuzzlesDir();
      final files = dir.listSync().whereType<File>().toList();
      final out = <Puzzle>[];
      for (final f in files) {
        try {
          final s = await f.readAsString();
          final p = puzzleFromJsonString(s);
          if (p != null) out.add(p);
        } catch (e) {
          // skip corrupt
        }
      }
      return out;
    } catch (e) {
      return <Puzzle>[];
    }
  }

  static Future<bool> deletePuzzleById(String id) async {
    try {
      final dir = await _ensurePuzzlesDir();
      final file = File('${dir.path}/${_puzzleFilenameForId(id)}');
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // ----------------- Utilities -----------------
  // Export a puzzle JSON string for sharing/export
  static Future<String> exportPuzzleToJson(Puzzle p) async {
    return puzzleToJsonString(p);
  }

  // Import puzzle from JSON string and save to local file (returns saved Puzzle or null)
  static Future<Puzzle> importPuzzleFromJson(String jsonString) async {
    try {
      final p = parseValidatedPuzzleJsonString(jsonString);
      if (p == null) return null;
      // ensure metadata id exists
      if (p.metadata == null || p.metadata.id == null) {
        p.metadata = PuzzleMetadata(id: 'imp-${DateTime.now().millisecondsSinceEpoch}', createdAt: DateTime.now().toIso8601String(), author: 'import');
      }
      final ok = await savePuzzleToFile(p);
      return ok ? p : null;
    } catch (e) {
      return null;
    }
  }
}

*/