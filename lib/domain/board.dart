
import 'dart:math';
import 'equation.dart';
import 'equation_generator.dart';

/// ========== CONFIGURACIÓN ==========
int ROWS = 14;
int COLS = 14;
const int MAX_ATTEMPTS = 200; // intentos por generación antes de declarar estancamiento
const int MIN_NUM = 0;
int MAX_NUM = 30; // configurable: rango de números permitidos (inclusive)
const int MAX_ROOT_ATTEMPTS = 5000; // intentos para generar ecuación raíz
const int CHILD_GEN_ATTEMPTS = 2500; // intentos para generar un hijo que cumpla restricciones
/// ===================================

/// Tablero simple
class Board {
  List<List<String>> grid = [];
  
  bool inBounds(int r, int c) => r >= 0 && r < ROWS && c >= 0 && c < COLS;
  bool inBoundsPoint(Point<int> p) => inBounds(p.x, p.y);

  String at(Point<int> p) => grid[p.x][p.y];
  void setAt(Point<int> p, String v) => grid[p.x][p.y] = v;
  
  void setConstrains(int size, int maxValue){
    ROWS = size;
    COLS = size;
    MAX_NUM = maxValue;
    grid = List.generate(ROWS, (_) => List.filled(COLS, '.', growable: false), growable: false);
  }
  
  /// Comprueba si child puede colocarse respecto al tablero y su parentChosenCoord (la coordenada del padre donde queremos la intersección).
  /// Reglas:
  ///  - Todas las celdas del child deben estar dentro del tablero.
  ///  - EXACTAMENTE la celda alignmentCoord debe corresponder a una celda ocupada por el padre y con el mismo token.
  ///  - Ninguna otra celda del child puede estar ocupada por algo distinto de '.'.
  ///  - Ninguna celda del child (ni su vecindad ortogonal) puede tocar celdas ocupadas por ecuaciones distintas del parent (se permite contacto con parent).
  bool canPlaceChild(Equation child, Equation parent, Point<int> alignmentCoord) {
    final childCells = child.cells();
    final parentCells = parent.cells().toSet();

    // límites
    for (var p in childCells) {
      if (!inBoundsPoint(p)) return false;
    }

    // Debe haber exactamente UNA superposición con contenidos no-vacíos:
    int overlaps = 0;
    Point<int> overlapCoord = null;
    for (int i = 0; i < childCells.length; i++) {
      final p = childCells[i];
      final existing = at(p);
      final token = child.tokenAtIndex(i);
      if (existing != '.') {
        overlaps++;
        overlapCoord = p;
        // esa celda existente debe pertenecer al parent y debe coincidir en token
        if (!parentCells.contains(p)) return false;
        if (existing != token) return false;
      }
    }

    if (overlaps != 1) return false;

    // La superposición debe ocurrir exactamente en alignmentCoord
    if (overlapCoord == null) return false;
    if (overlapCoord != alignmentCoord) return false;

    // Asegurarse que alignmentCoord es una coordenada numérica del parent
    final parentNumCoords = <Point<int>, String>{};
    for (int idx in parent.numericIndices()) {
      parentNumCoords[parent.coordAtIndex(idx)] = parent.tokenAtIndex(idx);
    }
    if (!parentNumCoords.containsKey(alignmentCoord)) return false;

    // Vecindad ortogonal: ninguna celda adyacente ortogonal (no perteneciente al parent) puede estar ocupada
    for (var cp in childCells) {
      final neighbors = [
        Point(cp.x - 1, cp.y),
        Point(cp.x + 1, cp.y),
        Point(cp.x, cp.y - 1),
        Point(cp.x, cp.y + 1)
      ];
      for (var n in neighbors) {
        if (!inBoundsPoint(n)) continue;
        if (parentCells.contains(n)) continue; // permitido si es parent
        if (childCells.contains(n)) continue; // parte del propio hijo
        if (at(n) != '.') return false; // toca otro elemento
      }
    }

    // OK
    return true;
  }

  void place(Equation eq) {
    for (int i = 0; i < 5; i++) {
      setAt(eq.coordAtIndex(i), eq.tokenAtIndex(i));
    }
  }

  void printBoard() {
    for (var r = 0; r < ROWS; r++) {
      final line = grid[r].map((s) {
        if (s == '.') return '   ';
        if (s.length == 1) return ' $s ';
        if (s.length == 2) return '$s ';
        return s.substring(0, 3);
      }).join();
      print(line);
    }
  }
  
  void generate(){
    final rng = Random();
    final gen = EquationGenerator(rng);
  
    // 1) Tablero vacío creado
  
    // 2) Generar y colocar ecuación raíz con attempts
    Equation root = null;
    for (int tries = 0; tries < MAX_ROOT_ATTEMPTS; tries++) {
      final orientation =
          rng.nextBool() ? Orientation.horizontal : Orientation.vertical;
      // elegir un índice donde se fijará el valor del "fixed" dentro del tablero al ubicarlo aleatoriamente
      // generamos un valor random que será uno de los tokens numéricos del root
      final fixedIndex = [0, 2, 4][rng.nextInt(3)];
      final fixedVal = rng.nextInt(MAX_NUM - MIN_NUM + 1) + MIN_NUM;
  
      // Elegir una coordenada alignment aleatoria tal que la ecuación quepa
      int r = rng.nextInt(ROWS);
      int c = rng.nextInt(COLS);
      // convert alignment to start assuming orientation
      // alignmentCoord es la coordenada donde estará el índice fixedIndex
      if (orientation == Orientation.horizontal) {
        if (c < fixedIndex || c - fixedIndex + 4 >= COLS) continue;
        final alignment = Point(r, c);
        final eq = gen.generateWithFixedIndex(fixedIndex, fixedVal, orientation, alignment,
            upToAttempts: 40);
        if (eq == null) continue;
        // verify empty cells
        bool ok = true;
        for (var p in eq.cells()) {
          if (!inBoundsPoint(p) || at(p) != '.') {
            ok = false;
            break;
          }
        }
        if (!ok) continue;
        root = eq;
        break;
      } else {
        if (r < fixedIndex || r - fixedIndex + 4 >= ROWS) continue;
        final alignment = Point(r, c);
        final eq = gen.generateWithFixedIndex(fixedIndex, fixedVal, orientation, alignment,
            upToAttempts: 40);
        if (eq == null) continue;
        bool ok = true;
        for (var p in eq.cells()) {
          if (!inBoundsPoint(p) || at(p) != '.') {
            ok = false;
            break;
          }
        }
        if (!ok) continue;
        root = eq;
        break;
      }
    }
  
    if (root == null) {
      return;
    }
  
    place(root);
    List<Equation> previousGen = [root];
  
    // 3) Ciclo generacional
    while (true) {
      int attempts = 0;
      List<Equation> nextGen = [];
      bool placedSomething = false;
  
      while (attempts < MAX_ATTEMPTS && !placedSomething) {
        nextGen.clear();
  
        // Para cada padre elegimos al azar hasta 3 índices numéricos distintos del padre (0,2,4)
        for (var parent in previousGen) {
          final parentNumIdxs = [0, 2, 4]..shuffle(rng);
          final chosenParentIdxs = parentNumIdxs.take(3).toList();
  
          for (var parentIdx in chosenParentIdxs) {
            final parentCoord = parent.coordAtIndex(parentIdx);
            final parentToken = parent.tokenAtIndex(parentIdx);
            final parentVal = int.tryParse(parentToken);
            if (parentVal == null) continue;
  
            // Orientación del hijo opuesta al padre
            final childOri = parent.orientation == Orientation.horizontal
                ? Orientation.vertical
                : Orientation.horizontal;
  
            // Elegir aleatoriamente el índice del hijo donde ocurrirá la intersección (0/2/4)
            final childIdx = [0, 2, 4][rng.nextInt(3)];
  
            // Generar ecuación hijo que tenga en childIdx el valor parentVal y que al ubicarla
            // en parentCoord como alignment quede dentro de tablero
            final childEq = gen.generateWithFixedIndex(
                childIdx, parentVal, childOri, parentCoord,
                upToAttempts: CHILD_GEN_ATTEMPTS ~/ 4);
  
            if (childEq == null) continue;
  
            // Validar que se puede colocar con respecto al estado actual del tablero y al parentCoord
            if (canPlaceChild(childEq, parent, parentCoord)) {
              place(childEq);
              nextGen.add(childEq);
              placedSomething = true;
            }
          }
        }
  
        if (!placedSomething) attempts++;
      } // end attempts loop
  
      if (!placedSomething) {
        // no se pudo colocar nada tras MAX_ATTEMPTS -> detener
        break;
      }
  
      if (nextGen.isEmpty) break;
      previousGen = nextGen;
    }
  }
  
  
  
}
