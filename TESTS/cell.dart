

// lib/domain/cell.dart

class CellType {
  static const CellType empty = CellType('empty');
  static const CellType number = CellType('number');
  static const CellType op = CellType('op');
  static const CellType equals = CellType('equals');
  static const CellType result = CellType('result');

  final String name;
  const CellType(this.name);
  static List<CellType> values = [
    empty,
    number,
    op,
    equals,
    result,
  ];

  @override
  String toString() => name;
}

class Cell {
  CellType type;
  int? number;        // solo para number y result
  String? op;   // solo para operator (+ - * /)
  bool fixed = false;

  Cell.empty() : type = CellType.empty;

  Cell.number(this.number, {this.fixed = false}) : type = CellType.number;

  Cell.op(this.op) : type = CellType.op;

  Cell.equals() : type = CellType.equals;

  Cell.result(this.number, {this.fixed = false}) : type = CellType.result;

  // Constructor factory según tipo
  factory Cell.fromType(CellType t) {
    switch (t) {
      case CellType.empty:
        return Cell.empty();
      case CellType.number:
        return Cell.number(null);
      case CellType.op:
        return Cell.op(null);
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
    c.op = op;
    c.fixed = fixed;
    return c;
  }
  
  String toString(){
    switch(type){
      case CellType.empty:
        return '•';
        break;
      
      case CellType.number:
        return '$number';
        break;
      
      case CellType.op:
        String nonNullOp = op ?? '•';
        return nonNullOp;
        break;
      
      case CellType.equals:
        return '=';
        break;
      
      case CellType.result:
        return '$number';
        break;
    }
    
    return '';
  }

}