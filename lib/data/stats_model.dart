
// lib/data/stats_model.dart
import 'dart:convert';

class StatsModel {
  String lastPlayed;
  int timePlayedSeconds;
  Map<String,int> solvedPerDifficulty = {};
  Map<String,int> bestTimes = {};

  StatsModel();

  static StatsModel decode(String s) {
    try {
      final Map j = json.decode(s);
      final out = StatsModel();
      out.lastPlayed = j['lastPlayed'];
      out.timePlayedSeconds = j['timePlayedSeconds'] ?? 0;
      final solved = Map<String,int>.from(j['solvedPerDifficulty'] ?? {});
      out.solvedPerDifficulty = solved;
      final best = Map<String,int>.from(j['bestTimes'] ?? {});
      out.bestTimes = best;
      return out;
    } catch (e) {
      return StatsModel();
    }
  }

  String encode() {
    final j = {
      'lastPlayed': lastPlayed,
      'timePlayedSeconds': timePlayedSeconds,
      'solvedPerDifficulty': solvedPerDifficulty,
      'bestTimes': bestTimes
    };
    return json.encode(j);
  }
}