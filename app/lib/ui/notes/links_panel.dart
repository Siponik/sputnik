// Панель «Связи» (docs/knowledge.md, шаг 7; макет G_NotesLinks): на что ссылается заметка (несуществующие — «Создать»),
// кто ссылается сюда, где упомянута без ссылки («Связать»), локальный граф глубины 1–2.
import 'package:flutter/material.dart';

import '../../core/notes/force.dart';
import '../../core/notes/local_graph.dart';
import '../../core/notes/parse.dart';
import '../../state/notes_state.dart';
import '../theme/tokens.dart';
import 'hue.dart';

class LinksPanel extends StatefulWidget {
  const LinksPanel({super.key, required this.st, required this.path, required this.onClose});
  final NotesState st;
  final String path;
  final VoidCallback onClose;
  @override
  State<LinksPanel> createState() => _LinksPanelState();
}

class _LinksPanelState extends State<LinksPanel> {
  int _depth = 1;
  bool _allBack = false;
  String? _key;
  LocalGraph? _graph;

  NotesState get st => widget.st;

  LocalGraph _local() {
    final k = '${widget.path}|$_depth|${st.index.length}|${st.index.degree(widget.path)}';
    if (k != _key || _graph == null) {
      _key = k;
      _graph = localGraph(st.index, widget.path, depth: _depth);
    }
    return _graph!;
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.path;
    final all = st.index.paths.toList();
    final out = st.index.outgoing(path);
    // Ссылки наружу — по одной на цель, несуществующие — в конце.
    final seen = <String>{};
    final found = <String>[];
    final missing = <String>[];
    for (final r in out) {
      if (r.to != null) {
        if (r.to != path && seen.add(r.to!)) found.add(r.to!);
      } else if (seen.add('?${r.link.target}') && r.link.target.isNotEmpty) {
        missing.add(r.link.target);
      }
    }
    final back = st.index.backlinks(path);
    final byFrom = <String, String>{};
    for (final b in back) {
      byFrom.putIfAbsent(b.from, () => b.snippet);
    }
    final backs = byFrom.entries.toList();
    final mentions = st.index.mentions(path);
    final g = _local();

    final kids = <Widget>[
      _Head('ССЫЛАЕТСЯ НА · ${found.length + missing.length}'),
      for (final p in found) _Item(name: baseName(p), color: folderHue(p, all), onTap: () => st.openNote(p)),
      for (final m in missing)
        _Item(
          name: m,
          dashed: true,
          action: 'СОЗДАТЬ',
          onAction: () => st.create(folderOf(path), m),
        ),
      if (found.isEmpty && missing.isEmpty) _Hint('Пока ни на что. Напиши [[ и название заметки.'),
      _Head('ССЫЛАЮТСЯ СЮДА · ${backs.length}', line: true),
      for (final e in (_allBack ? backs : backs.take(3)))
        _Item(name: baseName(e.key), color: folderHue(e.key, all), quote: '«${e.value}»', onTap: () => st.openNote(e.key)),
      if (!_allBack && backs.length > 3)
        _More('ещё ${backs.length - 3} ▾', () => setState(() => _allBack = true)),
      if (backs.isEmpty) _Hint('Сюда ещё никто не ссылается.'),
      if (mentions.isNotEmpty) ...[
        _Head('УПОМЯНУТО БЕЗ ССЫЛКИ · ${mentions.length}', line: true),
        for (final m in mentions)
          _Item(
            name: baseName(m.from),
            color: folderHue(m.from, all),
            quote: '«${m.snippet}»',
            onTap: () => st.openNote(m.from),
            action: 'Связать',
            onAction: () => st.linkMentionIn(path, m.from, m.line),
          ),
      ],
      _Head('ЛОКАЛЬНЫЙ ГРАФ · ГЛУБИНА $_depth', line: true),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Container(
          height: 220,
          decoration: BoxDecoration(color: SpColors.ground, borderRadius: BorderRadius.circular(SpRadius.node), border: Border.all(color: SpColors.lineSoft)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(SpRadius.node),
            child: _GraphBox(graph: g, center: path, all: all, onOpen: st.openNote),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        child: Row(children: [
          for (final d in const [1, 2])
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: InkWell(
                onTap: () => setState(() => _depth = d),
                borderRadius: BorderRadius.circular(5),
                child: Container(
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: d == _depth ? SpColors.ink : Colors.transparent,
                    border: Border.all(color: d == _depth ? SpColors.ink : SpColors.line),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text('$d', style: SpType.label(10.5, color: d == _depth ? SpColors.bg : SpColors.muted)),
                ),
              ),
            ),
          const SizedBox(width: 6),
          Expanded(child: Text('Глубина $_depth · ${g.nodes.length} ${_notes(g.nodes.length)}', style: SpType.text(12, color: SpColors.muted))),
        ]),
      ),
    ];

    return Container(
      decoration: BoxDecoration(color: SpColors.node, borderRadius: BorderRadius.circular(SpRadius.node), border: Border.all(color: SpColors.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 34,
          padding: const EdgeInsets.only(left: 12, right: 4),
          decoration: const BoxDecoration(color: SpColors.headGrey, borderRadius: BorderRadius.vertical(top: Radius.circular(SpRadius.node - 1))),
          child: Row(children: [
            Text('СВЯЗИ', style: SpType.label(10.5, w: FontWeight.w500, color: Colors.white, spacing: .14)),
            const Spacer(),
            TextButton(
              onPressed: widget.onClose,
              style: TextButton.styleFrom(minimumSize: const Size(0, 26), padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: Text('ЗАКРЫТЬ ✕', style: SpType.label(10, color: const Color(0xB8FFFFFF))),
            ),
          ]),
        ),
        Expanded(child: ListView(padding: const EdgeInsets.only(bottom: 4), children: kids)),
      ]),
    );
  }
}

String _notes(int n) {
  final m10 = n % 10, m100 = n % 100;
  if (m10 == 1 && m100 != 11) return 'заметка';
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return 'заметки';
  return 'заметок';
}

class _Head extends StatelessWidget {
  const _Head(this.text, {this.line = false});
  final String text;
  final bool line;
  @override
  Widget build(BuildContext context) => Container(
        margin: EdgeInsets.only(top: line ? 6 : 0),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        decoration: line ? const BoxDecoration(border: Border(top: BorderSide(color: SpColors.line))) : null,
        child: Text(text, style: SpType.label(9.5)),
      );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
        child: Text(text, style: SpType.text(12.5, color: SpColors.dim)),
      );
}

class _More extends StatelessWidget {
  const _More(this.text, this.onTap);
  final String text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.fromLTRB(34, 2, 14, 6), child: Text(text, style: SpType.text(12, color: SpColors.muted))),
      );
}

class _Item extends StatelessWidget {
  const _Item({required this.name, this.color, this.quote, this.onTap, this.action, this.onAction, this.dashed = false});
  final String name;
  final Color? color;
  final String? quote;
  final VoidCallback? onTap;
  final String? action;
  final VoidCallback? onAction;
  final bool dashed;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          hoverColor: SpColors.nodeHover,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 5, 6, 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: dashed ? Colors.transparent : color ?? SpColors.grey,
                    border: dashed ? Border.all(color: SpColors.dim) : null,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: dashed
                          ? SpType.text(13, color: SpColors.muted).copyWith(decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.dashed, decorationColor: SpColors.dim)
                          : SpType.text(13)),
                  if (quote != null) Text(quote!, maxLines: 2, overflow: TextOverflow.ellipsis, style: SpType.text(12, color: SpColors.muted)),
                ]),
              ),
              if (action != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 24),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: SpColors.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SpRadius.button), side: const BorderSide(color: SpColors.accentLine)),
                  ),
                  child: Text(action!, style: action == action!.toUpperCase() ? SpType.label(9.5, color: SpColors.accent) : SpType.text(12, w: FontWeight.w600, color: SpColors.accent)),
                ),
            ]),
          ),
        ),
      );
}

/// Рисунок локального графа: вписан в коробку, заметка — оранжевая и крупнее, соседи — цветом папки.
class _GraphBox extends StatelessWidget {
  const _GraphBox({required this.graph, required this.center, required this.all, required this.onOpen});
  final LocalGraph graph;
  final String center;
  final List<String> all;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final fit = _Fit(graph, box.biggest);
        return GestureDetector(
          onTapUp: (d) {
            final id = fit.hit(d.localPosition);
            if (id != null && id != center) onOpen(id);
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: CustomPaint(size: box.biggest, painter: _GraphPaint(graph, fit, center, all)),
          ),
        );
      });
}

class _Fit {
  _Fit(LocalGraph g, Size s) {
    var x0 = 0.0, x1 = 0.0, y0 = 0.0, y1 = 0.0;
    for (final n in g.nodes) {
      if (n.x < x0) x0 = n.x;
      if (n.x > x1) x1 = n.x;
      if (n.y < y0) y0 = n.y;
      if (n.y > y1) y1 = n.y;
    }
    const pad = 28.0;
    final w = (x1 - x0).abs() < 1 ? 1.0 : x1 - x0, h = (y1 - y0).abs() < 1 ? 1.0 : y1 - y0;
    k = [(s.width - pad * 2) / w, (s.height - pad * 2) / h, 2.2].reduce((a, b) => a < b ? a : b);
    ox = s.width / 2 - (x0 + x1) / 2 * k;
    oy = s.height / 2 - (y0 + y1) / 2 * k;
    nodes = g.nodes;
  }
  late final double k, ox, oy;
  late final List<ForceNode> nodes;
  Offset at(double x, double y) => Offset(ox + x * k, oy + y * k);
  String? hit(Offset p) {
    String? best;
    var bd = 14.0 * 14;
    for (final n in nodes) {
      final d = (at(n.x, n.y) - p).distanceSquared;
      if (d < bd) (bd, best) = (d, n.id);
    }
    return best;
  }
}

class _GraphPaint extends CustomPainter {
  _GraphPaint(this.g, this.fit, this.center, this.all);
  final LocalGraph g;
  final _Fit fit;
  final String center;
  final List<String> all;

  @override
  void paint(Canvas canvas, Size size) {
    final wire = Paint()
      ..color = SpColors.line
      ..strokeWidth = 1;
    final main = Paint()
      ..color = SpColors.accentLine
      ..strokeWidth = 1.2;
    for (final l in g.links) {
      final a = g.nodes[l.source], b = g.nodes[l.target];
      canvas.drawLine(fit.at(a.x, a.y), fit.at(b.x, b.y), a.id == center || b.id == center ? main : wire);
    }
    for (final n in g.nodes) {
      final c = fit.at(n.x, n.y);
      final me = n.id == center;
      final r = me ? 6.0 : (g.depth[n.id] == 1 ? 4.5 : 3.5);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCircle(center: c, radius: r), Radius.circular(me ? 3 : 2)), Paint()..color = me ? SpColors.accent : folderHue(n.id, all));
      if (me || g.depth[n.id] == 1 || g.nodes.length <= 12) {
        final tp = TextPainter(
          text: TextSpan(text: baseName(n.id), style: SpType.text(me ? 11.5 : 10.5, w: me ? FontWeight.w600 : FontWeight.w400, color: me ? SpColors.accentInk : SpColors.muted)),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: 120);
        tp.paint(canvas, c + Offset(-tp.width / 2, r + 3));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPaint old) => old.g != g || old.center != center;
}
