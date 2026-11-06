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
    final extra = {...j}
      ..remove('nodes')
      ..remove('edges');
    return CanvasDoc(
      [
        for (final n in (j['nodes'] as List? ?? const []))
          if (n is Map<String, dynamic> && n['id'] is String) CanvasNode(n),
      ],
      [
        for (final e in (j['edges'] as List? ?? const []))
          if (e is Map<String, dynamic> && e['id'] is String && e['fromNode'] is String && e['toNode'] is String)
            CanvasEdge(e),
      ],
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

  CanvasNode add(
    String type,
    double x,
    double y, {
    double w = 250,
    double h = 120,
    String? file,
    String? text,
    String? label,
  }) {
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
      if (n.id != g.id &&
          n.x >= g.x &&
          n.y >= g.y &&
          n.x + n.width <= g.x + g.width &&
          n.y + n.height <= g.y + g.height)
        n,
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
    final free = [
      for (final n in nodes)
        if (!n.isGroup) n,
    ];
    if (free.length < 2) return;
    final at = {for (var i = 0; i < free.length; i++) free[i].id: i};
    final fs = [
      for (final n in free)
        ForceNode(n.id, x: n.cx, y: n.cy, r: math.sqrt(n.width * n.width + n.height * n.height) / 2 + 20),
    ];
    final links = [
      for (final e in edges)
        if (at[e.from] != null && at[e.to] != null) ForceLink(at[e.from]!, at[e.to]!),
    ];
    final avg = free.fold<double>(0, (a, n) => a + math.max(n.width, n.height)) / free.length;
    final sim = ForceSim(
      fs,
      links,
      params: ForceParams(charge: -avg * 6, linkDistance: avg * 1.4, gravity: .08, collide: 1),
    );
    sim.run(maxTicks: 400);
    for (var i = 0; i < free.length; i++) {
      free[i].x = ((fs[i].x - free[i].width / 2) / 10).round() * 10;
      free[i].y = ((fs[i].y - free[i].height / 2) / 10).round() * 10;
    }
  }
}

extension CanvasEditing on CanvasDoc {
  /// Что двигать вместе с выделенным: сами ноды и всё, что целиком внутри выделенных групп.
  List<CanvasNode> movable(Set<String> ids) {
    final out = <String, CanvasNode>{};
    for (final id in ids) {
      final n = node(id);
      if (n == null) continue;
      out[n.id] = n;
      if (n.isGroup) {
        for (final k in inside(n)) {
          out[k.id] = k;
        }
      }
    }
    return out.values.toList();
  }

  /// Границы нод [ids] (x0, y0, x1, y1) или null.
  (double, double, double, double)? boundsOf(Iterable<String> ids) {
    double? x0, y0, x1, y1;
    for (final id in ids) {
      final n = node(id);
      if (n == null) continue;
      x0 = math.min(x0 ?? n.x, n.x);
      y0 = math.min(y0 ?? n.y, n.y);
      x1 = math.max(x1 ?? n.x + n.width, n.x + n.width);
      y1 = math.max(y1 ?? n.y + n.height, n.y + n.height);
    }
    return x0 == null ? null : (x0, y0!, x1!, y1!);
  }

  /// Выделение рамкой: ноды, которые задевает прямоугольник (группа — только целиком внутри рамки).
  Set<String> inRect(double x0, double y0, double x1, double y1) {
    final ax = math.min(x0, x1), bx = math.max(x0, x1), ay = math.min(y0, y1), by = math.max(y0, y1);
    return {
      for (final n in nodes)
        if (n.isGroup
            ? n.x >= ax && n.y >= ay && n.x + n.width <= bx && n.y + n.height <= by
            : n.x < bx && n.x + n.width > ax && n.y < by && n.y + n.height > ay)
          n.id,
    };
  }

  /// В буфер обмена: выделенные ноды и провода между ними, в том же формате JSON Canvas.
  String copyOf(Set<String> ids) {
    final ns = [
      for (final n in nodes)
        if (ids.contains(n.id)) n.raw,
    ];
    final es = [
      for (final e in edges)
        if (ids.contains(e.from) && ids.contains(e.to)) e.raw,
    ];
    return jsonEncode({'nodes': ns, 'edges': es});
  }

  /// Вставить из буфера так, чтобы середина вставленного встала в ([cx], [cy]). Id — новые, провода
  /// переподключаются. Не холст — null (тогда вставляется текстом).
  List<String>? paste(String text, double cx, double cy) {
    Object? j;
    try {
      j = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (j is! Map || j['nodes'] is! List) return null;
    final src = [
      for (final n in j['nodes'] as List)
        if (n is Map && n['id'] is String) Map<String, dynamic>.from(n),
    ];
    if (src.isEmpty) return null;
    double x0 = double.infinity, y0 = double.infinity, x1 = -double.infinity, y1 = -double.infinity;
    for (final n in src) {
      final c = CanvasNode(n);
      x0 = math.min(x0, c.x);
      y0 = math.min(y0, c.y);
      x1 = math.max(x1, c.x + c.width);
      y1 = math.max(y1, c.y + c.height);
    }
    final dx = cx - (x0 + x1) / 2, dy = cy - (y0 + y1) / 2;
    final ids = <String, String>{};
    final made = <String>[];
    for (final n in src) {
      final id = newId();
      ids[n['id'] as String] = id;
      final c = CanvasNode({...n, 'id': id});
      c.x = ((c.x + dx) / 10).round() * 10.0;
      c.y = ((c.y + dy) / 10).round() * 10.0;
      if (c.isGroup) {
        nodes.insert(0, c);
      } else {
        nodes.add(c);
      }
      made.add(id);
    }
    for (final e in (j['edges'] as List? ?? const [])) {
      if (e is! Map) continue;
      final a = ids[e['fromNode']], b = ids[e['toNode']];
      if (a == null || b == null) continue;
      edges.add(CanvasEdge({...Map<String, dynamic>.from(e), 'id': newId(), 'fromNode': a, 'toNode': b}));
    }
    return made;
  }

  /// Копия выделенного рядом (Ctrl+D).
  List<String> duplicate(Set<String> ids) {
    final b = boundsOf(ids);
    if (b == null) return const [];
    final (x0, y0, x1, y1) = b;
    return paste(copyOf(ids), (x0 + x1) / 2 + 30, (y0 + y1) / 2 + 30) ?? const [];
  }

  /// Группа вокруг выделенного (Ctrl+G).
  CanvasNode? groupAround(Set<String> ids, {double pad = 30, String label = 'Группа'}) {
    final b = boundsOf(ids);
    if (b == null) return null;
    final (x0, y0, x1, y1) = b;
    return add('group', x0 - pad, y0 - pad - 20, w: x1 - x0 + pad * 2, h: y1 - y0 + pad * 2 + 20, label: label);
  }

  /// Провод под точкой (с допуском [tol] в единицах холста) или null.
  String? edgeAt(double x, double y, double tol) {
    String? best;
    var bd = tol;
    for (final e in edges) {
      final a = node(e.from), b = node(e.to);
      if (a == null || b == null) continue;
      final c = edgeCurve(e, a, b);
      for (var i = 0; i <= 32; i++) {
        final (px, py) = c.at(i / 32);
        final d = math.sqrt((px - x) * (px - x) + (py - y) * (py - y));
        if (d < bd) {
          bd = d;
          best = e.id;
        }
      }
    }
    return best;
  }
}

/// Кривая провода: от сокета до сокета, ручки — наружу от сторон.
class EdgeCurve {
  final (double, double) a, c1, c2, b;
  final CanvasSide sa, sb;
  const EdgeCurve(this.a, this.c1, this.c2, this.b, this.sa, this.sb);

  (double, double) at(double t) {
    final u = 1 - t;
    double f(double p0, double p1, double p2, double p3) =>
        u * u * u * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * p3;
    return (f(a.$1, c1.$1, c2.$1, b.$1), f(a.$2, c1.$2, c2.$2, b.$2));
  }
}

(double, double) sideDir(CanvasSide s) => switch (s) {
  CanvasSide.top => (0, -1),
  CanvasSide.right => (1, 0),
  CanvasSide.bottom => (0, 1),
  CanvasSide.left => (-1, 0),
};

/// Кривая от точки [a] стороны [sa] к точке [b] (у конца сторона [sb] или нет — провод, который тянут).
EdgeCurve curveBetween((double, double) a, CanvasSide sa, (double, double) b, CanvasSide? sb) {
  final dist = math.sqrt(math.pow(b.$1 - a.$1, 2) + math.pow(b.$2 - a.$2, 2));
  final reach = math.max(dist / 2.5, 30.0);
  final da = sideDir(sa);
  final c1 = (a.$1 + da.$1 * reach, a.$2 + da.$2 * reach);
  final db = sb == null ? (0.0, 0.0) : sideDir(sb);
  final c2 = (b.$1 + db.$1 * reach, b.$2 + db.$2 * reach);
  return EdgeCurve(a, c1, c2, b, sa, sb ?? sa);
}

EdgeCurve edgeCurve(CanvasEdge e, CanvasNode a, CanvasNode b) {
  final (sa, sb) = edgeSides(e, a, b);
  return curveBetween(a.socket(sa), sa, b.socket(sb), sb);
}

/// История правок холста для Ctrl+Z / Ctrl+Shift+Z: снимки файла целиком, до 100 шагов.
class CanvasHistory {
  final _undo = <String>[];
  final _redo = <String>[];
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// Запомнить состояние ДО правки.
  void push(String before) {
    if (_undo.isNotEmpty && _undo.last == before) return;
    _undo.add(before);
    if (_undo.length > 100) _undo.removeAt(0);
    _redo.clear();
  }

  /// Шаг назад: вернёт прошлое состояние, а нынешнее [now] уйдёт в «вперёд».
  String? undo(String now) {
    if (_undo.isEmpty) return null;
    _redo.add(now);
    return _undo.removeLast();
  }

  String? redo(String now) {
    if (_redo.isEmpty) return null;
    _undo.add(now);
    return _redo.removeLast();
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
