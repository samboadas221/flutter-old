
// lib/ui/widgets/board_widget.dart
// Compatible with Flutter 1.22 (no null-safety)

import 'package:flutter/material.dart';
import '../../domain/puzzle_model.dart';
import '../../domain/rules.dart';
import 'cell_widget.dart';
import 'drag_handlers.dart';

typedef PlaceCallback = void Function(Coord to, int value, String source);
typedef SwapCallback = void Function(Coord from, Coord to);
typedef TapCallback = void Function(Coord pos);

class BoardWidget extends StatelessWidget {
  final Puzzle puzzle;
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

  // compute a set of coords that belong to correct lines, used to highlight
  Set<Coord> _computeCorrectCoords() {
    final Map<String, bool> lineStatus = validateAllLines(puzzle);
    final correctLines = puzzle.lines.where((l) => lineStatus[l.id] == true);
    final set = Set<Coord>();
    for (var l in correctLines) {
      set.addAll(l.operandCoords);
      set.add(l.operatorCoord);
      set.add(l.equalsCoord);
    }
    return set;
  }

  Widget _buildCell(BuildContext context, int r, int c, Set<Coord> correctCoords) {
    final coord = Coord(r, c);
    final cell = puzzle.cells[coord];
    if (cell == null) {
      return SizedBox(width: cellSize, height: cellSize);
    }

    final bool highlight = correctCoords.contains(coord);

    // If it's a number cell and has a non-fixed placed value, make it draggable (to allow swaps)
    if (cell.isNumber && cell.value != null && !cell.fixed) {
      final childWidget = CellWidget(cell: cell, highlight: highlight, onTap: (pos) {
        if (onTap != null) onTap(pos);
      }, size: cellSize);

      return DraggableNumber(
        value: cell.value as int,
        sourceId: 'board:${r}:${c}',
        child: childWidget,
        feedback: Material(
          color: Colors.transparent,
          child: Container(
            width: cellSize,
            height: cellSize,
            alignment: Alignment.center,
            child: childWidget,
          ),
        ),
      );
    }

    // otherwise a drop target (also for operator/target cells we keep non-accepting)
    return GenericDropTarget(
      builder: (ctx, candidateData, rejected) {
        final showCandidate = candidateData != null && candidateData.isNotEmpty;
        return Container(
          width: cellSize,
          height: cellSize,
          child: CellWidget(
            cell: cell,
            highlight: highlight || showCandidate,
            onTap: (pos) {
              if (onTap != null) onTap(pos);
            },
            size: cellSize,
          ),
        );
      },
      onWillAccept: (payload) {
        // only number cells accept drops
        if (cell == null) return false;
        if (!cell.isNumber) return false;
        // if fixed cannot accept
        if (cell.fixed) return false;
        // if payload from board and same coord -> reject
        if (payload.source != null && payload.source.startsWith('board:')) {
          final parts = payload.source.split(':');
          if (parts.length >= 3) {
            final or = int.parse(parts[1]);
            final oc = int.parse(parts[2]);
            if (or == r && oc == c) return false;
          }
        }
        // check immediate feasibility using rules.canPlaceNumber (light check)
        // create a temp copy of puzzle to test placement
        final temp = puzzle.copy();
        if (temp.cells[coord] == null) return false;
        temp.cells[coord].value = payload.value;
        final ok = canPlaceNumber(temp, coord, payload.value);
        return ok;
      },
      onAccept: (payload) {
        final src = payload.source ?? 'bank';
        if (src.startsWith('board:')) {
          final parts = src.split(':');
          final fr = int.parse(parts[1]);
          final fc = int.parse(parts[2]);
          final from = Coord(fr, fc);
          if (onSwap != null) onSwap(from, coord);
        } else {
          if (onPlace != null) onPlace(coord, payload.value, src);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = puzzle.rows;
    final cols = puzzle.cols;
    final correctCoords = _computeCorrectCoords();

    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(rows, (r) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(cols, (c) {
              return _buildCell(context, r, c, correctCoords);
            }),
          );
        }),
      ),
    );
  }
}