// Локальный граф для панели «Связи» (docs/knowledge.md, шаг 7): заметка и соседи на глубину 1–2,
// разложенные той же силовой раскладкой, что большой граф. Без Flutter — проверяется тестом.
import 'force.dart';
import 'index.dart';

class LocalGraph {
  /// Точки: id = путь заметки, первая — сама заметка (в центре, закреплена).
  final List<ForceNode> nodes;
  final List<ForceLink> links;

  /// Глубина от заметки: 0 — она сама, 1 — прямые соседи…
  final Map<String, int> depth;
  const LocalGraph(this.nodes, this.links, this.depth);
}

LocalGraph localGraph(NoteIndex ix, String path, {int depth = 1, int max = 60}) {
  // Обход в ширину — чтобы знать глубину каждой точки и обрезать по [max] ближних.
  final adj = <String, Set<String>>{};
  for (final e in ix.edges()) {
    adj.putIfAbsent(e.a, () => {}).add(e.b);
    adj.putIfAbsent(e.b, () => {}).add(e.a);
  }
  final d = <String, int>{path: 0};
  var front = [path];
  for (var i = 1; i <= depth && d.length < max; i++) {
    final next = <String>[];
    for (final p in front) {
      for (final n in (adj[p] ?? const <String>{}).toList()..sort()) {
        if (d.length >= max) break;
        if (d.containsKey(n)) continue;
        d[n] = i;
        next.add(n);
      }
    }
    front = next;
  }
  final ids = d.keys.toList();
  final at = {for (var i = 0; i < ids.length; i++) ids[i]: i};
  final nodes = [for (final id in ids) ForceNode(id, r: id == path ? 7 : 4.5, fx: id == path ? 0 : null, fy: id == path ? 0 : null)];
  final links = <ForceLink>[];
  for (final e in ix.edges()) {
    final a = at[e.a], b = at[e.b];
    if (a != null && b != null) links.add(ForceLink(a, b));
  }
  ForceSim(nodes, links, params: const ForceParams(charge: -120, linkDistance: 46, collide: 8)).run(maxTicks: 300);
  return LocalGraph(nodes, links, d);
}
