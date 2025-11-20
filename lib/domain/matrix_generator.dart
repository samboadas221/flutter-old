
// lib/domain/matrix_generator.dart
// Generador de puzzles CrossMath basado en la descripción del usuario - 20 Nov 2025
// Implementación exacta del algoritmo proporcionado

import 'dart:math';
import 'matrix_puzzle.dart';
import 'cell.dart';

class MatrixGenerator {
  static final Random _rnd = Random();

  static MatrixPuzzle generate({
    String difficulty = 'easy',
    int cluePercent = 40,
  }) {
    // Paso 1: Crear tablero y definir valores máximos
    int minSize, maxSize, maxVal;
    if (difficulty == 'easy') {
      minSize = 9;
      maxSize = 12;
      maxVal = 30;
    } else if (difficulty == 'medium') {
      minSize = 11;
      maxSize = 15;
      maxVal = 60;
    } else {
      minSize = 16;
      maxSize = 20;
      maxVal = 100;
    }

    final int size = minSize + _rnd.nextInt(maxSize - minSize + 1);
    final puzzle = MatrixPuzzle(size, size, difficulty: difficulty);

    // Inicializar grid vacío
    for (int row = 0; row < size; row++) {
      for (int col = 0; col < size; col++) {
        puzzle.grid[row][col] = Cell.empty();
      }
    }

    // Paso 2: Generar y colocar la primera ecuación
    final bool firstHorizontal = _rnd.nextBool();
    final int maxStart = size - 5;
    int startR = _rnd.nextInt(maxStart + 1);
    int startC = _rnd.nextInt(maxStart + 1);
    final List equationData = _generateEquation(maxVal, difficulty);
    if (equationData == null) {
      // Fallback simple si falla (raro)
      return puzzle; // vacío, pero para no crashear
    }
    _placeEquation(puzzle, firstHorizontal, startR, startC, equationData);

    // Lista de ecuaciones actuales para expandir
    List<_Equation> equations = [_Equation(firstHorizontal, startR, startC, equationData)];

    // Paso 3: Expandir recursivamente
    int index = 0;
    while (index < equations.length) {
      _tryExpandEquation(puzzle, equations, equations[index], maxVal, difficulty, size);
      index++;
    }

    // Paso 4: Rellenar el banco
    _fillBank(puzzle, equations, cluePercent);

    // Paso 5: Comprobaciones finales
    if (!_finalChecks(puzzle, equations, size)) {
      // Si falla, regenerar (pero para simplicidad, retornamos como está - se puede loop si se quiere)
      return generate(difficulty: difficulty, cluePercent: cluePercent);
    }

    return puzzle;
  }

  // Genera datos de ecuación [A, op, B, C]
  static List _generateEquation(int maxVal, String difficulty) {
    final List<String> ops = ['+', '-', '*', '/'];
    String op = ops[_rnd.nextInt(ops.length)];

    int A, B, C;
    for (int trial = 0; trial < 50; trial++) {
      A = 1 + _rnd.nextInt(maxVal);
      B = 1 + _rnd.nextInt(maxVal);
      if (op == '+') C = A + B;
      else if (op == '-') {
        C = A - B;
        if (C < 1) continue;
      } else if (op == '*') C = A * B;
      else {
        if (B == 0 || A % B != 0) continue;
        C = A ~/ B;
      }
      if (C >= 1 && C <= maxVal) return [A, op, B, C];
    }
    return null;
  }

  // Coloca la ecuación en el grid
  static void _placeEquation(MatrixPuzzle p, bool horizontal, int r, int c, List data) {
    final int A = data[0];
    final String op = data[1];
    final int B = data[2];
    final int C = data[3];

    if (horizontal) {
      p.grid[r][c] = Cell.number(A, fixed: false);
      p.grid[r][c + 1] = Cell.operator(op);
      p.grid[r][c + 2] = Cell.number(B, fixed: false);
      p.grid[r][c + 3] = Cell.equals();
      p.grid[r][c + 4] = Cell.result(C, fixed: false);
    } else {
      p.grid[r][c] = Cell.number(A, fixed: false);
      p.grid[r + 1][c] = Cell.operator(op);
      p.grid[r + 2][c] = Cell.number(B, fixed: false);
      p.grid[r + 3][c] = Cell.equals();
      p.grid[r + 4][c] = Cell.result(C, fixed: false);
    }
  }
  
  
  // Intenta expandir una ecuación generando 2 nuevas inversas
  static void _tryExpandEquation(MatrixPuzzle p, List<_Equation> equations, _Equation current, int maxVal, String difficulty, int size) {
    final bool newHorizontal = !current.horizontal;

    // Direcciones: izquierda/arriba = 0, derecha/abajo = 1
    for (int dir = 0; dir < 2; dir++) {
      for (int attempt = 0; attempt < 5; attempt++) {
        // Seleccionar casilla aleatoria de la ecuación actual (pos 0-4)
        final int basePos = _rnd.nextInt(5);

        final int baseR = current.horizontal ? current.row : current.row + basePos;
        final int baseC = current.horizontal ? current.col + basePos : current.col;

        // Elegir posición en la NUEVA ecuación donde se cruzará (0-4)
        final int crossPos = _rnd.nextInt(5);

        // Calcular start de nueva para cruzar en base (depende de dirección)
        int newR, newC;
        if (newHorizontal) {
          newR = baseR;
          newC = dir == 0 ? baseC - crossPos : baseC + (4 - crossPos); // izquierda o derecha
        } else {
          newR = dir == 0 ? baseR - crossPos : baseR + (4 - crossPos);
          newC = baseC;
        }

        // Verificar límites
        if (newR < 0 || newR + (newHorizontal ? 0 : 4) >= size || newC < 0 || newC + (newHorizontal ? 4 : 0) >= size) continue;

        // Verificar colisiones (ninguna celda ocupada, excepto el cruce en base)
        bool collision = false;
        for (int i = 0; i < 5; i++) {
          int cr = newHorizontal ? newR : newR + i;
          int cc = newHorizontal ? newC + i : newC;
          if (cr == baseR && cc == baseC) continue; // permitir el cruce
          if (p.grid[cr][cc].type != CellType.empty) {
            collision = true;
            break;
          }
        }
        if (collision) continue;

        // Generar nueva ecuación
        final List newData = _generateEquation(maxVal, difficulty);
        if (newData == null) continue;

        // Colocar
        _placeEquation(p, newHorizontal, newR, newC, newData);

        // Añadir a lista
        equations.add(_Equation(newHorizontal, newR, newC, newData));
        break; // Éxito en esta dirección
      }
    }
  }

  // Paso 4: Rellenar banco
  static void _fillBank(MatrixPuzzle p, List<_Equation> equations, int cluePercent) {
    p.bankCounts = {};
    for (final eq in equations) {
      final int numToHide = 1 + _rnd.nextInt(2); // 1 o 2
      final List<Coord> nums = eq.horizontal
          ? [Coord(eq.row, eq.col), Coord(eq.row, eq.col + 2), Coord(eq.row, eq.col + 4)]
          : [Coord(eq.row, eq.col), Coord(eq.row + 2, eq.col), Coord(eq.row + 4, eq.col)];

      nums.shuffle(_rnd);
      int hidden = 0;
      for (final coord in nums) {
        if (hidden < numToHide && hidden < nums.length - 1) {
          final Cell cell = p.grid[coord.r][coord.c];
          p.bankCounts[cell.number] = (p.bankCounts[cell.number] ?? 0) + 1;
          cell.number = null;
          cell.fixed = false;
          hidden++;
        } else {
          final Cell cell = p.grid[coord.r][coord.c];
          cell.fixed = true;
        }
      }
    }
  }

  // Paso 5: Comprobaciones finales
  static bool _finalChecks(MatrixPuzzle p, List<_Equation> equations, int size) {
    // Comprobar que ecuaciones no se toquen sin intersección
    for (int i = 0; i < equations.length; i++) {
      for (int j = i + 1; j < equations.length; j++) {
        final eq1 = equations[i];
        final eq2 = equations[j];

        // Si mismo tipo, verificar distancia >1
        if (eq1.horizontal == eq2.horizontal) {
          int dist = eq1.horizontal ? (eq1.row - eq2.row).abs() : (eq1.col - eq2.col).abs();
          if (dist <= 1) return false;
        } else {
          // Diferente tipo, verificar si se cruzan o están demasiado cerca
          bool intersects = false;
          for (int k = 0; k < 5; k++) {
            int r1 = eq1.horizontal ? eq1.row : eq1.row + k;
            int c1 = eq1.horizontal ? eq1.col + k : eq1.col;
            for (int m = 0; m < 5; m++) {
              int r2 = eq2.horizontal ? eq2.row : eq2.row + m;
              int c2 = eq2.horizontal ? eq2.col + m : eq2.col;
              if (r1 == r2 && c1 == c2) {
                intersects = true;
                break;
              }
            }
            if (intersects) break;
          }
          if (!intersects) {
            // No intersectan, verificar distancia >1
            int minDistR = (eq1.row - eq2.row).abs();
            int minDistC = (eq1.col - eq2.col).abs();
            if (minDistR <= 1 || minDistC <= 1) return false;
          }
        }
      }
    }

    // Comprobar al menos 1 número visible por ecuación
    for (final eq in equations) {
      int visible = 0;
      final List<Coord> nums = eq.horizontal
          ? [Coord(eq.row, eq.col), Coord(eq.row, eq.col + 2), Coord(eq.row, eq.col + 4)]
          : [Coord(eq.row, eq.col), Coord(eq.row + 2, eq.col), Coord(eq.row + 4, eq.col)];
      for (final coord in nums) {
        if (p.grid[coord.r][coord.c].number != null) visible++;
      }
      if (visible < 1) return false;
    }

    return true;
  }
}

class _Equation {
  final bool horizontal;
  final int row, col;
  final List data; // [A, op, B, C]
  _Equation(this.horizontal, this.row, this.col, this.data);
}