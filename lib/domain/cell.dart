
enum CellType { number, operator, result, empty }

class Cell {
  CellType type;
  int? number;
  String? operator;
  bool fixed;
}