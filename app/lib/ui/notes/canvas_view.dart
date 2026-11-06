// Холст `.canvas` (docs/knowledge.md, шаг 12; макет G_NotesCanvas): ноды-заметки в стиле G (шапка цвета папки,
// первые строки, теги), текстовые карточки, картинки, группы-рамки, провода от сокета к сокету с подписями.
// Перетащи заметку из списка слева — появится нода. Колёсико — масштаб, тянуть фон — двигать, двойной клик
// по фону — текст, по заметке — открыть, по тексту — править. Delete — убрать выбранное.
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/notes/canvas.dart';
import '../../core/notes/graph.dart' show GraphCamera, previewLines;
import '../../core/notes/parse.dart';
import '../../core/notes/view.dart' show shownName;
import '../../state/notes_state.dart';
import '../theme/tokens.dart';
import 'hue.dart';
import 'notes_search.dart';

/// Цвета холста JSON Canvas: «1»…«6» — красный, оранжевый, жёлтый, зелёный, голубой, фиолетовый.
Color? canvasColor(String? c) {
  switch (c) {
    case '1':
      return SpColors.red;
    case '2':
      return SpColors.accent;
    case '3':
      return SpColors.gold;
    case '4':
      return SpColors.green;
    case '5':
      return SpColors.blue;
    case '6':
      return SpColors.violet;
  }
  if (c != null && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(c)) return Color(int.parse('FF${c.substring(1)}', radix: 16));
  return null;
}

bool _isImage(String p) => RegExp(r'\.(png|jpe?g|gif|webp)$', caseSensitive: false).hasMatch(p);

class CanvasView extends StatefulWidget {
  const CanvasView({super.key, required this.st, required this.path});
  final NotesState st;
  final String path;
  @override
  State<CanvasView> createState() => _CanvasViewState();
}

class _CanvasViewState extends State<CanvasView> {
  NotesState get st => widget.st;
  CanvasDoc? _doc;
  bool _loading = true;
  final _cam = GraphCamera();
  bool _fitted = false;
  Size _size = Size.zero;
  String? _sel;
  String? _selEdge;
  final _stackKey = GlobalKey();
  final _focus = FocusNode();

  // Провод, который тянут из сокета.
  CanvasSide? _wireSide;
  String? _wireFrom;
  Offset? _wireTo;

  @override
  void initState() {
    super.initState();
    _load();
    st.addListener(_onState);
  }

  @override
  void dispose() {
    st.removeListener(_onState);
    _focus.dispose();
    super.dispose();
  }

  void _onState() {
    // Холст перечитали (снаружи поменяли или пришла копия с другого компьютера).
    if (!_loading && st.canvases[widget.path] == null && st.canvasErrors[widget.path] == null) _load();
  }

  Future<void> _load() async {
    _loading = true;
    final d = await st.canvas(widget.path);
    if (!mounted) return;
    setState(() {
      _doc = d;
      _loading = false;
      _fitted = false;
    });
  }

  void _changed() {
    st.canvasChanged(widget.path);
    setState(() {});
  }

  Offset _toGraph(Offset screen) {
    final (x, y) = _cam.toGraph(screen.dx, screen.dy);
    return Offset(x, y);
  }

  Offset _local(Offset global) {
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    return box == null ? global : box.globalToLocal(global);
  }

  Offset get _center => _toGraph(Offset(_size.width / 2, _size.height / 2));

  void _fit() {
    final d = _doc;
    if (d == null || _size.isEmpty) return;
    final (x0, y0, x1, y1) = d.bounds();
    _cam.fit(x0, y0, x1, y1, _size.width, _size.height, pad: 50, maxK: 1);
  }

  // ---------- действия ----------

  CanvasNode _addNote(String path, Offset at) {
    final n = _doc!.add('file', at.dx - 130, at.dy - 70, w: 260, h: _isImage(path) ? 200 : 140, file: path);
    _sel = n.id;
    _changed();
    return n;
  }

  Future<void> _pickNote() async {
    final pick = await showNotesSearch(context, st);
    if (pick is PickNote && mounted) _addNote(pick.path, _center);
  }

  Future<void> _addText([Offset? at]) async {
    final t = await _editText(context, 'Текст на холсте', '');
    if (t == null || t.isEmpty || !mounted) return;
    final p = at ?? _center;
    final n = _doc!.add('text', p.dx - 125, p.dy - 40, w: 250, h: 90, text: t);
    _sel = n.id;
    _changed();
  }

  Future<void> _addImage() async {
    const types = XTypeGroup(label: 'Картинки', extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp']);
    final f = await openFile(acceptedTypeGroups: const [types], confirmButtonText: 'Положить на холст');
    if (f == null || !mounted) return;
    final embed = await st.attach(f.name, await f.readAsBytes());
    final name = embed.substring(3, embed.length - 2);
    final path = st.index.files.firstWhere((p) => p.endsWith('/$name') || p == name, orElse: () => 'Вложения/$name');
    if (mounted) _addNote(path, _center);
  }

  void _addGroup() {
    final d = _doc!;
    final s = _sel == null ? null : d.node(_sel!);
    CanvasNode g;
    if (s != null && !s.isGroup) {
      g = d.add('group', s.x - 40, s.y - 60, w: s.width + 80, h: s.height + 100, label: 'Группа');
    } else {
      final c = _center;
      g = d.add('group', c.dx - 260, c.dy - 170, w: 520, h: 340, label: 'Группа');
    }
    _sel = g.id;
    _changed();
  }

  void _delete() {
    final d = _doc;
    if (d == null) return;
    if (_selEdge != null) {
      d.edges.removeWhere((e) => e.id == _selEdge);
      _selEdge = null;
      _changed();
    } else if (_sel != null) {
      d.remove(_sel!);
      _sel = null;
      _changed();
    }
  }

  Future<void> _editNode(CanvasNode n) async {
    if (n.type == 'file' && !_isImage(n.file) && st.index.doc(n.file) != null) {
      st.openNote(n.file);
      return;
    }
    if (n.type == 'text') {
      final t = await _editText(context, 'Текст на холсте', n.text);
      if (t == null || !mounted) return;
      n.text = t;
      _changed();
    } else if (n.isGroup) {
      final t = await _editText(context, 'Название группы', n.label, lines: 1);
      if (t == null || !mounted) return;
      n.label = t;
      _changed();
    }
  }

  Future<void> _editEdge(CanvasEdge e) async {
    final t = await _editText(context, 'Подпись провода', e.label, lines: 1, extra: 'Убрать провод');
    if (!mounted || t == null) return;
    if (t == '\u0000') {
      _doc!.edges.remove(e);
    } else {
      e.label = t;
    }
    _changed();
  }

  // ---------- рисование ----------

  @override
  Widget build(BuildContext context) {
    if (_loading) return Center(child: Text('Открываю холст…', style: SpType.text(13, color: SpColors.muted)));
    final err = st.canvasErrors[widget.path];
    if (_doc == null) {
      return Center(
        child: SizedBox(
          width: 420,
          child: Text(
            err == null ? 'Холст не найден' : 'Холст не прочитался: файл повреждён ($err). Я его не трогаю — поправь в другой программе или удали.',
            textAlign: TextAlign.center,
            style: SpType.text(13.5, color: SpColors.muted),
          ),
        ),
      );
    }
    final d = _doc!;
    final notice = st.canvasNotice[widget.path];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _toolbar(),
      if (notice != null)
        Container(
          color: SpColors.accentWash,
          padding: const EdgeInsets.fromLTRB(20, 8, 10, 8),
          child: Row(children: [
            Expanded(child: Text(notice, style: SpType.text(13, color: SpColors.accentInk))),
            TextButton(onPressed: () => setState(() => st.canvasNotice.remove(widget.path)), child: Text('Понятно', style: SpType.text(12.5, color: SpColors.accent))),
          ]),
        ),
      Expanded(
        child: ClipRect(
          child: LayoutBuilder(builder: (context, box) {
            _size = box.biggest;
            if (!_fitted) {
              _fit();
              _fitted = true;
            }
            return DragTarget<String>(
              onAcceptWithDetails: (det) {
                final at = _toGraph(_local(det.offset) + const Offset(60, 14));
                _addNote(det.data, at);
              },
              builder: (context, cand, _) => Focus(
                focusNode: _focus,
                autofocus: true,
                onKeyEvent: (_, e) {
                  if (e is! KeyDownEvent) return KeyEventResult.ignored;
                  if (e.logicalKey == LogicalKeyboardKey.delete || e.logicalKey == LogicalKeyboardKey.backspace) {
                    _delete();
                    return KeyEventResult.handled;
                  }
                  if (e.logicalKey == LogicalKeyboardKey.escape) {
                    setState(() => _sel = _selEdge = null);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Listener(
                  onPointerSignal: (e) {
                    if (e is PointerScrollEvent) {
                      setState(() => _cam.zoomAt(math.exp(-e.scrollDelta.dy / 400), e.localPosition.dx, e.localPosition.dy));
                    }
                  },
                  child: Stack(key: _stackKey, clipBehavior: Clip.hardEdge, children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (_) {
                          _focus.requestFocus();
                          setState(() => _sel = _selEdge = null);
                        },
                        onDoubleTapDown: (det) => _addText(_toGraph(det.localPosition)),
                        onDoubleTap: () {},
                        onPanUpdate: (det) => setState(() {
                          _cam.dx += det.delta.dx;
                          _cam.dy += det.delta.dy;
                        }),
                        child: CustomPaint(painter: _Ground(_cam, cand.isNotEmpty)),
                      ),
                    ),
                    for (final n in d.nodes.where((n) => n.isGroup)) _nodeBox(n),
                    Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _Wires(d, _cam, _selEdge, _sel, _wireFrom, _wireSide, _wireTo)))),
                    for (final n in d.nodes.where((n) => !n.isGroup)) _nodeBox(n),
                    for (final e in d.edges)
                      if (e.label.isNotEmpty) _edgeLabel(d, e),
                    if (_sel != null && d.node(_sel!) != null) ..._handles(d.node(_sel!)!),
                    if (d.nodes.isEmpty)
                      Center(
                        child: IgnorePointer(
                          child: Text('Перетащи заметку из списка — появится нода.\nДвойной клик по фону — текст.',
                              textAlign: TextAlign.center, style: SpType.text(13.5, color: SpColors.dim, height: 22)),
                        ),
                      ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Row(children: [
                        _Small('＋', 'Ближе', () => setState(() => _cam.zoomAt(1.25, _size.width / 2, _size.height / 2))),
                        const SizedBox(width: 4),
                        _Small('−', 'Дальше', () => setState(() => _cam.zoomAt(.8, _size.width / 2, _size.height / 2))),
                        const SizedBox(width: 4),
                        _Small('⤢', 'Весь холст', () => setState(_fit)),
                      ]),
                    ),
                  ]),
                ),
              ),
            );
          }),
        ),
      ),
    ]);
  }

  Widget _toolbar() {
    Widget btn(String label, VoidCallback on, {bool main = false}) => Padding(
          padding: const EdgeInsets.only(right: 4),
          child: TextButton(
            onPressed: on,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 28),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              backgroundColor: main ? SpColors.accent : Colors.transparent,
              foregroundColor: main ? SpColors.onAccent : SpColors.ink,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SpRadius.button), side: main ? BorderSide.none : const BorderSide(color: SpColors.line)),
            ),
            child: Text(label, style: SpType.text(12.5, w: FontWeight.w500, color: main ? SpColors.onAccent : SpColors.ink)),
          ),
        );
    final dir = folderOf(widget.path);
    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 16, right: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: SpColors.line))),
      child: Row(children: [
        Text('ХОЛСТ', style: SpType.label(10, w: FontWeight.w500, color: SpColors.ink)),
        const SizedBox(width: 10),
        Flexible(
          child: Text('${dir.isEmpty ? '' : '${dir.replaceAll('/', ' / ')} / '}${baseName(widget.path)}'.toUpperCase(),
              overflow: TextOverflow.ellipsis, style: SpType.label(9.5)),
        ),
        const SizedBox(width: 14),
        btn('＋ Заметка', _pickNote, main: true),
        btn('＋ Текст', () => _addText()),
        btn('＋ Картинка', _addImage),
        btn('Группа', _addGroup),
        Expanded(
          child: Text('ОТКРЫТЫЙ ФОРМАТ JSON CANVAS',
              textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: SpType.label(9, color: SpColors.dim)),
        ),
        const SizedBox(width: 10),
        btn('Авто-раскладка', () {
          _doc!.autoLayout();
          _changed();
          setState(_fit);
        }),
      ]),
    );
  }

  Rect _rectOf(CanvasNode n) {
    final (x, y) = _cam.toScreen(n.x, n.y);
    return Rect.fromLTWH(x, y, n.width * _cam.k, n.height * _cam.k);
  }

  Widget _nodeBox(CanvasNode n) {
    final r = _rectOf(n);
    final sel = n.id == _sel;
    return Positioned(
      left: r.left,
      top: r.top,
      width: r.width,
      height: r.height,
      child: GestureDetector(
        onTap: () {
          _focus.requestFocus();
          setState(() {
            _sel = n.id;
            _selEdge = null;
          });
        },
        onDoubleTap: () => _editNode(n),
        onPanStart: (_) => setState(() => _sel = n.id),
        onPanUpdate: (det) {
          final dx = det.delta.dx / _cam.k, dy = det.delta.dy / _cam.k;
          final kids = n.isGroup ? _doc!.inside(n) : const <CanvasNode>[];
          for (final m in [n, ...kids]) {
            m.raw['x'] = (m.raw['x'] as num) + dx;
            m.raw['y'] = (m.raw['y'] as num) + dy;
          }
          setState(() {});
        },
        onPanEnd: (_) {
          final kids = n.isGroup ? _doc!.inside(n) : const <CanvasNode>[];
          for (final m in [n, ...kids]) {
            m.x = (m.x / 10).round() * 10.0;
            m.y = (m.y / 10).round() * 10.0;
          }
          _changed();
        },
        child: FittedBox(
          fit: BoxFit.fill,
          alignment: Alignment.topLeft,
          child: SizedBox(width: n.width, height: n.height, child: _content(n, sel)),
        ),
      ),
    );
  }

  Widget _content(CanvasNode n, bool sel) {
    final tint = canvasColor(n.color);
    final all = st.index.paths.toList();
    final border = Border.all(color: sel ? SpColors.accent : (tint ?? SpColors.line), width: sel ? 1.5 : 1);
    if (n.isGroup) {
      final c = tint ?? SpColors.grey;
      return Container(
        decoration: BoxDecoration(color: c.withValues(alpha: .06), borderRadius: BorderRadius.circular(SpRadius.hub), border: Border.all(color: sel ? SpColors.accent : c.withValues(alpha: .5))),
        alignment: Alignment.topLeft,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        child: Text(n.label.isEmpty ? 'ГРУППА' : n.label.toUpperCase(), style: SpType.label(11, w: FontWeight.w500, color: c)),
      );
    }
    if (n.type == 'text' || n.type == 'link') {
      return Container(
        decoration: BoxDecoration(color: SpColors.node, borderRadius: BorderRadius.circular(SpRadius.node), border: border),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(n.type == 'link' ? 'ССЫЛКА' : 'ТЕКСТ НА ХОЛСТЕ', style: SpType.label(9, color: tint ?? SpColors.dim)),
          const SizedBox(height: 4),
          Expanded(
            child: Text(n.type == 'link' ? n.url : n.text, overflow: TextOverflow.fade, style: SpType.text(13, color: SpColors.body, height: 19)),
          ),
        ]),
      );
    }
    // Файл: картинка или заметка.
    final f = n.file;
    if (_isImage(f)) {
      return Container(
        decoration: BoxDecoration(color: SpColors.node, borderRadius: BorderRadius.circular(SpRadius.node), border: border),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: SpColors.headGrey,
            child: Row(children: [
              Expanded(child: Text(baseName(f).toUpperCase(), overflow: TextOverflow.ellipsis, style: SpType.label(9, w: FontWeight.w500, color: Colors.white))),
              Text('КАРТИНКА', style: SpType.label(8.5, color: const Color(0xB3FFFFFF))),
            ]),
          ),
          Expanded(
            child: st.vault == null
                ? const SizedBox()
                : Image.file(st.vault!.file(f), fit: BoxFit.cover, errorBuilder: (_, _, _) => Center(child: Text(f, style: SpType.label(9, color: SpColors.dim)))),
          ),
        ]),
      );
    }
    final doc = st.index.doc(f);
    final head = tint == null ? folderHead(f, all) : Color.lerp(tint, Colors.black, .45)!;
    return Container(
      decoration: BoxDecoration(
        color: SpColors.node,
        borderRadius: BorderRadius.circular(SpRadius.node),
        border: doc == null ? Border.all(color: SpColors.dim) : border,
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 14, offset: Offset(0, 6))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          color: doc == null ? SpColors.headGrey : head,
          child: Row(children: [
            Expanded(child: Text(shownName(f).toUpperCase(), overflow: TextOverflow.ellipsis, style: SpType.label(9.5, w: FontWeight.w500, color: Colors.white))),
            if (f.contains('/')) Text(f.substring(0, f.indexOf('/')).toUpperCase(), style: SpType.label(8.5, color: const Color(0xB3FFFFFF))),
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: doc == null
                ? Text('Файла нет: $f', style: SpType.text(12, color: SpColors.muted))
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final l in previewLines(st.index.text(f) ?? '', n: math.max(1, ((n.height - 60) / 17).floor()), width: 80))
                      Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: SpType.text(12, color: SpColors.body)),
                    const Spacer(),
                    if (doc.tags.isNotEmpty)
                      Text(doc.tags.take(3).map((t) => '#$t').join('  '), maxLines: 1, overflow: TextOverflow.ellipsis, style: SpType.text(11.5, color: SpColors.blue)),
                  ]),
          ),
        ),
      ]),
    );
  }

  Widget _edgeLabel(CanvasDoc d, CanvasEdge e) {
    final a = d.node(e.from), b = d.node(e.to);
    if (a == null || b == null) return const SizedBox.shrink();
    final (sa, sb) = edgeSides(e, a, b);
    final (ax, ay) = a.socket(sa);
    final (bx, by) = b.socket(sb);
    final (mx, my) = _cam.toScreen((ax + bx) / 2, (ay + by) / 2);
    final on = e.id == _selEdge;
    return Positioned(
      left: mx - 60,
      top: my - 11,
      width: 120,
      height: 22,
      child: Center(
        child: GestureDetector(
          onTap: () => setState(() {
            _selEdge = e.id;
            _sel = null;
            _focus.requestFocus();
          }),
          onDoubleTap: () => _editEdge(e),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: SpColors.bg, border: Border.all(color: on ? SpColors.accent : SpColors.lineStrong), borderRadius: BorderRadius.circular(4)),
            child: Text(e.label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: SpType.label(9, color: on ? SpColors.accentInk : SpColors.muted)),
          ),
        ),
      ),
    );
  }

  /// Сокеты по сторонам выбранной ноды (тянуть — провод) и уголок размера.
  List<Widget> _handles(CanvasNode n) {
    final out = <Widget>[];
    if (!n.isGroup) {
      for (final s in CanvasSide.values) {
        final (gx, gy) = n.socket(s);
        final (sx, sy) = _cam.toScreen(gx, gy);
        out.add(Positioned(
          left: sx - 7,
          top: sy - 7,
          width: 14,
          height: 14,
          child: MouseRegion(
            cursor: SystemMouseCursors.precise,
            child: GestureDetector(
              onPanStart: (det) => setState(() {
                _wireFrom = n.id;
                _wireSide = s;
                _wireTo = _local(det.globalPosition);
              }),
              onPanUpdate: (det) => setState(() => _wireTo = _local(det.globalPosition)),
              onPanEnd: (_) {
                final to = _wireTo == null ? null : _toGraph(_wireTo!);
                final target = to == null ? null : _doc!.hit(to.dx, to.dy);
                if (target != null && target.id != n.id && !target.isGroup) {
                  final e = _doc!.connect(n.id, target.id, fromSide: s, toSide: nearestSide(target, to!.dx, to.dy));
                  if (e != null) {
                    _selEdge = e.id;
                    _sel = null;
                    _changed();
                    Future.microtask(() => _editEdge(e));
                  }
                }
                setState(() => _wireFrom = _wireSide = _wireTo = null);
              },
              child: Container(
                decoration: BoxDecoration(color: SpColors.accent, borderRadius: BorderRadius.circular(SpRadius.socket), border: Border.all(color: SpColors.bg, width: 2)),
              ),
            ),
          ),
        ));
      }
    }
    final r = _rectOf(n);
    out.add(Positioned(
      left: r.right - 8,
      top: r.bottom - 8,
      width: 14,
      height: 14,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeDownRight,
        child: GestureDetector(
          onPanUpdate: (det) => setState(() {
            n.raw['width'] = math.max(80.0, (n.raw['width'] as num) + det.delta.dx / _cam.k);
            n.raw['height'] = math.max(50.0, (n.raw['height'] as num) + det.delta.dy / _cam.k);
          }),
          onPanEnd: (_) {
            n.width = (n.width / 10).round() * 10.0;
            n.height = (n.height / 10).round() * 10.0;
            _changed();
          },
          child: CustomPaint(painter: _Corner()),
        ),
      ),
    ));
    return out;
  }
}

class _Corner extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = SpColors.accent
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(s.width - 2, 4), Offset(4, s.height - 2), p);
    canvas.drawLine(Offset(s.width - 2, 9), Offset(9, s.height - 2), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Ground extends CustomPainter {
  _Ground(this.cam, this.drop);
  final GraphCamera cam;
  final bool drop;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = drop ? const Color(0xFF1E1D1C) : SpColors.ground);
    final step = 24.0 * cam.k.clamp(.5, 2.0);
    final p = Paint()..color = SpColors.dot;
    for (var y = cam.dy % step; y < size.height; y += step) {
      for (var x = cam.dx % step; x < size.width; x += step) {
        canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Ground old) => true;
}

class _Wires extends CustomPainter {
  _Wires(this.d, this.cam, this.selEdge, this.sel, this.from, this.side, this.to);
  final CanvasDoc d;
  final GraphCamera cam;
  final String? selEdge;
  final String? sel;
  final String? from;
  final CanvasSide? side;
  final Offset? to;

  static Offset _dir(CanvasSide s) => switch (s) {
        CanvasSide.top => const Offset(0, -1),
        CanvasSide.right => const Offset(1, 0),
        CanvasSide.bottom => const Offset(0, 1),
        CanvasSide.left => const Offset(-1, 0),
      };

  Path _curve(Offset a, CanvasSide sa, Offset b, CanvasSide? sb) {
    final reach = math.max((b - a).distance / 2.5, 30.0);
    final c1 = a + _dir(sa) * reach;
    final c2 = sb == null ? b : b + _dir(sb) * reach;
    return Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, b.dx, b.dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in d.edges) {
      final a = d.node(e.from), b = d.node(e.to);
      if (a == null || b == null) continue;
      final (sa, sb) = edgeSides(e, a, b);
      final (ax, ay) = a.socket(sa);
      final (bx, by) = b.socket(sb);
      final (pax, pay) = cam.toScreen(ax, ay);
      final (pbx, pby) = cam.toScreen(bx, by);
      final pa = Offset(pax, pay), pb = Offset(pbx, pby);
      final hot = e.id == selEdge || e.from == sel || e.to == sel;
      final color = hot ? SpColors.accent : (canvasColor(e.color) ?? SpColors.lineStrong);
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = hot ? 1.8 : 1.3
        ..color = color;
      canvas.drawPath(_curve(pa, sa, pb, sb), p);
      for (final (o, s) in [(pa, sa), (pb, sb)]) {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: 8, height: 8), const Radius.circular(SpRadius.socket)), Paint()..color = color);
        if ((o == pb && e.arrowTo) || (o == pa && e.arrowFrom)) {
          final dir = _dir(s);
          final tip = o + dir * 5;
          final back = o + dir * 14;
          final side = Offset(-dir.dy, dir.dx) * 5;
          canvas.drawPath(Path()
            ..moveTo(tip.dx, tip.dy)
            ..lineTo(back.dx + side.dx, back.dy + side.dy)
            ..lineTo(back.dx - side.dx, back.dy - side.dy)
            ..close(), Paint()..color = color);
        }
      }
    }
    if (from != null && side != null && to != null) {
      final a = d.node(from!);
      if (a != null) {
        final (ax, ay) = a.socket(side!);
        final (sx, sy) = cam.toScreen(ax, ay);
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = SpColors.accent;
        canvas.drawPath(_curve(Offset(sx, sy), side!, to!, null), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _Small extends StatelessWidget {
  const _Small(this.label, this.tip, this.onTap);
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
            child: SizedBox(width: 30, height: 30, child: Center(child: Text(label, style: SpType.text(15)))),
          ),
        ),
      );
}

/// Окно правки текста. [extra] — вторая кнопка (например «Убрать провод»), вернёт `\u0000`.
Future<String?> _editText(BuildContext context, String title, String initial, {int lines = 6, String? extra}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: SpColors.node,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SpRadius.hub), side: const BorderSide(color: SpColors.line)),
      title: Text(title, style: SpType.text(17, w: FontWeight.w600)),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: c,
          autofocus: true,
          minLines: lines == 1 ? 1 : 3,
          maxLines: lines,
          style: SpType.text(14),
          onSubmitted: lines == 1 ? (v) => Navigator.pop(ctx, v.trim()) : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: SpColors.bg,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: SpColors.lineStrong)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: SpColors.accent)),
          ),
        ),
      ),
      actions: [
        if (extra != null) TextButton(onPressed: () => Navigator.pop(ctx, '\u0000'), child: Text(extra, style: SpType.text(13, color: SpColors.red))),
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Отмена', style: SpType.text(13))),
        TextButton(
          onPressed: () => Navigator.pop(ctx, c.text.trim()),
          style: TextButton.styleFrom(backgroundColor: SpColors.accent),
          child: Text('Готово', style: SpType.text(13, w: FontWeight.w600, color: SpColors.onAccent)),
        ),
      ],
    ),
  );
}
