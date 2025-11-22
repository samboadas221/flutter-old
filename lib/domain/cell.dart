
// lib/domain/cell.dart

class CellType {
  static const CellType empty = CellType._('empty');
  static const CellType number = CellType._('number');
  static const CellType operator = CellType._('operator');
  static const CellType equals = CellType._('equals');
  static const CellType result = CellType._('result');

  final String name;
  const CellType.(this.name);

  static const List<CellType> values = [
    empty,
    number,
    operator,
    equals,
    result,
  ];

  @override
  String toString() => name;
}

class Cell {
  CellType type;
  int number;        // solo para number y result
  String operator;   // solo para operator (+ - * /)
  bool fixed = false;

  Cell.empty() : type = CellType.empty;

  Cell.number(this.number, {this.fixed = false}) : type = CellType.number;

  Cell.operator(this.operator) : type = CellType.operator;

  Cell.equals() : type = CellType.equals;

  Cell.result(this.number, {this.fixed = false}) : type = CellType.result;

  // Constructor factory según tipo
  factory Cell.fromType(CellType t) {
    switch (t) {
      case CellType.empty:
        return Cell.empty();
      case CellType.number:
        return Cell.number(null);
      case CellType.operator:
        return Cell.operator(null);
      case CellType.equals:
        return Cell.equals();
      case CellType.result:
        return Cell.result(null);
      default:
        return Cell.empty();
    }
  }

  // Para copiar celdas (usado en MatrixPuzzle.copy())
  Cell clone() {
    final c = Cell.empty();
    c.type = type;
    c.number = number;
    c.operator = operator;
    c.fixed = fixed;
    return c;
  }

}