import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const TetrisApp());
}

class TetrisApp extends StatelessWidget {
  const TetrisApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tetris tannenbusch',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF184D49), brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF184D49),
        useMaterial3: true,
      ),
      home: const TetrisHome(),
    );
  }
}

class TetrisHome extends StatefulWidget {
  const TetrisHome({super.key});
  @override
  State<TetrisHome> createState() => _TetrisHomeState();
}

class _TetrisHomeState extends State<TetrisHome> {
  static const int w = 10;
  static const int h = 20;
  List<List<Color?>> board = List.generate(h, (_) => List.filled(w, null));
  _Piece? active;
  _Piece? nextPiece;
  int score = 0;
  int lines = 0;
  int level = 1;
  Timer? timer;
  bool gameOver = false;
  final Random _rng = Random();
  bool logoReady = false;

  @override
  void initState() {
    super.initState();
    nextPiece = _randomPiece();
    _spawn();
    _startTimer();
    _loadLogo();
  }

  Future<void> _loadLogo() async {
    try {
      await rootBundle.load('assets/logo.png');
      setState(() {
        logoReady = true;
      });
    } catch (_) {
      logoReady = false;
    }
  }

  void _startTimer() {
    timer?.cancel();
    int ms = max(100, 800 - (level - 1) * 60);
    timer = Timer.periodic(Duration(milliseconds: ms), (_) => _tick());
  }

  void _tick() {
    if (gameOver) return;
    if (!_tryMove(0, 1, active!.rot)) {
      _lock();
      _clearLines();
      _spawn();
    }
  }

  _Piece _randomPiece() {
    int i = _rng.nextInt(_Piece.shapes.length);
    var s = _Piece.shapes[i];
    return _Piece(shape: s.$1, color: s.$2, pos: Point<int>(w ~/ 2 - 2, 0), rot: 0);
  }

  void _spawn() {
    active = nextPiece ?? _randomPiece();
    nextPiece = _randomPiece();
    active = _Piece(shape: active!.shape, color: active!.color, pos: Point<int>(w ~/ 2 - 2, 0), rot: 0);
    if (!_canPlace(active!)) {
      gameOver = true;
      timer?.cancel();
    }
    setState(() {});
  }

  bool _canPlace(_Piece p) {
    for (var cell in p.cells) {
      int x = p.pos.x + cell.x;
      int y = p.pos.y + cell.y;
      if (x < 0 || x >= w || y < 0 || y >= h) return false;
      if (board[y][x] != null) return false;
    }
    return true;
  }

  bool _tryMove(int dx, int dy, int rot) {
    var test = _Piece(shape: active!.shape, color: active!.color, pos: Point<int>(active!.pos.x + dx, active!.pos.y + dy), rot: rot);
    if (_canPlace(test)) {
      active = test;
      setState(() {});
      return true;
    }
    return false;
  }

  void _rotate() {
    int r = (active!.rot + 1) % active!.shape.length;
    if (!_tryMove(0, 0, r)) {
      if (_tryMove(1, 0, r)) return;
      if (_tryMove(-1, 0, r)) return;
    }
  }

  void _lock() {
    for (var c in active!.cells) {
      int x = active!.pos.x + c.x;
      int y = active!.pos.y + c.y;
      if (y >= 0 && y < h && x >= 0 && x < w) {
        board[y][x] = active!.color;
      }
    }
  }

  void _clearLines() {
    int cleared = 0;
    for (int y = h - 1; y >= 0; y--) {
      if (board[y].every((c) => c != null)) {
        board.removeAt(y);
        board.insert(0, List.filled(w, null));
        cleared++;
        y++;
      }
    }
    if (cleared > 0) {
      lines += cleared;
      score += [0, 100, 300, 500, 800][min(cleared, 4)];
      level = 1 + lines ~/ 10;
      _startTimer();
    }
    setState(() {});
  }

  void _hardDrop() {
    while (_tryMove(0, 1, active!.rot)) {}
    _lock();
    _clearLines();
    _spawn();
  }

  void _onKey(KeyEvent e) {
    if (gameOver) return;
    if (e is KeyDownEvent) {
      final k = e.logicalKey;
      if (k == LogicalKeyboardKey.arrowLeft) {
        _tryMove(-1, 0, active!.rot);
      } else if (k == LogicalKeyboardKey.arrowRight) {
        _tryMove(1, 0, active!.rot);
      } else if (k == LogicalKeyboardKey.arrowDown) {
        _tryMove(0, 1, active!.rot);
      } else if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.keyZ) {
        _rotate();
      } else if (k == LogicalKeyboardKey.space) {
        _hardDrop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color bg = Color(0xFF184D49);
    const Color frame = Color(0xFF113A36);
    const Color panel = Color(0xFFF2EFE6);
    const Color accent = Color(0xFFE8962E);

    Widget boardView = LayoutBuilder(builder: (context, constraints) {
      double maxW = constraints.maxWidth;
      double maxH = constraints.maxHeight;
      double boardMaxW = maxW * 0.68;
      double boardMaxH = maxH * 0.86;
      double cell = min(boardMaxW / w, boardMaxH / h);
      double bw = cell * w;
      double bh = cell * h;
      return Center(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: panel, border: Border.all(color: frame, width: 8)),
          child: SizedBox(
            width: bw,
            height: bh,
            child: CustomPaint(
              painter: _BoardPainter(board: board, active: active, empty: panel, grid: frame, badge: const Color(0xFF0E3A34)),
            ),
          ),
        ),
      );
    });

    bool isDesktop = defaultTargetPlatform == TargetPlatform.macOS;
    List<Widget> controls = isDesktop
        ? []
        : [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: () => _tryMove(-1, 0, active!.rot), child: const Icon(Icons.arrow_left)),
                ElevatedButton(onPressed: _rotate, child: const Icon(Icons.rotate_right)),
                ElevatedButton(onPressed: () => _tryMove(1, 0, active!.rot), child: const Icon(Icons.arrow_right)),
                ElevatedButton(onPressed: () => _tryMove(0, 1, active!.rot), child: const Icon(Icons.arrow_downward)),
                ElevatedButton(onPressed: _hardDrop, child: const Icon(Icons.file_download)),
              ],
            )
          ];

    Widget sidebar = SizedBox(
      width: 220,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.transparent, border: Border.all(color: frame, width: 6)),
            child: Column(
              children: [
                Text('SCORE', style: TextStyle(color: accent, fontWeight: FontWeight.w800, letterSpacing: 2)),
                const SizedBox(height: 8),
                Text('$score', style: const TextStyle(color: Colors.tealAccent, fontSize: 28, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.transparent, border: Border.all(color: frame, width: 6)),
            child: Column(
              children: [
                Text('NEXT', style: TextStyle(color: accent, fontWeight: FontWeight.w800, letterSpacing: 2)),
                const SizedBox(height: 12),
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CustomPaint(painter: _PreviewPainter(piece: nextPiece, empty: panel, grid: frame)),
                ),
              ],
            ),
          ),
          if (gameOver)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ElevatedButton(onPressed: _reset, child: const Text('Restart')),
            ),
        ],
      ),
    );

    Widget footer = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('tet', style: TextStyle(color: accent, fontSize: 28, fontWeight: FontWeight.bold)),
            Text('ris', style: TextStyle(color: accent, fontSize: 28, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(width: 16),
          const Expanded(child: Text('tannenbusch', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700))),
          if (logoReady)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Image.asset('assets/logo.png', width: 72, height: 48, fit: BoxFit.contain),
            ),
        ],
      ),
    );

    Widget content = Container(
      color: bg,
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: boardView),
                sidebar,
              ],
            ),
          ),
          footer,
          ...controls,
        ],
      ),
    );
    Widget wrapped = isDesktop
        ? KeyboardListener(focusNode: FocusNode(), autofocus: true, onKeyEvent: _onKey, child: content)
        : content;
    return Scaffold(body: wrapped);
  }

  void _reset() {
    board = List.generate(h, (_) => List.filled(w, null));
    score = 0;
    lines = 0;
    level = 1;
    gameOver = false;
    nextPiece = _randomPiece();
    _spawn();
    _startTimer();
    setState(() {});
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }
}

class _BoardPainter extends CustomPainter {
  final List<List<Color?>> board;
  final _Piece? active;
  final Color empty;
  final Color grid;
  final Color badge;
  _BoardPainter({required this.board, required this.active, required this.empty, required this.grid, required this.badge});
  @override
  void paint(Canvas canvas, Size size) {
    double cell = min(size.width / _TetrisDims.w, size.height / _TetrisDims.h);
    Paint border = Paint()
      ..color = grid
      ..style = PaintingStyle.stroke;
    for (int y = 0; y < _TetrisDims.h; y++) {
      for (int x = 0; x < _TetrisDims.w; x++) {
        Rect r = Rect.fromLTWH(x * cell, y * cell, cell, cell);
        final Color fill = board[y][x] ?? empty;
        canvas.drawRect(r, Paint()..color = fill);
        canvas.drawRect(r.deflate(1), border);
        if (board[y][x] != null && _isDark(fill)) {
          _drawBadge(canvas, r);
        }
      }
    }
    if (active != null) {
      for (var c in active!.cells) {
        int ax = active!.pos.x + c.x;
        int ay = active!.pos.y + c.y;
        if (ax >= 0 && ax < _TetrisDims.w && ay >= 0 && ay < _TetrisDims.h) {
          Rect r = Rect.fromLTWH(ax * cell, ay * cell, cell, cell);
          canvas.drawRect(r, Paint()..color = active!.color);
          if (_isDark(active!.color)) {
            _drawBadge(canvas, r);
          }
        }
      }
    }
  }

  bool _isDark(Color c) {
    return c.computeLuminance() < 0.25;
  }

  void _drawBadge(Canvas canvas, Rect r) {
    double s = min(r.width, r.height);
    Rect inner = Rect.fromCenter(center: r.center, width: s * 0.62, height: s * 0.62);
    RRect rr = RRect.fromRectAndRadius(inner, Radius.circular(s * 0.08));
    canvas.drawRRect(rr, Paint()..color = badge);
    double dotR = inner.height * 0.1;
    Offset dotC = Offset(inner.left + inner.width * 0.18, inner.center.dy);
    canvas.drawCircle(dotC, dotR, Paint()..color = Colors.white.withOpacity(0.95));
    final textPainter = TextPainter(
      text: const TextSpan(text: 'D', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(minWidth: 0, maxWidth: inner.width);
    double f = inner.height * 0.52;
    final tp = TextPainter(
      text: TextSpan(text: 'D', style: TextStyle(color: Colors.white, fontSize: f, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    Offset pos = Offset(inner.left + inner.width * 0.34 - tp.width * 0.5, inner.top + (inner.height - tp.height) / 2);
    tp.paint(canvas, pos);
  }
  @override
  bool shouldRepaint(covariant _BoardPainter oldDelegate) {
    return true;
  }
}

class _TetrisDims {
  static const int w = 10;
  static const int h = 20;
}

class _PreviewPainter extends CustomPainter {
  final _Piece? piece;
  final Color empty;
  final Color grid;
  _PreviewPainter({required this.piece, required this.empty, required this.grid});
  @override
  void paint(Canvas canvas, Size size) {
    const int gw = 4;
    const int gh = 4;
    double cell = min(size.width / gw, size.height / gh);
    Paint border = Paint()
      ..color = grid
      ..style = PaintingStyle.stroke;
    for (int y = 0; y < gh; y++) {
      for (int x = 0; x < gw; x++) {
        Rect r = Rect.fromLTWH(x * cell, y * cell, cell, cell);
        canvas.drawRect(r, Paint()..color = empty);
        canvas.drawRect(r.deflate(1), border);
      }
    }
    if (piece == null) return;
    for (var c in piece!.shape[0]) {
      int ax = c.x;
      int ay = c.y;
      Rect r = Rect.fromLTWH(ax * cell, ay * cell, cell, cell);
      canvas.drawRect(r, Paint()..color = piece!.color);
    }
  }
  @override
  bool shouldRepaint(covariant _PreviewPainter oldDelegate) {
    return true;
  }
}

class _Piece {
  final List<List<Point<int>>> shape;
  final Color color;
  final Point<int> pos;
  final int rot;
  _Piece({required this.shape, required this.color, required this.pos, required this.rot});
  List<Point<int>> get cells => shape[rot];
  static final List<(List<List<Point<int>>>, Color)> shapes = [
    ([
      [Point(0, 1), Point(1, 1), Point(2, 1), Point(3, 1)],
      [Point(2, 0), Point(2, 1), Point(2, 2), Point(2, 3)],
      [Point(0, 2), Point(1, 2), Point(2, 2), Point(3, 2)],
      [Point(1, 0), Point(1, 1), Point(1, 2), Point(1, 3)],
    ], const Color(0xFF2EBB6C)),
    ([
      [Point(1, 0), Point(2, 0), Point(1, 1), Point(2, 1)],
      [Point(1, 0), Point(2, 0), Point(1, 1), Point(2, 1)],
      [Point(1, 0), Point(2, 0), Point(1, 1), Point(2, 1)],
      [Point(1, 0), Point(2, 0), Point(1, 1), Point(2, 1)],
    ], const Color(0xFF3FAE64)),
    ([
      [Point(1, 0), Point(0, 1), Point(1, 1), Point(2, 1)],
      [Point(1, 0), Point(1, 1), Point(2, 1), Point(1, 2)],
      [Point(0, 1), Point(1, 1), Point(2, 1), Point(1, 2)],
      [Point(1, 0), Point(0, 1), Point(1, 1), Point(1, 2)],
    ], const Color(0xFF49C277)),
    ([
      [Point(0, 1), Point(1, 1), Point(2, 1), Point(2, 0)],
      [Point(1, 0), Point(1, 1), Point(1, 2), Point(2, 2)],
      [Point(0, 2), Point(0, 1), Point(1, 1), Point(2, 1)],
      [Point(0, 0), Point(1, 0), Point(1, 1), Point(1, 2)],
    ], const Color(0xFF3A9B5A)),
    ([
      [Point(0, 0), Point(0, 1), Point(1, 1), Point(2, 1)],
      [Point(1, 0), Point(2, 0), Point(1, 1), Point(1, 2)],
      [Point(0, 1), Point(1, 1), Point(2, 1), Point(2, 2)],
      [Point(1, 0), Point(1, 1), Point(0, 2), Point(1, 2)],
    ], const Color(0xFF63CF85)),
    ([
      [Point(1, 0), Point(2, 0), Point(0, 1), Point(1, 1)],
      [Point(1, 0), Point(1, 1), Point(2, 1), Point(2, 2)],
      [Point(1, 1), Point(2, 1), Point(0, 2), Point(1, 2)],
      [Point(0, 0), Point(0, 1), Point(1, 1), Point(1, 2)],
    ], const Color(0xFF2F7D4A)),
    ([
      [Point(0, 0), Point(1, 0), Point(1, 1), Point(2, 1)],
      [Point(2, 0), Point(1, 1), Point(2, 1), Point(1, 2)],
      [Point(0, 1), Point(1, 1), Point(1, 2), Point(2, 2)],
      [Point(1, 0), Point(0, 1), Point(1, 1), Point(0, 2)],
    ], const Color(0xFF76D98F)),
  ];
}
