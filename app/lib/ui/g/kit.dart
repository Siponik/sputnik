// Детали системы G (design/system-g/gen/kit.py): шапка, нода с цветной шапкой, сокеты и провода, кнопки, чипы,
// сегмент, отметка, этапы, штамп листа, размерная линия, заголовок колонки.
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../widgets/coon.dart';

const kDark = Color(0xFF1E1F23);
const kWait = Color(0xFF55575F);
const kBar = Color(0xFF45464D);
const kSoftWhite = Color(0xB8FFFFFF);

/// Тёмная заливка шапки ноды по цвету сферы (FILL в kit.py).
Color headFill(Color c) => switch (c.toARGB32()) {
  0xFFF0A04B => SpColors.headOrange,
  0xFF6FA2F2 => SpColors.headBlue,
  0xFFB48CF0 => SpColors.headViolet,
  0xFF7FD18C => SpColors.headGreen,
  0xFFE8C65A => SpColors.headGold,
  0xFFF0785F => SpColors.headRed,
  _ => SpColors.headGrey,
};

TextStyle gLbl({Color c = SpColors.muted, double size = 10.5, FontWeight w = FontWeight.w500}) =>
    SpType.label(size, color: c, w: w, spacing: .14);
TextStyle gMicro({Color c = SpColors.dim}) => SpType.label(9.5, color: c, spacing: .12);
TextStyle gMono(double size, {Color c = SpColors.muted, FontWeight w = FontWeight.w400}) =>
    SpType.label(size, color: c, w: w, spacing: 0);

// ---------- провода ----------

class _Wire {
  _Wire(this.from, this.to, this.color, this.width, this.dash, this.vertical);
  final String from, to;
  final Color color;
  final double width;
  final bool dash, vertical;
}

/// Провод между сокетами from → to (id сокетов внутри одного [WireBoard]).
class Wire {
  const Wire(this.from, this.to, this.color, {this.width = 1.5, this.dash = false, this.vertical = false});
  final String from, to;
  final Color color;
  final double width;
  final bool dash, vertical;
}

class _Reg extends InheritedWidget {
  const _Reg({required this.state, required super.child});
  final _WireBoardState state;
  @override
  bool updateShouldNotify(_Reg old) => false;
}

/// Холст с проводами: сокеты [Sock] внутри регистрируются по id, провода рисуются под нодами.
class WireBoard extends StatefulWidget {
  const WireBoard({super.key, required this.wires, required this.child});
  final List<Wire> wires;
  final Widget child;
  @override
  State<WireBoard> createState() => _WireBoardState();
}

class _WireBoardState extends State<WireBoard> {
  final keys = <String, GlobalKey>{};
  final _box = GlobalKey();
  Map<String, Offset> pos = {};

  GlobalKey keyOf(String id) => keys.putIfAbsent(id, GlobalKey.new);

  void _measure() {
    final root = _box.currentContext?.findRenderObject() as RenderBox?;
    if (root == null || !root.attached) return;
    final next = <String, Offset>{};
    for (final e in keys.entries) {
      final b = e.value.currentContext?.findRenderObject() as RenderBox?;
      if (b == null || !b.attached || !b.hasSize) continue;
      next[e.key] = root.globalToLocal(b.localToGlobal(b.size.center(Offset.zero)));
    }
    if (!_same(next, pos) && mounted) setState(() => pos = next);
  }

  bool _same(Map<String, Offset> a, Map<String, Offset> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] != null && (b[e.key]! - e.value).distance < .5);

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final ws = [
      for (final w in widget.wires)
        if (pos[w.from] != null && pos[w.to] != null) _Wire(w.from, w.to, w.color, w.width, w.dash, w.vertical),
    ];
    return _Reg(
      state: this,
      child: CustomPaint(key: _box, painter: _WirePainter(ws, pos), child: widget.child),
    );
  }
}

class _WirePainter extends CustomPainter {
  _WirePainter(this.ws, this.pos);
  final List<_Wire> ws;
  final Map<String, Offset> pos;

  @override
  void paint(Canvas canvas, Size size) {
    for (final w in ws) {
      final a = pos[w.from]!, b = pos[w.to]!;
      final p = Path()..moveTo(a.dx, a.dy);
      if (w.vertical) {
        final k = ((b.dy - a.dy).abs() / 2).clamp(20.0, 60.0);
        p.cubicTo(a.dx, a.dy + k, b.dx, b.dy - k, b.dx, b.dy);
      } else {
        final k = ((b.dx - a.dx).abs() / 2).clamp(20.0, 70.0);
        p.cubicTo(a.dx + k, a.dy, b.dx - k, b.dy, b.dx, b.dy);
      }
      final paint = Paint()
        ..color = w.color
        ..strokeWidth = w.width
        ..style = PaintingStyle.stroke;
      if (!w.dash) {
        canvas.drawPath(p, paint);
        continue;
      }
      for (final m in p.computeMetrics()) {
        for (var d = 0.0; d < m.length; d += 8) {
          canvas.drawPath(m.extractPath(d, d + 4), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_WirePainter old) => true;
}

/// Сокет: квадрат 10 px со скруглением 3, заливка цвета провода (ring — пустой, «ждёт»).
class Sock extends StatelessWidget {
  const Sock(this.id, this.color, {super.key, this.ring = false});
  final String? id;
  final Color color;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final reg = context.dependOnInheritedWidgetOfExactType<_Reg>();
    return Container(
      key: id == null ? null : reg?.state.keyOf(id!),
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: ring ? SpColors.ground : color,
        borderRadius: BorderRadius.circular(SpRadius.socket),
        border: Border.all(color: ring ? color : SpColors.ground, width: 1.5),
      ),
    );
  }
}

/// Строка с сокетом на краю ноды (сокет выступает на 6 px за край).
class SockRow extends StatelessWidget {
  const SockRow({super.key, required this.child, this.left, this.right});
  final Widget child;
  final Sock? left, right;
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      child,
      if (left != null) Positioned(left: -6, top: 0, bottom: 0, child: Center(child: left)),
      if (right != null) Positioned(right: -6, top: 0, bottom: 0, child: Center(child: right)),
    ],
  );
}

// ---------- нода ----------

class GHead extends StatelessWidget {
  const GHead({
    super.key,
    this.num,
    required this.name,
    this.kind,
    this.color,
    this.hub = false,
    this.height = 30,
    this.trailing,
  });
  final String? num;
  final String name;
  final String? kind;
  final Color? color; // null — без заливки (серая строка с линией снизу)
  final bool hub;
  final double height;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final filled = color != null || hub;
    final r = hub ? 11.0 : 7.0;
    return LayoutBuilder(
      builder: (context, box) {
        final kindMax = box.maxWidth.isFinite ? box.maxWidth * .45 : 400.0;
        return Container(
          height: height,
          padding: const EdgeInsets.fromLTRB(12, 0, 10, 0),
          decoration: BoxDecoration(
            color: hub ? SpColors.headMain : (color == null ? null : headFill(color!)),
            borderRadius: filled ? BorderRadius.vertical(top: Radius.circular(r)) : null,
            border: filled ? null : const Border(bottom: BorderSide(color: SpColors.line)),
          ),
          child: Row(
            children: [
              if (num != null) ...[
                Text(num!, style: gLbl(c: filled ? kSoftWhite : SpColors.dim)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  name.toUpperCase(),
                  style: gLbl(c: filled ? Colors.white : SpColors.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (kind != null) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: kindMax),
                  child: Text(
                    kind!.toUpperCase(),
                    style: gLbl(c: filled ? kSoftWhite : SpColors.dim),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              ?trailing,
            ],
          ),
        );
      },
    );
  }
}

/// Нода: контур, скругление 8 (главная — 12, рамка цвета accent-line, тень и уголки-скобки), «ждёт» — пунктир.
class GNode extends StatelessWidget {
  const GNode({
    super.key,
    required this.child,
    this.hub = false,
    this.wait = false,
    this.width,
    this.color = SpColors.node,
  });
  final Widget child;
  final bool hub, wait;
  final double? width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final r = hub ? SpRadius.hub : SpRadius.node;
    Widget box = Container(
      width: width,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(r),
        border: wait ? null : Border.all(color: hub ? SpColors.accentLine : SpColors.line),
        boxShadow: hub ? const [BoxShadow(color: Color(0x59000000), blurRadius: 40, offset: Offset(0, 18))] : null,
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
    if (wait) box = CustomPaint(foregroundPainter: _Dashed(r), child: box);
    if (!hub) return box;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        box,
        for (final (t, l) in [(true, true), (true, false), (false, true), (false, false)])
          Positioned(
            top: t ? -5 : null,
            bottom: t ? null : -5,
            left: l ? -5 : null,
            right: l ? null : -5,
            child: CustomPaint(size: const Size(14, 14), painter: _Tick(t, l)),
          ),
      ],
    );
  }
}

class _Tick extends CustomPainter {
  _Tick(this.top, this.left);
  final bool top, left;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = SpColors.accent
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final rect = Rect.fromLTWH(left ? 0 : -s.width, top ? 0 : -s.height, s.width * 2, s.height * 2);
    final start = top ? (left ? 3.1416 : -1.5708) : (left ? 1.5708 : 0.0);
    canvas.drawArc(rect.deflate(.75), start, 1.5708, false, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Dashed extends CustomPainter {
  _Dashed(this.r, [this.color = kWait]);
  final double r;
  final Color color;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke;
    final path = Path()..addRRect(RRect.fromRectAndRadius((Offset.zero & s).deflate(.5), Radius.circular(r)));
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 6) {
        canvas.drawPath(m.extractPath(d, d + 3), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Пунктирная рамка вокруг чего угодно.
class Dashed extends StatelessWidget {
  const Dashed({super.key, required this.child, this.r = 8, this.color = kWait});
  final Widget child;
  final double r;
  final Color color;
  @override
  Widget build(BuildContext context) => CustomPaint(foregroundPainter: _Dashed(r, color), child: child);
}

// ---------- кнопки и чипы ----------

enum BtnKind { acc, ink, sec, ghost }

class GBtn extends StatelessWidget {
  const GBtn(this.text, {super.key, this.kind = BtnKind.sec, this.sm = false, this.onTap, this.icon, this.border});
  final String text;
  final BtnKind kind;
  final bool sm;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, bd) = switch (kind) {
      BtnKind.acc => (SpColors.accent, kDark, null),
      BtnKind.ink => (SpColors.ink, SpColors.bg, null),
      BtnKind.ghost => (Colors.transparent, SpColors.muted, null),
      BtnKind.sec => (Colors.transparent, SpColors.ink, border ?? SpColors.lineStrong),
    };
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SpRadius.button),
        side: bd == null ? BorderSide.none : BorderSide(color: bd),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SpRadius.button),
        child: Container(
          height: sm ? 28 : 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SpType.text(
                    sm ? 12.5 : 13,
                    color: fg,
                    w: kind == BtnKind.acc || kind == BtnKind.ink ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Моно-чип (фильтр): включённый — заливка accent-wash и рамка цвета.
class GChip extends StatelessWidget {
  const GChip(this.text, {super.key, this.on = false, this.color = SpColors.accent, this.onTap, this.dot});
  final String text;
  final bool on;
  final Color color;
  final Color? dot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(SpRadius.button),
    child: Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: on ? SpColors.accentWash : Colors.transparent,
        borderRadius: BorderRadius.circular(SpRadius.button),
        border: Border.all(color: on ? color : SpColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[GDot(dot!), const SizedBox(width: 6)],
          Flexible(
            child: Text(
              text.toUpperCase(),
              style: SpType.label(10.5, w: FontWeight.w500, color: on ? SpColors.ink : SpColors.muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Дружелюбный чип окон (обычные слова): выбранный — рамка цвета и accent-wash.
class GPick extends StatelessWidget {
  const GPick(this.text, {super.key, this.on = false, this.color = SpColors.accent, this.onTap, this.dot});
  final String text;
  final bool on;
  final Color color;
  final Color? dot;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(SpRadius.button),
    child: Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: on ? SpColors.accentWash : Colors.transparent,
        borderRadius: BorderRadius.circular(SpRadius.button),
        border: Border.all(color: on ? color : SpColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[GDot(dot!), const SizedBox(width: 6)],
          Flexible(
            child: Text(
              text,
              style: SpType.text(12.5, color: on ? SpColors.ink : SpColors.muted, w: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
  );
}

class GSeg extends StatelessWidget {
  const GSeg({super.key, required this.items, required this.active, required this.onTap});
  final List<String> items;
  final int active;
  final void Function(int) onTap;
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: SpColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, t) in items.indexed)
            InkWell(
              onTap: () => onTap(i),
              borderRadius: BorderRadius.circular(5),
              child: Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == active ? SpColors.ink : null,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  t.toUpperCase(),
                  style: SpType.label(10.5, w: FontWeight.w500, color: i == active ? SpColors.bg : SpColors.muted),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class GDot extends StatelessWidget {
  const GDot(this.color, {super.key, this.size = 6});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
  );
}

/// Отметка 14 px: сделано — серая заливка с ✓.
class GCheck extends StatelessWidget {
  const GCheck({super.key, required this.done, this.onTap, this.color = SpColors.lineStrong});
  final bool done;
  final VoidCallback? onTap;
  final Color color;
  @override
  Widget build(BuildContext context) => InkResponse(
    onTap: onTap,
    radius: 14,
    child: Container(
      width: 14,
      height: 14,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done ? kBar : null,
        borderRadius: BorderRadius.circular(4),
        border: done ? null : Border.all(color: color),
      ),
      child: done ? const Icon(Icons.check, size: 10, color: SpColors.ink) : null,
    ),
  );
}

/// Дорожка этапов: сделанные — зелёные, текущий — оранжевый, остальные — серые.
class GStages extends StatelessWidget {
  const GStages({super.key, required this.done, required this.now, required this.total, this.h = 4});
  final int done, now, total;
  final double h;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < total; i++) ...[
        if (i > 0) const SizedBox(width: 3),
        Expanded(
          child: Container(
            height: h,
            decoration: BoxDecoration(
              color: i < done ? SpColors.green : (i == now ? SpColors.accent : kBar),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    ],
  );
}

/// Енот в пунктирном круге (на макете — место под енота).
class GCoon extends StatelessWidget {
  const GCoon(this.pose, {super.key, this.size = 50});
  final String pose;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Dashed(
      r: size / 2,
      color: SpColors.muted,
      child: ClipOval(
        child: Padding(
          padding: EdgeInsets.all(size * .08),
          child: Coon(pose, size: size * .84),
        ),
      ),
    ),
  );
}

/// Карточка енота с советом (пунктир).
class CoonTip extends StatelessWidget {
  const CoonTip({super.key, required this.pose, required this.text, this.action, this.onAction, this.color = kWait});
  final String pose;
  final String text;
  final String? action;
  final VoidCallback? onAction;
  final Color color;
  @override
  Widget build(BuildContext context) => Dashed(
    color: color,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          GCoon(pose),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: '$text${action == null ? '' : ' '}',
                children: [
                  if (action != null)
                    WidgetSpan(
                      child: InkWell(
                        onTap: onAction,
                        child: Text(
                          action!,
                          style: SpType.text(
                            12.5,
                            color: SpColors.accent,
                          ).copyWith(decoration: TextDecoration.underline, decorationColor: SpColors.accent),
                        ),
                      ),
                    ),
                ],
              ),
              style: SpType.text(12.5, color: const Color(0xFFB5B7C0)),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Заголовок колонки «01 · ИСТОЧНИКИ ———».
class ColHead extends StatelessWidget {
  const ColHead(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Text(
          text,
          style: SpType.label(10, w: FontWeight.w500, color: SpColors.dim, spacing: .16),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider(height: 1, color: SpColors.line)),
      ],
    ),
  );
}

/// Размерная линия «| —— текст —— |».
class DimLine extends StatelessWidget {
  const DimLine(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text('|', style: gMicro()),
      const SizedBox(width: 8),
      const Expanded(child: Divider(height: 1, color: kBar)),
      const SizedBox(width: 8),
      Flexible(
        flex: 8,
        child: Text(text, style: gMicro(), maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      const SizedBox(width: 8),
      const Expanded(child: Divider(height: 1, color: kBar)),
      const SizedBox(width: 8),
      Text('|', style: gMicro()),
    ],
  );
}

/// Штамп листа в углу: «ЛИСТ · …» и три ячейки.
class Stamp extends StatelessWidget {
  const Stamp({super.key, required this.sheet, required this.a, required this.b, required this.date, this.width = 280});
  final String sheet, a, b, date;
  final double width;
  @override
  Widget build(BuildContext context) {
    Widget cell(String t, {bool last = false}) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          border: last ? null : const Border(right: BorderSide(color: SpColors.line)),
        ),
        child: Text(t, style: gMicro(), maxLines: 1, overflow: TextOverflow.clip),
      ),
    );
    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SpColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: SpColors.line)),
            ),
            child: Text('ЛИСТ · $sheet', style: gMicro(c: SpColors.ink)),
          ),
          Row(children: [cell(date), cell(a), cell(b, last: true)]),
        ],
      ),
    );
  }
}

/// Строка ноды-источника: текст и моно-подпись справа.
class SrcRow extends StatelessWidget {
  const SrcRow(
    this.text,
    this.right, {
    super.key,
    this.rc = SpColors.muted,
    this.tc = SpColors.ink,
    this.strike = false,
    this.onTap,
  });
  final String text, right;
  final Color rc, tc;
  final bool strike;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      height: 28,
      padding: const EdgeInsets.fromLTRB(12, 0, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SpType.text(
                13,
                color: tc,
              ).copyWith(decoration: strike ? TextDecoration.lineThrough : null, decorationColor: tc),
            ),
          ),
          const SizedBox(width: 8),
          Text(right, style: gMono(11, c: rc)),
        ],
      ),
    ),
  );
}

/// Таблетка привычки: сделано — золотая заливка.
class HabitPill extends StatelessWidget {
  const HabitPill(this.text, {super.key, required this.done, this.color = SpColors.gold, this.onTap});
  final String text;
  final bool done;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: done ? color : Colors.transparent,
    shape: StadiumBorder(side: done ? BorderSide.none : BorderSide(color: Color.lerp(color, Colors.black, .4)!)),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (done) ...[const Icon(Icons.check, size: 14, color: kDark), const SizedBox(width: 4)],
            Text(
              text,
              style: SpType.text(12.5, color: done ? kDark : SpColors.ink, w: done ? FontWeight.w600 : FontWeight.w500),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Знак Спутника: орбита и «С».
class Logo extends StatelessWidget {
  const Logo({super.key});
  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size(20, 20), painter: _Logo());
}

class _Logo extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.scale(s.width / 24);
    final p = Paint()
      ..color = SpColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    c.save();
    c.translate(12, 12);
    c.rotate(-28 * 3.14159 / 180);
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: 20, height: 8), p);
    c.restore();
    final arc = Path()..addArc(Rect.fromCircle(center: const Offset(12, 12), radius: 5), -0.86, -4.56);
    c.drawPath(arc, p..strokeWidth = 1.5);
    c.drawRect(const Rect.fromLTWH(18, 6, 3, 3), Paint()..color = SpColors.accent);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Цвет сферы списка (точка, провод, шапка).
Color hueOf(String? cssOrId) {
  switch (cssOrId) {
    case 'blue':
      return SpColors.blue;
    case 'violet':
      return SpColors.violet;
    case 'green':
      return SpColors.green;
    case 'gold':
      return SpColors.gold;
    case 'red':
      return SpColors.red;
    case 'grey':
      return SpColors.grey;
    default:
      return SpColors.accent;
  }
}

/// Рамка-скобки: уголки по четырём углам (выбранная сфера, G_Spheres).
class Brackets extends StatelessWidget {
  const Brackets({super.key, required this.child, this.on = true, this.color = SpColors.accent});
  final Widget child;
  final bool on;
  final Color color;
  @override
  Widget build(BuildContext context) => on ? CustomPaint(foregroundPainter: _Brackets(color), child: child) : child;
}

class _Brackets extends CustomPainter {
  _Brackets(this.c);
  final Color c;
  @override
  void paint(Canvas canvas, Size s) {
    const l = 8.0;
    final p = Paint()
      ..color = c
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final w = s.width, h = s.height;
    for (final (x, y, dx, dy) in [(0.0, 0.0, 1, 1), (w, 0.0, -1, 1), (0.0, h, 1, -1), (w, h, -1, -1)]) {
      canvas.drawPath(
        Path()
          ..moveTo(x + dx * l, y)
          ..lineTo(x, y)
          ..lineTo(x, y + dy * l),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_Brackets o) => o.c != c;
}
