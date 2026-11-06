// Граф знаний (docs/knowledge.md, шаги 8–9; макеты G_NotesGraph, G_NotesZoom, G_NotesGraphNear).
// Слева нода «Фильтры» (поиск, весь/локальный, группы по папкам, что показывать, силы), справа холст:
// ×1 — точки (размер — число связей, цвет — папка), ×2 — шапки с названиями, ×3 — ноды с первыми строками
// и тегами, ссылки — провода с сокетами. Ноды раскрываются только ближе к центру экрана — граф из тысяч
// заметок не тормозит. Колёсико — масштаб, тянуть фон — двигать, тянуть точку — граф подстраивается,
// двойной клик — сразу ×3 вокруг точки (на ×3 — открыть заметку), Enter — открыть, L — локальный.
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../core/notes/force.dart';
import '../../core/notes/graph.dart';
import '../../core/notes/index.dart' show foldText;
import '../../state/notes_state.dart';
import '../theme/tokens.dart';
import 'hue.dart';

class GraphView extends StatefulWidget {
  const GraphView({super.key, required this.st});
  final NotesState st;
  @override
  State<GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends State<GraphView> with SingleTickerProviderStateMixin {
  NotesState get st => widget.st;

  GraphFilter _f = const GraphFilter();
  bool _local = false;
  final _q = TextEditingController();
  double _charge = -90, _dist = 60, _gravity = .06;

  GraphData? _g;
  ForceSim? _sim;
  String? _dataKey;
  final _cam = GraphCamera();
  bool _fitted = false;
  Size _size = Size.zero;
  String? _sel;
  String? _hover;
  late final Ticker _ticker;

  // Плавный перелёт камеры (двойной клик, кнопки масштаба), 220 мс.
  GraphCamera? _from, _to;
  Duration? _flyStart;
  Duration _now = Duration.zero;

  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _sel = st.active;
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _q.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTick(Duration t) {
    _now = t;
    var changed = false;
    if (_sim != null && !_sim!.settled) {
      _sim!.tick();
      changed = true;
    }
    if (_to != null) {
      _flyStart ??= t;
      final p = ((t - _flyStart!).inMilliseconds / 220).clamp(0.0, 1.0);
      final e = SpMotion.ease.transform(p);
      _cam
        ..k = _from!.k + (_to!.k - _from!.k) * e
        ..dx = _from!.dx + (_to!.dx - _from!.dx) * e
        ..dy = _from!.dy + (_to!.dy - _from!.dy) * e;
      if (p >= 1) _to = _from = _flyStart = null;
      changed = true;
    }
    if (changed && mounted) {
      setState(() {});
    } else {
      _ticker.stop(); // всё остыло — не крутим кадры зря
    }
  }

  void _wake() {
    if (!_ticker.isActive) _ticker.start();
  }

  void _fly(GraphCamera to) {
    _from = GraphCamera(_cam.k, _cam.dx, _cam.dy);
    _to = to;
    _flyStart = null;
    _wake();
  }

  GraphFilter get _filter => _local ? _f.copyWith(focus: _sel ?? st.active) : _f.copyWith(clearFocus: true);

  /// Пересобрать граф, если поменялись заметки или фильтр. Старые положения точек сохраняются.
  void _ensure() {
    final f = _filter;
    final key = '${identityHashCode(st.index)}|${st.index.version}|${f.focus}|${f.depth}|${f.tags}|${f.files}|${f.orphans}|${f.missing}|${f.hidden.join(',')}';
    if (key == _dataKey && _g != null) return;
    final old = {for (final n in _sim?.nodes ?? const <ForceNode>[]) n.id: n};
    final g = buildGraph(st.index, f);
    final nodes = [
      for (final n in g.nodes) ForceNode(n.id, x: old[n.id]?.x ?? double.nan, y: old[n.id]?.y ?? double.nan, r: dotRadius(n.degree)),
    ];
    final sim = ForceSim(nodes, [for (final (a, b) in g.links) ForceLink(a, b)], params: _params());
    if (old.isNotEmpty) sim.alpha = .5;
    // Первый раз раскладываем заранее, чтобы граф не «взрывался» на глазах.
    if (old.isEmpty) sim.run(maxTicks: nodes.length > 1500 ? 120 : 220);
    _g = g;
    _sim = sim;
    _dataKey = key;
    _fitted = false;
    WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _wake() : null);
  }

  ForceParams _params() => ForceParams(charge: _charge, linkDistance: _dist, gravity: _gravity, collide: .7);

  void _forces() {
    _sim?.params = _params();
    _sim?.reheat(.5);
    _wake();
    setState(() {});
  }

  void _fit({bool fly = false}) {
    final sim = _sim;
    if (sim == null || sim.nodes.isEmpty || _size.isEmpty) return;
    final (x0, y0, x1, y1) = sim.bounds();
    final c = GraphCamera()..fit(x0, y0, x1, y1, _size.width, _size.height, pad: 60, maxK: 1.4);
    if (fly) {
      _fly(c);
    } else {
      _cam
        ..k = c.k
        ..dx = c.dx
        ..dy = c.dy;
    }
  }

  void _zoomBy(double by) {
    final c = GraphCamera(_cam.k, _cam.dx, _cam.dy)..zoomAt(by, _size.width / 2, _size.height / 2);
    _fly(c);
  }

  GraphNode? _node(String? id) {
    final g = _g;
    if (g == null || id == null) return null;
    final i = g.indexOf(id);
    return i < 0 ? null : g.nodes[i];
  }

  void _open(String id) {
    final n = _node(id);
    if (n == null) return;
    switch (n.kind) {
      case GraphKind.note:
        st.openNote(id);
      case GraphKind.missing:
        st.create('', n.label);
      case GraphKind.tag:
        _q.text = n.label;
        setState(() {});
      case GraphKind.file:
        break;
    }
  }

  /// Двойной клик: издалека — перелёт к ×3 вокруг точки, вблизи — открыть.
  void _double(String id) {
    final i = _g!.indexOf(id);
    final n = _sim!.nodes[i];
    if (_cam.k >= zoomNodes) {
      _open(id);
    } else {
      _fly(GraphCamera()..centerOn(n.x, n.y, _size.width, _size.height, zoomNodes * 1.25));
    }
  }

  // ---------- раскладка на экране ----------

  List<_Box> _boxes() {
    final g = _g!, sim = _sim!;
    final w = _size.width, h = _size.height;
    final cx = w / 2, cy = h / 2;
    final half = math.sqrt(cx * cx + cy * cy);
    final out = <_Box>[];
    for (var i = 0; i < g.nodes.length; i++) {
      final n = g.nodes[i], p = sim.nodes[i];
      final (sx, sy) = _cam.toScreen(p.x, p.y);
      if (sx < -260 || sy < -200 || sx > w + 260 || sy > h + 200) continue;
      final far = math.sqrt((sx - cx) * (sx - cx) + (sy - cy) * (sy - cy)) / half;
      var o = openness(_cam.k, far);
      if (n.kind == GraphKind.tag || n.kind == GraphKind.file) o = math.min(o, 1);
      Rect r;
      if (o < .5) {
        final rad = dotRadius(n.degree) * (1 + o);
        r = Rect.fromCircle(center: Offset(sx, sy), radius: rad);
      } else if (o < 1.5) {
        final tw = math.min(_measure(n.label.toUpperCase(), 9.5) + 20, 200.0);
        r = Rect.fromCenter(center: Offset(sx, sy), width: tw, height: 22);
      } else {
        r = Rect.fromCenter(center: Offset(sx, sy), width: 196, height: n.kind == GraphKind.missing ? 62 : 92);
      }
      out.add(_Box(i, r, o));
    }
    return out;
  }

  final Map<String, double> _widths = {};
  double _measure(String s, double size) => _widths.putIfAbsent('$size|$s', () {
        final tp = TextPainter(text: TextSpan(text: s, style: SpType.label(size)), textDirection: TextDirection.ltr, maxLines: 1)..layout();
        return tp.width;
      });

  _Box? _hit(List<_Box> boxes, Offset p) {
    for (final b in boxes.reversed) {
      final r = b.o < .5 ? b.r.inflate(5) : b.r;
      if (r.contains(p)) return b;
    }
    return null;
  }

  // ---------- жесты ----------

  int? _dragNode;
  Offset? _panFrom;
  List<_Box> _last = const [];

  void _down(Offset p) {
    final b = _hit(_last, p);
    if (b != null) {
      _dragNode = b.i;
      final n = _sim!.nodes[b.i];
      n.fx = n.x;
      n.fy = n.y;
    } else {
      _panFrom = p;
    }
  }

  void _move(Offset p, Offset delta) {
    if (_dragNode != null) {
      final n = _sim!.nodes[_dragNode!];
      final (gx, gy) = _cam.toGraph(p.dx, p.dy);
      n.fx = gx;
      n.fy = gy;
      _sim!.reheat(.3);
      _wake();
    } else if (_panFrom != null) {
      _cam.dx += delta.dx;
      _cam.dy += delta.dy;
      setState(() {});
    }
  }

  void _up() {
    if (_dragNode != null) {
      final n = _sim!.nodes[_dragNode!];
      n.fx = n.fy = null;
    }
    _dragNode = null;
    _panFrom = null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) {
        _ensure();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(width: 264, child: _filters()),
            const SizedBox(width: 16),
            Expanded(child: _canvas()),
          ]),
        );
      },
    );
  }

  // ---------- нода «Фильтры» ----------

  Widget _filters() {
    final groups = <String, int>{};
    for (final p in st.index.paths) {
      final g = topGroup(p);
      groups[g] = (groups[g] ?? 0) + 1;
    }
    final names = groups.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final all = st.index.paths.toList();
    Widget sw(String label, bool v, ValueChanged<bool> on) => InkWell(
          onTap: () => on(!v),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 5, 12, 5),
            child: Row(children: [
              Expanded(child: Text(label, style: SpType.text(13))),
              _Toggle(on: v),
            ]),
          ),
        );
    Widget slider(String label, double v, double min, double max, ValueChanged<double> on) => Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 8, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: SpType.text(12.5, color: SpColors.muted)),
            SliderTheme(
              data: const SliderThemeData(
                trackHeight: 2,
                activeTrackColor: SpColors.accent,
                inactiveTrackColor: SpColors.line,
                thumbColor: SpColors.accentInk,
                overlayShape: RoundSliderOverlayShape(overlayRadius: 10),
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: SizedBox(height: 24, child: Slider(value: v.clamp(min, max), min: min, max: max, onChanged: on, onChangeEnd: (_) => _forces())),
            ),
          ]),
        );
    return Container(
      decoration: BoxDecoration(color: SpColors.node, borderRadius: BorderRadius.circular(SpRadius.node), border: Border.all(color: SpColors.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 34,
          padding: const EdgeInsets.only(left: 12, right: 10),
          decoration: const BoxDecoration(color: SpColors.headGrey, borderRadius: BorderRadius.vertical(top: Radius.circular(SpRadius.node - 1))),
          child: Row(children: [
            Text('01', style: SpType.label(10.5, color: const Color(0x99FFFFFF))),
            const SizedBox(width: 8),
            Text('ФИЛЬТРЫ', style: SpType.label(10.5, w: FontWeight.w500, color: Colors.white, spacing: .14)),
          ]),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.only(bottom: 10), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: SizedBox(
                height: 32,
                child: TextField(
                  controller: _q,
                  onChanged: (_) => setState(() {}),
                  style: SpType.text(13),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Найти на графе',
                    hintStyle: SpType.text(13, color: SpColors.muted),
                    prefixIcon: const Icon(Icons.search, size: 15, color: SpColors.muted),
                    prefixIconConstraints: const BoxConstraints(minWidth: 30),
                    filled: true,
                    fillColor: SpColors.bg,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: SpColors.lineStrong)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: SpColors.accent)),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(children: [
                for (final (label, v) in const [('ВЕСЬ', false), ('ЛОКАЛЬНЫЙ', true)])
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _local = v),
                      child: Container(
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _local == v ? SpColors.ink : Colors.transparent,
                          border: Border.all(color: _local == v ? SpColors.ink : SpColors.line),
                          borderRadius: BorderRadius.horizontal(left: Radius.circular(v ? 0 : 6), right: Radius.circular(v ? 6 : 0)),
                        ),
                        child: Text(label, style: SpType.label(10, w: FontWeight.w500, color: _local == v ? SpColors.bg : SpColors.muted)),
                      ),
                    ),
                  ),
              ]),
            ),
            if (_local)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Row(children: [
                  Text('Глубина', style: SpType.text(12.5, color: SpColors.muted)),
                  const Spacer(),
                  for (final d in const [1, 2, 3])
                    InkWell(
                      onTap: () => setState(() => _f = _f.copyWith(depth: d)),
                      child: Container(
                        width: 26,
                        height: 22,
                        margin: const EdgeInsets.only(left: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _f.depth == d ? SpColors.accentWash : Colors.transparent,
                          border: Border.all(color: _f.depth == d ? SpColors.accentLine : SpColors.line),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text('$d', style: SpType.label(10.5, color: _f.depth == d ? SpColors.accentInk : SpColors.muted)),
                      ),
                    ),
                ]),
              ),
            _sec('ГРУППЫ · ЦВЕТ ПО ПАПКЕ'),
            for (final g in names)
              InkWell(
                onTap: () => setState(() {
                  final h = {..._f.hidden};
                  h.contains(g) ? h.remove(g) : h.add(g);
                  _f = _f.copyWith(hidden: h);
                }),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 5, 14, 5),
                  child: Opacity(
                    opacity: _f.hidden.contains(g) ? .4 : 1,
                    child: Row(children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: folderHue(g.isEmpty ? 'x' : '$g/', all), borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 9),
                      Expanded(child: Text(g.isEmpty ? 'В корне' : g, overflow: TextOverflow.ellipsis, style: SpType.text(13))),
                      Text('${groups[g]}', style: SpType.label(11, color: SpColors.dim, spacing: 0)),
                    ]),
                  ),
                ),
              ),
            _sec('ПОКАЗЫВАТЬ'),
            sw('Теги точками', _f.tags, (v) => setState(() => _f = _f.copyWith(tags: v))),
            sw('Вложения', _f.files, (v) => setState(() => _f = _f.copyWith(files: v))),
            sw('Без связей', _f.orphans, (v) => setState(() => _f = _f.copyWith(orphans: v))),
            sw('Ещё не созданные', _f.missing, (v) => setState(() => _f = _f.copyWith(missing: v))),
            _sec('СИЛЫ'),
            slider('Отталкивание', -_charge, 10, 300, (v) => setState(() => _charge = -v)),
            slider('Длина связей', _dist, 15, 160, (v) => setState(() => _dist = v)),
            slider('Притяжение к центру', _gravity, 0, .3, (v) => setState(() => _gravity = v)),
          ]),
        ),
      ]),
    );
  }

  Widget _sec(String t) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: SpColors.line))),
        child: Text(t, style: SpType.label(9.5)),
      );

  // ---------- холст ----------

  Widget _canvas() {
    final g = _g!;
    final sel = _node(_sel);
    final selNeighbours = sel == null ? 0 : st.index.degree(sel.id);
    final q = foldText(_q.text.trim());
    final match = q.isEmpty ? null : {for (final n in g.nodes) if (foldText(n.label).contains(q)) n.id};
    return Container(
      decoration: BoxDecoration(
        color: SpColors.ground,
        borderRadius: BorderRadius.circular(SpRadius.hub),
        border: Border.all(color: SpColors.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SpRadius.hub - 1),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            height: 44,
            padding: const EdgeInsets.only(left: 16, right: 10),
            decoration: const BoxDecoration(color: SpColors.node, border: Border(bottom: BorderSide(color: SpColors.line))),
            child: Row(children: [
              Text('02 · ГРАФ ЗНАНИЙ', style: SpType.label(10.5, w: FontWeight.w500, color: SpColors.ink, spacing: .14)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  '${_notesIn(g)} ${_plural(_notesIn(g), 'ЗАМЕТКА', 'ЗАМЕТКИ', 'ЗАМЕТОК')} · ${g.links.length} ${_plural(g.links.length, 'СВЯЗЬ', 'СВЯЗИ', 'СВЯЗЕЙ')}'
                  '${sel == null ? '' : ' · ВЫБРАНО: $selNeighbours ${_plural(selNeighbours, 'СОСЕД', 'СОСЕДА', 'СОСЕДЕЙ')}'}',
                  overflow: TextOverflow.ellipsis,
                  style: SpType.label(9.5),
                ),
              ),
              TextButton(
                onPressed: () => st.show('note'),
                style: TextButton.styleFrom(minimumSize: const Size(0, 28), padding: const EdgeInsets.symmetric(horizontal: 10), foregroundColor: SpColors.ink),
                child: Text('← К заметке', style: SpType.text(12.5, w: FontWeight.w500)),
              ),
            ]),
          ),
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              _size = box.biggest;
              if (!_fitted && _sim != null) {
                _fit();
                _fitted = true;
              }
              final boxes = _boxes();
              _last = boxes;
              return Focus(
                focusNode: _focus,
                autofocus: true,
                onKeyEvent: (_, e) {
                  if (e is! KeyDownEvent) return KeyEventResult.ignored;
                  if (e.logicalKey == LogicalKeyboardKey.enter && _sel != null) {
                    _open(_sel!);
                    return KeyEventResult.handled;
                  }
                  if (e.logicalKey == LogicalKeyboardKey.keyL && _sel != null) {
                    setState(() => _local = !_local);
                    return KeyEventResult.handled;
                  }
                  if (e.logicalKey == LogicalKeyboardKey.escape) {
                    st.show('note');
                    return KeyEventResult.handled;
                  }
                  if (e.logicalKey == LogicalKeyboardKey.equal || e.logicalKey == LogicalKeyboardKey.numpadAdd) {
                    _zoomBy(1.4);
                    return KeyEventResult.handled;
                  }
                  if (e.logicalKey == LogicalKeyboardKey.minus || e.logicalKey == LogicalKeyboardKey.numpadSubtract) {
                    _zoomBy(1 / 1.4);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Stack(children: [
                  Positioned.fill(
                    child: Listener(
                      onPointerSignal: (e) {
                        if (e is PointerScrollEvent) {
                          setState(() => _cam.zoomAt(math.exp(-e.scrollDelta.dy / 400), e.localPosition.dx, e.localPosition.dy));
                        }
                      },
                      onPointerHover: (e) {
                        final b = _hit(boxes, e.localPosition);
                        final id = b == null ? null : g.nodes[b.i].id;
                        if (id != _hover) setState(() => _hover = id);
                      },
                      child: MouseRegion(
                        cursor: _hover != null ? SystemMouseCursors.click : SystemMouseCursors.grab,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (d) {
                            _focus.requestFocus();
                            final b = _hit(boxes, d.localPosition);
                            setState(() => _sel = b == null ? null : g.nodes[b.i].id);
                          },
                          onDoubleTapDown: (d) {
                            final b = _hit(boxes, d.localPosition);
                            if (b != null) _double(g.nodes[b.i].id);
                          },
                          onDoubleTap: () {},
                          onPanStart: (d) => _down(d.localPosition),
                          onPanUpdate: (d) => _move(d.localPosition, d.delta),
                          onPanEnd: (_) => _up(),
                          child: CustomPaint(
                            size: box.biggest,
                            painter: _GraphPaint(
                              g: g,
                              sim: _sim!,
                              cam: _cam,
                              boxes: boxes,
                              sel: _sel,
                              hover: _hover,
                              match: match,
                              all: st.index.paths.toList(),
                              text: st.index.text,
                              tags: (id) => st.index.doc(id)?.tags ?? const [],
                              tick: _now.inMilliseconds,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (sel != null) Positioned(left: 16, bottom: 16, child: _card(sel)),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Row(children: [
                        _ZoomBtn('＋', 'Ближе', () => _zoomBy(1.4)),
                        const SizedBox(width: 4),
                        _ZoomBtn('−', 'Дальше', () => _zoomBy(1 / 1.4)),
                        const SizedBox(width: 4),
                        _ZoomBtn('⤢', 'Весь граф', () => _fit(fly: true)),
                      ]),
                      const SizedBox(height: 10),
                      _stamp(g),
                    ]),
                  ),
                ]),
              );
            }),
          ),
        ]),
      ),
    );
  }

  Widget _card(GraphNode n) {
    final tags = n.kind == GraphKind.note ? (st.index.doc(n.id)?.tags ?? const <String>[]) : const <String>[];
    final lines = n.kind == GraphKind.note ? previewLines(st.index.text(n.id) ?? '', n: 1, width: 48) : const <String>[];
    final all = st.index.paths.toList();
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: SpColors.node,
        borderRadius: BorderRadius.circular(SpRadius.node),
        border: Border.all(color: SpColors.accentLine),
        boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: folderHead(n.id, all), borderRadius: const BorderRadius.vertical(top: Radius.circular(SpRadius.node - 1))),
          child: Row(children: [
            Expanded(child: Text(n.label.toUpperCase(), overflow: TextOverflow.ellipsis, style: SpType.label(10.5, w: FontWeight.w500, color: Colors.white))),
            Text('↔ ${n.kind == GraphKind.note ? st.index.degree(n.id) : n.degree}', style: SpType.label(10.5, color: const Color(0xCCFFFFFF))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (n.kind == GraphKind.missing) Text('Заметки ещё нет', style: SpType.text(12.5, color: SpColors.muted)),
            for (final l in lines) Text(l, maxLines: 2, overflow: TextOverflow.ellipsis, style: SpType.text(12.5, color: SpColors.body)),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, children: [for (final t in tags.take(4)) Text('#$t', style: SpType.text(12, color: SpColors.blue))]),
            ],
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Wrap(spacing: 12, runSpacing: 4, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    _Kbd('ENTER'),
                    Text(n.kind == GraphKind.missing ? ' создать' : ' открыть', style: SpType.text(12, color: SpColors.muted)),
                  ]),
                  if (n.kind == GraphKind.note)
                    Row(mainAxisSize: MainAxisSize.min, children: [_Kbd('L'), Text(_local ? ' весь граф' : ' локальный', style: SpType.text(12, color: SpColors.muted))]),
                ]),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _open(n.id),
                style: TextButton.styleFrom(minimumSize: const Size(0, 26), padding: const EdgeInsets.symmetric(horizontal: 10), backgroundColor: SpColors.accent, foregroundColor: SpColors.onAccent),
                child: Text(n.kind == GraphKind.missing ? 'Создать' : 'Открыть', style: SpType.text(12, w: FontWeight.w600, color: SpColors.onAccent)),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _stamp(GraphData g) {
    final d = DateTime.now();
    final date = '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${(d.year % 100).toString().padLeft(2, '0')}';
    final level = _cam.k >= zoomNodes ? '×3' : _cam.k >= zoomNames ? '×2' : '×1';
    Widget cell(String t, {bool first = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(border: first ? null : const Border(left: BorderSide(color: SpColors.line))),
          child: Text(t, style: SpType.label(9, color: SpColors.dim)),
        );
    return Container(
      decoration: BoxDecoration(color: SpColors.bg, border: Border.all(color: SpColors.line), borderRadius: BorderRadius.circular(4)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        cell('ЛИСТ · ГРАФ ЗНАНИЙ', first: true),
        cell(date),
        cell('${g.nodes.length} · ${g.links.length}'),
        cell('МАСШТАБ $level'),
      ]),
    );
  }
}

int _notesIn(GraphData g) => g.nodes.where((n) => n.kind == GraphKind.note).length;

String _plural(int n, String one, String few, String many) {
  final m10 = n % 10, m100 = n % 100;
  if (m10 == 1 && m100 != 11) return one;
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few;
  return many;
}

class _Box {
  final int i;
  final Rect r;
  final double o;
  const _Box(this.i, this.r, this.o);
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.on});
  final bool on;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: SpMotion.fast,
        width: 28,
        height: 16,
        padding: const EdgeInsets.all(2),
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(color: on ? SpColors.accent : SpColors.line, borderRadius: BorderRadius.circular(8)),
        child: Container(width: 12, height: 12, decoration: BoxDecoration(color: on ? SpColors.onAccent : SpColors.muted, borderRadius: BorderRadius.circular(6))),
      );
}

class _ZoomBtn extends StatelessWidget {
  const _ZoomBtn(this.label, this.tip, this.onTap);
  final String label;
  final String tip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Tooltip(
        message: tip,
        child: Material(
          color: SpColors.node,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SpRadius.button), side: const BorderSide(color: SpColors.line)),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(SpRadius.button),
            child: SizedBox(width: 30, height: 30, child: Center(child: Text(label, style: SpType.text(15, color: SpColors.ink)))),
          ),
        ),
      );
}

class _Kbd extends StatelessWidget {
  const _Kbd(this.t);
  final String t;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(border: Border.all(color: SpColors.line), borderRadius: BorderRadius.circular(4)),
        child: Text(t, style: SpType.label(9, color: SpColors.muted, spacing: .06)),
      );
}

class _GraphPaint extends CustomPainter {
  _GraphPaint({
    required this.g,
    required this.sim,
    required this.cam,
    required this.boxes,
    required this.sel,
    required this.hover,
    required this.match,
    required this.all,
    required this.text,
    required this.tags,
    required this.tick,
  });
  final GraphData g;
  final ForceSim sim;
  final GraphCamera cam;
  final List<_Box> boxes;
  final String? sel;
  final String? hover;
  final Set<String>? match;
  final List<String> all;
  final String? Function(String) text;
  final List<String> Function(String) tags;
  final int tick;

  static final Map<String, TextPainter> _tp = {};
  static TextPainter _text(String s, TextStyle st, {double max = 400}) {
    final key = '${st.fontSize}|${st.color?.toARGB32()}|${st.fontWeight}|${st.fontFamily}|$max|$s';
    if (_tp.length > 4000) _tp.clear();
    return _tp.putIfAbsent(key, () => TextPainter(text: TextSpan(text: s, style: st), textDirection: TextDirection.ltr, maxLines: 1, ellipsis: '…')..layout(maxWidth: max));
  }

  Color _hue(GraphNode n) => switch (n.kind) {
        GraphKind.tag => SpColors.blue,
        GraphKind.missing => SpColors.dim,
        GraphKind.file => SpColors.grey,
        GraphKind.note => folderHue(n.id, all),
      };

  Color _head(GraphNode n) => n.kind == GraphKind.note ? folderHead(n.id, all) : SpColors.headGrey;

  @override
  void paint(Canvas canvas, Size size) {
    // Точки холста — как у всех экранов G, двигаются вместе с графом.
    final dots = Paint()..color = SpColors.dot;
    final step = 24.0;
    final ox = cam.dx % step, oy = cam.dy % step;
    for (var y = oy; y < size.height; y += step) {
      for (var x = ox; x < size.width; x += step) {
        canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), dots);
      }
    }

    final byIndex = {for (final b in boxes) b.i: b};
    final selI = sel == null ? -1 : g.indexOf(sel!);
    final hovI = hover == null ? -1 : g.indexOf(hover!);
    final near = <int>{};
    for (final (a, b) in g.links) {
      if (a == selI || a == hovI) near.add(b);
      if (b == selI || b == hovI) near.add(a);
    }
    final focus = selI >= 0 || hovI >= 0;
    bool dimmed(int i) {
      if (match != null && !match!.contains(g.nodes[i].id)) return true;
      return false;
    }

    // Провода.
    final wire = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = SpColors.line;
    final hot = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = SpColors.accent;
    for (final (a, b) in g.links) {
      final ba = byIndex[a], bb = byIndex[b];
      if (ba == null && bb == null) continue;
      final pa = sim.nodes[a], pb = sim.nodes[b];
      final (ax, ay) = cam.toScreen(pa.x, pa.y);
      final (bx, by) = cam.toScreen(pb.x, pb.y);
      final isHot = a == selI || b == selI || a == hovI || b == hovI;
      final p = isHot ? hot : wire;
      final faded = (match != null && (dimmed(a) || dimmed(b))) || (focus && !isHot);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = p.strokeWidth
        ..color = p.color.withValues(alpha: faded ? .35 : 1);
      final missing = g.nodes[a].kind == GraphKind.missing || g.nodes[b].kind == GraphKind.missing;
      if ((ba?.o ?? 0) >= 1.5 && (bb?.o ?? 0) >= 1.5) {
        // Ноды: провод от сокета справа у левой к сокету слева у правой.
        final (l, r) = ba!.r.center.dx <= bb!.r.center.dx ? (ba, bb) : (bb, ba);
        final s = Offset(l.r.right, l.r.top + 13), e = Offset(r.r.left, r.r.top + 13);
        final dx = math.max((e.dx - s.dx).abs() / 2, 40.0);
        final path = Path()
          ..moveTo(s.dx, s.dy)
          ..cubicTo(s.dx + dx, s.dy, e.dx - dx, e.dy, e.dx, e.dy);
        missing ? _dashed(canvas, path, paint) : canvas.drawPath(path, paint);
        for (final o in [s, e]) {
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: 8, height: 8), const Radius.circular(SpRadius.socket)), Paint()..color = isHot ? SpColors.accent : SpColors.lineStrong);
        }
      } else {
        final path = Path()
          ..moveTo(ax, ay)
          ..lineTo(bx, by);
        missing ? _dashed(canvas, path, paint) : canvas.drawPath(path, paint);
      }
    }

    // Порог подписи на ×1: только у крупных (верхние ~8 % по связям) и у выбранной.
    final degrees = [for (final n in g.nodes) n.degree]..sort();
    final big = degrees.isEmpty ? 1 : math.max(3, degrees[(degrees.length * .92).floor().clamp(0, degrees.length - 1)]);

    for (final b in boxes) {
      final n = g.nodes[b.i];
      final isSel = b.i == selI, isHov = b.i == hovI;
      final fade = dimmed(b.i) || (focus && !isSel && !isHov && !near.contains(b.i));
      final alpha = fade ? .35 : 1.0;
      final hue = _hue(n).withValues(alpha: alpha);
      if (b.o < .5) {
        final c = b.r.center, rad = b.r.width / 2;
        if (n.kind == GraphKind.missing) {
          canvas.drawCircle(c, rad, Paint()
            ..style = PaintingStyle.stroke
            ..color = hue);
        } else {
          canvas.drawRRect(RRect.fromRectAndRadius(b.r, Radius.circular(n.kind == GraphKind.file ? 1.5 : rad)), Paint()..color = hue);
        }
        if (isSel) {
          canvas.drawCircle(c, rad + 4, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = SpColors.accent);
        }
        if (isSel || isHov || n.degree >= big || (match != null && !fade)) {
          final tp = _text(n.label, SpType.text(11, w: isSel ? FontWeight.w600 : FontWeight.w400, color: isSel ? SpColors.accentInk : SpColors.ink.withValues(alpha: alpha * .9)), max: 160);
          tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy + rad + 4));
        }
      } else if (b.o < 1.5) {
        final rr = RRect.fromRectAndRadius(b.r, const Radius.circular(SpRadius.button));
        canvas.drawRRect(rr, Paint()..color = (n.kind == GraphKind.missing ? SpColors.node : _head(n)).withValues(alpha: alpha));
        if (n.kind == GraphKind.missing) {
          _dashed(canvas, Path()..addRRect(rr), Paint()
            ..style = PaintingStyle.stroke
            ..color = SpColors.dim);
        }
        if (isSel) {
          canvas.drawRRect(rr.inflate(3), Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = SpColors.accent);
        }
        final tp = _text(n.label.toUpperCase(), SpType.label(9.5, w: FontWeight.w500, color: Colors.white.withValues(alpha: alpha)), max: b.r.width - 16);
        tp.paint(canvas, Offset(b.r.left + 10, b.r.center.dy - tp.height / 2));
      } else {
        _node(canvas, n, b, isSel, alpha);
      }
    }
  }

  void _node(Canvas canvas, GraphNode n, _Box b, bool isSel, double alpha) {
    final r = b.r;
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(SpRadius.node));
    final missing = n.kind == GraphKind.missing;
    canvas.drawRRect(rr.shift(const Offset(0, 8)), Paint()
      ..color = const Color(0x40000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawRRect(rr, Paint()..color = SpColors.node.withValues(alpha: alpha));
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..color = isSel ? SpColors.accent : SpColors.line;
    missing ? _dashed(canvas, Path()..addRRect(rr), border..color = SpColors.dim) : canvas.drawRRect(rr, border);
    if (!missing) {
      final head = RRect.fromRectAndCorners(Rect.fromLTWH(r.left, r.top, r.width, 26), topLeft: const Radius.circular(SpRadius.node), topRight: const Radius.circular(SpRadius.node));
      canvas.drawRRect(head, Paint()..color = _head(n).withValues(alpha: alpha));
      final grp = n.group.isEmpty ? '' : n.group.toUpperCase();
      final gp = _text(grp, SpType.label(8.5, color: const Color(0xB3FFFFFF)), max: 60);
      final tp = _text(n.label.toUpperCase(), SpType.label(9.5, w: FontWeight.w500, color: Colors.white), max: r.width - 24 - gp.width);
      tp.paint(canvas, Offset(r.left + 10, r.top + 13 - tp.height / 2));
      gp.paint(canvas, Offset(r.right - 10 - gp.width, r.top + 13 - gp.height / 2));
      var y = r.top + 34;
      for (final l in previewLines(text(n.id) ?? '', n: 2, width: 34)) {
        final lp = _text(l, SpType.text(11.5, color: SpColors.body.withValues(alpha: alpha)), max: r.width - 20);
        lp.paint(canvas, Offset(r.left + 10, y));
        y += 17;
      }
      final ts = tags(n.id);
      if (ts.isNotEmpty) {
        var x = r.left + 10;
        for (final t in ts.take(3)) {
          final p = _text('#$t', SpType.text(11, color: SpColors.blue), max: 80);
          if (x + p.width > r.right - 10) break;
          p.paint(canvas, Offset(x, r.bottom - 20));
          x += p.width + 8;
        }
      }
    } else {
      final tp = _text(n.label.toUpperCase(), SpType.label(9.5, w: FontWeight.w500, color: SpColors.muted), max: r.width - 20);
      tp.paint(canvas, Offset(r.left + 10, r.top + 10));
      final hint = _text('Заметки ещё нет · Создать', SpType.text(11.5, color: SpColors.accent), max: r.width - 20);
      hint.paint(canvas, Offset(r.left + 10, r.top + 34));
    }
  }

  void _dashed(Canvas canvas, Path path, Paint p) {
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + 4, m.length)), p);
        d += 7;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPaint old) => true;
}
