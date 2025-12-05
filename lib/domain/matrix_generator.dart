

import 'dart:math';
import 'matrix_puzzle.dart';
import 'cell.dart';
import 'board.dart';
import 'equation.dart';

class MatrixGenerator {
  
  static final Random random = Random();
  
  static MatrixPuzzle generate({ String difficulty = 'easy', }){
    // Paso 0: Definir la configuración
    int minSize, maxSize, maxVal, size;
    if (difficulty == 'easy') {
      minSize = 14;
      maxSize = 16;
      maxVal = 30;
    } else if (difficulty == 'medium') {
      minSize = 17;
      maxSize = 20;
      maxVal = 60;
    } else {
      minSize = 21;
      maxSize = 26;
      maxVal = 99;
    }
    
    size = maxSize;
    
    MatrixPuzzle puzzle = MatrixPuzzle(size, size, difficulty);
    
    Board board = Board();
    board.setConstrains(size, maxVal);
    board.generate();
    
    // ESTA ES LA FUNCIÓN QUE DEBES CREAR!!
    boardToPuzzle(board, puzzle);
    
    List<Equation> boardEquations = [];
    
    // scan horizontal
    for (int r = 0; r < puzzle.rows; r++) {
      for (int c = 0; c <= puzzle.cols - 5; c++) {
        if (puzzle.grid[c][r].type == CellType.number &&
            puzzle.grid[c+1][r].type == CellType.op &&
            puzzle.grid[c+2][r].type == CellType.number &&
            puzzle.grid[c+3][r].type == CellType.equals &&
            puzzle.grid[c+4][r].type == CellType.result) {
          final A = puzzle.grid[c][r].number;
          final op = puzzle.grid[c+1][r].op;
          final B = puzzle.grid[c+2][r].number;
          final C = puzzle.grid[c+4][r].number;
          // asegurar que no añadimos duplicados (por si hay solapes interpretables)
          boardEquations.add(Equation(true, c, r, [A, op, B, C]));
        }
      }
    }
    // scan vertical
    for (int c = 0; c < puzzle.cols; c++) {
      for (int r = 0; r <= puzzle.rows - 5; r++) {
        if (puzzle.grid[c][r].type == CellType.number &&
            puzzle.grid[c][r+1].type == CellType.op &&
            puzzle.grid[c][r+2].type == CellType.number &&
            puzzle.grid[c][r+3].type == CellType.equals &&
            puzzle.grid[c][r+4].type == CellType.result) {
          final A = puzzle.grid[c][r].number;
          final op = puzzle.grid[c][r+1].op;
          final B = puzzle.grid[c][r+2].number;
          final C = puzzle.grid[c][r+4].number;
          boardEquations.add(Equation(false, c, r, [A, op, B, C]));
        }
      }
    }
    
    // 2) Mapa coord -> lista de ecuaciones (índices)
    Map<String, List<int>> coordToEquations = {}; // key "r,c" -> list of indices in boardEquations
    String keyOf(int r, int c) => r.toString() + ',' + c.toString();
    
    List<List<Coord>> equationNumberCoords = []; // para cada ecuación, coords de A y B (no resultado)
    for (int i = 0; i < boardEquations.length; i++) {
      final eq = boardEquations[i];
      final List<Coord> coords = [];
      if (eq.horizontal) {
        coords.add(Coord(eq.x + 0, eq.y)); // A
        coords.add(Coord(eq.x + 2, eq.y)); // B
      } else {
        coords.add(Coord(eq.x, eq.y + 0)); // A
        coords.add(Coord(eq.x, eq.y + 2)); // B
      }
      equationNumberCoords.add(coords);
    
      for (final coord in coords) {
        final k = keyOf(coord.r, coord.c);
        coordToEquations[k] = coordToEquations[k] ?? [];
        coordToEquations[k].add(i);
      }
    }
    
    // 3) Para cada ecuación elegimos celdas candidatas a ocultar
    final rng = MatrixGenerator.random;
    
    // definimos probabilidad/criterio de cuántos quitar: 1 o 2 (aleatorio)
    for (int i = 0; i < boardEquations.length; i++) {
      final eq = boardEquations[i];
      final coords = equationNumberCoords[i];
    
      // comprobar cuántos operandos visibles tiene actualmente (A/B)
      List<int> visibleIdx = [];
      for (int idx = 0; idx < coords.length; idx++) {
        final p = coords[idx];
        if (puzzle.inBounds(p.r, p.c)) {
          final cell = puzzle.grid[p.r][p.c];
          if (cell.type == CellType.number && cell.number != null && !cell.fixed) {
            visibleIdx.add(idx);
          }
        }
      }
      if (visibleIdx.isEmpty) continue; // nada que quitar
    
      int want = 1 + rng.nextInt(2); // 1 o 2
      if (want >= visibleIdx.length) want = visibleIdx.length - 1; // dejar al menos 1 visible
      if (want <= 0) continue;
    
      // preferir candidatos que NO sean intersecciones (i.e., coordToEquations[key].length == 1)
      List<int> nonIntersecting = [];
      List<int> intersecting = [];
      for (final idx in visibleIdx) {
        final p = coords[idx];
        final k = keyOf(p.r, p.c);
        final users = coordToEquations[k] ?? [];
        if (users.length <= 1) nonIntersecting.add(idx);
        else intersecting.add(idx);
      }
    
      // construir lista de elección priorizada
      final List<int> pickPool = [];
      pickPool.addAll(nonIntersecting);
      pickPool.addAll(intersecting);
    
      // shuffle and pick up to 'want' but checking safety before removing each
      pickPool.shuffle(rng);
      int removed = 0;
      for (final idx in List<int>.from(pickPool)) {
        if (removed >= want) break;
        final coord = coords[idx];
        if (!puzzle.inBounds(coord.r, coord.c)) continue;
        final cell = puzzle.grid[coord.r][coord.c];
        if (cell.type != CellType.number || cell.number == null) continue;
    
        // simulación de efecto: para cada ecuación que usa esta celda, comprobar que tras quitar
        // no se queda sin operandos visibles
        final users = coordToEquations[keyOf(coord.r, coord.c)] ?? [];
        bool safe = true;
        for (final eqIndex in users) {
          // contar visibles si quitamos esta celda
          int visibleAfter = 0;
          final otherCoords = equationNumberCoords[eqIndex];
          for (int kIdx = 0; kIdx < otherCoords.length; kIdx++) {
            final oc = otherCoords[kIdx];
            if (oc.r == coord.r && oc.c == coord.c) continue; // sería eliminado
            if (!puzzle.inBounds(oc.r, oc.c)) continue;
            final ocell = puzzle.grid[oc.r][oc.c];
            if (ocell.type == CellType.number && ocell.number != null) visibleAfter++;
          }
          if (visibleAfter <= 0) {
            safe = false;
            break;
          }
        }
    
        if (!safe) continue;
    
        // realizar eliminación real
        final int val = cell.number;
        cell.number = null;
        cell.fixed = false;
        puzzle.bankPut(val);
    
        // actualizar estructuras: coordToEquations para esta celda ya no importa (celda vacía)
        coordToEquations.remove(keyOf(coord.r, coord.c));
        removed++;
      }
    
      // si no conseguimos quitar 'want' por constraints, está bien: dejamos lo que se pudo quitar
    }
    return puzzle;
  }
  
  static void boardToPuzzle(Board board, MatrixPuzzle puzzle) {
    // Asumimos que board.grid y puzzle.grid tienen la misma dimensión.
    final int rows = board.grid.length;
    final int cols = board.grid.isNotEmpty ? board.grid[0].length : 0;
  
    if (rows != puzzle.rows || cols != puzzle.cols) {
      throw ArgumentError(
          'Dimensiones incompatibles: Board ($rows x $cols) vs Puzzle (${puzzle.rows} x ${puzzle.cols})');
    }
  
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final String tok = board.grid[r][c];
  
        Cell newCell;
  
        if (tok == null || tok == '.' || tok.trim().isEmpty) {
          newCell = Cell.empty();
        } else if (tok == '=') {
          newCell = Cell.equals();
          newCell.fixed = true;
        } else if (tok == '+' || tok == '-' || tok == '*' || tok == '/') {
          newCell = Cell.op(tok);
          newCell.fixed = true;
        } else {
          // Intentar parsear número (A, B o C)
          final int val = int.tryParse(tok);
          if (val == null) {
            // Token inesperado: tratar como vacío para seguridad
            newCell = Cell.empty();
          } else {
            // Detectar si este número es el RESULTADO:
            // Si inmediatamente a la izquierda hay '=' (horizontal) o
            // inmediatamente arriba hay '=' (vertical), entonces es resultado.
            bool isResult = false;
            if (c - 1 >= 0 && board.grid[r][c - 1] == '=') isResult = true;
            if (r - 1 >= 0 && board.grid[r - 1][c] == '=') isResult = true;
  
            if (isResult) {
              newCell = Cell.result(val, fixed: true);
            } else {
              // Operando A o B: lo dejamos no fijo para que el generador pueda ocultarlo.
              newCell = Cell.number(val, fixed: false);
            }
          }
        }
  
        puzzle.grid[r][c] = newCell;
      }
    }
  
    // Inicializar banco vacío (si no está ya)
    puzzle.bankCounts = {};
  }
  
}