// «Календарь»: сверху одна панель (период, ‹ ›, «Сегодня», фильтры, «Неделя | Месяц»), справа панель выбранного дня.
// Неделя — сутки 0–24 с сжатыми пустыми часами (core/calendar.dart hourLayout), блоки — layoutBlocks,
// строка «весь день», ряд точек привычек; задачи перетаскиваются на другой день и время (шаг 15 мин).
// Месяц — сетка 6×7, до 3 строк в клетке и «+ ещё N». Клавиши: ←/→ период, T сегодня, W неделя, M месяц.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/calendar.dart' as cal;
import '../../core/dates.dart';
import '../../core/habits.dart' as hb;
import '../../state/app_state.dart';
import '../create/create_dialog.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/task_dialog.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.state});
  final AppState state;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  String mode = 'week';
  late String sel = ymd(DateTime.now());
  final show = <String>{'events', 'tasks', 'habits', 'bdays'};
  final _focus = FocusNode();

  AppState get s => widget.state;

  @override
  void dispose() {
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
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _shift(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _shift(1),
        const SingleActivator(LogicalKeyboardKey.keyT): () => setState(() => sel = s.todayYmd),
        const SingleActivator(LogicalKeyboardKey.keyW): () => setState(() => mode = 'week'),
        const SingleActivator(LogicalKeyboardKey.keyM): () => setState(() => mode = 'month'),
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        child: DotGround(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _bar(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final side = box.maxWidth > 1000;
                    final main = mode == 'week' ? _week(days, items) : _month(days, items);
                    if (!side) return main;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: main),
                        SizedBox(width: 320, child: _dayPanel(sel, items[sel] ?? _items([sel])[sel]!)),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(cal.periodTitle(sel, mode), style: SpType.text(20, w: FontWeight.w600)),
        IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
        TextButton(onPressed: () => setState(() => sel = s.todayYmd), child: const Text('Сегодня')),
        IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
        const SizedBox(width: 12),
        for (final (id, name) in [
          ('events', 'События'),
          ('tasks', 'Задачи'),
          ('habits', 'Привычки'),
          ('bdays', 'Дни рождения'),
        ])
          FilterChip(
            label: Text(name),
            selected: show.contains(id),
            onSelected: (on) => setState(() => on ? show.add(id) : show.remove(id)),
          ),
        const SizedBox(width: 12),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'week', label: Text('Неделя')),
            ButtonSegment(value: 'month', label: Text('Месяц')),
          ],
          selected: {mode},
          onSelectionChanged: (v) {
            setState(() => mode = v.first);
            _shift(0);
          },
        ),
      ],
    ),
  );

  Color _colorOf(Json i) => switch (i['kind']) {
    'event' => SpColors.grey,
    'birthday' => SpColors.violet,
    'habit' => SpColors.gold,
    _ => switch (i['type']) {
      'creative' => SpColors.accent,
      'personal' => SpColors.green,
      'study' => SpColors.violet,
      _ => SpColors.blue,
    },
  };

  // ---------- неделя ----------

  Widget _week(List<String> days, Map<String, List<Json>> items) {
    final timed = [for (final d in days) ...items[d]!.where((i) => i['s'] != null)];
    final lay = cal.hourLayout(timed.cast<Json>());
    const axis = 52.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
      child: Column(
        children: [
          // шапки дней + «весь день» + точки привычек
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: axis),
              for (final d in days) Expanded(child: _dayHead(d, items[d]!)),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: SpColors.node,
                borderRadius: BorderRadius.circular(SpRadius.node),
                border: Border.all(color: SpColors.line),
              ),
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
                                top: (l['top'] as num).toDouble(),
                                left: 8,
                                child: Text(
                                  l['text'] as String,
                                  style: SpType.label(l['small'] == true ? 9 : 10.5, color: SpColors.dim),
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
        .where((x) => x.$2['sched'] == true);
    final done = hab.where((x) => x.$2['done'] == true).length;
    return DragTarget<(String, Json)>(
      onAcceptWithDetails: (det) => s.schedule(det.data.$1, det.data.$2, d, null),
      builder: (context, cand, _) => InkWell(
        onTap: () => setState(() => sel = d),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: cand.isNotEmpty ? SpColors.accentWash : (sel == d ? SpColors.nodeHover : Colors.transparent),
            borderRadius: BorderRadius.circular(SpRadius.button),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text((lab['short'] as String).toUpperCase(), style: SpType.label(10.5)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: today ? SpColors.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(SpRadius.socket),
                    ),
                    child: Text(
                      '${lab['n']}',
                      style: SpType.text(15, w: FontWeight.w600, color: today ? SpColors.onAccent : SpColors.ink),
                    ),
                  ),
                  if (hab.isNotEmpty) Text('$done/${hab.length}', style: SpType.label(9.5, color: SpColors.gold)),
                ],
              ),
              if (hab.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    spacing: 3,
                    children: [
                      for (final x in hab)
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: x.$2['done'] == true ? SpColors.gold : Colors.transparent,
                            border: Border.all(
                              color: x.$2['done'] == true
                                  ? SpColors.gold
                                  : (x.$2['isToday'] == true ? SpColors.accent : SpColors.lineStrong),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              for (final i in allDay.take(3)) _allDayRow(i),
              if (allDay.length > 3)
                InkWell(
                  onTap: () => setState(() => sel = d),
                  child: Text('+ ещё ${allDay.length - 3}', style: SpType.label(10, color: SpColors.muted)),
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
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(SpRadius.socket),
        border: Border(left: BorderSide(color: c, width: 2)),
      ),
      child: Text(
        '${i['kind'] == 'birthday' ? '' : ''}${i['title']}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: SpType.text(
          11.5,
          color: i['done'] == true ? SpColors.dim : SpColors.ink,
        ).copyWith(decoration: i['done'] == true ? TextDecoration.lineThrough : null),
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
                        child: Container(color: SpColors.bg.withValues(alpha: .6)),
                      ),
                  for (final b in blocks) _block(b, w),
                  if (isToday)
                    Positioned(
                      top: lay.yAt(now.hour * 60 + now.minute).toDouble(),
                      left: 0,
                      right: 0,
                      child: Container(height: 2, color: SpColors.accent),
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
    final done = b['done'] == true;
    final box = Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: habit ? c.withValues(alpha: done ? .3 : .12) : c.withValues(alpha: b['kind'] == 'event' ? .22 : .28),
        borderRadius: BorderRadius.circular(SpRadius.socket),
        border: Border(left: BorderSide(color: c, width: 2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (b['kind'] == 'task' || (habit && b['isToday'] == true))
            Padding(
              padding: const EdgeInsets.only(right: 4, top: 1),
              child: Check(
                done: done,
                onTap: () {
                  if (habit) {
                    s.toggleHabit(b['h'] as Json);
                  } else {
                    s.toggleDone(b['listId'] as String, b['task'] as Json);
                  }
                },
              ),
            ),
          Expanded(
            child: Text(
              '${cal.fromMin((b['a'] as num).toInt())} ${b['title']}',
              maxLines: ((b['height'] as num) / 14).floor().clamp(1, 6),
              overflow: TextOverflow.ellipsis,
              style: SpType.text(11, color: done ? SpColors.dim : SpColors.ink),
            ),
          ),
        ],
      ),
    );
    Widget child = box;
    if (b['kind'] == 'task') {
      child = _taskDrag(
        b,
        InkWell(onTap: () => openTask(context, s, b['listId'] as String, b['task'] as Json), child: box),
      );
    } else if (b['kind'] == 'event' || b['kind'] == 'birthday') {
      child = Tooltip(message: _evTip(b['event'] as Json), child: box);
    }
    return Positioned(
      top: (b['top'] as num).toDouble(),
      height: (b['height'] as num).toDouble(),
      left: w / cols * col + 1,
      width: w / cols - 2,
      child: child,
    );
  }

  String _evTip(Json e) => [e['summary'] ?? '', if ((e['location'] ?? '') != '') e['location']].join('\n');

  // ---------- месяц ----------

  Widget _month(List<String> days, Map<String, List<Json>> items) {
    final m = cal.parseYmd(sel).month;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              for (final w in cal.wdShort)
                Expanded(
                  child: Center(child: Text(w.toUpperCase(), style: SpType.label(10.5))),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Column(
              children: [
                for (var r = 0; r < 6; r++)
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var c = 0; c < 7; c++) Expanded(child: _cell(days[r * 7 + c], items[days[r * 7 + c]]!, m)),
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

  Widget _cell(String d, List<Json> its, int month) {
    final p = cal.parseYmd(d);
    final today = d == s.todayYmd;
    final list = its.where((i) => i['kind'] != 'habit').toList()
      ..sort((a, b) => ((a['s'] ?? -1) as num).compareTo((b['s'] ?? -1) as num));
    final hab = s.habits.map((h) => cal.habitDay(h, s.habitLog, d, s.todayYmd)).where((x) => x['sched'] == true);
    final hd = hab.where((x) => x['done'] == true).length;
    return DragTarget<(String, Json)>(
      onAcceptWithDetails: (det) {
        final slot = s.layTask(det.data.$2['id'] as String)['slot'] as Json?;
        s.schedule(det.data.$1, det.data.$2, d, slot);
      },
      builder: (context, cand, _) => InkWell(
        onTap: () => setState(() => sel = d),
        child: Container(
          margin: const EdgeInsets.all(1.5),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: cand.isNotEmpty ? SpColors.accentWash : SpColors.node,
            borderRadius: BorderRadius.circular(SpRadius.socket),
            border: Border.all(color: sel == d ? SpColors.accentLine : SpColors.lineSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${p.day}',
                style: SpType.text(
                  12.5,
                  w: today ? FontWeight.w700 : FontWeight.w400,
                  color: today ? SpColors.accent : (p.month == month ? SpColors.ink : SpColors.dim),
                ),
              ),
              Expanded(
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    maxHeight: double.infinity,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final i in list.take(3)) _allDayRow(i),
                        if (list.length > 3) Text('+ ещё ${list.length - 3}', style: SpType.label(9.5)),
                      ],
                    ),
                  ),
                ),
              ),
              if (hab.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: hd / hab.length,
                    minHeight: 3,
                    color: SpColors.gold,
                    backgroundColor: SpColors.lineSoft,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- панель дня ----------

  Widget _dayPanel(String d, List<Json> its) {
    final lab = cal.dayLabel(d);
    final timed = its.where((i) => i['kind'] != 'habit').toList()
      ..sort((a, b) => ((a['s'] ?? -1) as num).compareTo((b['s'] ?? -1) as num));
    final habs = s.habits.where((h) => cal.habitDay(h, s.habitLog, d, s.todayYmd)['sched'] == true).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 20, 12),
      child: Node(
        title: '${lab['weekday']}, ${lab['title']}',
        head: d == s.todayYmd ? SpColors.headMain : SpColors.headGrey,
        child: Expanded(
          child: ListView(
            padding: const EdgeInsets.all(10),
            children: [
              if (timed.isEmpty && habs.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Свободный день', style: SpType.text(13, color: SpColors.muted)),
                ),
              for (final i in timed)
                InkWell(
                  onTap: i['kind'] == 'task'
                      ? () => openTask(context, s, i['listId'] as String, i['task'] as Json)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 46,
                          child: Text(
                            i['s'] == null ? 'день' : cal.fromMin((i['s'] as num).toInt()),
                            style: SpType.label(10.5),
                          ),
                        ),
                        if (i['kind'] == 'task')
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Check(
                              done: i['done'] == true,
                              onTap: () => s.toggleDone(i['listId'] as String, i['task'] as Json),
                            ),
                          )
                        else
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(color: _colorOf(i), shape: BoxShape.circle),
                          ),
                        Expanded(
                          child: Text(
                            i['title'] as String,
                            style: SpType.text(13, color: i['done'] == true ? SpColors.dim : SpColors.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (habs.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('ПРИВЫЧКИ', style: SpType.label(10)),
                for (final h in habs)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        if (d == s.todayYmd)
                          Check(done: hb.isDone(s.habitLog, h['id'], d), onTap: () => s.toggleHabit(h))
                        else
                          Icon(
                            hb.isDone(s.habitLog, h['id'], d) ? Icons.check_circle : Icons.radio_button_unchecked,
                            size: 16,
                            color: SpColors.gold,
                          ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(h['name'] as String, style: SpType.text(13))),
                        Text('${hb.stats(h, s.habitLog)['streak']}', style: SpType.label(11, color: SpColors.gold)),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 10),
              AddLine(
                hint: '＋ Добавить на этот день',
                onSubmit: (v) {
                  final r = s.addLine(v);
                  if (r == null) return;
                  final t = s.tasks[r.listId]!.first;
                  if (dueToYmd(t['due'] as String?) != d) s.setDue(r.listId, t, d);
                  s.say('Добавлено в «${s.listName(r.listId)}»');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
