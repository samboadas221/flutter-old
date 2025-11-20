
import 'package:flutter/material.dart';
import 'dart:math';
import '../../domain/matrix_generator.dart';
import '../../domain/matrix_puzzle.dart';
import '../../domain/cell.dart';

enum Difficulty { easy, medium, hard }

class GameScreen extends StatefulWidget {
  final Difficulty difficulty;

  GameScreen({Key key, this.difficulty}) : super(key: key);

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  MatrixPuzzle puzzle;
  int selectedNumber = null; // número seleccionado del banco para colocar

  @override
  void initState() {
    super.initState();
    _generatePuzzle();
  }

  void _generatePuzzle() {
    String diffStr;
    switch (widget.difficulty) {
      case Difficulty.easy:
        diffStr = 'easy';
        break;
      case Difficulty.medium:
        diffStr = 'medium';
        break;
      case Difficulty.hard:
        diffStr = 'hard';
        break;
    }

    setState(() {
      puzzle = MatrixGenerator.generate(
        difficulty: diffStr,
        cluePercent: 40,
      );
      selectedNumber = null;
    });
  }

  void _onCellTap(int r, int c) {
    final cell = puzzle.grid[r][c];

    // Solo interactuamos con celdas de número o resultado que no estén fijas
    if (cell.type != CellType.number && cell.type != CellType.result) return;
    if (cell.fixed) return;

    if (selectedNumber == null) {
      // Si no hay número seleccionado → intentar borrar
      if (cell.number != null) {
        puzzle.removeNumber(r, c);
        setState(() {});
      }
      return;
    }

    // Colocar número seleccionado
    if (puzzle.bankContains(selectedNumber)) {
      if (puzzle.placeNumber(r, c, selectedNumber)) {
        setState(() {
          if (!puzzle.bankContains(selectedNumber)) {
            selectedNumber = null; // se acabó ese número
          }
          _checkVictory();
        });
      }
    }
  }

  void _checkVictory() {
    if (puzzle.isSolved()) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => WinDialog(onNewGame: () {
          Navigator.of(context).pop();
          _generatePuzzle();
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('CrossMath - ${widget.difficulty.toString().split('.').last.toUpperCase()}'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _generatePuzzle,
          ),
        ],
      ),
      body: Column(
        children: [
          // Banco de números
          Container(
            padding: EdgeInsets.all(12),
            color: Colors.grey[200],
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: puzzle.bankCounts.keys.toList()
                ..sort()
                .map((num) {
                  int count = puzzle.bankCounts[num];
                  bool isSelected = selectedNumber == num;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedNumber = (selectedNumber == num) ? null : num;
                      });
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.indigo : Colors.white,
                        border: Border.all(color: Colors.indigo, width: 2),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            '$num',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (count > 1)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: CircleAvatar(
                                radius: 10,
                                backgroundColor: Colors.red,
                                child: Text(
                                  '$count',
                                  style: TextStyle(fontSize: 12, color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
            ),
          ),

          // Cuadrícula del puzzle
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: GridView.builder(
                physics: BouncingScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: puzzle.cols,
                  childAspectRatio: 1.0,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                ),
                itemCount: puzzle.rows * puzzle.cols,
                itemBuilder: (ctx, index) {
                  int r = index ~/ puzzle.cols;
                  int c = index % puzzle.cols;
                  Cell cell = puzzle.grid[r][c];

                  Color bgColor = Colors.white;
                  Color textColor = Colors.black87;
                  String display = '';

                  if (cell.type == CellType.empty) {
                    return Container(color: Colors.transparent);
                  }

                  if (cell.type == CellType.operator) {
                    bgColor = Colors.grey[300];
                    display = cell.operator ?? '';
                    textColor = Colors.deepPurple[900];
                  } else if (cell.type == CellType.equals) {
                    bgColor = Colors.grey[300];
                    display = '=';
                    textColor = Colors.deepPurple[900];
                  } else if (cell.type == CellType.number || cell.type == CellType.result) {
                    if (cell.fixed) {
                      bgColor = Colors.yellow[100];
                    } else if (cell.number != null) {
                      bgColor = Colors.lightBlue[50];
                    }
                    display = cell.number?.toString() ?? '';
                  }

                  return GestureDetector(
                    onTap: () => _onCellTap(r, c),
                    child: Container(
                      decoration: BoxDecoration(
                        color: bgColor,
                        border: Border.all(color: Colors.grey[400]),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        display,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Indicador de número seleccionado
          Container(
            padding: EdgeInsets.all(12),
            child: Text(
              selectedNumber == null
                  ? "Toca un número del banco para seleccionarlo\n(o toca una casilla con número para borrarlo)"
                  : "Coloca el número: $selectedNumber",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}

// Diálogo de victoria con confeti simple
class WinDialog extends StatelessWidget {
  final VoidCallback onNewGame;

  WinDialog({this.onNewGame});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('¡FELICIDADES! 🎉', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('¡Has completado el puzzle perfectamente!', textAlign: TextAlign.center),
          SizedBox(height: 20),
          Confetti(),
        ],
      ),
      actions: [
        RaisedButton(
          child: Text('Nuevo Puzzle'),
          color: Colors.indigo,
          textColor: Colors.white,
          onPressed: onNewGame,
        ),
        FlatButton(
          child: Text('Salir'),
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ],
    );
  }
}

// Confeti muy ligero (solo círculos animados)
class Confetti extends StatefulWidget {
  @override
  _ConfettiState createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  AnimationController controller;
  List<Particle> particles = [];

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: Duration(seconds: 4))
      ..addListener(() => setState(() {}))
      ..forward();

    Random rnd = Random();
    for (int i = 0; i < 50; i++) {
      particles.add(Particle(
        color: Colors.primaries[rnd.nextInt(Colors.primaries.length)],
        vx: rnd.nextDouble() * 8 - 4,
        vy: rnd.nextDouble() * -10 - 5,
        x: rnd.nextDouble() * 300 - 150,
        y: -20,
      ));
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 200,
      child: CustomPaint(
        painter: ConfettiPainter(particles, controller.value),
      ),
    );
  }
}

class Particle {
  Color color;
  double x, y, vx, vy;
  Particle({this.color, this.x, this.y, this.vx, this.vy});
}

class ConfettiPainter extends CustomPainter {
  final List<Particle> particles;
  final double progress;

  ConfettiPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var p in particles) {
      double t = progress;
      double cx = p.x + p.vx * t * 30;
      double cy = p.y + p.vy * t * 30 + 0.5 * 300 * t * t; // gravedad
      paint.color = p.color;
      canvas.drawCircle(Offset(cx + size.width / 2, cy), 6, paint);
    }
  }

  @override
  bool shouldRepaint(_) => true;
}