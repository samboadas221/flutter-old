
// lib/data/json_formats.dart
import '../domain/matrix_puzzle.dart';
import '../domain/puzzle_model.dart';

String puzzleToJsonString(Puzzle p) {
  return p._m.encode();
}

Puzzle puzzleFromJsonString(String s) {
  final mp = MatrixPuzzle.decode(s);
  return Puzzle.fromMatrix(mp);
}