// Граф знаний (docs/knowledge.md, шаги 8–9; макеты G_NotesGraph, G_NotesZoom, G_NotesGraphNear): что показать
// по фильтрам, как точка растёт с масштабом (×1 точки → ×2 названия → ×3 ноды) и что в ноде.
// Без Flutter — проверяется тестом. Раскладка — force.dart.
import 'dart:math' as math;

import 'index.dart';
import 'parse.dart';

enum GraphKind { note, tag, file, missing }

class GraphNode {
  /// Путь заметки или вложения, `#тег`, `?Название` для ещё не созданной.
  final String id;
  final GraphKind kind;
  final String label;

  /// Папка верхнего уровня (для цвета и групп); у тегов и несозданных — ''.
  final String group;
  int degree = 0;
  GraphNode(this.id, this.kind, this.label, this.group);
}

class GraphFilter {
  /// Глубина вокруг [focus] (локальный граф); null — весь.
  final String? focus;
  final int depth;
  final bool tags;
  final bool files;
  final bool orphans;
  final bool missing;

  /// Скрытые группы (папки верхнего уровня; '' — корень).
  final Set<String> hidden;
  const GraphFilter({this.focus, this.depth = 1, this.tags = false, this.files = false, this.orphans = true, this.missing = false, this.hidden = const {}});

  GraphFilter copyWith({String? focus, bool clearFocus = false, int? depth, bool? tags, bool? files, bool? orphans, bool? missing, Set<String>? hidden}) => GraphFilter(
        focus: clearFocus ? null : focus ?? this.focus,
        depth: depth ?? this.depth,
        tags: tags ?? this.tags,
        files: files ?? this.files,
        orphans: orphans ?? this.orphans,
        missing: missing ?? this.missing,
        hidden: hidden ?? this.hidden,
      );
}

class GraphData {
  final List<GraphNode> nodes;

  /// Связи по номерам в [nodes].
  final List<(int, int)> links;
  const GraphData(this.nodes, this.links);
  int indexOf(String id) => nodes.indexWhere((n) => n.id == id);
}

String topGroup(String path) => path.contains('/') ? path.substring(0, path.indexOf('/')) : '';

/// Собрать граф по фильтру. Порядок точек устойчивый (по id) — раскладка одна и та же при каждом открытии.
GraphData buildGraph(NoteIndex ix, GraphFilter f) {
  final nodes = <String, GraphNode>{};
  final edges = <(String, String)>{};
  for (final p in ix.paths) {
    nodes[p] = GraphNode(p, GraphKind.note, ix.doc(p)?.title ?? baseName(p), topGroup(p));
  }
  for (final e in ix.edges(withFiles: f.files, withMissing: f.missing)) {
    for (final id in [e.a, e.b]) {
      if (nodes.containsKey(id)) continue;
      if (id.startsWith('?')) {
        nodes[id] = GraphNode(id, GraphKind.missing, id.substring(1), '');
      } else {
        nodes[id] = GraphNode(id, GraphKind.file, id.substring(id.lastIndexOf('/') + 1), topGroup(id));
      }
    }
    edges.add((e.a, e.b));
  }
  if (f.tags) {
    for (final p in ix.paths) {
      for (final t in ix.doc(p)!.tags) {
        final id = '#${t.toLowerCase()}';
        nodes.putIfAbsent(id, () => GraphNode(id, GraphKind.tag, '#$t', ''));
        edges.add((p, id));
      }
    }
  }
  // Скрытые группы — убираем точки (теги и несозданные остаются, если к ним ещё что-то ведёт).
  nodes.removeWhere((id, n) => (n.kind == GraphKind.note || n.kind == GraphKind.file) && f.hidden.contains(n.group));
  edges.removeWhere((e) => !nodes.containsKey(e.$1) || !nodes.containsKey(e.$2));
  // Тег или несозданная заметка, к которым больше ничего не ведёт, — тоже убираем.
  final linked = {for (final e in edges) ...[e.$1, e.$2]};
  nodes.removeWhere((id, n) => (n.kind == GraphKind.tag || n.kind == GraphKind.missing) && !linked.contains(id));

  // Локальный граф: обход в ширину от заметки.
  if (f.focus != null && nodes.containsKey(f.focus)) {
    final adj = <String, Set<String>>{};
    for (final e in edges) {
      adj.putIfAbsent(e.$1, () => {}).add(e.$2);
      adj.putIfAbsent(e.$2, () => {}).add(e.$1);
    }
    final keep = {f.focus!};
    var front = {f.focus!};
    for (var i = 0; i < f.depth; i++) {
      front = {for (final p in front) ...?adj[p]}..removeAll(keep);
      keep.addAll(front);
    }
    nodes.removeWhere((id, _) => !keep.contains(id));
    edges.removeWhere((e) => !keep.contains(e.$1) || !keep.contains(e.$2));
  }

  for (final e in edges) {
    nodes[e.$1]!.degree++;
    nodes[e.$2]!.degree++;
  }
  // Без связей: заметки-одиночки прячутся по фильтру; теги и несозданные без связей не бывают.
  if (!f.orphans) nodes.removeWhere((id, n) => n.degree == 0 && id != f.focus);
  final list = nodes.values.toList()..sort((a, b) => a.id.compareTo(b.id));
  final at = {for (var i = 0; i < list.length; i++) list[i].id: i};
  final links = [for (final e in edges.toList()..sort((a, b) => '${a.$1}|${a.$2}'.compareTo('${b.$1}|${b.$2}'))) (at[e.$1]!, at[e.$2]!)];
  return GraphData(list, links);
}

/// Радиус точки на ×1 (в точках экрана): растёт с числом связей, как в Obsidian.
double dotRadius(int degree) => 3 + math.sqrt(degree.toDouble()) * 1.6;

/// Масштаб, с которого точка — шапка с названием (×2) и нода (×3).
const zoomNames = 1.8;
const zoomNodes = 3.2;

/// Насколько точка раскрыта при масштабе [k] и расстоянии до центра экрана [far] (0 — в центре, 1 — у края):
/// 0 — точка, 1 — шапка с названием, 2 — нода. Дробные значения — переход (220 мс на экране).
double openness(double k, double far) {
  final names = ((k - zoomNames * .85) / (zoomNames * .3)).clamp(0.0, 1.0);
  var nodes = ((k - zoomNodes * .85) / (zoomNodes * .3)).clamp(0.0, 1.0);
  // Ноды раскрываются только там, куда смотришь: у края экрана остаются шапками.
  nodes *= (1 - ((far - .55) / .3)).clamp(0.0, 1.0);
  return names + nodes;
}

/// Первые строки заметки для ноды ×3: без шапки свойств, заголовков-решёток и разметки ссылок.
List<String> previewLines(String text, {int n = 2, int width = 60}) {
  final fs = frontSpan(text);
  final body = fs == null ? text : text.substring(fs.bodyStart);
  final out = <String>[];
  for (var l in body.split('\n')) {
    l = l.trim();
    if (l.isEmpty || l.startsWith('```') || l.startsWith('![[')) continue;
    l = l.replaceFirst(RegExp(r'^#{1,6}\s+'), '').replaceFirst(RegExp(r'^[-*+]\s+(\[.\]\s+)?'), '');
    l = l.replaceAll(RegExp(r'!\[\[[^\]]*\]\]'), '');
    l = l.replaceAllMapped(RegExp(r'\[\[(?:[^\]|]*\|)?([^\]]*)\]\]'), (m) => m[1]!).replaceAll(RegExp(r'[*_`]'), '').trim();
    if (l.isEmpty) continue;
    out.add(l.length > width ? '${l.substring(0, width - 1)}…' : l);
    if (out.length >= n) break;
  }
  return out;
}

/// Камера графа: масштаб [k] и сдвиг. Экран = граф · k + сдвиг.
class GraphCamera {
  double k;
  double dx;
  double dy;
  GraphCamera([this.k = 1, this.dx = 0, this.dy = 0]);

  (double, double) toScreen(double x, double y) => (x * k + dx, y * k + dy);
  (double, double) toGraph(double sx, double sy) => ((sx - dx) / k, (sy - dy) / k);

  /// Приблизить в [by] раз вокруг точки экрана (колёсико — вокруг курсора). Масштаб — от 0.1 до 8.
  void zoomAt(double by, double sx, double sy) {
    final nk = (k * by).clamp(0.1, 8.0);
    final (gx, gy) = toGraph(sx, sy);
    k = nk;
    dx = sx - gx * k;
    dy = sy - gy * k;
  }

  /// Уместить прямоугольник графа в экран [w]×[h] с полями [pad]; масштаб не больше [maxK].
  void fit(double x0, double y0, double x1, double y1, double w, double h, {double pad = 40, double maxK = 1.6}) {
    final gw = math.max(x1 - x0, 1.0), gh = math.max(y1 - y0, 1.0);
    k = math.min(math.min((w - pad * 2) / gw, (h - pad * 2) / gh), maxK).clamp(0.1, 8.0);
    dx = w / 2 - (x0 + x1) / 2 * k;
    dy = h / 2 - (y0 + y1) / 2 * k;
  }

  /// Поставить точку графа в центр экрана с масштабом [nk].
  void centerOn(double x, double y, double w, double h, [double? nk]) {
    if (nk != null) k = nk.clamp(0.1, 8.0);
    dx = w / 2 - x * k;
    dy = h / 2 - y * k;
  }
}
