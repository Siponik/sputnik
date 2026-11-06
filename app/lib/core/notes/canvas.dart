// Холст `.canvas` в открытом формате JSON Canvas 1.0 (jsoncanvas.org, MIT; тот же файл открывает Obsidian):
// docs/knowledge.md, шаг 12. Ноды text / file / link / group, провода с подписями между сторонами нод.
// Неизвестные поля (свои у Obsidian и плагинов) сохраняются как были — файл не портится.
// Без Flutter — проверяется тестом.
import 'dart:convert';
import 'dart:math' as math;

import 'force.dart';

enum CanvasSide { top, right, bottom, left }

CanvasSide? sideOf(String? s) => switch (s) {
      'top' => CanvasSide.top,
      'right' => CanvasSide.right,
      'bottom' => CanvasSide.bottom,
      'left' => CanvasSide.left,
      _ => null,
    };

class CanvasNode {
  final Map<String, dynamic> raw;
  CanvasNode(this.raw);

  String get id => raw['id'] as String;
  String get type => raw['type'] as String? ?? 'text';
  double get x => (raw['x'] as num? ?? 0).toDouble();
  double get y => (raw['y'] as num? ?? 0).toDouble();
  double get width => (raw['width'] as num? ?? 250).toDouble();
  double get height => (raw['height'] as num? ?? 60).toDouble();
  set x(double v) => raw['x'] = v.round();
  set y(double v) => raw['y'] = v.round();
  set width(double v) => raw['width'] = v.round();
  set height(double v) => raw['height'] = v.round();

  /// Цвет: `"1"`…`"6"` (красный, оранжевый, жёлтый, зелёный, голубой, фиолетовый) или `#RRGGBB`.
  String? get color => raw['color'] as String?;
  set color(String? v) => v == null ? raw.remove('color') : raw['color'] = v;
  String get text => raw['text'] as String? ?? '';
  set text(String v) => raw['text'] = v;

  /// Путь файла от корня папки заметок (у type = file).
  String get file => raw['file'] as String? ?? '';
  String get url => raw['url'] as String? ?? '';
  String get label => raw['label'] as String? ?? '';
  set label(String v) => raw['label'] = v;

  bool get isGroup => type == 'group';
  double get cx => x + width / 2;
  double get cy => y + height / 2;
  bool contains(double px, double py) => px >= x && px <= x + width && py >= y && py <= y + height;

  /// Точка на середине стороны.
  (double, double) socket(CanvasSide s) => switch (s) {
        CanvasSide.top => (cx, y),
        CanvasSide.right => (x + width, cy),
        CanvasSide.bottom => (cx, y + height),
        CanvasSide.left => (x, cy),
      };
}

class CanvasEdge {
  final Map<String, dynamic> raw;
  CanvasEdge(this.raw);
  String get id => raw['id'] as String;
  String get from => raw['fromNode'] as String;
  String get to => raw['toNode'] as String;
  CanvasSide? get fromSide => sideOf(raw['fromSide'] as String?);
  CanvasSide? get toSide => sideOf(raw['toSide'] as String?);
  String get label => raw['label'] as String? ?? '';
  set label(String v) => v.isEmpty ? raw.remove('label') : raw['label'] = v;
  String? get color => raw['color'] as String?;

  /// Стрелка на конце: по умолчанию у `to` есть, у `from` нет.
  bool get arrowTo => (raw['toEnd'] as String? ?? 'arrow') == 'arrow';
  bool get arrowFrom => (raw['fromEnd'] as String? ?? 'none') == 'arrow';
}

class CanvasDoc {
  final List<CanvasNode> nodes;
  final List<CanvasEdge> edges;

  /// Прочие поля верхнего уровня файла.
  final Map<String, dynamic> extra;
  CanvasDoc(this.nodes, this.edges, [Map<String, dynamic>? extra]) : extra = extra ?? {};

  /// Разобрать файл. Пустой или битый — пустой холст (но [parseError] скажет, что файл не прочитался).
  factory CanvasDoc.parse(String text) {
    if (text.trim().isEmpty) return CanvasDoc([], []);
    final j = jsonDecode(text);
    if (j is! Map<String, dynamic>) throw const FormatException('Холст — не объект JSON');
    final extra = {...j}..remove('nodes')..remove('edges');
    return CanvasDoc(
      [for (final n in (j['nodes'] as List? ?? const [])) if (n is Map<String, dynamic> && n['id'] is String) CanvasNode(n)],
      [for (final e in (j['edges'] as List? ?? const [])) if (e is Map<String, dynamic> && e['id'] is String && e['fromNode'] is String && e['toNode'] is String) CanvasEdge(e)],
      extra,
    );
  }

  /// В файл — с отступами табуляцией, как пишет Obsidian.
  String encode() => const JsonEncoder.withIndent('\t').convert({
        'nodes': [for (final n in nodes) n.raw],
        'edges': [for (final e in edges) e.raw],
        ...extra,
      });

  CanvasNode? node(String id) {
    for (final n in nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  final _rnd = math.Random();

  /// Новый id: 16 шестнадцатеричных знаков, как у Obsidian, не занятый.
  String newId() {
    final taken = {for (final n in nodes) n.id, for (final e in edges) e.id};
    while (true) {
      final id = List.generate(16, (_) => _rnd.nextInt(16).toRadixString(16)).join();
      if (!taken.contains(id)) return id;
    }
  }

  CanvasNode add(String type, double x, double y, {double w = 250, double h = 120, String? file, String? text, String? label}) {
    final n = CanvasNode({
      'id': newId(),
      'type': type,
      'x': x.round(),
      'y': y.round(),
      'width': w.round(),
      'height': h.round(),
      'file': ?file,
      'text': ?text,
      'label': ?label,
    });
    // Группы — под остальными (раньше в списке — ниже на экране).
    if (type == 'group') {
      nodes.insert(0, n);
    } else {
      nodes.add(n);
    }
    return n;
  }

  /// Убрать ноду вместе с её проводами.
  void remove(String id) {
    nodes.removeWhere((n) => n.id == id);
    edges.removeWhere((e) => e.from == id || e.to == id);
  }

  /// Провод [from] → [to]. Такой уже есть или это одна нода — null.
  CanvasEdge? connect(String from, String to, {CanvasSide? fromSide, CanvasSide? toSide, String label = ''}) {
    if (from == to || node(from) == null || node(to) == null) return null;
    if (edges.any((e) => (e.from == from && e.to == to) || (e.from == to && e.to == from))) return null;
    final e = CanvasEdge({
      'id': newId(),
      'fromNode': from,
      'fromSide': ?fromSide?.name,
      'toNode': to,
      'toSide': ?toSide?.name,
      if (label.isNotEmpty) 'label': label,
    });
    edges.add(e);
    return e;
  }

  /// Ноды внутри группы (целиком) — двигаются вместе с ней.
  List<CanvasNode> inside(CanvasNode g) => [
        for (final n in nodes)
          if (n.id != g.id && n.x >= g.x && n.y >= g.y && n.x + n.width <= g.x + g.width && n.y + n.height <= g.y + g.height) n,
      ];

  /// Самая верхняя нода под точкой (группы — только если под точкой нет другой ноды).
  CanvasNode? hit(double x, double y) {
    for (final n in nodes.reversed) {
      if (!n.isGroup && n.contains(x, y)) return n;
    }
    for (final n in nodes.reversed) {
      if (n.isGroup && n.contains(x, y)) return n;
    }
    return null;
  }

  /// Границы всех нод (x0, y0, x1, y1); пустой холст — вокруг нуля.
  (double, double, double, double) bounds() {
    if (nodes.isEmpty) return (-400, -300, 400, 300);
    var x0 = double.infinity, y0 = double.infinity, x1 = -double.infinity, y1 = -double.infinity;
    for (final n in nodes) {
      x0 = math.min(x0, n.x);
      y0 = math.min(y0, n.y);
      x1 = math.max(x1, n.x + n.width);
      y1 = math.max(y1, n.y + n.height);
    }
    return (x0, y0, x1, y1);
  }

  /// «Авто-раскладка»: силовая раскладка нод (кроме групп) от их нынешних мест; провода — пружины,
  /// ноды не налезают друг на друга. Шаг сетки 10, как у Obsidian.
  void autoLayout() {
    final free = [for (final n in nodes) if (!n.isGroup) n];
    if (free.length < 2) return;
    final at = {for (var i = 0; i < free.length; i++) free[i].id: i};
    final fs = [for (final n in free) ForceNode(n.id, x: n.cx, y: n.cy, r: math.sqrt(n.width * n.width + n.height * n.height) / 2 + 20)];
    final links = [
      for (final e in edges)
        if (at[e.from] != null && at[e.to] != null) ForceLink(at[e.from]!, at[e.to]!),
    ];
    final avg = free.fold<double>(0, (a, n) => a + math.max(n.width, n.height)) / free.length;
    final sim = ForceSim(fs, links, params: ForceParams(charge: -avg * 6, linkDistance: avg * 1.4, gravity: .08, collide: 1));
    sim.run(maxTicks: 400);
    for (var i = 0; i < free.length; i++) {
      free[i].x = ((fs[i].x - free[i].width / 2) / 10).round() * 10;
      free[i].y = ((fs[i].y - free[i].height / 2) / 10).round() * 10;
    }
  }
}

/// С какой стороны ноды [n] ближе всего точка (для провода, отпущенного над нодой).
CanvasSide nearestSide(CanvasNode n, double px, double py) {
  final d = {
    CanvasSide.top: (py - n.y).abs(),
    CanvasSide.bottom: (py - n.y - n.height).abs(),
    CanvasSide.left: (px - n.x).abs(),
    CanvasSide.right: (px - n.x - n.width).abs(),
  };
  return d.entries.reduce((a, b) => b.value < a.value ? b : a).key;
}

/// Стороны провода, если в файле не указаны: смотрят друг на друга по главной оси.
(CanvasSide, CanvasSide) edgeSides(CanvasEdge e, CanvasNode a, CanvasNode b) {
  if (e.fromSide != null && e.toSide != null) return (e.fromSide!, e.toSide!);
  final dx = b.cx - a.cx, dy = b.cy - a.cy;
  final (fa, fb) = dx.abs() >= dy.abs()
      ? (dx >= 0 ? (CanvasSide.right, CanvasSide.left) : (CanvasSide.left, CanvasSide.right))
      : (dy >= 0 ? (CanvasSide.bottom, CanvasSide.top) : (CanvasSide.top, CanvasSide.bottom));
  return (e.fromSide ?? fa, e.toSide ?? fb);
}
