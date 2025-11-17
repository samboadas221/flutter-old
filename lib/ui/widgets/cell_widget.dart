
// lib/ui/widgets/cell_widget.dart
// Compatible with Flutter 1.22 (no null-safety)

import 'package:flutter/material.dart';

typedef CellDropCallback = void Function(Coord pos, int value);
typedef CellTapCallback = void Function(Coord pos);

class CellWidget extends StatelessWidget {
  final Cell cell;
  final bool highlight; // e.g., correct / incorrect visual hint
  final CellDropCallback onAccept; // called when a numeric tile is dropped here
  final CellTapCallback onTap;
  final double size; // square size in pixels

  const CellWidget({
    Key key,
    @required this.cell,
    this.highlight = false,
    this.onAccept,
    this.onTap,
    this.size = 56.0,
  }) : super(key: key);

  Color _bgColor(BuildContext c) {
    if (cell.isOperator || cell.isEquals || cell.isTarget) {
      return Colors.grey[200];
    }
    if (cell.fixed) return Colors.green[200];
    return Colors.white;
  }

  Widget _buildNumber(BuildContext context) {
    final txt = cell.value != null ? '${cell.value}' : '';
    final style = TextStyle(
      fontSize: 16.0,
      fontWeight: cell.fixed ? FontWeight.bold : FontWeight.w500,
      color: cell.fixed ? Colors.black87 : Colors.black87,
    );

    // If droppable, wrap with DragTarget if callback provided
    if (onAccept != null && cell.isNumber) {
      return DragTarget<int>(
        builder: (context, candidateData, rejectedData) {
          final showCandidate = candidateData.isNotEmpty;
          return Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: showCandidate ? Colors.yellow[100] : _bgColor(context),
              borderRadius: BorderRadius.circular(6.0),
              border: Border.all(color: highlight ? Colors.blue : Colors.grey[300], width: highlight ? 2.0 : 1.0),
            ),
            child: Text(txt, style: style),
          );
        },
        onWillAccept: (val) {
          return true;
        },
        onAccept: (val) {
          if (onAccept != null) onAccept(cell.pos, val);
        },
      );
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _bgColor(context),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: highlight ? Colors.blue : Colors.grey[300], width: highlight ? 2.0 : 1.0),
      ),
      child: Text(txt, style: style),
    );
  }

  Widget _buildOperator(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _bgColor(context),
        borderRadius: BorderRadius.circular(6.0),
      ),
      child: Text(
        cell.value ?? '',
        style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEquals(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      child: Text('=', style: TextStyle(fontSize: 18.0)),
    );
  }

  Widget _buildTarget(BuildContext context) {
    return Container(
      width: size + 10,
      height: size,
      padding: EdgeInsets.symmetric(horizontal: 4.0),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6.0),
      ),
      child: Text(
        '${cell.value ?? ''}',
        style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget inner;
    if (cell.isOperator) inner = _buildOperator(context);
    else if (cell.isEquals) inner = _buildEquals(context);
    else if (cell.isTarget) inner = _buildTarget(context);
    else inner = _buildNumber(context);

    return GestureDetector(
      onTap: () {
        if (onTap != null) onTap(cell.pos);
      },
      child: inner,
    );
  }
}