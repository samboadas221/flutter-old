

// Compatible con Flutter 1.22 (no null-safety)

import 'dart:convert';
import 'cell.dart';

class Coord {
  final int width;
  final int height;
  Coord(this.width, this.height);
  
  // Map:
  // r = width
  // c = height

  @override
  bool operator ==(other) => other is Coord && other.width == width && other.height == height;

  @override
  int get hashCode => width.hashCode ^ height.hashCode;

  Map<String, int> toJson() => {'width': width, 'height': height};

  static Coord fromJson(Map j) => Coord(j['width'], j['height']);
}

class MatrixPuzzle {
  final int width;
  final int height;
  
  // Map:
  // rows = width
  // cols = Height
  
  late List<List<Cell>> grid;

  Map<int, int> bankCounts = {};

  String? id;
  String difficulty; // "easy","medium","hard"

  MatrixPuzzle(this.width, this.height, {this.difficulty = 'easy', this.id}) {
    grid = List.generate(
      width,
      (_) => List.generate(height, (_) => Cell.empty()),
    );
  }

  bool inBounds(int x, int y){
    return x >= 0 && x < width && y >= 0 && y < height;
  }

  Cell cellAt(Coord p) => grid[p.width][p.height];

  void setCellAt(Coord p, Cell cell) {
    grid[p.width][p.height] = cell;
  }
  
  void consolePrint(){
    print('Ancho: $width');
    print('Alto: $height');
    for(int y = 0; y < height; y++){
      String line = '';
      for(int x = 0; x < width; x++){
        String cell = grid[x][y].toString();
        line += cell;
      }
      print(line);
    }
  }

  bool placeNumber(int x, int y, int value, {bool markFixed = false}) {
    if (!inBounds(x, y)) return false;
    final cell = grid[x][y];

    if (cell.type != CellType.number) return false;
    if (cell.fixed) return false;

    cell.number = value;
    if (markFixed) cell.fixed = true;
    
    final count = bankCounts[value] ?? 0;
    if (bankCounts.containsKey(value) && count > 0) {
      bankCounts[value] = count - 1;
      if (bankCounts[value] == 0) bankCounts.remove(value);
    }

    return true;
  }

  bool removeNumber(int x, int y) {
    if (!inBounds(x, y)) return false;
    Cell cell = grid[x][y];
    if (cell.type != CellType.number) return false;
    if (cell.fixed) return false;
    if (cell.number == null) return false;

    int? n = cell.number;
    if(n == null) return false;
    int v = n;
    cell = Cell.empty();
    bankCounts[v] = (bankCounts[v] ?? 0) + 1;
    return true;
  }
  

  // ------------ Equation detection ------------

  // -------- bank --------

  void bankPut(int v) => bankCounts[v] = (bankCounts[v] ?? 0) + 1;
  
  /*
  // Old bankContains pre null safety
  bool bankContains(int v) =>
      bankCounts.containsKey(v) && bankCounts[v] > 0;
  */
  
  bool bankContains(int v) {
    final count = bankCounts[v];
    return count != null && count > 0;
  }
  
  /*
  // OLD bankUse previous to null safety
  bool bankUse(int v) {
    if (!bankContains(v)) return false;
    bankCounts[v] = bankCounts[v] - 1;
    if (bankCounts[v] == 0) bankCounts.remove(v);
    return true;
  }
  */
  
  bool bankUse(int v) {
    final current = bankCounts[v] ?? 0;
    if (current <= 0) return false;
    final next = current - 1;
    if (next > 0) {
      bankCounts[v] = next;
    } else {
      bankCounts.remove(v);
    }
    return true;
  }
}
