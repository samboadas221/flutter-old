
// lib/ui/widgets/board_widget.dart
// Reescrito para MatrixPuzzle - Flutter 1.22 (no null-safety)

import 'package:flutter/material.dart';
import '../../domain/matrix_puzzle.dart';
import '../../domain/matrix_solver.dart';
import '../../domain/cell.dart';
import 'cell_widget.dart';
import 'drag_handlers.dart';

typedef PlaceCallback = void Function(int row, int col, int value, String source);
typedef SwapCallback = void Function(int fromRow, int fromCol, int toRow, int toCol);
typedef TapCallback = void Function(int row, int col);

class BoardWidget extends StatelessWidget {
  final MatrixPuzzle puzzle;
  final double cellSize;
  final PlaceCallback onPlace;
  final SwapCallback onSwap;
  final TapCallback onTap;
  final EdgeInsets padding;

  BoardWidget({
    Key key,
    @required this.puzzle,
    this.cellSize = 52.0,
    this.onPlace,
    this.onSwap,
    this.onTap,
    this.padding = const EdgeInsets.all(8.0),
  }) : super(key: key);

  /// Highlight opcional: destaca únicamente celdas que pertenecen
  /// a ecuaciones correctas (muy simple: la ecuación completa es correcta).
  Set<String> _computeCorrectCellKeys() {
    final correct = Set<String>();

    // Revisar ecuaciones horizontales
    for (int r = 0; r < puzzle.rows; r++) {
      for (int c = 0; c <= puzzle.cols - 5; c++) {
        if (_isEquationAt(r, c, true)) {
          if (MatrixSolver._checkEquation(puzzle, r, c, true)) {
            for (int k = 0; k < 5; k++) {
              correct.add("${r}_${c + k}");
            }
          }
        }
      }
    }

    // Revisar ecuaciones verticales
    for (int c = 0; c < puzzle.cols; c++) {
      for (int r = 0; r <= puzzle.rows - 5; r++) {
        if (_isEquationAt(r, c, false)) {
          if (MatrixSolver._checkEquation(puzzle, r, c, false)) {
            for (int k = 0; k < 5; k++) {
              correct.add("${r + k}_${c}");
            }
          }
        }
      }
    }

    return correct;
  }

  bool _isEquationAt(int r, int c, bool horizontal) {
    // Copiado de MatrixSolver._isEquationAt pero inline para highlight
    int r0 = r;
    int c0 = c;

    int dr = horizontal ? 0 : 1;
    int dc = horizontal ? 1 : 0;

    Coord a  = Coord(r0 + 0 * dr, c0 + 0 * dc);
    Coord op = Coord(r0 + 1 * dr, c0 + 1 * dc);
    Coord b  = Coord(r0 + 2 * dr, c0 + 2 * dc);
    Coord eq = Coord(r0 + 3 * dr, c0 + 3 * dc);
    Coord rs = Coord(r0 + 4 * dr, c0 + 4 * dc);

    if (!puzzle.inBounds(a.r, a.c)) return false;
    if (!puzzle.inBounds(rs.r, rs.c)) return false;

    Cell ca = puzzle.grid[a.r][a.c];
    Cell cop = puzzle.grid[op.r][op.c];
    Cell cb = puzzle.grid[b.r][b.c];
    Cell ceq = puzzle.grid[eq.r][eq.c];
    Cell cres = puzzle.grid[rs.r][rs.c];

    return ca.type == CellType.number &&
        cop.type == CellType.operator &&
        cb.type == CellType.number &&
        ceq.type == CellType.equals &&
        cres.type == CellType.result;
  }

  Widget _buildCell(BuildContext context, int r, int c, Set<String> correctKeys) {
    final cell = puzzle.grid[r][c];
    final key = "${r}_${c}";
    final highlight = correctKeys.contains(key);

    // 1) Celdas NUMBER no fijas → Draggable
    if (cell.type == CellType.number && cell.value == null && cell.number == null) {
      // celda vacía, drop target
      return _buildDropTarget(r, c, cell, highlight);
    }

    if (cell.type == CellType.number && cell.number != null && !cell.fixed) {
      // celda con número colocado por jugador → draggable
      final widget = CellWidget(
        cell: cell,
        size: cellSize,
        highlight: highlight,
        onTap: (_) {
          if (onTap != null) onTap(r, c);
        },
      );

      return DraggableNumber(
        value: cell.number,
        sourceId: "board:$r:$c",
        child: widget,
        feedback: Material(
          color: Colors.transparent,
          child: Container(
            width: cellSize,
            height: cellSize,
            alignment: Alignment.center,
            child: widget,
          ),
        ),
      );
    }

    // 2) Celdas NUMÉRICAS fijas → no draggable
    if (cell.type == CellType.number && cell.fixed) {
      return _fixedNumber(r, c, cell, highlight);
    }

    // 3) Operadores / igual / resultado → widgets normales (algunos aceptan drops)
    if (cell.type == CellType.operator ||
        cell.type == CellType.equals ||
        cell.type == CellType.result) {
      return _buildDropTarget(r, c, cell, highlight);
    }

    return SizedBox(width: cellSize, height: cellSize);
  }

  Widget _fixedNumber(int r, int c, Cell cell, bool highlight) {
    return Container(
      width: cellSize,
      height: cellSize,
      child: CellWidget(
        cell: cell,
        size: cellSize,
        highlight: highlight,
        onTap: (_) {
          if (onTap != null) onTap(r, c);
        },
      ),
    );
  }

  /// Construye un drop target para celdas donde se puede colocar un número.
  Widget _buildDropTarget(int r, int c, Cell cell, bool highlight) {
    return GenericDropTarget(
      builder: (ctx, candidate, rejected) {
        bool candidateHighlight = candidate != null && candidate.isNotEmpty;
        return Container(
          width: cellSize,
          height: cellSize,
          child: CellWidget(
            cell: cell,
            size: cellSize,
            highlight: highlight || candidateHighlight,
            onTap: (_) {
              if (onTap != null) onTap(r, c);
            },
          ),
        );
      },
      onWillAccept: (payload) {
        if (cell.fixed) return false;
        if (cell.type != CellType.number && cell.type != CellType.result) return false;
        return true;
      },
      onAccept: (payload) {
        final src = payload.source ?? "bank";

        if (src.startsWith("board:")) {
          final parts = src.split(":");
          int fr = int.parse(parts[1]);
          int fc = int.parse(parts[2]);
          if (onSwap != null) onSwap(fr, fc, r, c);
        } else {
          if (onPlace != null) onPlace(r, c, payload.value, src);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final correctKeys = _computeCorrectCellKeys();

    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(puzzle.rows, (r) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(puzzle.cols, (c) {
              return _buildCell(context, r, c, correctKeys);
            }),
          );
        }),
      ),
    );
  }
}