
// lib/ui/widgets/hud.dart
// Compatible with Flutter 1.22 (no null-safety)

import 'package:flutter/material.dart';

typedef VoidCoordCallback = void Function();
typedef VoidIntCallback = void Function(int);

class HudWidget extends StatelessWidget {
  final int timeSeconds; // total seconds played in current session
  final int moves;
  final int hintsLeft;
  final int bestTime; // optional display for current difficulty
  final VoidCoordCallback onUndo;
  final VoidCoordCallback onHint;
  final VoidCoordCallback onCheck;
  final VoidCoordCallback onReset;
  final VoidCoordCallback onPause; // optional pause/save

  HudWidget({
    Key key,
    this.timeSeconds = 0,
    this.moves = 0,
    this.hintsLeft = 0,
    this.bestTime,
    this.onUndo,
    this.onHint,
    this.onCheck,
    this.onReset,
    this.onPause,
  }) : super(key: key);

  String _formatTime(int s) {
    final mins = s ~/ 60;
    final secs = s % 60;
    final mm = mins.toString().padLeft(2, '0');
    final ss = secs.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(value, style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
        SizedBox(height: 4.0),
        Text(label, style: TextStyle(fontSize: 12.0, color: Colors.black54)),
      ],
    );
  }

  Widget _iconButton({IconData icon, String tooltip, VoidCallback onPressed, Color color}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8.0),
        onTap: onPressed,
        child: Container(
          width: 44,
          height: 36,
          alignment: Alignment.center,
          child: Tooltip(message: tooltip ?? '', child: Icon(icon, size: 20.0, color: color ?? Colors.black87)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(timeSeconds);
    final bestStr = bestTime != null ? _formatTime(bestTime) : '--:--';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0,2))],
        borderRadius: BorderRadius.circular(6.0),
      ),
      child: Row(
        children: <Widget>[
          // left: small controls column
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _iconButton(
                icon: Icons.undo,
                tooltip: 'Undo',
                color: onUndo != null ? Colors.black87 : Colors.grey,
                onPressed: onUndo,
              ),
              SizedBox(height: 4.0),
              _iconButton(
                icon: Icons.refresh,
                tooltip: 'Reset',
                color: onReset != null ? Colors.black87 : Colors.grey,
                onPressed: onReset,
              ),
            ],
          ),
          SizedBox(width: 12.0),
          // center: stats
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                _buildStatColumn('TIEMPO', timeStr),
                _buildStatColumn('MOVIMIENTOS', moves.toString()),
                _buildStatColumn('HINTS', hintsLeft.toString()),
                _buildStatColumn('MEJOR', bestStr),
              ],
            ),
          ),
          // right: action buttons
          Row(
            children: <Widget>[
              _iconButton(
                icon: Icons.lightbulb_outline,
                tooltip: 'Hint',
                color: onHint != null ? Colors.orange[700] : Colors.grey,
                onPressed: onHint,
              ),
              SizedBox(width: 8.0),
              _iconButton(
                icon: Icons.check_circle_outline,
                tooltip: 'Check',
                color: onCheck != null ? Colors.green[700] : Colors.grey,
                onPressed: onCheck,
              ),
              SizedBox(width: 8.0),
              _iconButton(
                icon: Icons.pause,
                tooltip: 'Pause',
                color: onPause != null ? Colors.black87 : Colors.grey,
                onPressed: onPause,
              ),
            ],
          ),
        ],
      ),
    );
  }
}