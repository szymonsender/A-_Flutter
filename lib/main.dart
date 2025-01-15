import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey, RawKeyDownEvent, RawKeyEvent, rootBundle;

void main() {
  runApp(const MyApp());
}

/// Główna aplikacja
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'A* Demo - Desktop z Klawiaturą',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
      ),
      home: const AStarDemoPage(),
    );
  }
}

/// Tryby edycji (start, cel, punkt pośredni, przeszkody)
enum EditMode {
  start,
  goal,
  waypoint,   // punkt pośredni
  obstacle,   // toggle przeszkód
}

class AStarDemoPage extends StatefulWidget {
  const AStarDemoPage({Key? key}) : super(key: key);

  @override
  State<AStarDemoPage> createState() => _AStarDemoPageState();
}

class _AStarDemoPageState extends State<AStarDemoPage> with SingleTickerProviderStateMixin {
  late List<List<int>> grid;
  int rows = 0;
  int cols = 0;

  // Punkty kluczowe
  Point<int> start = const Point(0, 0);
  Point<int> goal = const Point(19, 19);
  Point<int>? forcedPoint; // punkt pośredni (opcjonalny)

  // Animacja
  AnimationController? _animationController;
  List<Point<int>> _path = [];
  int _currentStep = 0;
  Timer? _timer;

  // Tryb edycji
  EditMode _editMode = EditMode.obstacle;

  // Kursor (pozycja „logiczna” na mapie, obsługiwana strzałkami)
  Point<int> _cursorPosition = const Point(0, 0);

  // FocusNode do obsługi klawiatury
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _loadGridFromFile('assets/grid');
    _animationController = AnimationController(vsync: this, duration: const Duration(seconds: 1));

    // Przygotowanie FocusNode do obsługi klawiatury
    _focusNode = FocusNode();
    // Automatyczne przejęcie fokusu (czasem trzeba kliknąć w okno, by zadziałało)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  /// Wczytuje siatkę z pliku
  Future<void> _loadGridFromFile(String path) async {
    final data = await rootBundle.loadString(path);
    final lines = data.split('\n');

    List<List<int>> tempGrid = [];
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      final values = line.split(' ');
      tempGrid.add(values.map(int.parse).toList());
    }

    setState(() {
      // Odwracamy, by "0,0" było na dole
      grid = tempGrid.reversed.toList();

      rows = grid.length;
      cols = grid.isNotEmpty ? grid[0].length : 0;

      // Reset punktów
      start = const Point(0, 0);
      goal = Point(cols - 1, rows - 1);
      forcedPoint = null;
      _path.clear();
      _currentStep = 0;
      _timer?.cancel();

      // Kursor też ustaw na (0,0) (lub gdzie chcesz)
      _cursorPosition = const Point(0, 0);
    });
  }

  /// Reset
  void _resetGrid() {
    _loadGridFromFile('assets/grid');
  }

  /// Uruchom A* (z uwzględnieniem punktu pośredniego)
  Future<void> _runAStar() async {
    // Wyczyść poprzednią trasę
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        if (grid[y][x] == 3) {
          grid[y][x] = 0;
        }
      }
    }

    // Jeśli brak forcedPoint, proste start -> goal
    if (forcedPoint == null) {
      final path = await aStar(grid: grid, start: start, goal: goal);
      if (path.isEmpty) {
        _showNoPathMessage();
        return;
      }
      _markPathAndAnimate(path);
    } else {
      // Z punkt pośrednim: start->forcedPoint, forcedPoint->goal
      final path1 = await aStar(grid: grid, start: start, goal: forcedPoint!);
      if (path1.isEmpty) {
        _showNoPathMessage();
        return;
      }
      final path2 = await aStar(grid: grid, start: forcedPoint!, goal: goal);
      if (path2.isEmpty) {
        _showNoPathMessage();
        return;
      }
      // Połącz
      final combinedPath = [...path1, ...path2.skip(1)];
      _markPathAndAnimate(combinedPath);
    }
  }

  void _markPathAndAnimate(List<Point<int>> path) {
    setState(() {
      _path = path;
      for (final p in path) {
        if (grid[p.y][p.x] == 0) {
          grid[p.y][p.x] = 3;
        }
      }
      _currentStep = 0;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_currentStep < _path.length - 1) {
        setState(() {
          _currentStep++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _showNoPathMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Brak możliwej ścieżki!')),
    );
  }

  void _stopAnimation() {
    _timer?.cancel();
    setState(() {
      _currentStep = 0;
    });
  }

  /// Reakcja na klik myszą
  void _onTapCell(int x, int y) {
    setState(() {
      switch (_editMode) {
        case EditMode.start:
          start = Point(x, y);
          break;
        case EditMode.goal:
          goal = Point(x, y);
          break;
        case EditMode.waypoint:
          forcedPoint = Point(x, y);
          break;
        case EditMode.obstacle:
          final currentVal = grid[y][x];
          if (currentVal == 5) {
            grid[y][x] = 0;
          } else if (currentVal == 0 || currentVal == 3) {
            grid[y][x] = 5;
          }
          break;
      }
    });
  }

  /// Obsługa klawiszy
  void _handleKey(RawKeyEvent event) {
    // Tylko przy naciśnięciu (pomijamy key up, repeated, itp.)
    if (event is! RawKeyDownEvent) return;

    final key = event.logicalKey;
    int x = _cursorPosition.x;
    int y = _cursorPosition.y;

    // Reaguj na strzałki
    if (key == LogicalKeyboardKey.arrowUp) {
      // w górę => y + 1 (o ile w granicach)
      if (y + 1 < rows) {
        setState(() => _cursorPosition = Point(x, y + 1));
      }
    } else if (key == LogicalKeyboardKey.arrowDown) {
      if (y - 1 >= 0) {
        setState(() => _cursorPosition = Point(x, y - 1));
      }
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      if (x - 1 >= 0) {
        setState(() => _cursorPosition = Point(x - 1, y));
      }
    } else if (key == LogicalKeyboardKey.arrowRight) {
      if (x + 1 < cols) {
        setState(() => _cursorPosition = Point(x + 1, y));
      }
    } else if (key == LogicalKeyboardKey.space) {
      // Spacja = wybierz bądź toggluj według aktualnego trybu
      // Zamiast klikać myszą
      _onTapCell(_cursorPosition.x, _cursorPosition.y);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (rows == 0 || cols == 0) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('A* Demo - Ładowanie...'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('A* (Desktop) - Szymon Sender'),
      ),
      // RawKeyboardListener pozwala przechwycić klawisze
      body: RawKeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKey: _handleKey,
        child: Stack(
          children: [
            // Tło
            Container(
              decoration: const BoxDecoration(color: Colors.white),
            ),
            // Główny widok siatki
            Center(
              child: AspectRatio(
                aspectRatio: cols / rows,
                child: GestureDetector(
                  onTapDown: (details) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box == null) return;
                    final localPos = box.globalToLocal(details.globalPosition);
                    final cellSize = box.size.width / cols;

                    final dx = (localPos.dx / cellSize).floor();
                    final dy = rows - 1 - (localPos.dy / cellSize).floor();

                    if (dx >= 0 && dx < cols && dy >= 0 && dy < rows) {
                      _onTapCell(dx, dy);
                    }
                  },
                  child: CustomPaint(
                    painter: GridPainter(
                      grid: grid,
                      rows: rows,
                      cols: cols,
                      start: start,
                      goal: goal,
                      waypoint: forcedPoint,
                      path: _path,
                      currentStep: _currentStep,
                      cursor: _cursorPosition,  // <-- Nowe: pozycja kursora
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: Colors.white70,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            focusNode: FocusNode(skipTraversal: true),
            onPressed: _runAStar,
            child: const Text('Uruchom A*'),
          ),
          ElevatedButton(
            focusNode: FocusNode(skipTraversal: true),
            onPressed: _stopAnimation,
            child: const Text('Stop'),
          ),
          ElevatedButton(
            focusNode: FocusNode(skipTraversal: true),
            onPressed: _resetGrid,
            child: const Text('Reset'),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Tryb:'),
              const SizedBox(width: 4),
              ChoiceChip(
                focusNode: FocusNode(skipTraversal: true),
                label: const Text('Start'),
                selected: _editMode == EditMode.start,
                onSelected: (_) => setState(() => _editMode = EditMode.start),
              ),
              const SizedBox(width: 4),
              ChoiceChip(
                focusNode: FocusNode(skipTraversal: true),
                label: const Text('Cel'),
                selected: _editMode == EditMode.goal,
                onSelected: (_) => setState(() => _editMode = EditMode.goal),
              ),
              const SizedBox(width: 4),
              ChoiceChip(
                focusNode: FocusNode(skipTraversal: true),
                label: const Text('Pośredni'),
                selected: _editMode == EditMode.waypoint,
                onSelected: (_) => setState(() => _editMode = EditMode.waypoint),
              ),
              const SizedBox(width: 4),
              ChoiceChip(
                focusNode: FocusNode(skipTraversal: true),
                label: const Text('Przeszkody'),
                selected: _editMode == EditMode.obstacle,
                onSelected: (_) => setState(() => _editMode = EditMode.obstacle),
              ),
            ],
          )
        ],
      ),
    );
  }


  @override
  void dispose() {
    _timer?.cancel();
    _animationController?.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

/// Rysowanie siatki, trasy, kursora
class GridPainter extends CustomPainter {
  final List<List<int>> grid;
  final int rows;
  final int cols;
  final Point<int> start;
  final Point<int> goal;
  final Point<int>? waypoint;
  final List<Point<int>> path;
  final int currentStep;

  // Nowe: Pozycja logicznego kursora
  final Point<int> cursor;

  GridPainter({
    required this.grid,
    required this.rows,
    required this.cols,
    required this.start,
    required this.goal,
    required this.waypoint,
    required this.path,
    required this.currentStep,
    required this.cursor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final double cellWidth = size.width / cols;
    final double cellHeight = size.height / rows;

    // Przeszkody (5) / trasa (3)
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        final val = grid[y][x];
        Color color;
        if (val == 5) {
          color = Colors.black.withOpacity(0.7);
        } else if (val == 3) {
          color = Colors.green.withOpacity(0.4);
        } else {
          color = Colors.transparent;
        }
        paint.color = color;

        final rect = Rect.fromLTWH(
          x * cellWidth,
          (rows - 1 - y) * cellHeight,
          cellWidth,
          cellHeight,
        );
        canvas.drawRect(rect, paint);
      }
    }

    // Linie siatki (opcjonalne)
    final linePaint = Paint()
      ..color = Colors.grey.withOpacity(0.5)
      ..strokeWidth = 1;
    for (int i = 0; i <= cols; i++) {
      final dx = i * cellWidth;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), linePaint);
    }
    for (int j = 0; j <= rows; j++) {
      final dy = j * cellHeight;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), linePaint);
    }

    // Start (czerwony)
    paint.color = Colors.red.withOpacity(0.7);
    final startRect = Rect.fromLTWH(
      start.x * cellWidth,
      (rows - 1 - start.y) * cellHeight,
      cellWidth,
      cellHeight,
    );
    canvas.drawRect(startRect, paint);

    // Cel (niebieski)
    paint.color = Colors.blue.withOpacity(0.7);
    final goalRect = Rect.fromLTWH(
      goal.x * cellWidth,
      (rows - 1 - goal.y) * cellHeight,
      cellWidth,
      cellHeight,
    );
    canvas.drawRect(goalRect, paint);

    // Punkt pośredni (fioletowy)
    if (waypoint != null) {
      paint.color = Colors.purple.withOpacity(0.7);
      final wpRect = Rect.fromLTWH(
        waypoint!.x * cellWidth,
        (rows - 1 - waypoint!.y) * cellHeight,
        cellWidth,
        cellHeight,
      );
      canvas.drawRect(wpRect, paint);
    }

    // Animowany "agent" (żółte kółko) na ścieżce
    if (path.isNotEmpty && currentStep < path.length) {
      final agentPoint = path[currentStep];
      final centerX = (agentPoint.x + 0.5) * cellWidth;
      final centerY = (rows - 1 - agentPoint.y + 0.5) * cellHeight;
      paint.color = Colors.yellow;
      canvas.drawCircle(
        Offset(centerX, centerY),
        min(cellWidth, cellHeight) * 0.35,
        paint,
      );
    }

    // Rysowanie "kursora" (pomarańczowe zaznaczenie)
    // To logiczna kratka, którą można wybrać klawiszem spacji.
    paint.color = Colors.orange.withOpacity(0.4);
    final cursorRect = Rect.fromLTWH(
      cursor.x * cellWidth,
      (rows - 1 - cursor.y) * cellHeight,
      cellWidth,
      cellHeight,
    );
    canvas.drawRect(cursorRect, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

/// Struktura węzła A*
class Node {
  final int x;
  final int y;
  double g;
  double h;
  double get f => g + h;
  Node? parent;

  Node({
    required this.x,
    required this.y,
    required this.g,
    required this.h,
    this.parent,
  });
}

/// Dystans Euklidesowy
double _euclideanDistance(Point<int> a, Point<int> b) {
  return sqrt(pow((b.x - a.x), 2) + pow((b.y - a.y), 2));
}

/// Implementacja A*
Future<List<Point<int>>> aStar({
  required List<List<int>> grid,
  required Point<int> start,
  required Point<int>? goal,
}) async {
  if (goal == null) return [];

  final openList = <Node>[];
  final closedList = <Node>[];

  final startNode = Node(
    x: start.x,
    y: start.y,
    g: 0.0,
    h: _euclideanDistance(start, goal),
  );
  openList.add(startNode);


    while (openList.isNotEmpty) {
      openList.sort((a, b) => a.f.compareTo(b.f));
      final max = openList.where((n) => n.f == openList[0].f).length;
      final current = openList.removeAt(max - 1);
      closedList.add(current);


    if (current.x == goal.x && current.y == goal.y) {
      return _reconstructPath(current);
    }

    final neighbors = _getNeighbors(current.x, current.y, grid);
    for (final n in neighbors) {
      if (grid[n.y][n.x] == 5 ||
          closedList.any((c) => c.x == n.x && c.y == n.y)) {
        continue;
      }
      final tentativeG = current.g + 1;
      final existing = openList.firstWhere(
            (o) => o.x == n.x && o.y == n.y,
        orElse: () => Node(x: -1, y: -1, g: double.infinity, h: double.infinity),
      );
      if (existing.x == -1 || tentativeG < existing.g) {
        final hVal = _euclideanDistance(Point(n.x, n.y), goal);
        final newNode = Node(
          x: n.x,
          y: n.y,
          g: tentativeG,
          h: hVal,
          parent: current,
        );
        if (existing.x == -1) {
          openList.add(newNode);
        } else {
          existing.g = tentativeG;
          existing.h = hVal;
          existing.parent = current;
        }
      }
    }
  }

  return [];
}

/// Sąsiedzi w 4 kierunkach
List<Point<int>> _getNeighbors(int x, int y, List<List<int>> grid) {
  final neighbors = <Point<int>>[];

  // góra, dół, lewo, prawo
  if (x - 1 >= 0) {
    neighbors.add(Point(x - 1, y));
  }
  if (x + 1 < grid[0].length) {
    neighbors.add(Point(x + 1, y));
  }
  if (y - 1 >= 0) {
    neighbors.add(Point(x, y - 1));
  }
  if (y + 1 < grid.length) {
    neighbors.add(Point(x, y + 1));
  }

  return neighbors;
}

/// Odtwarzanie ścieżki
List<Point<int>> _reconstructPath(Node goalNode) {
  final path = <Point<int>>[];
  Node? current = goalNode;
  while (current != null) {
    path.add(Point(current.x, current.y));
    current = current.parent;
  }
  return path.reversed.toList();
}

