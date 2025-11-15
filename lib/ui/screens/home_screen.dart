import 'package:flutter/material.dart';
import 'game_screen.dart';
import 'stats_screen.dart';
import '../../domain/puzzle_model.dart'; // para Difficulty

class HomeScreen extends StatelessWidget {
  
  Widget _bigButton(BuildContext c, String label, Color color, VoidCallback onPressed) {
  return Container(
    width: double.infinity,
    margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 24.0),
    child: RaisedButton(
      onPressed: onPressed,
      color: color,
      textColor: Colors.white,
      padding: EdgeInsets.symmetric(vertical: 18.0),
      child: Text(label, style: TextStyle(fontSize: 18.0)),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            SizedBox(height: 12.0),
            
            _bigButton(context, 'FÁCIL', Colors.green, () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameScreen(difficulty: Difficulty.easy)));
            }),
            
            _bigButton(context, 'MEDIO', Colors.orange, () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameScreen(difficulty: Difficulty.medium)));
            }),
            
            _bigButton(context, 'DIFÍCIL', Colors.red, () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameScreen(difficulty: Difficulty.hard)));
            }),
            
            Expanded(child: Container()), // pushes stats button to bottom
            Container(
              alignment: Alignment.centerRight,
              padding: EdgeInsets.only(right: 12.0, bottom: 12.0),
              child: SizedBox(
                width: 120,
                height: 40,
                child: RaisedButton(
                  onPressed: () {}, // placeholder: abrir estadísticas
                  color: Colors.grey[200],
                  child: Text('Estadísticas', style: TextStyle(color: Colors.black87)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
