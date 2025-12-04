
import 'dart:math';

enum Orientation { horizontal, vertical }

/// Representa una ecuación en 5 tokens: [A, op, B, '=', C]
class Equation {
  final List<String> tokens; // length = 5
  final int row; // fila del token 0 (top-left)
  final int col; // col del token 0 (top-left)
  final Orientation orientation;

  Equation(this.tokens, this.row, this.col, this.orientation) {
    if (tokens.length != 5) throw ArgumentError('tokens debe tener longitud 5');
  }

  List<Point<int>> cells() {
    final out = <Point<int>>[];
    for (int i = 0; i < 5; i++) {
      if (orientation == Orientation.horizontal) {
        out.add(Point(row, col + i));
      } else {
        out.add(Point(row + i, col));
      }
    }
    return out;
  }

  Point<int> coordAtIndex(int i) {
    if (orientation == Orientation.horizontal) {
      return Point(row, col + i);
    } else {
      return Point(row + i, col);
    }
  }

  String tokenAtIndex(int i) => tokens[i];

  /// índices numéricos: 0(A),2(B),4(C)
  List<int> numericIndices() => [0, 2, 4];
}
