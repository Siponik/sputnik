// Раскладка графа «Знаний» (docs/knowledge.md, шаг 3): перенос симуляции сил d3-force
// (https://github.com/d3/d3-force, лицензия ISC, © Mike Bostock) на Dart.
//
// Как в d3: скорость Верле с затуханием, «температура» alpha остывает примерно за 300 шагов; силы —
// отталкивание точек (many-body, приближение Барнса — Хата через квадродерево), пружины связей, притяжение
// к центру (forceX/forceY), сдвиг центра масс в ноль (forceCenter) и необязательное «не налезать» (collide).
// Случайность — та же линейная конгруэнтная последовательность, что в d3 (seed = 1), поэтому раскладка
// всегда одинаковая для одних и тех же данных.
import 'dart:math' as math;

/// Точка графа. `fx/fy` — закреплена (тянут мышью).
class ForceNode {
  final String id;
  double x;
  double y;
  double vx = 0;
  double vy = 0;
  double? fx;
  double? fy;

  /// Радиус точки — для collide.
  double r;
  int index = 0;

  ForceNode(this.id, {this.x = double.nan, this.y = double.nan, this.r = 4, this.fx, this.fy});
}

/// Связь между точками по номерам.
class ForceLink {
  final int source;
  final int target;
  const ForceLink(this.source, this.target);
}

/// Настройки — те же ползунки, что в фильтрах графа.
class ForceParams {
  /// Отталкивание: отрицательное число, d3 по умолчанию −30.
  final double charge;

  /// Длина связи, d3 по умолчанию 30.
  final double linkDistance;

  /// Множитель силы пружин (1 — как в d3: 1 / min(связей у концов)).
  final double linkScale;

  /// Притяжение к центру по x и y (forceX/forceY, d3 по умолчанию 0.1; 0 — выключено).
  final double gravity;

  /// Не налезать друг на друга: 0 — выключено, 1 — полностью.
  final double collide;

  /// Точность Барнса — Хата (d3: 0.9). 0 — точный расчёт O(N²).
  final double theta;

  /// Дальше этого расстояния точки не отталкиваются (d3: бесконечность).
  final double distanceMax;

  const ForceParams({
    this.charge = -30,
    this.linkDistance = 30,
    this.linkScale = 1,
    this.gravity = 0.05,
    this.collide = 0,
    this.theta = 0.9,
    this.distanceMax = double.infinity,
  });
}

/// Генератор как `lcg` в d3-force: a = 1664525, c = 1013904223, m = 2^32.
class Lcg {
  int _s;
  Lcg([int seed = 1]) : _s = seed;
  double next() {
    _s = (1664525 * _s + 1013904223) % 4294967296;
    return _s / 4294967296;
  }
}

class ForceSim {
  final List<ForceNode> nodes;
  final List<ForceLink> links;
  ForceParams params;

  double alpha = 1;
  double alphaMin = 0.001;
  double alphaDecay = 1 - math.pow(0.001, 1 / 300).toDouble();
  double alphaTarget = 0;

  /// Сколько скорости остаётся за шаг (d3: velocityDecay 0.4 → остаётся 0.6).
  double velocityKeep = 0.6;

  final Lcg _rnd;
  late List<double> _linkStrength;
  late List<double> _linkBias;

  ForceSim(this.nodes, this.links, {this.params = const ForceParams(), int seed = 1}) : _rnd = Lcg(seed) {
    _initNodes();
    _initLinks();
  }

  static const _initialRadius = 10.0;
  static final _initialAngle = math.pi * (3 - math.sqrt(5));

  void _initNodes() {
    for (var i = 0; i < nodes.length; i++) {
      final n = nodes[i]..index = i;
      if (n.fx != null) n.x = n.fx!;
      if (n.fy != null) n.y = n.fy!;
      if (n.x.isNaN || n.y.isNaN) {
        // Раскладка-подсолнух, как в d3: точки сразу расходятся ровно, без случайного «взрыва».
        final rad = _initialRadius * math.sqrt(0.5 + i), ang = i * _initialAngle;
        n.x = rad * math.cos(ang);
        n.y = rad * math.sin(ang);
      }
      if (n.vx.isNaN || n.vy.isNaN) n.vx = n.vy = 0;
    }
  }

  void _initLinks() {
    final count = List<int>.filled(nodes.length, 0);
    for (final l in links) {
      count[l.source]++;
      count[l.target]++;
    }
    _linkStrength = [for (final l in links) 1 / math.max(1, math.min(count[l.source], count[l.target]))];
    _linkBias = [
      for (final l in links) count[l.source] / math.max(1, count[l.source] + count[l.target]),
    ];
  }

  double _jiggle() => (_rnd.next() - 0.5) * 1e-6;

  /// Остыла ли раскладка.
  bool get settled => alpha < alphaMin;

  /// Снова «нагреть» (после перетаскивания или смены ползунков), как `simulation.alpha(a).restart()`.
  void reheat([double a = 0.3]) => alpha = math.max(alpha, a);

  /// Один шаг.
  void tick() {
    alpha += (alphaTarget - alpha) * alphaDecay;
    _link(alpha);
    _manyBody(alpha);
    if (params.gravity > 0) _gravity(alpha);
    if (params.collide > 0) _collide();
    for (final n in nodes) {
      if (n.fx == null) {
        n.vx *= velocityKeep;
        n.x += n.vx;
      } else {
        n.x = n.fx!;
        n.vx = 0;
      }
      if (n.fy == null) {
        n.vy *= velocityKeep;
        n.y += n.vy;
      } else {
        n.y = n.fy!;
        n.vy = 0;
      }
    }
    _center();
  }

  /// Шаги, пока не остынет (или [maxTicks]). Возвращает, сколько сделано.
  int run({int maxTicks = 1000}) {
    var k = 0;
    while (!settled && k < maxTicks) {
      tick();
      k++;
    }
    return k;
  }

  // ---- силы ----

  void _link(double alpha) {
    final dist = params.linkDistance;
    for (var i = 0; i < links.length; i++) {
      final s = nodes[links[i].source], t = nodes[links[i].target];
      if (identical(s, t)) continue;
      var x = t.x + t.vx - s.x - s.vx;
      if (x == 0) x = _jiggle();
      var y = t.y + t.vy - s.y - s.vy;
      if (y == 0) y = _jiggle();
      var l = math.sqrt(x * x + y * y);
      l = (l - dist) / l * alpha * _linkStrength[i] * params.linkScale;
      x *= l;
      y *= l;
      final b = _linkBias[i];
      t.vx -= x * b;
      t.vy -= y * b;
      s.vx += x * (1 - b);
      s.vy += y * (1 - b);
    }
  }

  void _manyBody(double alpha) {
    if (nodes.isEmpty || params.charge == 0) return;
    final tree = _Quad.build(nodes);
    tree.accumulate(params.charge);
    final theta2 = params.theta * params.theta;
    final dMax2 = params.distanceMax * params.distanceMax;
    const dMin2 = 1.0;
    for (final node in nodes) {
      tree.visit((q) {
        if (q.value == 0) return true;
        var x = q.cx - node.x, y = q.cy - node.y;
        final w = q.size;
        var l = x * x + y * y;
        // Далеко — весь квадрат как одна точка.
        if (w * w / theta2 < l) {
          if (l < dMax2) {
            if (x == 0) {
              x = _jiggle();
              l += x * x;
            }
            if (y == 0) {
              y = _jiggle();
              l += y * y;
            }
            if (l < dMin2) l = math.sqrt(dMin2 * l);
            node.vx += x * q.value * alpha / l;
            node.vy += y * q.value * alpha / l;
          }
          return true;
        }
        if (q.kids != null || l >= dMax2) return false;
        // Лист: точки по одной.
        for (final d in q.items!) {
          if (identical(d, node)) continue;
          var dx = d.x - node.x, dy = d.y - node.y;
          var dl = dx * dx + dy * dy;
          if (dx == 0) {
            dx = _jiggle();
            dl += dx * dx;
          }
          if (dy == 0) {
            dy = _jiggle();
            dl += dy * dy;
          }
          if (dl < dMin2) dl = math.sqrt(dMin2 * dl);
          final k = params.charge * alpha / dl;
          node.vx += dx * k;
          node.vy += dy * k;
        }
        return true;
      });
    }
  }

  void _gravity(double alpha) {
    final k = params.gravity * alpha;
    for (final n in nodes) {
      n.vx += (0 - n.x) * k;
      n.vy += (0 - n.y) * k;
    }
  }

  void _center() {
    if (nodes.isEmpty) return;
    var sx = 0.0, sy = 0.0;
    for (final n in nodes) {
      sx += n.x;
      sy += n.y;
    }
    sx /= nodes.length;
    sy /= nodes.length;
    for (final n in nodes) {
      if (n.fx == null) n.x -= sx;
      if (n.fy == null) n.y -= sy;
    }
  }

  void _collide() {
    // Сетка вместо квадродерева: соседи ищутся только в своей и соседних клетках.
    var rMax = 0.0;
    for (final n in nodes) {
      rMax = math.max(rMax, n.r);
    }
    if (rMax <= 0) return;
    final cell = rMax * 2;
    final grid = <int, List<ForceNode>>{};
    int key(int gx, int gy) => gx * 73856093 ^ gy * 19349663;
    for (final n in nodes) {
      final gx = ((n.x + n.vx) / cell).floor(), gy = ((n.y + n.vy) / cell).floor();
      grid.putIfAbsent(key(gx, gy), () => []).add(n);
    }
    final s = params.collide;
    for (final a in nodes) {
      final ax = a.x + a.vx, ay = a.y + a.vy;
      final gx = (ax / cell).floor(), gy = (ay / cell).floor();
      for (var i = -1; i <= 1; i++) {
        for (var j = -1; j <= 1; j++) {
          for (final b in grid[key(gx + i, gy + j)] ?? const <ForceNode>[]) {
            if (b.index <= a.index) continue;
            final r = a.r + b.r;
            var x = ax - (b.x + b.vx), y = ay - (b.y + b.vy);
            var l = x * x + y * y;
            if (l >= r * r) continue;
            if (x == 0) {
              x = _jiggle();
              l += x * x;
            }
            if (y == 0) {
              y = _jiggle();
              l += y * y;
            }
            final d = math.sqrt(l);
            final k = (r - d) / d * s;
            final rb = b.r * b.r / (a.r * a.r + b.r * b.r);
            a.vx += x * k * rb;
            a.vy += y * k * rb;
            b.vx -= x * k * (1 - rb);
            b.vy -= y * k * (1 - rb);
          }
        }
      }
    }
  }

  /// Рамка всех точек: (minX, minY, maxX, maxY) — чтобы вписать граф в окно.
  (double, double, double, double) bounds() {
    if (nodes.isEmpty) return (0, 0, 0, 0);
    var a = double.infinity, b = double.infinity, c = -double.infinity, d = -double.infinity;
    for (final n in nodes) {
      a = math.min(a, n.x - n.r);
      b = math.min(b, n.y - n.r);
      c = math.max(c, n.x + n.r);
      d = math.max(d, n.y + n.r);
    }
    return (a, b, c, d);
  }

  /// Ближайшая к (x, y) точка не дальше [within] (для наведения и клика), иначе null.
  ForceNode? find(double x, double y, {double within = double.infinity}) {
    ForceNode? best;
    var bd = within * within;
    for (final n in nodes) {
      final dx = n.x - x, dy = n.y - y, d = dx * dx + dy * dy;
      if (d < bd) {
        bd = d;
        best = n;
      }
    }
    return best;
  }
}

/// Квадродерево для отталкивания: квадрат, четыре детей или лист с точками.
class _Quad {
  final double x0, y0, size;
  List<_Quad?>? kids;
  List<ForceNode>? items;
  double value = 0;
  double cx = 0, cy = 0;

  _Quad(this.x0, this.y0, this.size);

  static _Quad build(List<ForceNode> nodes) {
    var a = double.infinity, b = double.infinity, c = -double.infinity, d = -double.infinity;
    for (final n in nodes) {
      a = math.min(a, n.x);
      b = math.min(b, n.y);
      c = math.max(c, n.x);
      d = math.max(d, n.y);
    }
    final size = math.max(math.max(c - a, d - b), 1e-9) * 1.0001;
    final root = _Quad(a, b, size);
    root._fill(List.of(nodes), 0);
    return root;
  }

  void _fill(List<ForceNode> pts, int depth) {
    final first = pts.first;
    final same = pts.every((p) => p.x == first.x && p.y == first.y);
    if (pts.length == 1 || same || depth > 48) {
      items = pts;
      return;
    }
    final h = size / 2;
    final parts = List<List<ForceNode>>.generate(4, (_) => []);
    for (final p in pts) {
      final i = (p.x >= x0 + h ? 1 : 0) + (p.y >= y0 + h ? 2 : 0);
      parts[i].add(p);
    }
    kids = List<_Quad?>.filled(4, null);
    for (var i = 0; i < 4; i++) {
      if (parts[i].isEmpty) continue;
      final q = _Quad(x0 + (i & 1) * h, y0 + (i >> 1) * h, h);
      q._fill(parts[i], depth + 1);
      kids![i] = q;
    }
  }

  /// Суммарная «сила» и её центр (все точки одинаковой силы [charge]).
  void accumulate(double charge) {
    if (kids != null) {
      var s = 0.0, w = 0.0, x = 0.0, y = 0.0;
      for (final q in kids!) {
        if (q == null) continue;
        q.accumulate(charge);
        final c = q.value.abs();
        if (c == 0) continue;
        s += q.value;
        w += c;
        x += c * q.cx;
        y += c * q.cy;
      }
      value = s;
      cx = w == 0 ? x0 : x / w;
      cy = w == 0 ? y0 : y / w;
    } else {
      final it = items!;
      value = charge * it.length;
      var x = 0.0, y = 0.0;
      for (final p in it) {
        x += p.x;
        y += p.y;
      }
      cx = x / it.length;
      cy = y / it.length;
    }
  }

  /// Обход сверху вниз; [f] вернул true — детей не смотреть.
  void visit(bool Function(_Quad) f) {
    if (f(this)) return;
    for (final q in kids ?? const <_Quad?>[]) {
      if (q != null) q.visit(f);
    }
  }
}
