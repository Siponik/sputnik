// Холст `.canvas` (docs/knowledge.md, шаг 12; переделан 06.11 под управление Obsidian): ноды-заметки, текстовые
// карточки, картинки, группы, провода. Управление как в Obsidian: колёсико — двигать, Ctrl/Space + колёсико — масштаб,
// тянуть по пустому — рамка выделения, Space + тянуть или средняя кнопка — двигать холст, двойной клик по пустому —
// карточка, по карточке — править на месте. Ctrl+Z/Y, Ctrl+C/X/V/D/A, Delete, Shift+1 / Shift+2.
//
// Отклик: весь «мир» (ноды, провода, подписи) лежит под одним Transform и не перестраивается, пока двигают
// или масштабируют камеру — меняется только матрица. Ноды строятся с запасом вокруг экрана.
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../core/notes/canvas.dart';
import '../../core/notes/graph.dart' show GraphCamera;
import '../../core/notes/parse.dart';
import '../../core/notes/view.dart' show shownName;
import '../../state/notes_state.dart';
import '../theme/tokens.dart';
import 'hue.dart';
import 'md_view.dart';
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

/// Клавиши холста — для подсказки «?».
const canvasKeys = [
  ('Колёсико', 'двигать холст (Shift — вбок)'),
  ('Ctrl + колёсико, Space + колёсико', 'масштаб у курсора'),
  ('Space + тянуть, средняя кнопка', 'двигать холст'),
  ('Тянуть по пустому', 'выделить рамкой'),
  ('Shift / Ctrl + клик', 'добавить к выделению'),
  ('Двойной клик по пустому', 'новая карточка'),
  ('Двойной клик по карточке, Enter', 'править на месте'),
  ('Alt + тянуть', 'тянуть копию'),
  ('Тянуть от точки на краю', 'провод; отпустить на пустом — новая карточка'),
  ('Delete, Backspace', 'удалить выделенное'),
  ('Ctrl+Z, Ctrl+Shift+Z, Ctrl+Y', 'отменить, вернуть'),
  ('Ctrl+C, Ctrl+X, Ctrl+V', 'копировать, вырезать, вставить'),
  ('Ctrl+D', 'дублировать'),
  ('Ctrl+A', 'выделить всё'),
  ('Ctrl+G', 'в группу'),
  ('Shift+1', 'весь холст'),
  ('Shift+2', 'к выделенному'),
  ('Ctrl+=, Ctrl+−, Ctrl+0', 'ближе, дальше, 100 %'),
  ('Стрелки', 'сдвинуть выделенное (Shift — на 50)'),
  ('Esc', 'закончить правку, снять выделение'),
];

bool _isImage(String p) => RegExp(r'\.(png|jpe?g|gif|webp)$', caseSensitive: false).hasMatch(p);
double _snap10(double v) => (v / 10).round() * 10.0;

class _Cam extends ChangeNotifier {
  final c = GraphCamera();
  void changed() => notifyListeners();
}

enum _Mode { pan, move, box, resize, wire }

class _Drag {
  _Drag(this.mode, this.s0, this.w0);
  final _Mode mode;
  final Offset s0;
  final Offset w0;
  bool moved = false;
  Offset last = Offset.zero;
  final start = <String, Rect>{};
  String? id;
  int sides = 0; // 1 — левый край, 2 — верх, 4 — правый, 8 — низ
  CanvasSide? side;
  Set<String> base = const {};
}

enum _EditKind { node, group, edge }

class CanvasView extends StatefulWidget {
  const CanvasView({super.key, required this.st, required this.path});
  final NotesState st;
  final String path;
  @override
  State<CanvasView> createState() => _CanvasViewState();
}

class _CanvasViewState extends State<CanvasView> with SingleTickerProviderStateMixin {
  NotesState get st => widget.st;
  CanvasDoc? _doc;
  bool _loading = true;
  final _cam = _Cam();
  GraphCamera get _c => _cam.c;
  bool _fitted = false;
  Size _size = Size.zero;
  final _hist = CanvasHistory();
  final _focus = FocusNode(debugLabel: 'canvas');

  // Выделение.
  Set<String> _sel = {};
  String? _selEdge;

  // Что под курсором: нода и её точка-сокет (для подсветки) — без перестройки мира.
  final _hot = ValueNotifier<(String?, CanvasSide?)>((null, null));
  final _box = ValueNotifier<Rect?>(null);
  final _wire = ValueNotifier<(String, CanvasSide, Offset)?>(null);
  final _cursor = ValueNotifier<MouseCursor>(SystemMouseCursors.basic);
  Offset? _mouse; // курсор в координатах холста — сюда вставляем

  _Drag? _drag;
  bool _space = false;
  double _pzScale = 1;
  (Duration, Offset)? _lastClick;

  // Правка на месте.
  (_EditKind, String)? _editing;
  String? _fresh; // только что созданная карточка: пустой при выходе из правки — убираем
  final _ed = TextEditingController();
  final _edFocus = FocusNode(debugLabel: 'canvas-edit');
  bool _edDirty = false;

  // Содержимое нод не зависит от камеры: строим один раз и переиспользуем, пока нода не изменилась.
  final _cache = <String, (String, Widget)>{};
  int _ver = -1;
  List<String>? _all;
  Rect? _built; // какую часть холста построили (с запасом вокруг экрана)
  bool _far = false; // издалека — ноды упрощённо

  bool _palette = false;
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  GraphCamera? _from, _to;

  @override
  void initState() {
    super.initState();
    _load();
    st.addListener(_onState);
    _cam.addListener(_onCam);
    _anim.addListener(() {
      final a = _from, b = _to;
      if (a == null || b == null) return;
      final t = Curves.easeOutCubic.transform(_anim.value);
      _c.k = a.k + (b.k - a.k) * t;
      _c.dx = a.dx + (b.dx - a.dx) * t;
      _c.dy = a.dy + (b.dy - a.dy) * t;
      _cam.changed();
    });
  }

  @override
  void dispose() {
    _commitEdit();
    st.removeListener(_onState);
    _anim.dispose();
    _cam.dispose();
    _hot.dispose();
    _box.dispose();
    _wire.dispose();
    _cursor.dispose();
    _ed.dispose();
    _edFocus.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onState() {
    // Холст перечитали (снаружи поменяли или пришла копия с другого компьютера).
    if (!_loading && st.canvases[widget.path] == null && st.canvasErrors[widget.path] == null) _load();
  }

  void _onCam() {
    if (_size.isEmpty || !mounted) return;
    final v = _view();
    final b = _built;
    if ((_c.k < .35) != _far || b == null || !b.contains(v.topLeft) || !b.contains(v.bottomRight)) setState(() {});
  }

  Future<void> _load() async {
    _loading = true;
    final d = await st.canvas(widget.path);
    if (!mounted) return;
    setState(() {
      _cache.clear();
      _doc = d;
      _loading = false;
      _fitted = false;
      _sel = {};
      _selEdge = null;
      _editing = null;
    });
  }

  /// Правка закончена — записать (через задержку сохранения) и перестроить.
  void _changed() {
    st.canvasChanged(widget.path);
    if (mounted) setState(() {});
  }

  void _remember() => _hist.push(_doc!.encode());

  // ---------- камера ----------

  Offset _w(Offset s) {
    final (x, y) = _c.toGraph(s.dx, s.dy);
    return Offset(x, y);
  }

  Offset _s(double x, double y) {
    final (sx, sy) = _c.toScreen(x, y);
    return Offset(sx, sy);
  }

  Rect _view() => Rect.fromPoints(_w(Offset.zero), _w(Offset(_size.width, _size.height)));
  Offset get _center => _w(Offset(_size.width / 2, _size.height / 2));

  Rect _screenRect(CanvasNode n) => Rect.fromPoints(_s(n.x, n.y), _s(n.x + n.width, n.y + n.height));

  void _moveCam(void Function(GraphCamera c) f) {
    _anim.stop();
    f(_c);
    _cam.changed();
  }

  void _flyTo(void Function(GraphCamera c) f) {
    final to = GraphCamera(_c.k, _c.dx, _c.dy);
    f(to);
    _from = GraphCamera(_c.k, _c.dx, _c.dy);
    _to = to;
    _anim.forward(from: 0);
  }

  void _fitAll({bool fly = true}) {
    final d = _doc;
    if (d == null || _size.isEmpty) return;
    final (x0, y0, x1, y1) = d.bounds();
    void f(GraphCamera c) => c.fit(x0, y0, x1, y1, _size.width, _size.height, pad: 60, maxK: 1);
    fly ? _flyTo(f) : f(_c);
  }

  void _fitSel() {
    final b = _doc?.boundsOf(_sel);
    if (b == null) return _fitAll();
    final (x0, y0, x1, y1) = b;
    _flyTo((c) => c.fit(x0, y0, x1, y1, _size.width, _size.height, pad: 80, maxK: 1.5));
  }

  void _zoomBy(double by) => _moveCam((c) => c.zoomAt(by, _size.width / 2, _size.height / 2));

  // ---------- мышь ----------

  bool get _ctrl => HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
  bool get _shift => HardwareKeyboard.instance.isShiftPressed;

  /// Сокет под точкой экрана: у ноды под курсором и у выбранной.
  (String, CanvasSide)? _socketAt(Offset s) {
    final d = _doc!;
    final ids = {?_hot.value.$1, if (_sel.length == 1) _sel.first};
    for (final id in ids) {
      final n = d.node(id);
      if (n == null || n.isGroup) continue;
      for (final side in CanvasSide.values) {
        final (x, y) = n.socket(side);
        if ((_s(x, y) - s).distance <= 9) return (id, side);
      }
    }
    return null;
  }

  /// Край выбранной ноды под точкой: за него тянут размер.
  int _resizeAt(Offset s) {
    if (_sel.length != 1) return 0;
    final n = _doc!.node(_sel.first);
    if (n == null) return 0;
    final r = _screenRect(n);
    if (!r.inflate(6).contains(s)) return 0;
    var sides = 0;
    if ((s.dx - r.left).abs() <= 6) sides |= 1;
    if ((s.dy - r.top).abs() <= 6) sides |= 2;
    if ((s.dx - r.right).abs() <= 6) sides |= 4;
    if ((s.dy - r.bottom).abs() <= 6) sides |= 8;
    return sides;
  }

  Rect _labelRect(CanvasDoc d, CanvasEdge e) {
    final a = d.node(e.from)!, b = d.node(e.to)!;
    final (mx, my) = edgeCurve(e, a, b).at(.5);
    return Rect.fromCenter(center: Offset(mx, my), width: math.min(180, e.label.length * 7.0 + 22), height: 22);
  }

  String? _edgeHit(Offset w) {
    final d = _doc!;
    for (final e in d.edges.reversed) {
      if (e.label.isEmpty || d.node(e.from) == null || d.node(e.to) == null) continue;
      if (_labelRect(d, e).contains(w)) return e.id;
    }
    return d.edgeAt(w.dx, w.dy, 8 / _c.k);
  }

  bool _inEditor(Offset w) {
    final e = _editing;
    if (e == null) return false;
    final d = _doc!;
    switch (e.$1) {
      case _EditKind.node:
        return d.node(e.$2)?.contains(w.dx, w.dy) ?? false;
      case _EditKind.group:
        final g = d.node(e.$2);
        return g != null && Rect.fromLTWH(g.x, g.y, g.width, 44).contains(w);
      case _EditKind.edge:
        final ed = d.edges.where((x) => x.id == e.$2).firstOrNull;
        return ed != null && _labelRect(d, ed).inflate(10).contains(w);
    }
  }

  void _down(PointerDownEvent e) {
    final d = _doc;
    if (d == null) return;
    final s = e.localPosition, w = _w(s);
    if (_inEditor(w)) return; // клик внутри поля правки — его
    _commitEdit();
    _focus.requestFocus();
    _palette = false;
    if (e.buttons & kMiddleMouseButton != 0 ||
        _space ||
        (e.kind == PointerDeviceKind.touch && d.hit(w.dx, w.dy) == null)) {
      _drag = _Drag(_Mode.pan, s, w)..last = s;
      _cursor.value = SystemMouseCursors.grabbing;
      return;
    }
    if (e.buttons & kSecondaryMouseButton != 0) {
      _menu(e.position, w);
      return;
    }
    final sock = _socketAt(s);
    if (sock != null) {
      _drag = _Drag(_Mode.wire, s, w)
        ..id = sock.$1
        ..side = sock.$2;
      return;
    }
    final sides = _resizeAt(s);
    if (sides != 0) {
      final n = d.node(_sel.first)!;
      _drag = _Drag(_Mode.resize, s, w)
        ..id = n.id
        ..sides = sides;
      _drag!.start[n.id] = Rect.fromLTWH(n.x, n.y, n.width, n.height);
      return;
    }
    final n = d.hit(w.dx, w.dy);
    final edge = n == null || n.isGroup ? _edgeHit(w) : null;
    if (edge != null) {
      setState(() {
        _sel = {};
        _selEdge = edge;
      });
      _drag = _Drag(_Mode.box, s, w)..id = 'edge';
      return;
    }
    if (n != null) {
      final add = _shift || _ctrl;
      setState(() {
        _selEdge = null;
        if (add) {
          _sel = {..._sel};
          if (!_sel.remove(n.id)) _sel.add(n.id);
        } else if (!_sel.contains(n.id)) {
          _sel = {n.id};
        }
      });
      _drag = _Drag(_Mode.move, s, w)..id = n.id;
      return;
    }
    final keep = _shift || _ctrl;
    setState(() {
      _selEdge = null;
      if (!keep) _sel = {};
    });
    _drag = _Drag(_Mode.box, s, w)..base = keep ? {..._sel} : const {};
  }

  void _move(PointerMoveEvent e) {
    final g = _drag, d = _doc;
    if (g == null || d == null) return;
    final s = e.localPosition, w = _w(s);
    _mouse = w;
    if (!g.moved && (s - g.s0).distance < 3) return;
    final first = !g.moved;
    g.moved = true;
    switch (g.mode) {
      case _Mode.pan:
        final delta = s - g.last;
        g.last = s;
        _moveCam((c) {
          c.dx += delta.dx;
          c.dy += delta.dy;
        });
      case _Mode.box:
        if (g.id == 'edge') return;
        _box.value = Rect.fromPoints(g.w0, w);
      case _Mode.wire:
        _wire.value = (g.id!, g.side!, w);
      case _Mode.move:
        if (first) {
          _remember();
          if (HardwareKeyboard.instance.isAltPressed) {
            final copies = d.duplicate(_sel);
            for (final id in copies) {
              final c = d.node(id)!;
              c.x = c.x - 30;
              c.y = c.y - 30;
            }
            _sel = copies.toSet();
          }
          for (final m in d.movable(_sel)) {
            g.start[m.id] = Rect.fromLTWH(m.x, m.y, m.width, m.height);
          }
        }
        final dw = w - g.w0;
        for (final MapEntry(:key, :value) in g.start.entries) {
          final m = d.node(key);
          if (m == null) continue;
          m.x = _snap10(value.left + dw.dx);
          m.y = _snap10(value.top + dw.dy);
        }
        setState(() {});
      case _Mode.resize:
        if (first) _remember();
        final n = d.node(g.id!);
        final r0 = g.start[g.id!];
        if (n == null || r0 == null) return;
        final dw = w - g.w0;
        final minW = n.isGroup ? 120.0 : 60.0, minH = n.isGroup ? 80.0 : 40.0;
        var l = r0.left, t = r0.top, r = r0.right, b = r0.bottom;
        if (g.sides & 1 != 0) l = math.min(_snap10(r0.left + dw.dx), r - minW);
        if (g.sides & 4 != 0) r = math.max(_snap10(r0.right + dw.dx), l + minW);
        if (g.sides & 2 != 0) t = math.min(_snap10(r0.top + dw.dy), b - minH);
        if (g.sides & 8 != 0) b = math.max(_snap10(r0.bottom + dw.dy), t + minH);
        n
          ..x = l
          ..y = t
          ..width = r - l
          ..height = b - t;
        setState(() {});
    }
  }

  void _up(PointerUpEvent e) {
    final g = _drag, d = _doc;
    _drag = null;
    if (g == null || d == null) return;
    final s = e.localPosition, w = _w(s);
    switch (g.mode) {
      case _Mode.pan:
        _cursor.value = _space ? SystemMouseCursors.grab : SystemMouseCursors.basic;
      case _Mode.box:
        final b = _box.value;
        _box.value = null;
        if (b != null) setState(() => _sel = {...g.base, ...d.inRect(b.left, b.top, b.right, b.bottom)});
      case _Mode.wire:
        _wire.value = null;
        if (g.moved) _endWire(g.id!, g.side!, w);
      case _Mode.move:
        if (g.moved) {
          _changed();
        } else if (!_shift && !_ctrl && _sel.length > 1) {
          setState(() => _sel = {g.id!});
        }
      case _Mode.resize:
        if (g.moved) _changed();
    }
    if (g.moved || g.mode == _Mode.pan) return;
    // Двойной клик — сами: у GestureDetector одиночный клик ждал бы второго.
    final now = e.timeStamp, last = _lastClick;
    _lastClick = (now, s);
    if (last != null && now - last.$1 < const Duration(milliseconds: 400) && (s - last.$2).distance < 8) {
      _lastClick = null;
      _double(w);
    }
  }

  void _double(Offset w) {
    final d = _doc!;
    final n = d.hit(w.dx, w.dy);
    if (n != null && n.isGroup && w.dy > n.y + 44) {
      // По пустому месту в группе — карточка в группе.
      _newCard(w);
      return;
    }
    if (n != null) {
      _startEdit(n);
      return;
    }
    final e = _edgeHit(w);
    if (e != null) {
      _startEditEdge(e);
      return;
    }
    _newCard(w);
  }

  void _hover(PointerHoverEvent e) {
    final d = _doc;
    if (d == null) return;
    final s = e.localPosition, w = _w(s);
    _mouse = w;
    final n = d.hit(w.dx, w.dy);
    final id = n == null || n.isGroup ? null : n.id;
    _hot.value = (id, null);
    final sock = _socketAt(s);
    if (sock != null) _hot.value = (sock.$1, sock.$2);
    if (_space) {
      _cursor.value = SystemMouseCursors.grab;
    } else if (sock != null) {
      _cursor.value = SystemMouseCursors.precise;
    } else {
      final sides = _resizeAt(s);
      _cursor.value = switch (sides) {
        3 || 12 => SystemMouseCursors.resizeUpLeftDownRight,
        6 || 9 => SystemMouseCursors.resizeUpRightDownLeft,
        1 || 4 => SystemMouseCursors.resizeLeftRight,
        2 || 8 => SystemMouseCursors.resizeUpDown,
        _ => SystemMouseCursors.basic,
      };
    }
  }

  void _signal(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      GestureBinding.instance.pointerSignalResolver.register(e, (ev) {
        final se = ev as PointerScrollEvent;
        final p = se.localPosition;
        if (_ctrl || _space) {
          _moveCam((c) => c.zoomAt(math.exp(-se.scrollDelta.dy / 300), p.dx, p.dy));
        } else if (_shift && se.scrollDelta.dx == 0) {
          _moveCam((c) => c.dx -= se.scrollDelta.dy);
        } else {
          _moveCam((c) {
            c.dx -= se.scrollDelta.dx;
            c.dy -= se.scrollDelta.dy;
          });
        }
      });
    } else if (e is PointerScaleEvent) {
      _moveCam((c) => c.zoomAt(e.scale, e.localPosition.dx, e.localPosition.dy));
    }
  }

  // ---------- клавиши ----------

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    final k = e.logicalKey, p = e.physicalKey;
    if (k == LogicalKeyboardKey.space) {
      if (_editing != null) return KeyEventResult.ignored;
      _space = e is! KeyUpEvent;
      if (_drag == null) _cursor.value = _space ? SystemMouseCursors.grab : SystemMouseCursors.basic;
      return KeyEventResult.handled;
    }
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    if (_editing != null) {
      if (k == LogicalKeyboardKey.escape || (_ctrl && k == LogicalKeyboardKey.enter)) {
        _commitEdit();
        _focus.requestFocus();
        setState(() {});
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    final d = _doc;
    if (d == null) return KeyEventResult.ignored;
    bool on(PhysicalKeyboardKey key) => p == key;
    final repeat = e is KeyRepeatEvent;
    if (k == LogicalKeyboardKey.delete || k == LogicalKeyboardKey.backspace) {
      _deleteSel();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape) {
      setState(() {
        _sel = {};
        _selEdge = null;
        _palette = false;
      });
      return KeyEventResult.handled;
    }
    final arrows = {
      LogicalKeyboardKey.arrowLeft: const Offset(-1, 0),
      LogicalKeyboardKey.arrowRight: const Offset(1, 0),
      LogicalKeyboardKey.arrowUp: const Offset(0, -1),
      LogicalKeyboardKey.arrowDown: const Offset(0, 1),
    };
    if (arrows[k] case final dir?) {
      if (_sel.isEmpty) {
        _moveCam((c) {
          c.dx -= dir.dx * 80;
          c.dy -= dir.dy * 80;
        });
      } else {
        if (!repeat) _remember();
        final step = _shift ? 50.0 : 10.0;
        for (final m in d.movable(_sel)) {
          m.x = _snap10(m.x) + dir.dx * step;
          m.y = _snap10(m.y) + dir.dy * step;
        }
        _changed();
      }
      return KeyEventResult.handled;
    }
    if (repeat && !_ctrl) return KeyEventResult.ignored;
    if (_ctrl) {
      if (on(PhysicalKeyboardKey.keyZ)) {
        _undo(redo: _shift);
      } else if (on(PhysicalKeyboardKey.keyY)) {
        _undo(redo: true);
      } else if (on(PhysicalKeyboardKey.keyA)) {
        setState(() => _sel = {for (final n in d.nodes) n.id});
      } else if (on(PhysicalKeyboardKey.keyC)) {
        _copy();
      } else if (on(PhysicalKeyboardKey.keyX)) {
        _copy();
        _deleteSel();
      } else if (on(PhysicalKeyboardKey.keyV)) {
        _paste();
      } else if (on(PhysicalKeyboardKey.keyD)) {
        _duplicate();
      } else if (on(PhysicalKeyboardKey.keyG)) {
        _groupSel();
      } else if (on(PhysicalKeyboardKey.equal) || on(PhysicalKeyboardKey.numpadAdd)) {
        _zoomBy(1.25);
      } else if (on(PhysicalKeyboardKey.minus) || on(PhysicalKeyboardKey.numpadSubtract)) {
        _zoomBy(.8);
      } else if (on(PhysicalKeyboardKey.digit0) || on(PhysicalKeyboardKey.numpad0)) {
        final c = _center;
        _flyTo((cam) => cam.centerOn(c.dx, c.dy, _size.width, _size.height, 1));
      } else {
        return KeyEventResult.ignored;
      }
      return KeyEventResult.handled;
    }
    if (_shift && on(PhysicalKeyboardKey.digit1)) {
      _fitAll();
      return KeyEventResult.handled;
    }
    if (_shift && on(PhysicalKeyboardKey.digit2)) {
      _fitSel();
      return KeyEventResult.handled;
    }
    if ((k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.f2) && _sel.length == 1) {
      final n = d.node(_sel.first);
      if (n != null) _startEdit(n);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.enter && _selEdge != null) {
      _startEditEdge(_selEdge!);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---------- действия ----------

  void _undo({bool redo = false}) {
    _commitEdit();
    final now = _doc!.encode();
    final t = redo ? _hist.redo(now) : _hist.undo(now);
    if (t == null) return;
    final d = CanvasDoc.parse(t);
    st.canvases[widget.path] = d;
    _doc = d;
    _sel = {..._sel.where((id) => d.node(id) != null)};
    _selEdge = null;
    _changed();
  }

  void _deleteSel() {
    final d = _doc!;
    if (_selEdge != null) {
      _remember();
      d.edges.removeWhere((e) => e.id == _selEdge);
      _selEdge = null;
      _changed();
    } else if (_sel.isNotEmpty) {
      _remember();
      for (final id in _sel) {
        d.remove(id);
      }
      _sel = {};
      _changed();
    }
  }

  void _copy() {
    if (_sel.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _doc!.copyOf(_sel)));
  }

  Offset get _pastePoint {
    final m = _mouse;
    return m != null && _view().contains(m) ? m : _center;
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (!mounted || text.trim().isEmpty || _doc == null) return;
    final at = _pastePoint, d = _doc!;
    final before = d.encode();
    var ids = d.paste(text, at.dx, at.dy);
    if (ids == null) {
      final t = text.trim();
      final url = RegExp(r'^https?://\S+$').hasMatch(t);
      final lines = t.split('\n').length;
      final n = d.add(
        url ? 'link' : 'text',
        _snap10(at.dx - 130),
        _snap10(at.dy - 40),
        w: 260,
        h: url ? 60 : _snap10(math.min(400, 50 + lines * 20.0)),
        text: url ? null : t,
      );
      if (url) n.raw['url'] = t;
      ids = [n.id];
    }
    _hist.push(before);
    _sel = ids.toSet();
    _selEdge = null;
    _changed();
  }

  void _duplicate() {
    if (_sel.isEmpty) return;
    _remember();
    _sel = _doc!.duplicate(_sel).toSet();
    _changed();
  }

  void _groupSel() {
    final d = _doc!;
    _remember();
    final g = _sel.isEmpty
        ? d.add('group', _snap10(_center.dx - 260), _snap10(_center.dy - 170), w: 520, h: 340, label: 'Группа')
        : d.groupAround(_sel)!;
    _sel = {g.id};
    _changed();
    _startEdit(g);
  }

  void _setColor(String? c) {
    final d = _doc!;
    _remember();
    for (final id in _sel) {
      d.node(id)?.color = c;
    }
    final e = d.edges.where((x) => x.id == _selEdge).firstOrNull;
    if (e != null) c == null ? e.raw.remove('color') : e.raw['color'] = c;
    _cache.clear();
    _changed();
  }

  CanvasNode _addNote(String path, Offset at) {
    _remember();
    final n = _doc!.add(
      'file',
      _snap10(at.dx - 150),
      _snap10(at.dy - 100),
      w: 300,
      h: _isImage(path) ? 220 : 260,
      file: path,
    );
    _sel = {n.id};
    _selEdge = null;
    _changed();
    return n;
  }

  Future<void> _pickNote([Offset? at]) async {
    final pick = await showNotesSearch(context, st);
    if (pick is PickNote && mounted) _addNote(pick.path, at ?? _center);
  }

  void _newCard(Offset at) {
    _remember();
    final d = _doc!;
    final n = d.add('text', _snap10(at.dx - 130), _snap10(at.dy - 30), w: 260, h: 60, text: '');
    _fresh = n.id;
    _sel = {n.id};
    _selEdge = null;
    _changed();
    _startEdit(n, remembered: true);
  }

  Future<void> _addImage([Offset? at]) async {
    const types = XTypeGroup(label: 'Картинки', extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp']);
    final f = await openFile(acceptedTypeGroups: const [types], confirmButtonText: 'Положить на холст');
    if (f == null || !mounted) return;
    final embed = await st.attach(f.name, await f.readAsBytes());
    final name = embed.substring(3, embed.length - 2);
    final path = st.index.files.firstWhere((p) => p.endsWith('/$name') || p == name, orElse: () => 'Вложения/$name');
    if (mounted) _addNote(path, at ?? _center);
  }

  /// Провод отпустили: на ноде — соединить, на пустом — новая карточка с проводом (как в Obsidian).
  void _endWire(String from, CanvasSide side, Offset w) {
    final d = _doc!;
    final target = d.hit(w.dx, w.dy);
    if (target != null && target.id != from && !target.isGroup) {
      _remember();
      final e = d.connect(from, target.id, fromSide: side, toSide: nearestSide(target, w.dx, w.dy));
      if (e != null) {
        _sel = {};
        _selEdge = e.id;
      }
      _changed();
      return;
    }
    final a = d.node(from);
    if (a == null || a.contains(w.dx, w.dy)) return;
    _remember();
    final (dx, dy) = sideDir(side);
    final toSide = dx.abs() > dy.abs()
        ? (dx > 0 ? CanvasSide.left : CanvasSide.right)
        : (dy > 0 ? CanvasSide.top : CanvasSide.bottom);
    const cw = 260.0, ch = 60.0;
    final x = switch (toSide) {
      CanvasSide.left => w.dx,
      CanvasSide.right => w.dx - cw,
      _ => w.dx - cw / 2,
    };
    final y = switch (toSide) {
      CanvasSide.top => w.dy,
      CanvasSide.bottom => w.dy - ch,
      _ => w.dy - ch / 2,
    };
    final n = d.add('text', _snap10(x), _snap10(y), w: cw, h: ch, text: '');
    d.connect(from, n.id, fromSide: side, toSide: toSide);
    _fresh = n.id;
    _sel = {n.id};
    _selEdge = null;
    _changed();
    _startEdit(n, remembered: true);
  }

  // ---------- правка на месте ----------

  void _startEdit(CanvasNode n, {bool remembered = false}) {
    _commitEdit();
    if (n.type == 'file' && (_isImage(n.file) || st.index.doc(n.file) == null)) return;
    if (n.type == 'link') return;
    if (!remembered && n.type != 'file') _remember();
    _ed.text = n.isGroup ? n.label : (n.type == 'file' ? st.textOf(n.file) : n.text);
    _ed.selection = TextSelection.collapsed(offset: _ed.text.length);
    _edDirty = false;
    setState(() {
      _editing = (n.isGroup ? _EditKind.group : _EditKind.node, n.id);
      _sel = {n.id};
      _selEdge = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _edFocus.requestFocus();
    });
  }

  void _startEditEdge(String id) {
    _commitEdit();
    final e = _doc!.edges.where((x) => x.id == id).firstOrNull;
    if (e == null) return;
    _remember();
    _ed.text = e.label;
    _ed.selection = TextSelection(baseOffset: 0, extentOffset: e.label.length);
    _edDirty = false;
    setState(() {
      _editing = (_EditKind.edge, id);
      _sel = {};
      _selEdge = id;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _edFocus.requestFocus();
    });
  }

  void _typed(String v) {
    final e = _editing, d = _doc;
    if (e == null || d == null) return;
    _edDirty = true;
    if (e.$1 == _EditKind.edge) {
      d.edges.where((x) => x.id == e.$2).firstOrNull?.label = v.trim();
      st.canvasChanged(widget.path);
      return;
    }
    final n = d.node(e.$2);
    if (n == null) return;
    if (n.isGroup) {
      n.label = v;
      st.canvasChanged(widget.path);
    } else if (n.type == 'file') {
      st.edit(n.file, v); // заметка правится прямо с холста — как в Obsidian
    } else {
      n.text = v;
      // Карточка растёт под текст, пока её размер не меняли руками.
      final need = _snap10(math.max(60, 34 + '\n'.allMatches(v).length * 20.0 + 20));
      if (need > n.height) n.height = need;
      st.canvasChanged(widget.path);
    }
  }

  void _commitEdit() {
    final e = _editing, d = _doc;
    if (e == null || d == null) return;
    _editing = null;
    if (_fresh == e.$2 && (d.node(e.$2)?.text.trim().isEmpty ?? false)) {
      d.remove(e.$2); // пустую новую карточку не оставляем
      _sel = {};
      st.canvasChanged(widget.path);
    } else if (_edDirty) {
      _cache.remove(e.$2);
    }
    _fresh = null;
  }

  // ---------- меню ----------

  Future<void> _menu(Offset global, Offset w) async {
    final d = _doc!;
    final n = d.hit(w.dx, w.dy);
    final edge = n == null ? _edgeHit(w) : null;
    if (n != null && !_sel.contains(n.id)) setState(() => _sel = {n.id});
    if (edge != null) setState(() => _selEdge = edge);
    PopupMenuItem<String> it(String v, String label, [String? keys]) => PopupMenuItem(
      value: v,
      height: 34,
      child: Row(
        children: [
          Expanded(child: Text(label, style: SpType.text(13))),
          if (keys != null) Text(keys, style: SpType.label(10, color: SpColors.dim)),
        ],
      ),
    );
    final isNote = n != null && n.type == 'file' && st.index.doc(n.file) != null;
    final items = <PopupMenuEntry<String>>[
      if (n != null) ...[
        if (n.type != 'link' && !(n.type == 'file' && _isImage(n.file)))
          it('edit', n.isGroup ? 'Переименовать' : 'Править', 'Enter'),
        if (isNote) it('open', 'Открыть заметку'),
        it('fit', 'К выделенному', 'Shift+2'),
        it('copy', 'Копировать', 'Ctrl+C'),
        it('dup', 'Дублировать', 'Ctrl+D'),
        it('group', 'В группу', 'Ctrl+G'),
        it('del', 'Удалить', 'Delete'),
      ] else if (edge != null) ...[
        it('label', 'Подпись', 'Enter'),
        it('del', 'Удалить провод', 'Delete'),
      ] else ...[
        it('card', 'Карточка здесь', '2× клик'),
        it('note', 'Заметка…'),
        it('image', 'Картинка…'),
        it('paste', 'Вставить', 'Ctrl+V'),
        it('all', 'Весь холст', 'Shift+1'),
      ],
    ];
    final v = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(global.dx, global.dy, global.dx, global.dy),
      color: SpColors.node,
      items: items,
    );
    if (!mounted || v == null) return;
    switch (v) {
      case 'edit':
        _startEdit(n!);
      case 'open':
        st.openNote(n!.file);
      case 'fit':
        _fitSel();
      case 'copy':
        _copy();
      case 'dup':
        _duplicate();
      case 'group':
        _groupSel();
      case 'del':
        _deleteSel();
      case 'label':
        _startEditEdge(edge!);
      case 'card':
        _newCard(w);
      case 'note':
        _pickNote(w);
      case 'image':
        _addImage(w);
      case 'paste':
        _mouse = w;
        _paste();
      case 'all':
        _fitAll();
    }
  }

  void _help() => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: SpColors.node,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SpRadius.hub),
        side: BorderSide(color: SpColors.line),
      ),
      title: Text('Управление холстом', style: SpType.text(17, w: FontWeight.w600)),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (k, what) in canvasKeys)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 200,
                        child: Text(k, style: SpType.label(11, color: SpColors.ink2, spacing: 0)),
                      ),
                      Expanded(
                        child: Text(what, style: SpType.text(13, color: SpColors.body)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Понятно', style: SpType.text(13, color: SpColors.accent)),
        ),
      ],
    ),
  );

  // ---------- рисование ----------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: Text('Открываю холст…', style: SpType.text(13, color: SpColors.muted)),
      );
    }
    final err = st.canvasErrors[widget.path];
    if (_doc == null) {
      return Center(
        child: SizedBox(
          width: 420,
          child: Text(
            err == null
                ? 'Холст не найден'
                : 'Холст не прочитался: файл повреждён ($err). Я его не трогаю — поправь в другой программе или удали.',
            textAlign: TextAlign.center,
            style: SpType.text(13.5, color: SpColors.muted),
          ),
        ),
      );
    }
    final d = _doc!;
    final notice = st.canvasNotice[widget.path];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        if (notice != null)
          Container(
            color: SpColors.accentWash,
            padding: const EdgeInsets.fromLTRB(20, 8, 10, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(notice, style: SpType.text(13, color: SpColors.accentInk)),
                ),
                TextButton(
                  onPressed: () => setState(() => st.canvasNotice.remove(widget.path)),
                  child: Text('Понятно', style: SpType.text(12.5, color: SpColors.accent)),
                ),
              ],
            ),
          ),
        Expanded(
          child: ClipRect(
            child: LayoutBuilder(
              builder: (context, box) {
                _size = box.biggest;
                if (!_fitted) {
                  _fitAll(fly: false);
                  _fitted = true;
                }
                return DragTarget<String>(
                  onAcceptWithDetails: (det) {
                    final rb = context.findRenderObject() as RenderBox?;
                    final local = rb == null ? det.offset : rb.globalToLocal(det.offset);
                    _addNote(det.data, _w(local + const Offset(60, 14)));
                  },
                  builder: (context, cand, _) => Focus(
                    focusNode: _focus,
                    autofocus: true,
                    onKeyEvent: _key,
                    onFocusChange: (f) {
                      if (!f) _space = false;
                    },
                    child: ValueListenableBuilder<MouseCursor>(
                      valueListenable: _cursor,
                      builder: (_, cur, child) =>
                          MouseRegion(cursor: cur, onExit: (_) => _hot.value = (null, null), child: child),
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: _down,
                        onPointerMove: _move,
                        onPointerUp: _up,
                        onPointerCancel: (_) {
                          _drag = null;
                          _box.value = null;
                          _wire.value = null;
                        },
                        onPointerHover: _hover,
                        onPointerSignal: _signal,
                        onPointerPanZoomStart: (_) => _pzScale = 1,
                        onPointerPanZoomUpdate: (e) => _moveCam((c) {
                          c.dx += e.panDelta.dx;
                          c.dy += e.panDelta.dy;
                          if (e.scale != _pzScale) {
                            c.zoomAt(e.scale / _pzScale, e.localPosition.dx, e.localPosition.dy);
                            _pzScale = e.scale;
                          }
                        }),
                        child: Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [
                            Positioned.fill(
                              child: RepaintBoundary(child: CustomPaint(painter: _Ground(_cam, cand.isNotEmpty))),
                            ),
                            Positioned.fill(
                              child: AnimatedBuilder(
                                animation: _cam,
                                builder: (_, child) => Transform(
                                  transform: Matrix4(_c.k, 0, 0, 0, 0, _c.k, 0, 0, 0, 0, 1, 0, _c.dx, _c.dy, 0, 1),
                                  child: child,
                                ),
                                child: RepaintBoundary(child: _world(d)),
                              ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: RepaintBoundary(
                                  child: CustomPaint(
                                    painter: _Overlay(
                                      d,
                                      _cam,
                                      _sel,
                                      _hot,
                                      _box,
                                      _wire,
                                      showHandles: _editing == null,
                                      repaint: Listenable.merge([_cam, _hot, _box, _wire]),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (d.nodes.isEmpty)
                              Center(
                                child: IgnorePointer(
                                  child: Text(
                                    'Двойной клик — карточка. Перетащи заметку из списка — появится нода.\nПравый клик — меню, «?» вверху — все клавиши.',
                                    textAlign: TextAlign.center,
                                    style: SpType.text(13.5, color: SpColors.dim, height: 22),
                                  ),
                                ),
                              ),
                            _selectionBar(d),
                            Positioned(left: 0, right: 0, bottom: 14, child: Center(child: _addBar())),
                            Positioned(right: 12, bottom: 14, child: _zoomBar()),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _header() {
    final dir = folderOf(widget.path);
    Widget icon(IconData i, String tip, VoidCallback? on) => IconButton(
      tooltip: tip,
      visualDensity: VisualDensity.compact,
      iconSize: 18,
      color: SpColors.muted,
      disabledColor: SpColors.lineStrong,
      onPressed: on,
      icon: Icon(i),
    );
    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 16, right: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: SpColors.line)),
      ),
      child: Row(
        children: [
          Text(
            'ХОЛСТ',
            style: SpType.label(10, w: FontWeight.w500, color: SpColors.ink),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${dir.isEmpty ? '' : '${dir.replaceAll('/', ' / ')} / '}${baseName(widget.path)}'.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: SpType.label(9.5),
            ),
          ),
          icon(Icons.undo, 'Отменить · Ctrl+Z', _hist.canUndo ? () => _undo() : null),
          icon(Icons.redo, 'Вернуть · Ctrl+Shift+Z', _hist.canRedo ? () => _undo(redo: true) : null),
          icon(Icons.auto_awesome_mosaic_outlined, 'Разложить ноды без места', () {
            _remember();
            _doc!.autoLayout();
            _changed();
            _fitAll();
          }),
          icon(Icons.help_outline, 'Клавиши холста', _help),
          icon(
            st.wide ? Icons.fullscreen_exit : Icons.fullscreen,
            st.wide ? 'Обычный вид' : 'Во весь экран',
            () => st.setWide(!st.wide),
          ),
        ],
      ),
    );
  }

  Widget _panel(List<Widget> kids, {Axis dir = Axis.horizontal}) => Material(
    color: SpColors.node,
    elevation: 6,
    shadowColor: Colors.black54,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(SpRadius.hub),
      side: BorderSide(color: SpColors.line),
    ),
    child: Padding(
      padding: const EdgeInsets.all(3),
      child: Flex(direction: dir, mainAxisSize: MainAxisSize.min, children: kids),
    ),
  );

  Widget _tool(IconData i, String tip, VoidCallback on, {Color? color}) => Tooltip(
    message: tip,
    waitDuration: const Duration(milliseconds: 400),
    child: InkWell(
      onTap: on,
      borderRadius: BorderRadius.circular(SpRadius.button),
      child: SizedBox(width: 34, height: 34, child: Icon(i, size: 18, color: color ?? SpColors.ink2)),
    ),
  );

  Widget _addBar() => _panel([
    _tool(Icons.sticky_note_2_outlined, 'Карточка · двойной клик по пустому', () => _newCard(_center)),
    _tool(Icons.description_outlined, 'Заметка из папки', () => _pickNote()),
    _tool(Icons.image_outlined, 'Картинка', () => _addImage()),
    _tool(Icons.crop_free, 'Группа · Ctrl+G', _groupSel),
  ]);

  Widget _zoomBar() => AnimatedBuilder(
    animation: _cam,
    builder: (_, _) => _panel([
      _tool(Icons.remove, 'Дальше · Ctrl+−', () => _zoomBy(.8)),
      Tooltip(
        message: '100 % · Ctrl+0',
        child: InkWell(
          onTap: () {
            final c = _center;
            _flyTo((cam) => cam.centerOn(c.dx, c.dy, _size.width, _size.height, 1));
          },
          child: SizedBox(
            width: 46,
            height: 34,
            child: Center(
              child: Text('${(_c.k * 100).round()} %', style: SpType.label(10.5, color: SpColors.ink2, spacing: 0)),
            ),
          ),
        ),
      ),
      _tool(Icons.add, 'Ближе · Ctrl+=', () => _zoomBy(1.25)),
      _tool(Icons.fit_screen_outlined, 'Весь холст · Shift+1', _fitAll),
    ]),
  );

  /// Панель над выделенным: цвет, править, открыть, к выделенному, удалить.
  Widget _selectionBar(CanvasDoc d) {
    if (_editing != null || (_sel.isEmpty && _selEdge == null)) return const SizedBox.shrink();
    final edge = d.edges.where((x) => x.id == _selEdge).firstOrNull;
    final one = _sel.length == 1 ? d.node(_sel.first) : null;
    final isNote = one != null && one.type == 'file' && st.index.doc(one.file) != null;
    final canEdit =
        one != null &&
        one.type != 'link' &&
        !(one.type == 'file' && _isImage(one.file)) &&
        (one.type != 'file' || isNote);
    final cur = edge?.color ?? one?.color;
    return AnimatedBuilder(
      animation: _cam,
      builder: (_, child) {
        Rect r;
        if (edge != null) {
          final a = d.node(edge.from), b = d.node(edge.to);
          if (a == null || b == null) return const SizedBox.shrink();
          final (mx, my) = edgeCurve(edge, a, b).at(.5);
          r = Rect.fromCenter(center: _s(mx, my), width: 1, height: 24);
        } else {
          final bb = d.boundsOf(_sel);
          if (bb == null || _drag?.moved == true) return const SizedBox.shrink();
          final (x0, y0, x1, y1) = bb;
          r = Rect.fromPoints(_s(x0, y0), _s(x1, y1));
        }
        final top = (r.top - 50).clamp(8.0, math.max(8.0, _size.height - 60)).toDouble();
        final left = r.center.dx.clamp(120.0, math.max(120.0, _size.width - 120)).toDouble();
        return Positioned(
          left: left,
          top: top,
          child: FractionalTranslation(translation: const Offset(-.5, 0), child: child),
        );
      },
      child: _panel([
        if (_palette)
          for (final c in const [null, '1', '2', '3', '4', '5', '6'])
            InkWell(
              onTap: () {
                _palette = false;
                _setColor(c);
              },
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 30,
                height: 34,
                child: Center(
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: canvasColor(c) ?? SpColors.node,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: c == cur ? SpColors.ink : (c == null ? SpColors.lineStrong : Colors.transparent),
                        width: c == cur ? 2 : 1,
                      ),
                    ),
                    child: c == null ? Icon(Icons.block, size: 12, color: SpColors.dim) : null,
                  ),
                ),
              ),
            )
        else ...[
          _tool(Icons.palette_outlined, 'Цвет', () => setState(() => _palette = true), color: canvasColor(cur)),
          if (canEdit)
            _tool(
              Icons.edit_outlined,
              one.isGroup ? 'Переименовать · Enter' : 'Править · Enter',
              () => _startEdit(one),
            ),
          if (edge != null) _tool(Icons.short_text, 'Подпись · Enter', () => _startEditEdge(edge.id)),
          if (isNote) _tool(Icons.open_in_new, 'Открыть заметку', () => st.openNote(one.file)),
          if (edge == null) _tool(Icons.center_focus_strong_outlined, 'К выделенному · Shift+2', _fitSel),
          _tool(Icons.delete_outline, 'Удалить · Delete', _deleteSel, color: SpColors.red),
        ],
      ]),
    );
  }

  /// Мир холста в его собственных координатах. Камера двигает его целиком матрицей — без перестройки.
  Widget _world(CanvasDoc d) {
    if (st.index.version != _ver) {
      _ver = st.index.version;
      _cache.clear();
      _all = null;
    }
    _far = _c.k < .35;
    final v = _size.isEmpty ? null : _view();
    _built = v?.inflate(math.max(v.width, v.height) * .75);
    bool shown(CanvasNode n) =>
        _built == null ||
        _sel.contains(n.id) ||
        _editing?.$2 == n.id ||
        _built!.overlaps(Rect.fromLTWH(n.x, n.y, n.width, n.height));
    final edit = _editing;
    return _FreeStack(
      children: [
        for (final n in d.nodes)
          if (n.isGroup && shown(n))
            _place(n, edit != null && edit.$1 == _EditKind.group && edit.$2 == n.id ? _groupEditor(n) : _cached(n)),
        Positioned(left: 0, top: 0, width: 1, height: 1, child: CustomPaint(painter: _Wires(d, _selEdge, _sel))),
        for (final n in d.nodes)
          if (!n.isGroup && shown(n))
            _place(n, edit != null && edit.$1 == _EditKind.node && edit.$2 == n.id ? _editor(n) : _cached(n)),
        for (final e in d.edges)
          if ((e.label.isNotEmpty || (edit?.$1 == _EditKind.edge && edit?.$2 == e.id)) &&
              d.node(e.from) != null &&
              d.node(e.to) != null)
            _edgeLabel(d, e, edit?.$1 == _EditKind.edge && edit?.$2 == e.id),
      ],
    );
  }

  Widget _place(CanvasNode n, Widget child) =>
      Positioned(key: ValueKey(n.id), left: n.x, top: n.y, width: n.width, height: n.height, child: child);

  Widget _cached(CanvasNode n) {
    final scroll = _sel.length == 1 && _sel.first == n.id;
    final key =
        '${n.width}x${n.height}|${n.color}|$scroll|$_far|${n.type == 'text'
            ? n.text.hashCode
            : n.type == 'group'
            ? n.label
            : n.file}';
    final hit = _cache[n.id];
    if (hit != null && hit.$1 == key) return hit.$2;
    final w = RepaintBoundary(child: _far ? _farContent(n) : _content(n, scroll));
    _cache[n.id] = (key, w);
    return w;
  }

  String? _resolve(String target) {
    final all = _all ??= [...st.index.paths, ...st.index.files];
    return resolveLink(target, widget.path, all);
  }

  /// Содержимое ноды целиком, как в Obsidian: длинное прокручивается колёсиком, когда нода выбрана.
  Widget _scroll(bool on, Widget child) => ScrollConfiguration(
    behavior: const ScrollBehavior().copyWith(scrollbars: on),
    child: SingleChildScrollView(
      physics: on ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: child,
    ),
  );

  /// Издалека текст не читается — рисуем плашку с названием (так быстрее и понятнее).
  Widget _farContent(CanvasNode n) {
    final tint = canvasColor(n.color);
    if (n.isGroup) {
      final c = tint ?? SpColors.grey;
      return Container(
        decoration: BoxDecoration(
          color: c.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(SpRadius.hub),
          border: Border.all(color: c.withValues(alpha: .5), width: 3),
        ),
        alignment: Alignment.topLeft,
        padding: const EdgeInsets.all(16),
        child: Text(
          n.label.isEmpty ? 'Группа' : n.label,
          style: SpType.text(44, w: FontWeight.w600, color: c),
        ),
      );
    }
    final title = switch (n.type) {
      'file' => _isImage(n.file) ? null : shownName(n.file),
      'link' => n.url,
      _ =>
        n.text
            .split('\n')
            .map((l) => l.replaceAll(RegExp(r'^[#>\-*\s]+'), ''))
            .firstWhere((l) => l.trim().isNotEmpty, orElse: () => ''),
    };
    if (title == null) return _content(n, false);
    final all = _all ??= [...st.index.paths, ...st.index.files];
    final c = tint ?? (n.type == 'file' ? folderHead(n.file, all) : SpColors.lineStrong);
    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(c.withValues(alpha: .25), SpColors.node),
        borderRadius: BorderRadius.circular(SpRadius.node * 2),
        border: Border.all(color: c, width: 3),
      ),
      padding: const EdgeInsets.all(14),
      alignment: Alignment.center,
      child: Text(
        title,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: SpType.text(36, w: FontWeight.w600, color: SpColors.ink),
      ),
    );
  }

  Widget _content(CanvasNode n, bool scroll) {
    final tint = canvasColor(n.color);
    final border = Border.all(color: tint ?? SpColors.line);
    final fileOf = st.vault?.file;
    if (n.isGroup) {
      final c = tint ?? SpColors.grey;
      return Container(
        decoration: BoxDecoration(
          color: c.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(SpRadius.hub),
          border: Border.all(color: c.withValues(alpha: .5)),
        ),
        alignment: Alignment.topLeft,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        child: Text(
          n.label.isEmpty ? 'Группа' : n.label,
          style: SpType.text(15, w: FontWeight.w600, color: c),
        ),
      );
    }
    if (n.type == 'text' || n.type == 'link') {
      return Container(
        decoration: BoxDecoration(
          color: tint == null ? SpColors.node : Color.alphaBlend(tint.withValues(alpha: .08), SpColors.node),
          borderRadius: BorderRadius.circular(SpRadius.node),
          border: border,
        ),
        clipBehavior: Clip.antiAlias,
        child: _scroll(
          scroll,
          n.type == 'link'
              ? Text(n.url, style: SpType.text(13, color: SpColors.blue))
              : MdView(text: n.text, resolve: _resolve, fileOf: fileOf),
        ),
      );
    }
    // Файл: картинка — целиком, без обрезки; заметка — полностью, с разметкой.
    final f = n.file;
    if (_isImage(f)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(SpRadius.node),
        child: st.vault == null
            ? const SizedBox()
            : Image(
                // Картинку читаем не больше, чем нужно ноде (с запасом на приближение), а не в полный размер файла.
                image: ResizeImage(
                  FileImage(st.vault!.file(f)),
                  width: ((n.width * 2 / 256).ceil() * 256).clamp(256, 2048),
                  policy: ResizeImagePolicy.fit,
                ),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Center(
                  child: Text(f, style: SpType.label(9, color: SpColors.dim)),
                ),
              ),
      );
    }
    final doc = st.index.doc(f);
    final all = _all ??= [...st.index.paths, ...st.index.files];
    return Container(
      decoration: BoxDecoration(
        color: SpColors.node,
        borderRadius: BorderRadius.circular(SpRadius.node),
        border: doc == null ? Border.all(color: SpColors.dim) : border,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _noteHead(n, doc != null, all),
          Expanded(
            child: doc == null
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Файла нет: $f', style: SpType.text(12, color: SpColors.muted)),
                  )
                : _scroll(scroll, MdView(text: st.textOf(f), resolve: (t) => resolveLink(t, f, all), fileOf: fileOf)),
          ),
        ],
      ),
    );
  }

  Widget _noteHead(CanvasNode n, bool exists, List<String> all) {
    final f = n.file;
    final tint = canvasColor(n.color);
    final head = tint == null ? folderHead(f, all) : Color.lerp(tint, Colors.black, .45)!;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: exists ? head : SpColors.headGrey,
      child: Row(
        children: [
          Expanded(
            child: Text(
              shownName(f),
              overflow: TextOverflow.ellipsis,
              style: SpType.text(12.5, w: FontWeight.w600, color: Colors.white),
            ),
          ),
          if (f.contains('/'))
            Text(
              f.substring(0, f.lastIndexOf('/')).replaceAll('/', ' › '),
              style: SpType.text(10.5, color: const Color(0xB3FFFFFF)),
            ),
        ],
      ),
    );
  }

  Widget _field({bool expands = true, String hint = 'Текст… (Markdown)', TextStyle? style}) => Material(
    type: MaterialType.transparency,
    child: TextField(
      controller: _ed,
      focusNode: _edFocus,
      maxLines: expands ? null : 1,
      expands: expands,
      textAlignVertical: TextAlignVertical.top,
      onChanged: _typed,
      onSubmitted: expands
          ? null
          : (_) {
              _commitEdit();
              _focus.requestFocus();
              setState(() {});
            },
      cursorColor: SpColors.accent,
      style: style ?? SpType.text(13, color: SpColors.body, height: 19.5),
      decoration: InputDecoration.collapsed(
        hintText: hint,
        hintStyle: SpType.text(13, color: SpColors.dim),
      ),
    ),
  );

  Widget _editor(CanvasNode n) {
    final tint = canvasColor(n.color);
    final box = BoxDecoration(
      color: tint == null ? SpColors.node : Color.alphaBlend(tint.withValues(alpha: .08), SpColors.node),
      borderRadius: BorderRadius.circular(SpRadius.node),
      border: Border.all(color: SpColors.accent, width: 2),
    );
    if (n.type == 'file') {
      return Container(
        decoration: box,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _noteHead(n, true, _all ??= [...st.index.paths, ...st.index.files]),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: _field(hint: 'Текст заметки…'),
              ),
            ),
          ],
        ),
      );
    }
    return Container(decoration: box, padding: const EdgeInsets.fromLTRB(14, 10, 14, 10), child: _field());
  }

  Widget _groupEditor(CanvasNode n) {
    final c = canvasColor(n.color) ?? SpColors.grey;
    return Container(
      decoration: BoxDecoration(
        color: c.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(SpRadius.hub),
        border: Border.all(color: SpColors.accent, width: 2),
      ),
      alignment: Alignment.topLeft,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: SizedBox(
        height: 24,
        child: _field(
          expands: false,
          hint: 'Название группы',
          style: SpType.text(15, w: FontWeight.w600, color: c),
        ),
      ),
    );
  }

  Widget _edgeLabel(CanvasDoc d, CanvasEdge e, bool editing) {
    final r = _labelRect(d, e);
    final on = e.id == _selEdge;
    if (editing) {
      return Positioned(
        left: r.center.dx - 100,
        top: r.top - 4,
        width: 200,
        height: 30,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: SpColors.bg,
            border: Border.all(color: SpColors.accent, width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: _field(
            expands: false,
            hint: 'Подпись',
            style: SpType.text(12, color: SpColors.ink),
          ),
        ),
      );
    }
    return Positioned(
      left: r.left,
      top: r.top,
      width: r.width,
      height: r.height,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: SpColors.bg,
          border: Border.all(color: on ? SpColors.accent : SpColors.lineStrong),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          e.label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: SpType.label(9, color: on ? SpColors.accentInk : SpColors.muted),
        ),
      ),
    );
  }
}

/// Stack, который отдаёт касания детям и за своими границами: ноды лежат в координатах холста, где угодно.
class _FreeStack extends Stack {
  const _FreeStack({required super.children}) : super(clipBehavior: Clip.none);

  @override
  RenderStack createRenderObject(BuildContext context) =>
      _RenderFreeStack(textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr);
}

class _RenderFreeStack extends RenderStack {
  _RenderFreeStack({super.textDirection}) : super(clipBehavior: Clip.none);

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (hitTestChildren(result, position: position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}

class _Ground extends CustomPainter {
  _Ground(this.cam, this.drop) : super(repaint: cam);
  final _Cam cam;
  final bool drop;
  @override
  void paint(Canvas canvas, Size size) {
    final c = cam.c;
    canvas.drawRect(Offset.zero & size, Paint()..color = drop ? const Color(0xFF1E1D1C) : SpColors.ground);
    var step = 24.0 * c.k;
    while (step < 12) {
      step *= 2;
    }
    final p = Paint()
      ..color = SpColors.dot
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    // Все точки одним вызовом: по одной — тысячи вызовов на каждый кадр.
    final pts = <double>[];
    for (var y = c.dy % step; y < size.height; y += step) {
      for (var x = c.dx % step; x < size.width; x += step) {
        pts
          ..add(x)
          ..add(y);
      }
    }
    canvas.drawRawPoints(ui.PointMode.points, Float32List.fromList(pts), p);
  }

  @override
  bool shouldRepaint(covariant _Ground old) => old.drop != drop || old.cam != cam;
}

Path _path(EdgeCurve c) => Path()
  ..moveTo(c.a.$1, c.a.$2)
  ..cubicTo(c.c1.$1, c.c1.$2, c.c2.$1, c.c2.$2, c.b.$1, c.b.$2);

/// Провода — в координатах холста, внутри мира.
class _Wires extends CustomPainter {
  _Wires(this.d, this.selEdge, this.sel);
  final CanvasDoc d;
  final String? selEdge;
  final Set<String> sel;

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in d.edges) {
      final a = d.node(e.from), b = d.node(e.to);
      if (a == null || b == null) continue;
      final c = edgeCurve(e, a, b);
      final hot = e.id == selEdge || sel.contains(e.from) || sel.contains(e.to);
      final color = e.id == selEdge
          ? SpColors.accent
          : (canvasColor(e.color) ?? (hot ? SpColors.ink2 : SpColors.lineStrong));
      canvas.drawPath(
        _path(c),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = e.id == selEdge ? 3 : 2
          ..color = color,
      );
      for (final (o, s, arrow) in [(c.a, c.sa, e.arrowFrom), (c.b, c.sb, e.arrowTo)]) {
        if (!arrow) continue;
        final (dx, dy) = sideDir(s);
        final tip = Offset(o.$1, o.$2);
        final dir = Offset(dx, dy);
        final back = tip + dir * 12;
        final side = Offset(-dir.dy, dir.dx) * 6;
        canvas.drawPath(
          Path()
            ..moveTo(tip.dx, tip.dy)
            ..lineTo(back.dx + side.dx, back.dy + side.dy)
            ..lineTo(back.dx - side.dx, back.dy - side.dy)
            ..close(),
          Paint()..color = color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Поверх мира, в координатах экрана: рамки выделенного, ручки размера, точки-сокеты, рамка выделения, тянущийся провод.
class _Overlay extends CustomPainter {
  _Overlay(
    this.d,
    this.cam,
    this.sel,
    this.hot,
    this.box,
    this.wire, {
    required this.showHandles,
    required Listenable repaint,
  }) : super(repaint: repaint);
  final CanvasDoc d;
  final _Cam cam;
  final Set<String> sel;
  final ValueNotifier<(String?, CanvasSide?)> hot;
  final ValueNotifier<Rect?> box;
  final ValueNotifier<(String, CanvasSide, Offset)?> wire;
  final bool showHandles;

  Offset _s(double x, double y) {
    final (sx, sy) = cam.c.toScreen(x, y);
    return Offset(sx, sy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final k = cam.c.k;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = SpColors.accent;
    for (final id in sel) {
      final n = d.node(id);
      if (n == null) continue;
      final r = Rect.fromPoints(_s(n.x, n.y), _s(n.x + n.width, n.y + n.height));
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.inflate(1), Radius.circular((n.isGroup ? SpRadius.hub : SpRadius.node) * k + 1)),
        line,
      );
      if (sel.length == 1 && showHandles) {
        for (final p in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
          canvas.drawRect(Rect.fromCenter(center: p, width: 7, height: 7), Paint()..color = SpColors.ground);
          canvas.drawRect(Rect.fromCenter(center: p, width: 7, height: 7), line..strokeWidth = 1.5);
        }
        line.strokeWidth = 2;
      }
    }
    // Точки для провода — у ноды под курсором и у единственной выбранной.
    final (hid, hside) = hot.value;
    final w = wire.value;
    final ids = {?hid, if (sel.length == 1) sel.first, ?w?.$1};
    if (showHandles || w != null) {
      for (final id in ids) {
        final n = d.node(id);
        if (n == null || n.isGroup) continue;
        for (final s in CanvasSide.values) {
          final (x, y) = n.socket(s);
          final p = _s(x, y);
          final on = (id == hid && s == hside) || (w != null && w.$1 == id && w.$2 == s);
          canvas.drawCircle(p, on ? 6 : 4.5, Paint()..color = on ? SpColors.accent : SpColors.ground);
          canvas.drawCircle(
            p,
            on ? 6 : 4.5,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = on ? SpColors.accent : SpColors.lineStrong,
          );
        }
      }
    }
    final b = box.value;
    if (b != null) {
      final r = Rect.fromPoints(_s(b.left, b.top), _s(b.right, b.bottom));
      canvas.drawRect(r, Paint()..color = SpColors.accent.withValues(alpha: .08));
      canvas.drawRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = SpColors.accent.withValues(alpha: .7),
      );
    }
    if (w != null) {
      final a = d.node(w.$1);
      if (a != null) {
        final from = a.socket(w.$2);
        final target = d.hit(w.$3.dx, w.$3.dy);
        final snapTo = target != null && target.id != a.id && !target.isGroup;
        final toSide = snapTo ? nearestSide(target, w.$3.dx, w.$3.dy) : null;
        final to = snapTo ? target.socket(toSide!) : (w.$3.dx, w.$3.dy);
        final c = curveBetween(from, w.$2, to, toSide);
        canvas.save();
        canvas.translate(cam.c.dx, cam.c.dy);
        canvas.scale(k);
        canvas.drawPath(
          _path(c),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 / math.max(k, .3)
            ..color = SpColors.accent,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Overlay old) => true;
}
