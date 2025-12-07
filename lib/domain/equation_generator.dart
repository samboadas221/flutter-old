
import 'dart:math';
import 'equation.dart';
import 'board.dart';

/// Generador de ecuaciones que puede fijar cualquier índice numérico (0,2 o 4) a un valor dado.
class EquationGenerator {
  final Random rng;
  EquationGenerator(this.rng);

  /// Genera una ecuación que tiene en tokenIndex (0/2/4) el valor fixedVal.
  /// Devuelve null si no consigue una ecuación válida en upToAttempts.
  Equation generateWithFixedIndex(
      int fixedIndex, int fixedVal, Orientation orientation, Point<int> alignmentCoord,
      {int upToAttempts = CHILD_GEN_ATTEMPTS}) {
    // fixedIndex ∈ {0,2,4}
    for (int attempt = 0; attempt < upToAttempts; attempt++) {
      final ops = ['+', '-', '*', '/'];
      final op = ops[rng.nextInt(ops.length)];

      int A = 0, B = 0, C = 0;
      bool ok = false;

      if (fixedIndex == 0) {
        // A = fixedVal. Encontrar B y op tal que A op B = C dentro de rangos y sin decimales.
        A = fixedVal;
        if (op == '+') {
          B = rng.nextInt(MAX_NUM - MIN_NUM + 1) + MIN_NUM;
          C = A + B;
          ok = C >= MIN_NUM && C <= MAX_NUM;
        } else if (op == '-') {
          // A - B = C => B = A - C, C must be >=0
          C = rng.nextInt(A - MIN_NUM + 1); // C in [0..A]
          B = A - C;
          ok = B >= MIN_NUM && B <= MAX_NUM;
        } else if (op == '*') {
          if (A == 0) {
            B = rng.nextInt(MAX_NUM - MIN_NUM + 1) + MIN_NUM;
            C = 0;
            ok = true;
          } else {
            int maxB = (MAX_NUM ~/ A);
            if (maxB >= MIN_NUM) {
              B = rng.nextInt(maxB - MIN_NUM + 1) + MIN_NUM;
              C = A * B;
              ok = C >= MIN_NUM && C <= MAX_NUM;
            } else {
              ok = false;
            }
          }
        } else if (op == '/') {
          // A / B = C -> B != 0 and C integer -> choose C then B = A / C if divisible
          if (A == 0) {
            // 0 / B = 0 valid for any B != 0; choose B random nonzero
            B = rng.nextInt(MAX_NUM - MIN_NUM + 1) + MIN_NUM;
            if (B == 0) continue;
            C = 0;
            ok = true;
          } else {
            // choose B such that A % B == 0 and result within range
            // Try random B attempts
            int tries = 0;
            while (tries < 30) {
              int candidateB = rng.nextInt(MAX_NUM - MIN_NUM + 1) + MIN_NUM;
              if (candidateB == 0) {
                tries++;
                continue;
              }
              if (A % candidateB == 0) {
                B = candidateB;
                C = A ~/ B;
                if (C >= MIN_NUM && C <= MAX_NUM) {
                  ok = true;
                  break;
                }
              }
              tries++;
            }
          }
        }
      } else if (fixedIndex == 2) {
        // B = fixedVal (caso central)
        B = fixedVal;
        if (op == '+') {
          A = rng.nextInt(MAX_NUM - MIN_NUM + 1) + MIN_NUM;
          C = A + B;
          ok = C >= MIN_NUM && C <= MAX_NUM;
        } else if (op == '-') {
          // A - B = C ; need A >= B
          A = rng.nextInt(MAX_NUM - MIN_NUM + 1) + MIN_NUM;
          if (A < B) continue;
          C = A - B;
          ok = C >= MIN_NUM && C <= MAX_NUM;
        } else if (op == '*') {
          if (B == 0) {
            A = rng.nextInt(MAX_NUM - MIN_NUM + 1) + MIN_NUM;
            C = 0;
            ok = true;
          } else {
            int maxA = (MAX_NUM ~/ B);
            if (maxA >= MIN_NUM) {
              A = rng.nextInt(maxA - MIN_NUM + 1) + MIN_NUM;
              C = A * B;
              ok = C >= MIN_NUM && C <= MAX_NUM;
            } else {
              ok = false;
            }
          }
        } else if (op == '/') {
          // A / B = C -> B != 0
          if (B == 0) {
            ok = false;
          } else {
            C = rng.nextInt(MAX_NUM - MIN_NUM + 1) + MIN_NUM;
            A = C * B;
            if (A >= MIN_NUM && A <= MAX_NUM) ok = true;
          }
        }
      } else if (fixedIndex == 4) {
        // C = fixedVal
        C = fixedVal;
        if (op == '+') {
          // A + B = C -> choose A in [0..C], B = C - A
          A = rng.nextInt(C - MIN_NUM + 1) + MIN_NUM;
          B = C - A;
          ok = A >= MIN_NUM && B >= MIN_NUM && A <= MAX_NUM && B <= MAX_NUM;
        } else if (op == '-') {
          // A - B = C -> A = C + B ; choose B
          B = rng.nextInt(MAX_NUM - MIN_NUM + 1) + MIN_NUM;
          A = C + B;
          ok = A >= MIN_NUM && A <= MAX_NUM;
        } else if (op == '*') {
          // A * B = C -> find factor pairs of C within range
          if (C == 0) {
            // choose any A, B such that A*B=0 => at least one is 0
            A = 0;
            B = rng.nextInt(MAX_NUM - MIN_NUM + 1) + MIN_NUM;
            ok = true;
          } else {
            // find random divisor
            int tries = 0;
            while (tries < 50) {
              int candidateA = rng.nextInt(MAX_NUM - MIN_NUM + 1) + MIN_NUM;
              if (candidateA == 0) {
                tries++;
                continue;
              }
              if (C % candidateA == 0) {
                int candidateB = C ~/ candidateA;
                if (candidateB >= MIN_NUM && candidateB <= MAX_NUM) {
                  A = candidateA;
                  B = candidateB;
                  ok = true;
                  break;
                }
              }
              tries++;
            }
          }
        } else if (op == '/') {
          // A / B = C -> A = B * C ; choose B such that A in range and B != 0
          int tries = 0;
          while (tries < 50) {
            int candidateB = rng.nextInt(MAX_NUM - MIN_NUM + 1) + MIN_NUM;
            if (candidateB == 0) {
              tries++;
              continue;
            }
            int candidateA = candidateB * C;
            if (candidateA >= MIN_NUM && candidateA <= MAX_NUM) {
              A = candidateA;
              B = candidateB;
              ok = true;
              break;
            }
            tries++;
          }
        }
      }

      if (!ok) continue;

      // Validación final de rangos
      if (A < MIN_NUM || A > MAX_NUM) continue;
      if (B < MIN_NUM || B > MAX_NUM) continue;
      if (C < MIN_NUM || C > MAX_NUM) continue;

      final tokens = [A.toString(), op, B.toString(), '=', C.toString()];

      // compute top-left start based on alignmentCoord and fixedIndex
      // alignmentCoord is la coordenada donde debe quedar el índice fixedIndex del child
      int startRow, startCol;
      if (orientation == Orientation.horizontal) {
        startRow = alignmentCoord.x;
        startCol = alignmentCoord.y - fixedIndex;
      } else {
        startRow = alignmentCoord.x - fixedIndex;
        startCol = alignmentCoord.y;
      }

      final eq = Equation(tokens, startRow, startCol, orientation);

      // Quick bounds check for eq cells
      bool fits = true;
      for (var p in eq.cells()) {
        if (p.x < 0 || p.x >= ROWS || p.y < 0 || p.y >= COLS) {
          fits = false;
          break;
        }
      }
      if (!fits) continue;

      return eq;
    }
    return null;
  }
}
