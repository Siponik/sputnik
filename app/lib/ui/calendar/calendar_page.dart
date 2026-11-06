// «Календарь»: неделя колонками по дням — события и задачи со сроком. ‹ › — соседние недели (в пределах загруженных).
import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../state/app_state.dart';
import '../theme/tokens.dart';
import '../today/today_page.dart' show eventTime;
import '../widgets/common.dart';
import '../widgets/task_dialog.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.state});
  final AppState state;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  int week = 0; // 0 — эта неделя

  static const _dn = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final now = DateTime.now();
    final mon = DateTime(now.year, now.month, now.day - (now.weekday - 1) + week * 7);
    final days = [for (var i = 0; i < 7; i++) DateTime(mon.year, mon.month, mon.day + i)];
    final end = days.last;
    return DotGround(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Row(
              children: [
                Text(
                  '${mon.day}.${mon.month.toString().padLeft(2, '0')} — ${end.day}.${end.month.toString().padLeft(2, '0')}',
                  style: SpType.text(20, w: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: week > -1 ? () => setState(() => week--) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                TextButton(onPressed: () => setState(() => week = 0), child: const Text('Сегодня')),
                IconButton(
                  onPressed: week < 4 ? () => setState(() => week++) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, d) in days.indexed)
                    Expanded(
                      child: Padding(padding: const EdgeInsets.only(right: 8), child: _day(context, s, d, i)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _day(BuildContext context, AppState s, DateTime d, int i) {
    final day = ymd(d);
    final isToday = day == s.todayYmd;
    final ev = s.eventsOn(day);
    final ts = s.tasksOn(day);
    return Node(
      title: '${_dn[i]} ${d.day}',
      head: isToday ? SpColors.headMain : SpColors.headGrey,
      child: Flexible(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(6),
          children: [
            for (final e in ev)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: SpColors.nodeHover,
                  borderRadius: BorderRadius.circular(SpRadius.socket),
                  border: const Border(left: BorderSide(color: SpColors.blue, width: 2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(eventTime(e), style: SpType.label(10.5)),
                    Text((e['summary'] ?? '(без названия)') as String, style: SpType.text(12.5)),
                  ],
                ),
              ),
            for (final (l, t) in ts)
              InkWell(
                onTap: () => openTask(context, s, l, t),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    children: [
                      Check(done: s.isDone(t), onTap: () => s.toggleDone(l, t)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          (t['title'] ?? '') as String,
                          style: SpType.text(12.5, color: s.isDone(t) ? SpColors.dim : SpColors.ink),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: AddLine(
                hint: 'Задача',
                onSubmit: (v) {
                  final ls = s.boardLists;
                  if (ls.isEmpty) return;
                  final r = s.addLine(v);
                  if (r == null) return;
                  final t = s.tasks[r.listId]!.first;
                  if (dueToYmd(t['due'] as String?) != day) s.setDue(r.listId, t, day);
                  s.say('Добавлено в «${s.listName(r.listId)}» на ${d.day}.${d.month}');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
