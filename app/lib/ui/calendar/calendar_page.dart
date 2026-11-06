// «Календарь»: сверху одна панель (период, ‹ ›, «Сегодня», фильтры, «Неделя | Месяц»), справа панель выбранного дня.
// Неделя — сутки 0–24 с сжатыми пустыми часами (core/calendar.dart hourLayout), блоки — layoutBlocks,
// строка «весь день», ряд точек привычек; задачи перетаскиваются на другой день и время (шаг 15 мин).
// Месяц — сетка 6×7, до 3 строк в клетке и «+ ещё N». Клавиши: ←/→ период, T сегодня, W неделя, M месяц.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keys.dart';

import '../../core/calendar.dart' as cal;
import '../../core/dates.dart';
import '../../core/habits.dart' as hb;
import '../../state/app_state.dart';
import '../create/create_dialog.dart';
import '../theme/tokens.dart';
import '../g/kit.dart';
import '../today/today_page.dart' show listHue;
import '../widgets/task_dialog.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.state});
  final AppState state;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  String mode = calStartMode;
  late String sel = ymd(DateTime.now());
  final show = <String>{'events', 'tasks', 'habits', 'bdays'};
  final _focus = FocusNode();

  AppState get s => widget.state;

  @override
  void dispose() {
    PageKeys.clear(this);
    _focus.dispose();
    super.dispose();
  }

  void _shift(int dir) {
    setState(() => sel = cal.shiftPeriod(sel, mode, dir));
    final days = cal.periodDays(sel, mode);
    s.ensureEvents(cal.parseYmd(days.first), cal.parseYmd(days.last));
  }

  /// Всё за дни периода: события, задачи, привычки-блоки — с фильтрами.
  Map<String, List<Json>> _items(List<String> days) {
    final out = {for (final d in days) d: <Json>[]};
    if (show.contains('events') || show.contains('bdays')) {
      final ev = cal.eventsByDay([
        for (final e in s.events)
          if (s.isBirthday(e) ? show.contains('bdays') : show.contains('events'))
            {...e, 'kind': s.isBirthday(e) ? 'birthday' : 'event'},
      ], days);
      ev.forEach((d, xs) => out[d]!.addAll(xs));
    }
    if (show.contains('tasks')) {
      final t = cal.tasksByDay(s.boardLists, s.tasks, s.layer['tasks'] as Map?, (l, id) {
        final ty = s.layTask(id)['type'];
        return ty is String ? ty : cal.typeOfTemplate(s.layList(l)['template'] as String?);
      }, days);
      t.forEach((d, xs) => out[d]!.addAll(xs));
    }
    if (show.contains('habits')) {
      for (final d in days) {
        out[d]!.addAll(cal.habitBlocks(s.habits, s.habitLog, d, s.todayYmd));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final days = cal.periodDays(sel, mode);
    final items = _items(days);
    PageKeys.set(this, {
      const PKey(PhysicalKeyboardKey.arrowLeft): () => _shift(-1),
      const PKey(PhysicalKeyboardKey.arrowRight): () => _shift(1),
      const PKey(PhysicalKeyboardKey.keyT): () => setState(() => sel = s.todayYmd),
      const PKey(PhysicalKeyboardKey.keyW): () => setState(() => mode = 'week'),
      const PKey(PhysicalKeyboardKey.keyM): () => setState(() => mode = 'month'),
      const PKey(PhysicalKeyboardKey.keyA): () => openCreate(context, s, day: sel),
    });
    return KeyedSubtree(
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        child: DotGround(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _bar(),
                const SizedBox(height: 16),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final side = box.maxWidth > 1000;
                      final main = mode == 'week' ? _week(days, items) : _month(days, items);
                      if (!side) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 3, child: main),
                            const SizedBox(height: 12),
                            Expanded(flex: 2, child: _dayPanel(sel, items[sel] ?? _items([sel])[sel]!)),
                          ],
                        );
                      }
                      return WireBoard(
                        wires: const [Wire('cal:hub', 'cal:day', SpColors.accent, width: 2)],
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: main),
                            const SizedBox(width: 24),
                            SizedBox(width: 324, child: _dayPanel(sel, items[sel] ?? _items([sel])[sel]!)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _overview(days, items),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _overview(List<String> days, Map<String, List<Json>> items) {
    var busy = 0;
    var dues = 0;
    for (final d in days) {
      for (final i in items[d]!) {
        if (i['s'] != null && i['e'] != null && i['kind'] != 'habit') {
          busy += ((i['e'] as num) - (i['s'] as num)).toInt();
        }
        if (i['kind'] == 'task' && i['s'] == null) dues++;
      }
    }
    if (mode == 'month') {
      return Wrap(
        spacing: 0,
        runSpacing: 4,
        children: [
          Text('ПОЛОСКА ВНИЗУ КЛЕТКИ', style: gMicro()),
          const SizedBox(width: 14),
          Text('ЗОЛОТО — ПРИВЫЧКИ СДЕЛАНЫ', style: gMicro(c: SpColors.gold)),
          const SizedBox(width: 14),
          Text('ПУНКТИР — ЕЩЁ ВПЕРЕДИ', style: gMicro()),
        ],
      );
    }
    return Row(
      children: [
        Text(mode == 'week' ? 'ОБЗОР НЕДЕЛИ' : 'ОБЗОР МЕСЯЦА', style: gLbl(c: SpColors.ink)),
        const SizedBox(width: 16),
        Text('ЗАГРУЗКА ${(busy / 60).round()} Ч', style: gMicro()),
        const SizedBox(width: 16),
        Text('СРОКИ $dues', style: gMicro()),
        const SizedBox(width: 16),
        Expanded(child: DimLine('${days.length} ДНЕЙ · ЧАСЫ БЕЗ ДЕЛ СЖАТЫ')),
      ],
    );
  }

  static const _monthUp = [
    'ЯНВАРЬ',
    'ФЕВРАЛЬ',
    'МАРТ',
    'АПРЕЛЬ',
    'МАЙ',
    'ИЮНЬ',
    'ИЮЛЬ',
    'АВГУСТ',
    'СЕНТЯБРЬ',
    'ОКТЯБРЬ',
    'НОЯБРЬ',
    'ДЕКАБРЬ',
  ];

  int _weekNo(DateTime d) {
    final th = d.add(Duration(days: 3 - (d.weekday + 6) % 7));
    final jan = DateTime(th.year, 1, 4);
    return 1 + th.difference(jan.add(Duration(days: -((jan.weekday + 6) % 7)))).inDays ~/ 7 - 0;
  }

  Widget _sq(String t, VoidCallback on) => InkWell(
    onTap: on,
    borderRadius: BorderRadius.circular(6),
    child: Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SpColors.lineStrong),
      ),
      child: Text(t, style: gMono(12, c: SpColors.ink)),
    ),
  );

  Widget _bar() {
    final d = cal.parseYmd(sel);
    return GNode(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
        child: Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('${_monthUp[d.month - 1]} ${d.year}', style: gLbl(c: SpColors.ink, size: 11)),
                  if (mode == 'week') Text('НЕДЕЛЯ ${_weekNo(d)}', style: gLbl(c: SpColors.dim, size: 10.5)),
                  const SizedBox(width: 4),
                  _sq('‹', () => _shift(-1)),
                  _sq('›', () => _shift(1)),
                  GBtn('Сегодня', sm: true, onTap: () => setState(() => sel = s.todayYmd)),
                  Container(
                    width: 1,
                    height: 20,
                    color: SpColors.line,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  for (final (id, name, c) in [
                    ('events', 'События', SpColors.grey),
                    ('tasks', 'Задачи', SpColors.accent),
                    ('habits', 'Привычки', SpColors.gold),
                    ('bdays', 'Дни рождения', SpColors.violet),
                  ])
                    GChip(
                      name,
                      on: show.contains(id),
                      dot: c,
                      color: c == SpColors.grey ? SpColors.lineStrong : c,
                      onTap: () => setState(() => show.contains(id) ? show.remove(id) : show.add(id)),
                    ),
                ],
              ),
            ),
            GSeg(
              items: const ['Неделя', 'Месяц'],
              active: mode == 'week' ? 0 : 1,
              onTap: (i) {
                setState(() => mode = i == 0 ? 'week' : 'month');
                _shift(0);
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _colorOf(Json i) => switch (i['kind']) {
    'event' => SpColors.grey,
    'birthday' => SpColors.violet,
    'habit' => SpColors.gold,
    _ => i['listId'] is String ? listHue(s, i['listId'] as String) : SpColors.accent,
  };

  // ---------- неделя ----------

  Widget _week(List<String> days, Map<String, List<Json>> items) {
    final timed = [for (final d in days) ...items[d]!.where((i) => i['s'] != null)];
    final lay = cal.hourLayout(timed.cast<Json>());
    const axis = 64.0;
    var busy = 0;
    for (final i in timed) {
      if (i['e'] != null && i['kind'] != 'habit') busy += ((i['e'] as num) - (i['s'] as num)).toInt();
    }
    final a = cal.parseYmd(days.first), b = cal.parseYmd(days.last);
    const gen = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    final range = a.month == b.month
        ? '${a.day.toString().padLeft(2, '0')}–${b.day.toString().padLeft(2, '0')} ${gen[b.month - 1]}'
        : '${a.day} ${gen[a.month - 1]} – ${b.day} ${gen[b.month - 1]}';
    return GNode(
      hub: true,
      child: Column(
        children: [
          SockRow(
            right: const Sock('cal:hub', SpColors.accent),
            child: GHead(hub: true, name: 'Неделя · $range', kind: 'занято ${(busy / 60).round()} ч'),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: axis,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 44),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ПРИВЫЧКИ', style: gMicro(), maxLines: 1, overflow: TextOverflow.clip),
                      const SizedBox(height: 14),
                      Text('ДЕНЬ', style: gMicro()),
                    ],
                  ),
                ),
              ),
              for (final d in days) Expanded(child: _dayHead(d, items[d]!)),
            ],
          ),
          const Divider(height: 1, color: SpColors.line),
          Expanded(
            child: SingleChildScrollView(
              child: SizedBox(
                height: lay.height.toDouble() + 8,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: axis,
                      child: Stack(
                        children: [
                          for (final l in lay.labels)
                            Positioned(
                              top: (l['top'] as num).toDouble() + 2,
                              left: 8,
                              child: Text(
                                l['text'] as String,
                                style: gMono(l['small'] == true ? 9 : 10, c: SpColors.dim),
                              ),
                            ),
                        ],
                      ),
                    ),
                    for (final d in days) Expanded(child: _dayCol(d, items[d]!, lay)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayHead(String d, List<Json> its) {
    final lab = cal.dayLabel(d);
    final today = d == s.todayYmd;
    final allDay = its.where((i) => i['s'] == null && i['kind'] != 'habit').toList()
      ..sort((a, b) => (a['done'] == true ? 1 : 0) - (b['done'] == true ? 1 : 0));
    final hab = s.habits
        .map((h) => (h, cal.habitDay(h, s.habitLog, d, s.todayYmd)))
        .where((x) => x.$2['sched'] == true)
        .toList();
    final done = hab.where((x) => x.$2['done'] == true).length;
    return DragTarget<(String, Json)>(
      onAcceptWithDetails: (det) => s.schedule(det.data.$1, det.data.$2, d, null),
      builder: (context, cand, _) => InkWell(
        onTap: () => setState(() => sel = d),
        child: Container(
          constraints: const BoxConstraints(minHeight: 92),
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
          decoration: BoxDecoration(
            color: cand.isNotEmpty
                ? SpColors.accentWash
                : (today ? const Color(0xFF2A2A2E) : (sel == d ? SpColors.nodeHover : null)),
            border: const Border(left: BorderSide(color: SpColors.lineSoft)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text.rich(
                TextSpan(
                  text: '${(lab['short'] as String).toUpperCase()} ${lab['n'].toString().padLeft(2, '0')}',
                  children: [if (today) const TextSpan(text: ' СЕГОДНЯ')],
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: gLbl(c: today ? SpColors.accent : SpColors.muted, size: 10),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 14,
                child: hab.isEmpty
                    ? null
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final x in hab.take(5)) ...[
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                color: x.$2['done'] == true ? SpColors.gold : Colors.transparent,
                                border: Border.all(
                                  color: x.$2['done'] == true
                                      ? SpColors.gold
                                      : (x.$2['isToday'] == true ? SpColors.accent : SpColors.lineStrong),
                                ),
                              ),
                            ),
                            const SizedBox(width: 3),
                          ],
                          const SizedBox(width: 4),
                          Text('$done/${hab.length}', style: gMicro()),
                        ],
                      ),
              ),
              const SizedBox(height: 4),
              for (final i in allDay.take(3)) _allDayRow(i),
              if (allDay.length > 3)
                InkWell(
                  onTap: () => setState(() => sel = d),
                  child: Text('+ ЕЩЁ ${allDay.length - 3}', style: gMicro(c: SpColors.muted)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _allDayRow(Json i) {
    final c = _colorOf(i);
    final w = Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: SpColors.node,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: SpColors.line),
      ),
      child: Row(
        children: [
          GDot(c),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${i['kind'] == 'birthday' ? '★ ' : ''}${i['title']}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SpType.text(
                11.5,
                color: i['done'] == true ? SpColors.dim : SpColors.ink,
              ).copyWith(decoration: i['done'] == true ? TextDecoration.lineThrough : null),
            ),
          ),
        ],
      ),
    );
    if (i['kind'] != 'task') return w;
    return _taskDrag(i, InkWell(onTap: () => openTask(context, s, i['listId'] as String, i['task'] as Json), child: w));
  }

  Widget _taskDrag(Json i, Widget child) {
    if (i['done'] == true) return child;
    return Draggable<(String, Json)>(
      data: (i['listId'] as String, i['task'] as Json),
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(6),
          color: SpColors.accentWash,
          child: Text(i['title'] as String, style: SpType.text(12)),
        ),
      ),
      child: child,
    );
  }

  /// Минута по высоте на экране (обратное к yAt), с шагом 15.
  int _minAt(cal.HourLayout lay, double y) {
    for (var h = 0; h < 24; h++) {
      final top = lay.y[h], ht = lay.ht[h];
      if (y < top + ht || h == 23) {
        final m = h * 60 + (ht == 0 ? 0 : ((y - top) / ht * 60)).clamp(0, 59).toInt();
        return (m ~/ 15) * 15;
      }
    }
    return 0;
  }

  Widget _dayCol(String d, List<Json> its, cal.HourLayout lay) {
    final blocks = cal.layoutBlocks(its.where((i) => i['s'] != null).toList(), (m) => lay.yAt(m));
    final now = DateTime.now();
    final isToday = d == s.todayYmd;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        return DragTarget<(String, Json)>(
          onAcceptWithDetails: (det) {
            final rb = context.findRenderObject() as RenderBox;
            final y = rb.globalToLocal(det.offset).dy;
            final st = _minAt(lay, y);
            final L = s.layTask(det.data.$2['id'] as String)['slot'] as Map?;
            final len = L?['s'] != null && L?['e'] != null
                ? cal.toMin(L!['e'] as String) - cal.toMin(L['s'] as String)
                : 60;
            final e = (st + len).clamp(0, 1439);
            s.schedule(det.data.$1, det.data.$2, d, {'s': cal.fromMin(st), 'e': cal.fromMin(e)});
          },
          builder: (context, cand, _) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (det) {
              setState(() => sel = d);
              final m = _minAt(lay, det.localPosition.dy);
              final hh = cal.fromMin((m ~/ 60) * 60);
              openCreate(context, s, kind: 'event', day: d, time: hh);
            },
            child: Container(
              decoration: BoxDecoration(
                color: cand.isNotEmpty ? SpColors.accentWash : null,
                border: const Border(left: BorderSide(color: SpColors.lineSoft)),
              ),
              child: Stack(
                children: [
                  for (final l in lay.lines)
                    Positioned(
                      top: l.toDouble(),
                      left: 0,
                      right: 0,
                      child: Container(height: 1, color: SpColors.lineSoft),
                    ),
                  for (final b in lay.bands)
                    if ((b['h'] as num) > 0)
                      Positioned(
                        top: (b['top'] as num).toDouble(),
                        left: 0,
                        right: 0,
                        height: (b['h'] as num).toDouble(),
                        child: CustomPaint(painter: _BandHatch()),
                      ),
                  for (final b in blocks) _block(b, w),
                  if (isToday)
                    Positioned(
                      top: lay.yAt(now.hour * 60 + now.minute).toDouble(),
                      left: 0,
                      right: 0,
                      child: Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(color: SpColors.accent, borderRadius: BorderRadius.circular(2)),
                          ),
                          Expanded(child: Container(height: 1.5, color: SpColors.accent)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _block(Json b, double w) {
    final cols = (b['cols'] as int?) ?? 1;
    final col = (b['col'] as int?) ?? 0;
    final c = _colorOf(b);
    final habit = b['kind'] == 'habit';
    final task = b['kind'] == 'task';
    final done = b['done'] == true;
    final h = (b['height'] as num).toDouble();
    final time = cal.fromMin((b['a'] as num).toInt());
    final head = Row(
      children: [
        if (task || (habit && b['isToday'] == true))
          InkWell(
            onTap: () {
              if (habit) {
                s.toggleHabit(b['h'] as Json);
              } else {
                s.toggleDone(b['listId'] as String, b['task'] as Json);
              }
            },
            child: Container(
              width: 9,
              height: 9,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? c : null,
                border: Border.all(color: c, width: 1.3),
              ),
            ),
          ),
        Flexible(
          child: Text(time, style: gMono(10, c: done ? SpColors.dim : c.withValues(alpha: .95)), maxLines: 1),
        ),
      ],
    );
    Widget box = Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 3),
      decoration: BoxDecoration(
        color: habit ? c.withValues(alpha: done ? .18 : .06) : (task ? const Color(0xFF2B2622) : SpColors.nodeHover),
        borderRadius: BorderRadius.circular(5),
        border: habit ? null : Border.all(color: task ? Color.lerp(c, SpColors.node, .45)! : SpColors.line),
      ),
      child: ClipRect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (h >= 30 || task) head,
            if (h >= 22)
              Flexible(
                child: Text(
                  b['title'] as String,
                  maxLines: ((h - 16) / 14).floor().clamp(1, 6),
                  overflow: TextOverflow.ellipsis,
                  style: SpType.text(
                    11.5,
                    color: done ? SpColors.dim : SpColors.ink,
                  ).copyWith(decoration: done ? TextDecoration.lineThrough : null, decorationColor: SpColors.dim),
                ),
              ),
          ],
        ),
      ),
    );
    if (habit) {
      box = Dashed(
        r: 5,
        color: c.withValues(alpha: done ? .9 : .6),
        child: box,
      );
    }
    Widget child = box;
    if (task) {
      child = _taskDrag(
        b,
        InkWell(onTap: () => openTask(context, s, b['listId'] as String, b['task'] as Json), child: box),
      );
    } else if (b['kind'] == 'event' || b['kind'] == 'birthday') {
      child = Tooltip(message: _evTip(b['event'] as Json), child: box);
    }
    return Positioned(
      top: (b['top'] as num).toDouble() + 1,
      height: h - 2,
      left: w / cols * col + 3,
      width: w / cols - 6,
      child: child,
    );
  }

  String _evTip(Json e) => [e['summary'] ?? '', if ((e['location'] ?? '') != '') e['location']].join('\n');

  // ---------- месяц ----------

  Widget _month(List<String> days, Map<String, List<Json>> items) {
    final sd = cal.parseYmd(sel);
    final m = sd.month;
    final inMonth = days.where((d) => cal.parseYmd(d).month == m);
    var n = 0;
    for (final d in inMonth) {
      n += items[d]!.where((i) => i['kind'] == 'task').length;
    }
    return GNode(
      hub: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SockRow(
            right: const Sock('cal:hub', SpColors.accent),
            child: GHead(hub: true, name: '${_monthUp[m - 1]} ${sd.year}', kind: '${inMonth.length} дней · $n дел'),
          ),
          Container(
            height: 24,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: SpColors.line)),
            ),
            child: Row(
              children: [
                for (final w in cal.wdShort)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Text(w.toUpperCase(), style: gMicro()),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                for (var r = 0; r < 6; r++)
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var c = 0; c < 7; c++)
                          Expanded(child: _cell(days[r * 7 + c], items[days[r * 7 + c]]!, m, c == 6, r == 5)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(String d, List<Json> its, int month, bool lastCol, bool lastRow) {
    final p = cal.parseYmd(d);
    final today = d == s.todayYmd;
    final other = p.month != month;
    final list = its.where((i) => i['kind'] != 'habit').toList()
      ..sort((a, b) => ((a['s'] ?? -1) as num).compareTo((b['s'] ?? -1) as num));
    final hab = s.habits
        .map((h) => cal.habitDay(h, s.habitLog, d, s.todayYmd))
        .where((x) => x['sched'] == true)
        .toList();
    String hm(num v) => '${(v ~/ 60).toString().padLeft(2, '0')}:${(v % 60).toInt().toString().padLeft(2, '0')}';
    Widget body = Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      decoration: BoxDecoration(
        border: today
            ? Border.all(color: SpColors.accent, width: 1.2)
            : Border(
                right: lastCol ? BorderSide.none : const BorderSide(color: SpColors.lineSoft),
                bottom: lastRow ? BorderSide.none : const BorderSide(color: SpColors.lineSoft),
              ),
        borderRadius: today ? BorderRadius.circular(6) : null,
        color: sel == d && !today ? SpColors.accentWash : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                p.day.toString().padLeft(2, '0'),
                style: gMono(
                  11,
                  c: today ? SpColors.accent : (other ? SpColors.dim : SpColors.ink),
                  w: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (today)
                Flexible(
                  child: Text(
                    'СЕГОДНЯ',
                    style: gMicro(c: SpColors.accent),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (!other)
            Expanded(
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  maxHeight: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final i in list.take(3))
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              GDot(_colorOf(i)),
                              const SizedBox(width: 6),
                              if (i['s'] != null) ...[
                                Text(hm(i['s'] as num), style: gMono(9.5, c: SpColors.dim)),
                                const SizedBox(width: 5),
                              ],
                              Expanded(
                                child: Text(
                                  '${i['kind'] == 'birthday' ? '★ ' : ''}${i['title']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  softWrap: false,
                                  style: SpType.text(
                                    11,
                                    color: i['done'] == true ? SpColors.dim : SpColors.ink,
                                  ).copyWith(decoration: i['done'] == true ? TextDecoration.lineThrough : null),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (list.length > 3) Text('+ ещё ${list.length - 3}', style: gMicro()),
                    ],
                  ),
                ),
              ),
            )
          else
            const Spacer(),
          if (!other)
            SizedBox(
              height: 3,
              child: hab.isEmpty
                  ? CustomPaint(painter: _DashLine())
                  : Row(
                      children: [
                        for (final (k, h) in hab.indexed) ...[
                          if (k > 0) const SizedBox(width: 4),
                          Expanded(
                            child: h['done'] == true
                                ? Container(
                                    decoration: BoxDecoration(
                                      color: SpColors.gold,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      color: SpColors.lineSoft,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                          ),
                        ],
                      ],
                    ),
            ),
        ],
      ),
    );
    if (today) body = CustomPaint(painter: _TodayHatch(), child: body);
    final full = body;
    body = LayoutBuilder(
      builder: (context, box) => box.maxHeight < 70 || box.maxWidth < 70
          ? Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                border: today
                    ? Border.all(color: SpColors.accent)
                    : const Border(
                        right: BorderSide(color: SpColors.lineSoft),
                        bottom: BorderSide(color: SpColors.lineSoft),
                      ),
              ),
              child: ClipRect(
                child: Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      p.day.toString().padLeft(2, '0'),
                      style: gMono(10, c: today ? SpColors.accent : (other ? SpColors.dim : SpColors.ink)),
                    ),
                    if (list.isNotEmpty && !other) GDot(_colorOf(list.first)),
                  ],
                ),
              ),
            )
          : full,
    );
    return DragTarget<(String, Json)>(
      onAcceptWithDetails: (det) {
        final slot = s.layTask(det.data.$2['id'] as String)['slot'] as Json?;
        s.schedule(det.data.$1, det.data.$2, d, slot);
      },
      builder: (context, cand, _) => InkWell(
        onTap: () => setState(() => sel = d),
        child: Container(color: cand.isNotEmpty ? SpColors.accentWash : null, child: body),
      ),
    );
  }

  // ---------- панель дня ----------

  Widget _dayPanel(String d, List<Json> its) {
    final lab = cal.dayLabel(d);
    final today = d == s.todayYmd;
    final timed = its.where((i) => i['kind'] != 'habit').toList()
      ..sort((a, b) => ((a['s'] ?? 9999) as num).compareTo((b['s'] ?? 9999) as num));
    final habs = s.habits.where((h) => cal.habitDay(h, s.habitLog, d, s.todayYmd)['sched'] == true).toList();
    final hdone = habs.where((h) => hb.isDone(s.habitLog, h['id'], d)).length;
    final now = DateTime.now().hour * 60 + DateTime.now().minute;
    Json? cur;
    if (today) {
      for (final i in timed) {
        if (i['kind'] == 'task' &&
            i['done'] != true &&
            i['s'] != null &&
            (i['e'] ?? (i['s'] as num) + 60) as num > now) {
          cur = i;
          break;
        }
      }
    }
    final dd = cal.parseYmd(d);
    return GNode(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SockRow(
            left: const Sock('cal:day', SpColors.accent),
            child: GHead(
              name:
                  '${(lab['short'] as String).toUpperCase()} ${dd.day.toString().padLeft(2, '0')} · ${today ? 'сегодня' : lab['title']}',
              kind: '${timed.length} дел',
              color: today ? SpColors.accent : SpColors.grey,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (timed.isEmpty && habs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        const GCoon('sleep', size: 56),
                        const SizedBox(height: 8),
                        Text('СВОБОДНЫЙ ДЕНЬ', style: gMicro()),
                      ],
                    ),
                  ),
                for (final i in timed) _panelRow(i, i == cur),
                if (habs.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.only(top: 10, bottom: 4),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFF8A7424))),
                    ),
                    child: Text('ПРИВЫЧКИ · $hdone / ${habs.length}', style: gLbl(c: SpColors.gold, size: 10)),
                  ),
                  for (final h in habs)
                    InkWell(
                      onTap: today ? () => s.toggleHabit(h) : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            if (hb.isDone(s.habitLog, h['id'], d))
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.check, size: 14, color: SpColors.ink),
                              ),
                            Expanded(child: Text(h['name'] as String, style: SpType.text(13))),
                            Text(
                              '${hb.stats(h, s.habitLog)['streak']} ДН',
                              style: gMono(10.5, c: hb.isDone(s.habitLog, h['id'], d) ? SpColors.gold : SpColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => openCreate(context, s, day: d),
                  child: Dashed(
                    child: Container(
                      height: 32,
                      alignment: Alignment.center,
                      child: Text('+ Добавить на этот день', style: SpType.text(13, w: FontWeight.w500)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_free(timed) case final (int, int) w)
                  CoonTip(
                    pose: 'think',
                    color: SpColors.accentLine,
                    text: 'Свободно ${cal.fromMin(w.$1)}–${cal.fromMin(w.$2)}.',
                    action: 'Добавить туда',
                    onAction: () => openCreate(context, s, day: d, time: cal.fromMin(w.$1)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Самое длинное окно 09–21 без дел (с текущего часа для сегодня), час и больше.
  (int, int)? _free(List<Json> timed) {
    final busy = [
      for (final i in timed)
        if (i['s'] != null) ((i['s'] as num).toInt(), ((i['e'] ?? (i['s'] as num) + 60) as num).toInt()),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    var from = 9 * 60;
    if (sel == s.todayYmd) {
      final n = DateTime.now();
      from = ((n.hour + 1) * 60).clamp(9 * 60, 21 * 60);
    }
    (int, int)? best;
    var at = from;
    for (final (a, b) in [...busy, (21 * 60, 21 * 60)]) {
      if (a > at && (best == null || a - at > best.$2 - best.$1)) best = (at, a.clamp(at, 21 * 60));
      if (b > at) at = b;
    }
    return best != null && best.$2 - best.$1 >= 60 ? best : null;
  }

  Widget _panelRow(Json i, bool cur) {
    final task = i['kind'] == 'task';
    final done = i['done'] == true;
    final row = Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: cur
          ? BoxDecoration(
              color: SpColors.accentWash,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: SpColors.accent),
            )
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: SpColors.lineSoft)),
            ),
      child: Row(
        children: [
          if (task)
            GCheck(
              done: done,
              color: SpColors.muted,
              onTap: () => s.toggleDone(i['listId'] as String, i['task'] as Json),
            )
          else
            const SizedBox(width: 14),
          const SizedBox(width: 10),
          SizedBox(
            width: 42,
            child: Text(
              i['s'] == null ? 'ДЕНЬ' : cal.fromMin((i['s'] as num).toInt()),
              style: gMono(11.5, c: cur ? SpColors.accentInk : (done ? SpColors.dim : SpColors.muted)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${i['kind'] == 'birthday' ? '★ ' : ''}${i['title']}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SpType.text(
                13,
                color: done ? SpColors.dim : SpColors.ink,
              ).copyWith(decoration: done ? TextDecoration.lineThrough : null, decorationColor: SpColors.dim),
            ),
          ),
          GDot(_colorOf(i)),
        ],
      ),
    );
    if (!task) return Tooltip(message: _evTip(i['event'] as Json? ?? {}), child: row);
    return InkWell(onTap: () => openTask(context, s, i['listId'] as String, i['task'] as Json), child: row);
  }
}

/// С какого вида открывается календарь (для снимков и проверок).
String calStartMode = 'week';

class _DashLine extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = SpColors.line
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 5) {
      canvas.drawLine(Offset(x, size.height / 2), Offset(x + 2, size.height / 2), p);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _TodayHatch extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = SpColors.accent.withValues(alpha: .07)
      ..strokeWidth = 1;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var x = -size.height; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_) => false;
}

class _BandHatch extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF222327));
    final p = Paint()
      ..color = const Color(0xFF2E2F35)
      ..strokeWidth = 1;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var x = 0.0; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
