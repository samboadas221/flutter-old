
// lib/domain/cell.dart
// Compatible con Flutter 1.22 (no null-safety)

enum CellType { number, operator, result, equals, empty }

class Cell {
  CellType type;

  // Usamos int y String normales, permitiendo null (Flutter 1.22 lo permite)
  int number;
  String operator;

  bool fixed;

  Cell(this.type, {this.number, this.operator, this.fixed = false});

  // --- Factories ---
  factory Cell.empty() => Cell(CellType.empty);

  factory Cell.fromType(CellType t) => Cell(t);

  // --- Clone ---
  Cell clone() {
    return Cell(
      type,
      number: number,
      operator: operator,
      fixed: fixed,
    );
  }
}