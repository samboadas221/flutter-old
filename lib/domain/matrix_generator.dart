
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

import 'dart:math';
import 'matrix_puzzle.dart';
import 'cell.dart';

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
    // 4.1) Por cada ecuación se crea un nivel/stack
    //      con 3 ecuaciones más que usarán los
    //      3 valores de esa primers ecuación
    //      Esta paso es exponencial. Si hay 1
    //      ecuación van a intentar crearse 3 ecuaciones
    //      más, si hay 3 van a intentar crearse 9 más, etc
    
    // 4.2) Luego de crear esas ecuaciones van a 
    //      generamos sus coordenadas basados
    //      en la intersección con el padre.
    
    // 4.3) verificamos si hay colisiones
    
    // 4.4) Si no hay colisiones colocamos
    //      la ecuación, y la añadimos a la
    //      siguiente lista para generar más
    //      ecuaciones
    
    List<Equation> nextGeneration = [firstEquation];
    List<Equation> generatedChilds = [];
    List<Equation> previousGeneration = [];
    List<Equation> placedEquations = [];
    bool generatedLevel = false;
    
    while(!generatedLevel){
      
      // Limpiamos las ecuaciones generadas
      // en la generación previa
      generatedChilds.clear();
      placedEquations.clear();
      
      // Generar un stack de ecuaciones,
      // para luego intentar poner esas
      // ecuaciones hijas en el tablero
      // e intentar intersectarlas con
      // sus ecuaciones padre
      for(Equation parent in nextGeneration){
        List childA = generateEquationWithRequired(maxVal, parent.data[0]);
        List childB = generateEquationWithRequired(maxVal, parent.data[2]);
        List childC = generateEquationWithRequired(maxVal, parent.data[3]);
        
        Equation equationA = Equation(!parent.horizontal, -1, -1, childA);
        Equation equationB = Equation(!parent.horizontal, -1, -1, childB);
        Equation equationC = Equation(!parent.horizontal, -1, -1, childC);
        
        // Generamos las coordenadas correctas
        // basado en la intersección con el padre
        generateEquationCoords(parent, equationA);
        generateEquationCoords(parent, equationA);
        generateEquationCoords(parent, equationA);
        
        generatedChilds.add(equationA);
        generatedChilds.add(equationB);
        generatedChilds.add(equationC);
      }
      
      // Las ecuaciones generadas ahora hay
      // que verificar sus colisiones y
      // colocarlas en el tablero
      for(Equation parent in nextGeneration){
        int offset = nextGeneration.indexOf(parent) * 3;
        if(!collide(generatedChilds[0 + offset], parent, puzzle)){
          placeEquation(puzzle, generatedChilds[0 + offset]);
          placedEquations.add(generatedChilds[0 + offset]);
        }
        if(!collide(generatedChilds[1 + offset], parent, puzzle)){
          placeEquation(puzzle, generatedChilds[1 + offset]);
          placedEquations.add(generatedChilds[1 + offset]);
        }
        if(!collide(generatedChilds[2 + offset], parent, puzzle)){
          placeEquation(puzzle, generatedChilds[2 + offset]);
          placedEquations.add(generatedChilds[2 + offset]);
        }
      }
      
      // Ahora que hemos puesto todas las
      // ecuaciones sin colision en el tablero
      // debemos limpiar la lista de padres
      // actual, para que los padres de la
      // nueva generación sean las ecuaciones
      // que acabamos de poner
      nextGeneration.clear();
      for(Equation equation in placedEquations){
        nextGeneration.add(equation);
      }
      placedEquations.clear();
      
      // Si no hay ecuaciones para trabajar
      // quiere decir que no hay más espacio
      // para colocar más ecuaciones
      if(nextGeneration.length <= 0){
        generatedLevel = true;
      }
    }
    
    // -> En esta parte al parecer debe
    // ir la lógica de quitar celdas y
    // añadirlas al banco
    
    // ------------------ BLOQUE: OCULTAR NÚMEROS Y METER EN EL BANCO ------------------
    // Inserta esto justo antes de "return puzzle;"
    
    // 1) Recopilar todas las ecuaciones presentes en el tablero
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
    
    // FIN BLOQUE ocultado
    
    return puzzle;
  }
  
  // HELPER FUNCTIONS:
  
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
  
  static void generateEquationCoords(Equation parent, Equation child){
    int intersectionIndex = getChildIndexIntersection(parent, child, 0);
    if(intersectionIndex != -1){
      generatePositionFromIntersection(parent, child, 0, intersectionIndex);
      return;
    }
    
    intersectionIndex = getChildIndexIntersection(parent, child, 2);
    if(intersectionIndex != -1){
      generatePositionFromIntersection(parent, child, 2, intersectionIndex);
      return;
    }
    
    intersectionIndex = getChildIndexIntersection(parent, child, 3);
    if(intersectionIndex != -1){
      generatePositionFromIntersection(parent, child, 3, intersectionIndex);
      return;
    }
  }
  
  static int getChildIndexIntersection(Equation parent, Equation child, int index){
    if(parent.data[index] == child.data[0]){return 0;}
    if(parent.data[index] == child.data[2]){return 2;}
    if(parent.data[index] == child.data[3]){return 3;}
    return -1;
  }
  
  static void generatePositionFromIntersection(Equation parent, Equation child, int parentIndex, int childIndex){
    if(parentIndex == 0 && childIndex == 0){
      child.x = parent.x;
      child.y = parent.y;
      return;
    }
    if(parent.horizontal){
      switch(parentIndex){
        case 0: switch(childIndex){
          case 2:
            child.x = parent.x;
            child.y = parent.y-2;
            return;
          case 3:
            child.x = parent.x;
            child.y = parent.y-4;
            return;
          default: break;
        }
        break;
        
        case 2: switch(childIndex){
          case 0:
            child.x = parent.x+2;
            child.y = parent.y;
            return;
          
          case 2:
            child.x = parent.x+2;
            child.y = parent.y-2;
            return;
            
          case 3:
            child.x = parent.x+2;
            child.y = parent.y-4;
            return;
            
          default: break;
        }
        break;
        
        case 3: switch(childIndex){
          case 0:
            child.x = parent.x+4;
            child.y = parent.y;
            return;
          
          case 2:
            child.x = parent.x+4;
            child.y = parent.y-2;
            return;
          
          case 3:
            child.x = parent.x+4;
            child.y = parent.y-4;
            return;
          
          default: break;
        }
        break;
      }
    } else {
      switch(parentIndex){
        case 0: switch(childIndex){
          case 2:
            child.x = parent.x-2;
            child.y = parent.y;
            return;
            
          case 3:
            child.x = parent.x-4;
            child.y = parent.y;
            return;
            
          default: break;
        }
        break;
        
        case 2: switch(childIndex){
          case 0:
            child.x = parent.x;
            child.y = parent.y+2;
            return;
          
          case 2:
            child.x = parent.x+2;
            child.y = parent.y+2;
            return;
            
          case 3:
            child.x = parent.x+4;
            child.y = parent.y+2;
            return;
          
          default: break;
        }
        break;
        
        case 3: switch(childIndex){
          case 0:
            child.x = parent.x;
            child.y = parent.y+4;
            return;
          
          case 2:
            child.x = parent.x-2;
            child.y = parent.y+4;
            return;
          
          case 3:
            child.x = parent.x-4;
            child.y = parent.y+4;
            return;
          
          default: break;
        }
        break;
      }
    }
    
  }

  static bool collide(Equation child, Equation parent, MatrixPuzzle board){
    
    if(child.horizontal){
      for(int y=-1; y<2; y++){
        for(int x=-1; x<6; x++){
          int posX = child.x + x;
          int posY = child.y + y;
          if(board.inBounds(posX, posY)){
            if(
              board.grid[posX][posY] != Cell.empty() &&
              posX != (parent.x + x) && posY != (parent.y + y)) {
                return true;
            }
          } else {
            return false;
          }
        }
      }
      
    // Now lets do the same but for Vertical equations
    } else {
      for(int y=-1; y<6; y++){
        for(int x=-1; x<2; x++){
          int posX = child.x + x;
          int posY = child.y + y;
          if(board.inBounds(posX, posY)){
            if(
              board.grid[posX][posY] != Cell.empty() &&
              posX != (parent.x + x) && posY != (parent.y + y)) {
                return true;
            }
          } else {
            return false;
          }
        }
      }
    }
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