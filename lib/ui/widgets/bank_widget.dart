
// lib/ui/widgets/bank_widget.dart
// Compatible with Flutter 1.22 (no null-safety)

import 'package:flutter/material.dart';
import 'drag_handlers.dart';

typedef OnTileDragStarted = void Function(int value);
typedef OnTileDragCompleted = void Function(int value);
typedef OnTileTap = void Function(int value);

class BankWidget extends StatelessWidget {
  final Bank bank;
  final double tileSize;
  final OnTileDragStarted onDragStarted;
  final OnTileDragCompleted onDragCompleted;
  final OnTileTap onTap;
  final Axis direction;
  final EdgeInsets padding;

  BankWidget({
    Key key,
    @required this.bank,
    this.tileSize = 56.0,
    this.onDragStarted,
    this.onDragCompleted,
    this.onTap,
    this.direction = Axis.horizontal,
    this.padding = const EdgeInsets.all(8.0),
  })  : assert(bank != null),
        super(key: key);

  Widget _buildTile(BuildContext ctx, int value, int count) {
    final tile = Container(
      width: tileSize,
      height: tileSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.green[300],
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: Colors.black12),
      ),
      child: Text('$value', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
    );

    final wrapped = GestureDetector(
      onTap: () {
        if (onTap != null) onTap(value);
      },
      child: Stack(
        alignment: Alignment.topRight,
        children: <Widget>[
          tile,
          if (count != null)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Text('$count', style: TextStyle(color: Colors.white, fontSize: 11.0)),
              ),
            ),
        ],
      ),
    );

    return DraggableNumber(
      value: value,
      sourceId: 'bank',
      child: wrapped,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: tileSize,
          height: tileSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.green[400],
            borderRadius: BorderRadius.circular(6.0),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0,3))],
          ),
          child: Text('$value', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ),
      onDragStarted: () {
        if (onDragStarted != null) onDragStarted(value);
      },
      onDragCompleted: () {
        if (onDragCompleted != null) onDragCompleted(value);
      },
    );
  }

  List<Widget> _buildChildren(BuildContext ctx) {
    final tiles = <Widget>[];
    final entries = bank.toList();
    if (entries.isEmpty) return tiles;
    // Build map value->count
    final Map<int, int> counts = {};
    for (var v in entries) counts[v] = (counts[v] ?? 0) + 1;
    final sortedKeys = counts.keys.toList()..sort();
    for (var k in sortedKeys) {
      tiles.add(_buildTile(ctx, k, counts[k]));
      tiles.add(SizedBox(width: 8.0, height: 8.0));
    }
    if (tiles.isNotEmpty) tiles.removeLast();
    return tiles;
  }

  @override
  Widget build(BuildContext context) {
    final children = _buildChildren(context);
    if (direction == Axis.horizontal) {
      return Container(
        padding: padding,
        height: tileSize + 16,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: children),
        ),
      );
    } else {
      return Container(
        padding: padding,
        width: tileSize + 16,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Column(children: children),
        ),
      );
    }
  }
}