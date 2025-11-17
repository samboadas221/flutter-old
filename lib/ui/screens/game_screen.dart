
// lib/ui/screens/game_screen.dart
// Compatible with Flutter 1.22 (no null-safety)

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../../data/storage_manager.dart';
import '../widgets/board_widget.dart';
import '../widgets/bank_widget.dart';
import '../widgets/hud.dart';

class _ActionRecord {
  final Coord coord;
  final int previousValue;
  final String source; // 'bank' or 'board'
  _ActionRecord(this.coord, this.previousValue, this.source);
}

class GameScreen extends StatefulWidget {
  final Difficulty difficulty;
  final Puzzle initialPuzzle; // optional: play a specific puzzle

  GameScreen({Key key, this.difficulty = Difficulty.easy, this.initialPuzzle}) : super(key: key);

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  Puzzle _puzzle;
  Timer _timer;
  int _timeSeconds = 0;
  int _moves = 0;
  int _hintsLeft = 3;
  List<_ActionRecord> _undoStack = [];
  bool _loading = true;
  bool _solved = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initGame() async {
    setState(() {
      _loading = true;
    });

    // priority: initialPuzzle -> last saved -> any saved template -> error
    try {
      if (widget.initialPuzzle != null) {
        _puzzle = widget.initialPuzzle.copy();
      } else {
        final stored = await StorageManager.loadLastPuzzle();
        if (stored != null) {
          _puzzle = stored;
        } else {
          
          final templates = await StorageManager.listAllSavedPuzzles();
          if (templates != null && templates.isNotEmpty) {
            final matching = templates.where((p) => p.difficulty == widget.difficulty).toList();
            _puzzle = (matching.isNotEmpty ? matching.first : templates.first).copy();
          } else {
            // Try loading bundled templates from assets (hybrid approach)
            List<Puzzle> assetTemplates = [];
            final difficulty = widget.difficulty ?? Difficulty.easy;
            try {
              if (difficulty == Difficulty.easy) {
                assetTemplates = await Generator.loadTemplatesFromAsset('assets/puzzles/easy_templates.json');
              } else if (difficulty == Difficulty.medium) {
                assetTemplates = await Generator.loadTemplatesFromAsset('assets/puzzles/medium_templates.json');
              } else {
                assetTemplates = await Generator.loadTemplatesFromAsset('assets/puzzles/hard_templates.json');
              }
            } catch (e) {
              assetTemplates = [];
            }
          
            if (assetTemplates != null && assetTemplates.isNotEmpty) {
              // Choose random template then run generator to vary it (hybrid)
              final tpl = assetTemplates[Random().nextInt(assetTemplates.length)].copy();
              // Use the generator to produce a puzzle variant from the template skeleton
              _puzzle = Generator.generateFromSkeleton(tpl, difficulty: difficulty, requireUnique: false, cluePercent: 40);
            } else {
              throw Exception('No puzzle available. Import or create a template first.');
            }
          }
          
        }
      }

      // initialize runtime state for this puzzle
      _timeSeconds = 0;
      _moves = 0;
      _undoStack.clear();
      _hintsLeft = 3;
      _solved = isPuzzleSolved(_puzzle);

      // start timer
      _startTimer();

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
      // show dialog
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Error'),
          content: Text('No puzzle available to start.\\n${e.toString()}'),
          actions: <Widget>[
            FlatButton(
              child: Text('OK'),
              onPressed: () => Navigator.of(ctx).pop(),
            )
          ],
        ),
      );
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      setState(() {
        _timeSeconds++;
      });
    });
  }

  Future<void> _saveProgress() async {
    try {
      await StorageManager.saveLastPuzzle(_puzzle);
      final stats = await StorageManager.loadStats();
      if (stats != null) {
        stats.lastPlayed = DateTime.now().toIso8601String();
        await StorageManager.saveStats(stats);
      }
    } catch (e) {
      // ignore save errors
    }
  }

  void _pushUndo(Coord coord, int prevValue, String source) {
    _undoStack.add(_ActionRecord(coord, prevValue, source));
    if (_undoStack.length > 200) _undoStack.removeAt(0);
  }

  // place a value coming from bank into coord
  void _onPlace(Coord coord, int value, String source) async {
    if (_busy) return;
    setState(() {
      _busy = true;
    });

    final cell = _puzzle.cells[coord];
    if (cell == null || !cell.isNumber || cell.fixed) {
      setState(() {
        _busy = false;
      });
      return;
    }
    final prev = cell.value;
    // consume from bank
    if (!_puzzle.bank.contains(value)) {
      setState(() {
        _busy = false;
      });
      return;
    }
    _puzzle.bank.use(value);
    _puzzle.placeNumber(coord.r, coord.c, value, markAsFixed: false);
    _moves++;
    _pushUndo(coord, prev, source ?? 'bank');
    await _saveProgress();
    setState(() {
      _busy = false;
      _solved = isPuzzleSolved(_puzzle);
    });
    if (_solved) _onSolved();
  }

  // swap values between two board coords
  void _onSwap(Coord from, Coord to) async {
    if (_busy) return;
    setState(() {
      _busy = true;
    });
    final fromCell = _puzzle.cells[from];
    final toCell = _puzzle.cells[to];
    if (fromCell == null || toCell == null) {
      setState(() {
        _busy = false;
      });
      return;
    }
    final prevFrom = fromCell.value;
    final prevTo = toCell.value;
    // do swap
    fromCell.value = prevTo;
    toCell.value = prevFrom;
    _moves++;
    // store undo as two records (reverse op will swap back)
    _pushUndo(from, prevFrom, 'board');
    _pushUndo(to, prevTo, 'board');
    await _saveProgress();
    setState(() {
      _busy = false;
      _solved = isPuzzleSolved(_puzzle);
    });
    if (_solved) _onSolved();
  }

  void _onTapCell(Coord pos) {
    // optional: implement quick remove by tapping non-fixed number cell -> return to bank
    final cell = _puzzle.cells[pos];
    if (cell == null) return;
    if (cell.isNumber && cell.value != null && !cell.fixed) {
      final prev = cell.value;
      cell.value = null;
      _puzzle.bank.put(prev);
      _moves++;
      _pushUndo(pos, prev, 'remove');
      _saveProgress();
      setState(() {
        _solved = isPuzzleSolved(_puzzle);
      });
    }
  }

  void _onUndo() async {
    if (_undoStack.isEmpty) return;
    final rec = _undoStack.removeLast();
    final cell = _puzzle.cells[rec.coord];
    if (cell == null) return;
    // rec.source tells if previous action was bank->cell or board swap or removal
    // We will simply restore previousValue and adjust bank accordingly.
    final current = cell.value;
    // restore
    cell.value = rec.previousValue;
    // if previousValue was null and current not null and source was bank, return current to bank
    if (rec.previousValue == null && current != null) {
      _puzzle.bank.put(current);
    } else if (rec.previousValue != null && current == null) {
      // we restored a number from before, remove one from bank
      if (_puzzle.bank.contains(rec.previousValue)) {
        _puzzle.bank.use(rec.previousValue);
      }
    }
    _moves = (_moves > 0) ? _moves - 1 : 0;
    await _saveProgress();
    setState(() {
      _solved = isPuzzleSolved(_puzzle);
    });
  }

  Future<void> _onHint() async {
    if (_hintsLeft <= 0) return;
    setState(() {
      _busy = true;
    });
    // Solve to get a legal solution
    final sols = Solver.solve(_puzzle, maxSolutions: 1);
    if (sols == null || sols.isEmpty) {
      setState(() {
        _busy = false;
      });
      return;
    }
    final solution = sols.first;
    // find a coord to reveal (empty number cell)
    Coord reveal;
    solution.cells.forEach((coord, cell) {
      if (reveal != null) return;
      final myCell = _puzzle.cells[coord];
      if (myCell != null && myCell.isNumber && myCell.value == null) reveal = coord;
    });
    if (reveal == null) {
      setState(() {
        _busy = false;
      });
      return;
    }
    final val = solution.cells[reveal].value as int;
    // place it: ensure bank contains that value (if not, we still place and do not touch bank)
    if (_puzzle.bank.contains(val)) _puzzle.bank.use(val);
    _puzzle.placeNumber(reveal.r, reveal.c, val, markAsFixed: true);
    _hintsLeft--;
    _moves++;
    _pushUndo(reveal, null, 'hint');
    await _saveProgress();
    setState(() {
      _busy = false;
      _solved = isPuzzleSolved(_puzzle);
    });
    if (_solved) _onSolved();
  }

  Future<void> _onCheck() async {
    final solved = isPuzzleSolved(_puzzle);
    if (solved) {
      await _onSolved();
    } else {
      Scaffold.of(context).showSnackBar(SnackBar(content: Text('Aún no está correcto')));
    }
  }

  Future<void> _onSolved() async {
    if (_solved) {
      // already handled
    }
    setState(() {
      _solved = true;
    });
    _timer?.cancel();
    // update stats
    try {
      final stats = await StorageManager.loadStats() ?? StatsModel();
      final key = difficultyToString(_puzzle.difficulty ?? widget.difficulty);
      stats.timePlayedSeconds = (stats.timePlayedSeconds ?? 0) + _timeSeconds;
      stats.solvedPerDifficulty[key] = (stats.solvedPerDifficulty[key] ?? 0) + 1;
      final best = stats.bestTimes[key] ?? 0;
      if (best == 0 || _timeSeconds < best) stats.bestTimes[key] = _timeSeconds;
      stats.lastPlayed = DateTime.now().toIso8601String();
      await StorageManager.saveStats(stats);
    } catch (e) {
      // ignore
    }
    // show dialog
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¡Puzzle resuelto!'),
        content: Text('Tiempo: ${_formatTime(_timeSeconds)}\\nMovimientos: $_moves'),
        actions: <Widget>[
          FlatButton(child: Text('OK'), onPressed: () => Navigator.of(ctx).pop())
        ],
      ),
    );
  }

  String _formatTime(int s) {
    final mins = s ~/ 60;
    final secs = s % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _onReset() async {
    // reload original puzzle state if metadata id exists
    try {
      final orig = await StorageManager.loadPuzzleFromFileById(_puzzle.metadata?.id ?? '');
      if (orig != null) {
        setState(() {
          _puzzle = orig.copy();
          _moves = 0;
          _timeSeconds = 0;
          _hintsLeft = 3;
          _undoStack.clear();
          _solved = isPuzzleSolved(_puzzle);
        });
        await _saveProgress();
        return;
      }
    } catch (e) {}
    // fallback: clear all non-fixed number cells and rebuild bank from hidden values if possible
    final hidden = <int>[];
    _puzzle.cells.forEach((coord, cell) {
      if (cell.isNumber) {
        if (!cell.fixed) {
          if (cell.value != null) {
            hidden.add(cell.value);
            cell.value = null;
          }
        } else {
          // keep fixed
        }
      }
    });
    _puzzle.bank = Bank.fromList(hidden);
    setState(() {
      _moves = 0;
      _timeSeconds = 0;
      _hintsLeft = 3;
      _undoStack.clear();
      _solved = isPuzzleSolved(_puzzle);
    });
    await _saveProgress();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Cargando...')),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_puzzle == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Juego')),
        body: Center(child: Text('No hay puzzle disponible.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('CrossMath - ${difficultyToString(_puzzle.difficulty ?? widget.difficulty)}')),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(padding: EdgeInsets.all(8.0), child: HudWidget(
              timeSeconds: _timeSeconds,
              moves: _moves,
              hintsLeft: _hintsLeft,
              bestTime: null,
              onUndo: _onUndo,
              onHint: _onHint,
              onCheck: _onCheck,
              onReset: _onReset,
              onPause: () async {
                await _saveProgress();
                Scaffold.of(context).showSnackBar(SnackBar(content: Text('Progreso guardado')));
              },
            )),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: BoardWidget(
                      puzzle: _puzzle,
                      cellSize: 56.0,
                      onPlace: (coord, value, source) => _onPlace(coord, value, source),
                      onSwap: (from, to) => _onSwap(from, to),
                      onTap: (pos) => _onTapCell(pos),
                    ),
                  ),
                ),
              ),
            ),
            BankWidget(
              bank: _puzzle.bank,
              tileSize: 56.0,
              onTap: (v) {
                // optional quick-place: find first empty cell that accepts the number
                Coord target;
                for (var l in _puzzle.lines) {
                  for (var c in l.operandCoords) {
                    final cell = _puzzle.cells[c];
                    if (cell != null && cell.isNumber && cell.value == null && !cell.fixed) {
                      final temp = _puzzle.copy();
                      temp.cells[c].value = v;
                      if (canPlaceNumber(temp, c, v)) {
                        target = c;
                        break;
                      }
                    }
                  }
                  if (target != null) break;
                }
                if (target != null) _onPlace(target, v, 'bank');
              },
            ),
            SizedBox(height: 8.0),
          ],
        ),
      ),
    );
  }
}