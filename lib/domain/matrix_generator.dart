
import 'dart:math';
import 'matrix_puzzle.dart';
import 'cell.dart';

/*
DESCRIPCIÓN DEL ALGORIRMO:

1) Primero, crea el tablero y define los 
   valores máximos:
     Fácil: Tablero mínimo de 9x9 casillas,
     máximo de 12x12 casillas. 
     Número máximo 30, es decir, ninguna 
     suma o multiplicación puede ser mayor a 30
     
     Medio: Mínimo de 11x11, máximo de 15x15.
     Número máximo 60
     
     Difícil: Mínimo de 16x16, 
     máximo de 20x20. Número máximo 100

2) Genera una ecuación cualquiera y la pone
en cualquier lugar del tablero (Obviamente 
no en los bordes para no salirse del tamaño
del array permitido. Por ejemplo, si el 
tablero mide 10x10 una ecuación no puede 
colocarse en la casilla X:8, ya que las 
ecuaciones ocupan 5 casillas, saliéndose del 
tablero)

3) Luego de poner la primera ecuación en el
tablero empieza un loop para poner dos 
ecuaciones más que sean del tipo inverso 
(Es decir, si la primera ecuación fue 
vertical la siguiente será horizontal). 
Se selecciona una casilla de la ecuación 
actual (Puede ser un número o un operador,
ya que sí, los operadores son intersecciones
válidas), y se usa el número u operador 
en esa casilla para generar una nueva 
ecuación, y se pone ya sea hacia la 
izquierda o la derecha si es horizontal, 
o hacia arriba o abajo si la ecuaciòn que 
debe generarse es vertical. En este punto 
es donde se hacen las verificaciones de 
colisiones, algo así: Debo poner esta 
ecuación hacia la izquierda, y estoy en 
X:8|Y:5, hay alguna ecuación hacia la 
izquierda que me impida poner la ecuación? 
Si es así la descarto, un máximo de 5 veces 
(Es decir, este loop sólo se puede repetir
5 veces), y si las cinco veces fallas se 
selecciona otra casilla con un valor para 
generar ecuaciones.

En resumen, si seleccione el resultado como
casilla/valor incial para generar otra 
ecuación que debe ir hacia la izquiera,
pero las 5 veces falló porque hay alguna 
colisión hacia la izquierda, entonces 
selecciono otra casilla, puede ser por 
ejemplo el signo '=', y si las 5 casillas 
no pueden generar una ecuaciòn hacia la 
izquierda (Por cualquier motivo, ya sea 
porque se sale del tablero o porque hay 
colisiones), entonces no se genera nada 
hacia la izquierda y pasamos a intentar 
generar hacia la derecha.

Y las ecuaciones que sean generadas también
deben intentar generar más ecuaciones 
inversas a su orientación, hasta que todos 
los intentos de generar más ecuaciones 
fallen. Completando la generación del 
nivel/puzzle

4) Una vez creado el nivel vamos a rellenar
el banco. Vamos a ir ecuación por ecuación y
generaremos un valor entre 1 y 2. Dependiendo
del valor le vamos a quitar esa misma 
cantidad de números a la ecuación y los 
vamos a pasar al banco. Es decir, si sale un 
uno le quitamos un número a la ecuación, si 
sale un dos le quitamos dos números (Siempre 
dejando al menos uno)

5) Comprobaciones finales. Comprobaremos 
finalmente que las ecuaciones que no se 
intersectan no se toquen. Y comprobaremos de
nuevo que las ecuaciones tengan al menos 1 
números visible (Puede pasar que en alguna
interseccion, una ecuación que ya había 
pasado dos números al banco pierda su 
tercer número cuando la otra ecuación que 
se intersectaba en esa casilla decidió 
ocultarlo, dejando a la ecuación con sus 
tres números ocultos)
*/

class MatrixGenerator {
  
  static final Random random = Random();
  
  static MatrixPuzzle generate({
    String difficulty = 'easy',
  }){
    // Paso 0: Definir la configuración
    int minSize, maxSize, maxVal;
    if (difficulty == 'easy') {
      minSize = 10;
      maxSize = 12;
      maxVal = 30;
    } else if (difficulty == 'medium') {
      minSize = 13;
      maxSize = 15;
      maxVal = 60;
    } else {
      minSize = 16;
      maxSize = 20;
      maxVal = 99;
    }
    
    // Paso 1: Generar el tablero
    final int size = minSize + random.nextInt(maxSize - minSize + 1);
    final puzzle = MatrixPuzzle(size, size, difficulty: difficulty);
    
    for (int row = 0; row < size; row++) {
      for (int col = 0; col < size; col++) {
        puzzle.grid[row][col] = Cell.empty();
      }
    }
    
    // Paso 2: Generar la primera ecuación
    final bool firstHorizontal = random.nextBool();
    final List firstEquationData = generateEquation(maxVal);
    
    // Paso 3: Colocar la ecuación en un lugar al azar del tablero
    int posX;
    int posY;
    if(firstHorizontal){
      posX = random.nextInt(size - 5);
      posY = random.nextInt(size);
    } else {
      posX = random.nextInt(size);
      posY = random.nextInt(size - 5);
    }
    
    Equation firstEquation = Equation(
      firstHorizontal, 
      posX,
      posY,
      firstEquationData
    );
    
    placeEquation(puzzle, firstEquation);
    
    // PASO 4:
    // Asegurar que toda ecuación nueva INTERSECTA realmente a la existente.
    // No se permiten "shifts" que rompan la intersección (esto causaba
    // ecuaciones separadas). También se impone 1 casilla de separación
    // para celdas que NO forman parte de la misma ecuación.
    // ------------------------------------------------------------

    // devuelve coords ocupadas por eq como lista de [r,c]
    List<List<int>> _coordsFor(Equation eq) {
      final List<List<int>> out = [];
      if (eq.horizontal) {
        for (int i = 0; i < 5; i++) out.add([eq.x + i, eq.y]);
      } else {
        for (int i = 0; i < 5; i++) out.add([eq.x, eq.y + i]);
      }
      return out;
    }

    bool _coordsContains(List<List<int>> coords, int r, int c) {
      for (final cc in coords) if (cc[0] == r && cc[1] == c) return true;
      return false;
    }

    // canPlace: además de compatibilidad en las mismas casillas,
    // impone que NINGUNA celda objetivo tenga vecinos ocupados
    // (4-direcciones) que no formen parte de la misma ecuación.
    bool canPlaceEquationAt(MatrixPuzzle p, Equation eq) {
      final desiredCells = eq.toCells();
      final coords = _coordsFor(eq);

      for (int i = 0; i < coords.length; i++) {
        final int cx = coords[i][0];
        final int cy = coords[i][1];

        // debe caber
        if (!p.inBounds(cx, cy)) return false;

        final Cell existing = p.grid[cx][cy];
        final Cell desired = desiredCells[i];

        // si hay algo en la casilla: han de ser compatibles
        if (existing.type != CellType.empty) {
          if (existing.type != desired.type) return false;
          if ((desired.type == CellType.number || desired.type == CellType.result) &&
              existing.number != null && desired.number != null &&
              existing.number != desired.number) return false;
          if (desired.type == CellType.op &&
              existing.op != null && desired.op != null &&
              existing.op != desired.op) return false;
        }

        // vecinos 4-dir: si alguno está ocupado y NO pertenece a coords -> rechazo
        final List<List<int>> neigh = [
          [cx - 1, cy],
          [cx + 1, cy],
          [cx, cy - 1],
          [cx, cy + 1],
        ];

        for (final n in neigh) {
          final nr = n[0];
          final nc = n[1];
          if (!p.inBounds(nr, nc)) continue;

          // si el vecino sería una casilla de esta misma ecuación, ignorarlo
          if (_coordsContains(coords, nr, nc)) continue;

          if (p.grid[nr][nc].type != CellType.empty) {
            return false; // vecino ocupado por otra ecuación -> demasiado cerca
          }
        }
      }

      return true;
    }

    // coloca la ecuación sin sobrescribir celdas existentes (preserva intersecciones reales)
    void placeEquationRespecting(MatrixPuzzle puzzle, Equation equation) {
      final List<Cell> cells_equation = equation.toCells();
      final coords = _coordsFor(equation);
      for (int i = 0; i < coords.length; i++) {
        final int cx = coords[i][0];
        final int cy = coords[i][1];
        if (!puzzle.inBounds(cx, cy)) continue;
        final existing = puzzle.grid[cx][cy];
        if (existing.type == CellType.empty) {
          puzzle.grid[cx][cy] = cells_equation[i];
        } else {
          // ya existe: asumimos compatibilidad (canPlaceEquationAt la comprobó)
          // no sobrescribimos para mantener la referencia compartida en intersecciones
        }
      }
    }

    void commitEquation(MatrixPuzzle p, Equation eq, List<Equation> placedEquations, List<Equation> frontier) {
      placeEquationRespecting(p, eq);
      placedEquations.add(eq);
      frontier.add(eq);
    }

    // flujo principal: solo intentos que preserven la intersección exacta
    List<Equation> placedEquations = [firstEquation];
    List<Equation> frontier = [firstEquation];
    bool nextHorizontal = !firstHorizontal;
    int globalIterations = 0;
    const int MAX_GLOBAL_ITERS = 200;

    while (frontier.isNotEmpty && globalIterations < MAX_GLOBAL_ITERS) {
      globalIterations++;
      final List<Equation> currentLevel = List<Equation>.from(frontier);
      frontier.clear();
      final List<List> candidates = generateLevel(maxVal, currentLevel);

      int candIndex = 0;
      for (int i = 0; i < currentLevel.length; i++) {
        final Equation parent = currentLevel[i];
        int failCount = 0;

        // por cada parent intentamos sus 3 candidatos; **NUNCA** hacemos shifts que rompan la intersección
        for (int k = 0; k < 3; k++) {
          if (candIndex >= candidates.length) break;
          final List cand = candidates[candIndex++];
          if (cand == null || cand.isEmpty) continue;
          if (cand.length == 1 && cand[0] == -1) continue;
          int requiredValue;
          if (k == 0) requiredValue = parent.data[0];
          else if (k == 1) requiredValue = parent.data[2];
          else requiredValue = parent.data[3];

          final valPos = parent.getValuePosition(requiredValue);
          if (valPos is int) continue; // no encontró la posición (salta)
          final int vx = (valPos as List)[0];
          final int vy = (valPos as List)[1];

          final bool candidateHorizontal = nextHorizontal;
          final List candData = cand;

          int slotOffset = -1;
          if (candData[0] == requiredValue) slotOffset = 0;
          else if (candData[2] == requiredValue) slotOffset = 2;
          else if (candData[3] == requiredValue) slotOffset = 4;
          else continue;

          int ex, ey;
          if (candidateHorizontal) {
            ex = vx - slotOffset;
            ey = vy;
          } else {
            ex = vx;
            ey = vy - slotOffset;
          }

          final Equation eqCand = Equation(candidateHorizontal, ex, ey, candData);

          // Intentos: solo colocar EXACTAMENTE en (ex,ey) — si no cabe, lo descartamos.
          if (canPlaceEquationAt(puzzle, eqCand)) {
            commitEquation(puzzle, eqCand, placedEquations, frontier);
          } else {
            failCount++;
            if (failCount >= 5) break;
            // NO substituir por desplazamientos que rompan la intersección.
            // Simplemente se intentará con el siguiente candidato/parent.
          }
        } // end for k
      } // end for parents

      nextHorizontal = !nextHorizontal;
      // si frontier quedó vacío, no hay más ecuaciones que se puedan generar intersectando la red actual
      if (frontier.isEmpty) break;
    } // end while

    // Relleno del banco (igual que antes)
    for (final eq in placedEquations) {
      final List<Coord> operandCoords = [];
      if (eq.horizontal) {
        operandCoords.add(Coord(eq.x + 0, eq.y));
        operandCoords.add(Coord(eq.x + 2, eq.y));
      } else {
        operandCoords.add(Coord(eq.x, eq.y + 0));
        operandCoords.add(Coord(eq.x, eq.y + 2));
      }

      List<int> visibleIdx = [];
      for (int idx = 0; idx < operandCoords.length; idx++) {
        final c = operandCoords[idx];
        if (puzzle.inBounds(c.r, c.c)) {
          final cell = puzzle.grid[c.r][c.c];
          if ((cell.type == CellType.number) && (cell.number != null) && !cell.fixed) {
            visibleIdx.add(idx);
          }
        }
      }

      if (visibleIdx.length <= 1) continue;

      int toRemove = 1 + random.nextInt(2);
      if (toRemove >= visibleIdx.length) {
        toRemove = visibleIdx.length - 1;
      }
      visibleIdx.shuffle(random);
      final List<int> removeIdxs = visibleIdx.sublist(0, toRemove);

      for (final ridx in removeIdxs) {
        final coord = operandCoords[ridx];
        if (!puzzle.inBounds(coord.r, coord.c)) continue;
        final cell = puzzle.grid[coord.r][coord.c];
        if (cell.type == CellType.number && cell.number != null && !cell.fixed) {
          final int val = cell.number;
          cell.number = null;
          puzzle.bankPut(val);
        }
      }
    }

    return puzzle;
  }
  
  // HELPER FUNCTIONS:
  
  // helper: comprueba si una ecuación puede colocarse (compatibilidad/collision)
  static bool canPlaceEquationAt(MatrixPuzzle p, Equation eq) {
    if (eq.horizontal) {
      for (int i = 0; i < 5; i++) {
        final int cx = eq.x + i;
        final int cy = eq.y;
        if (!p.inBounds(cx, cy)) return false;
        final Cell existing = p.grid[cx][cy];
        final Cell desired = eq.toCells()[i];

        // empty is ok
        if (existing.type == CellType.empty) continue;

        // if types differ -> collision
        if (existing.type != desired.type) return false;

        // same type: check value compatibility
        if (desired.type == CellType.number || desired.type == CellType.result) {
          // if existing has a number, it must match desired number (or existing.number==null allowed)
          if (existing.number != null && desired.number != null && existing.number != desired.number) return false;
          // if existing has a fixed number different -> collision (already checked by previous line)
        } else if (desired.type == CellType.op) {
          if (existing.op != null && desired.op != null && existing.op != desired.op) return false;
        }
        // equals cell has no extra constraints beyond type
      }
    } else {
      for (int i = 0; i < 5; i++) {
        final int cx = eq.x;
        final int cy = eq.y + i;
        if (!p.inBounds(cx, cy)) return false;
        final Cell existing = p.grid[cx][cy];
        final Cell desired = eq.toCells()[i];

        if (existing.type == CellType.empty) continue;
        if (existing.type != desired.type) return false;

        if (desired.type == CellType.number || desired.type == CellType.result) {
          if (existing.number != null && desired.number != null && existing.number != desired.number) return false;
        } else if (desired.type == CellType.op) {
          if (existing.op != null && desired.op != null && existing.op != desired.op) return false;
        }
      }
    }
    return true;
  }
  
  // helper: coloca la ecuación y registra que fue añadida
  static void commitEquation(MatrixPuzzle p, Equation eq, List<Equation> placedEquations, List<Equation> frontier) {
    placeEquation(p, eq);
    placedEquations.add(eq);
    frontier.add(eq);
  }
  
  static List generateEquation(int maxVal) {
    final List<String> ops = ['+', '-', '*', '/'];
    String op = ops[random.nextInt(ops.length)];
    int A, B, C;
    for (int trial = 0; trial < 50; trial++) {
      A = 1 + random.nextInt(maxVal);
      B = 1 + random.nextInt(maxVal);
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
  
  static List generateEquationWithRequired(int maxVal, int requiredValue) {
    final List<String> ops = ['+', '-', '*', '/'];
    if (maxVal < 1 || requiredValue < 1) return [-1];
    for (int trial = 0; trial < 1000; trial++) {
      final String op = ops[random.nextInt(ops.length)];
      int A, B, C;
      
      final int placement = random.nextInt(3); 
  
      if (placement == 0) {
        A = requiredValue;
        B = 1 + random.nextInt(maxVal);
        if (op == '+') {
          C = A + B;
        } else if (op == '-') {
          C = A - B;
          if (C < 1) continue;
        } else if (op == '*') {
          C = A * B;
        } else {
          if (B == 0 || A % B != 0) continue;
          C = A ~/ B;
        }
        if (C >= 1 && C <= maxVal) return [A, op, B, C];
        continue;
      }
  
      if (placement == 1) {
        B = requiredValue;
        A = 1 + random.nextInt(maxVal);
        if (op == '+') {
          C = A + B;
        } else if (op == '-') {
          C = A - B;
          if (C < 1) continue;
        } else if (op == '*') {
          C = A * B;
        } else {
          if (B == 0 || A % B != 0) continue;
          C = A ~/ B;
        }
        if (C >= 1 && C <= maxVal) return [A, op, B, C];
        continue;
      }
      
      C = requiredValue;
      if (op == '+') {
        A = 1 + random.nextInt(maxVal);
        B = C - A;
        if (B >= 1 && B <= maxVal) return [A, op, B, C];
        continue;
      } else if (op == '-') {
        final int maxB = maxVal - C;
        if (maxB < 1) continue;
        B = 1 + random.nextInt(maxB);
        A = C + B;
        if (A >= 1 && A <= maxVal) return [A, op, B, C];
        continue;
      } else if (op == '*') {
        int attempts = 0;
        while (attempts < 20) {
          A = 1 + random.nextInt(maxVal);
          if (A != 0 && C % A == 0) {
            B = C ~/ A;
            if (B >= 1 && B <= maxVal) return [A, op, B, C];
          }
          attempts++;
        }
        continue;
      } else {
        int attempts = 0;
        while (attempts < 20) {
          B = 1 + random.nextInt(maxVal);
          A = C * B;
          if (A >= 1 && A <= maxVal) return [A, op, B, C];
          attempts++;
        }
        continue;
      }
    }
    return [-1];
  }
  
  static void placeEquation(MatrixPuzzle puzzle, Equation equation){
    List<Cell> cells_equation = equation.toCells();
    if(equation.horizontal){
      puzzle.grid[equation.x+0][equation.y] = cells_equation[0];
      puzzle.grid[equation.x+1][equation.y] = cells_equation[1];
      puzzle.grid[equation.x+2][equation.y] = cells_equation[2];
      puzzle.grid[equation.x+3][equation.y] = cells_equation[3];
      puzzle.grid[equation.x+4][equation.y] = cells_equation[4];
    } else {
      puzzle.grid[equation.x][equation.y+0] = cells_equation[0];
      puzzle.grid[equation.x][equation.y+1] = cells_equation[1];
      puzzle.grid[equation.x][equation.y+2] = cells_equation[2];
      puzzle.grid[equation.x][equation.y+3] = cells_equation[3];
      puzzle.grid[equation.x][equation.y+4] = cells_equation[4];
    }
  }
  
  static List<List> generateLevel(int maxVal, List<Equation> requests){
    List<List> equations = [];
    for(int i = 0; i < requests.length; i++){
      equations.add(
        generateEquationWithRequired(
          maxVal, requests[i].data[0]
        )
      );
      equations.add(
        generateEquationWithRequired(
          maxVal, requests[i].data[2]
        )
      );
      equations.add(
        generateEquationWithRequired(
          maxVal, requests[i].data[3]
        )
      );
    }
    return equations;
  }
  

}

class Equation {
  bool horizontal;
  int x, y;
  List data; // [A, op, B, C]
  Equation(this.horizontal, this.x, this.y, this.data);
  
  List<int> getValuePosition(int value){
    if(data.contains(value)){
      if(horizontal){
        if(data[0] == value){ return [x, y]; }
        if(data[2] == value){ return [x+2, y]; }
        if(data[3] == value){ return [x+4, y]; }
      } else {
        if(data[0] == value){ return [x, y]; }
        if(data[2] == value){ return [x, y+2]; }
        if(data[3] == value){ return [x, y+4]; }
      }
    }
    return [-1];
  }
  
  List<Cell> toCells(){
    final List<Cell> cells = [];
    cells.add(Cell.number  (data[0] as int));
    cells.add(Cell.op(data[1] as String));
    cells.add(Cell.number  (data[2] as int));
    cells.add(Cell.equals  ());
    cells.add(Cell.result  (data[3] as int));
    return cells;
  }
}