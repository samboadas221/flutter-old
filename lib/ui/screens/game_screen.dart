
// lib/ui/screens/game_screen.dart
// Compatible con Flutter 1.22.x (pre null-safety).
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

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  MatrixPuzzle puzzle;
  int selectedNumber; // número seleccionado del banco para colocar
  TransformationController _transformationController;
  AnimationController _resetController;
  Animation<Matrix4> _resetAnimation;

  // Valores determinísticos para el tamaño lógico de celda
  // (construiremos el tablero a partir de este tamaño lógico y lo escalaremos
  // para que encaje en pantalla mediante TransformationController).
  static const double _logicalCellSize = 56.0; // tamaño deseado por celda en "unidades lógicas"
  static const double _minCellSize = 28.0;     // si queremos asegurar legibilidad mínima
  static const double _maxInitialScale = 4.0;
  static const double _minInitialScale = 0.15;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _resetController = AnimationController(vsync: this, duration: Duration(milliseconds: 300));
    _resetController.addListener(() {
      _transformationController.value = _resetAnimation.value;
    });
    _generatePuzzle();
  }

  @override
  void dispose() {
    _resetController.dispose();
    _transformationController.dispose();
    super.dispose();
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
      );
      selectedNumber = null;
      // reset transform when new puzzle created
      _resetToFit();
    });
  }

  // Ajusta la transform para que el tablero (con tamaño lógico) quepa en el espacio disponible.
  // Usaremos LayoutBuilder en build para calcular la escala de adaptación y aplicarla aquí.
  void _resetTo(Matrix4 target) {
    _resetAnimation = Matrix4Tween(begin: _transformationController.value, end: target).animate(
        CurvedAnimation(parent: _resetController, curve: Curves.easeOut));
    _resetController.forward(from: 0.0);
  }

  void _resetToFit({double viewportWidth, double viewportHeight}) {
    if (puzzle == null || viewportWidth == null || viewportHeight == null) return;
    final double contentWidth = puzzle.cols * _logicalCellSize;
    final double contentHeight = puzzle.rows * _logicalCellSize;

    // Compute scale so that content fits within available viewport (padding considered)
    final double scaleX = viewportWidth / contentWidth;
    final double scaleY = viewportHeight / contentHeight;
    double scale = min(scaleX, scaleY);

    // clamp scale to sensible limits
    scale = scale.clamp(_minInitialScale, _maxInitialScale);

    // center the content in viewport: translate so that scaled content is centered
    final double translateX = (viewportWidth - contentWidth * scale) / 2.0;
    final double translateY = (viewportHeight - contentHeight * scale) / 2.0;

    final Matrix4 m = Matrix4.identity()
      ..translate(translateX, translateY)
      ..scale(scale, scale);

    _transformationController.value = m;
  }

  void _onCellTap(int r, int c) {
    final cell = puzzle.grid[r][c];

    // Solo celdas de número o resultado
    if (cell.type != CellType.number && cell.type != CellType.result) return;
    if (cell.fixed) return; // pistas no se tocan

    // Si no hay número seleccionado → intentar borrar (devolver al banco)
    if (selectedNumber == null) {
      if (cell.number != null) {
        final removed = cell.number;
        puzzle.removeNumber(r, c);
        setState(() {});
        // Opcional: seleccionar automáticamente el que acabas de quitar
        setState(() {
          selectedNumber = removed;
        });
      }
      return;
    }

    // === COLOCAR NÚMERO (incluso si ya hay uno) ===
    if (puzzle.bankContains(selectedNumber)) {
      final oldNumber = cell.number;

      // Colocamos el nuevo (siempre, sin validar nada)
      cell.number = selectedNumber;
      puzzle.bankUse(selectedNumber);

      // Si había un número anterior → lo devolvemos al banco
      if (oldNumber != null) {
        puzzle.bankCounts[oldNumber] = (puzzle.bankCounts[oldNumber] ?? 0) + 1;
      }

      setState(() {
        if (!puzzle.bankContains(selectedNumber)) {
          selectedNumber = null;
        }
        _checkVictory();
      });
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

  // Widget para renderizar una celda. Usamos FittedBox para evitar texto cortado.
  Widget _buildCell(int r, int c, double logicalSize) {
    Cell cell = puzzle.grid[r][c];

    if (cell.type == CellType.empty) {
      return SizedBox(width: logicalSize, height: logicalSize);
    }

    Color bgColor = Colors.white;
    Color textColor = Colors.black87;
    String display = '';

    if (cell.type == CellType.op) {
      bgColor = Colors.grey[300];
      display = cell.op ?? '';
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
      onTap: () {
        _onCellTap(r, c);
      },
      child: Container(
        width: logicalSize,
        height: logicalSize,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: Colors.grey[400]),
        ),
        alignment: Alignment.center,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: logicalSize * 0.06),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              display,
              textAlign: TextAlign.center,
              style: TextStyle(
                // font size is intentionally large; FittedBox will scale it down as needed
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Construye el grid lógico (no scrollable). Será renderizado dentro de InteractiveViewer,
  // que proveerá pan/zoom. Para rendimiento, usamos GridView.builder pero con NeverScrollableScrollPhysics
  // y contenedor de tamaño fijo (cols * logicalSize).
  Widget _buildGrid(double logicalSize) {
    final int rows = puzzle.rows;
    final int cols = puzzle.cols;

    final double totalW = cols * logicalSize;
    final double totalH = rows * logicalSize;

    // GridView.builder dentro de Container de tamaño fijo.
    return Container(
      width: totalW,
      height: totalH,
      child: GridView.builder(
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          childAspectRatio: 1.0,
          mainAxisSpacing: 0,
          crossAxisSpacing: 0,
        ),
        itemCount: rows * cols,
        itemBuilder: (ctx, index) {
          final int r = index ~/ cols;
          final int c = index % cols;
          return _buildCell(r, c, logicalSize);
        },
      ),
    );
  }

  // Banco de números (igual al tuyo pero con tamaños adaptativos)
  Widget _buildBank() {
    if (puzzle == null) return SizedBox.shrink();
    List<int> numbers = puzzle.bankCounts.keys.toList();
    numbers.sort((a, b) => a.compareTo(b));
    return Container(
      padding: EdgeInsets.all(12),
      color: Colors.grey[200],
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: numbers.map((num) {
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
    );
  }

  @override
  Widget build(BuildContext context) {
    // compat: si aún no hay puzzle (cargando), mostramos loader
    if (puzzle == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('CrossMath - ${widget.difficulty.toString().split('.').last.toUpperCase()}'),
          actions: [
            IconButton(icon: Icon(Icons.refresh), onPressed: _generatePuzzle),
          ],
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('CrossMath - ${widget.difficulty.toString().split('.').last.toUpperCase()}'),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _generatePuzzle),
          IconButton(
            icon: Icon(Icons.center_focus_strong),
            tooltip: 'Ajustar al espacio',
            onPressed: () {
              // trigger fit-to-screen: compute using current layout via post-frame callback
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final RenderBox box = context.findRenderObject();
                final Size viewport = box?.constraints?.constrain(Size(double.infinity, double.infinity)) ?? MediaQuery.of(context).size;
                // safer: use MediaQuery for viewport size
                _resetToFit(viewportWidth: MediaQuery.of(context).size.width - 16, viewportHeight: MediaQuery.of(context).size.height - 200);
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          
          Expanded(
            child: Stack(
              children: <Widget>[
                // 1) Tablero en el fondo (InteractiveViewer dentro de ClipRect)
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // viewport disponible para el tablero (consideramos padding)
                      final double viewportW = constraints.maxWidth - 16; // margen lateral
                      final double viewportH = constraints.maxHeight - 16; // margen vertical
          
                      // tamaño lógico del contenido
                      final double contentW = puzzle.cols * _logicalCellSize;
                      final double contentH = puzzle.rows * _logicalCellSize;
          
                      // escala para que el contenido quepa
                      double fitScale = min(viewportW / contentW, viewportH / contentH);
                      fitScale = fitScale.clamp(_minInitialScale, _maxInitialScale);
          
                      // traducción para centrar con un pequeño padding
                      final double translateX = (viewportW - contentW * fitScale) / 2.0 + 8;
                      final double translateY = (viewportH - contentH * fitScale) / 2.0 + 8;
          
                      final Matrix4 initial = Matrix4.identity()
                        ..translate(translateX, translateY)
                        ..scale(fitScale, fitScale);
          
                      // Inicializamos el controller si está en identidad (primer frame)
                      // Nota: comparar matrices por identidad es aceptable para el primer ajuste.
                      final Matrix4 current = _transformationController.value;
                      final bool isIdentity = current == null || current == Matrix4.identity();
                      if (isIdentity) {
                        _transformationController.value = initial;
                      }
          
                      return Padding(
                        padding: EdgeInsets.all(8),
                        child: ClipRect(
                          child: InteractiveViewer(
                            transformationController: _transformationController,
                            panEnabled: true,
                            scaleEnabled: true,
                            
                            boundaryMargin: EdgeInsets.only(
                              left: 2000,
                              right: 2000,
                              bottom: 2000,
                              top: 800,
                            ),
                            
                            minScale: 0.05,
                            maxScale: _maxInitialScale * 6.0,
                            child: _buildGrid(_logicalCellSize),
                          ),
                        ),
                      );
                    },
                  ),
                ),
          
                // 2) Banco en la parte superior (siempre encima)
                //    Ajusta top/left/right para controlar posición y márgenes.
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Material(
                    // Material con elevation para que tenga sombra y se note encima del tablero
                    color: Colors.transparent,
                    elevation: 4.0,
                    child: Container(
                      // Le damos un fondo semitransparente para legibilidad si el tablero pasa por debajo
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _buildBank(),
                    ),
                  ),
                ),
          
                // 3) Indicador inferior (texto), también encima del tablero
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                  ),
                ),
              ],
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
          Text('¡Has completado el Puzzle!', textAlign: TextAlign.center),
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