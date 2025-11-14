
// lib/ui/widgets/drag_handlers.dart
// Compatible with Flutter 1.22 (no null-safety)

import 'package:flutter/material.dart';

/// Payload carried during a drag.
class DragPayload {
  final int value;
  final String source; // optional id (e.g., 'bank', 'board:(r,c)')
  DragPayload(this.value, {this.source});
  @override
  String toString() => 'DragPayload(value:$value, source:$source)';
}

/// A simple draggable numeric tile. Uses Draggable<DragPayload>.
/// - value: numeric value carried
/// - child: widget shown in place
/// - feedback: widget shown under finger while dragging (if null, a default tile is used)
/// - onDragStarted/onDragCompleted/onDragEnd: optional lifecycle hooks
class DraggableNumber extends StatelessWidget {
  final int value;
  final Widget child;
  final Widget feedback;
  final VoidCallback onDragStarted;
  final VoidCallback onDragCompleted;
  final void Function(DraggableDetails) onDragEnd;
  final String sourceId;

  DraggableNumber({
    Key key,
    @required this.value,
    this.child,
    this.feedback,
    this.onDragStarted,
    this.onDragCompleted,
    this.onDragEnd,
    this.sourceId,
  }) : super(key: key);

  Widget _defaultFeedback(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.green[300],
          borderRadius: BorderRadius.circular(6.0),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0,2))],
        ),
        child: Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final payload = DragPayload(value, source: sourceId);
    return LongPressDraggable<DragPayload>(
      data: payload,
      child: child ?? _defaultFeedback(context),
      feedback: feedback ?? _defaultFeedback(context),
      childWhenDragging: Opacity(opacity: 0.4, child: child ?? _defaultFeedback(context)),
      onDragStarted: onDragStarted,
      onDragCompleted: onDragCompleted,
      onDragEnd: onDragEnd,
    );
  }
}

/// Generic drop-area wrapper for DragPayload.
/// - builder: builds child UI given candidate state
/// - onWillAccept/onAccept/onLeave: callbacks for drag lifecycle
class GenericDropTarget extends StatelessWidget {
  final Widget Function(BuildContext, List<DragPayload>, List<dynamic>) builder;
  final bool Function(DragPayload) onWillAccept;
  final void Function(DragPayload) onAccept;
  final void Function(DragPayload) onLeave;

  GenericDropTarget({
    Key key,
    @required this.builder,
    this.onWillAccept,
    this.onAccept,
    this.onLeave,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DragTarget<DragPayload>(
      builder: builder,
      onWillAccept: (payload) {
        try {
          if (onWillAccept != null) return onWillAccept(payload);
        } catch (e) {}
        return true;
      },
      onAccept: (payload) {
        if (onAccept != null) onAccept(payload);
      },
      onLeave: (payload) {
        if (onLeave != null) onLeave(payload);
      },
    );
  }
}