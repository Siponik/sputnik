// «Сегодня»: умная строка сверху, задачи на сегодня и просроченные, справа — события дня.
import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/task_dialog.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final items = s.todayItems;
    final open = items.where((x) => !s.isDone(x.$2)).length;
    final ev = s.eventsOn(s.todayYmd);
    return DotGround(
      child: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth > 900;
          final main = ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(_title(), style: SpType.text(24, w: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                open == 0 ? 'На сегодня всё сделано' : 'Осталось $open',
                style: SpType.text(13, color: SpColors.muted),
              ),
              const SizedBox(height: 16),
              AddLine(
                hint: 'Новая задача: «позвонить маме завтра 17:00 @дом !!»',
                autofocus: true,
                onSubmit: (v) {
                  final r = s.addLine(v);
                  if (r != null) s.say('Добавлено в «${s.listName(r.listId)}»: ${r.title}');
                },
              ),
              const SizedBox(height: 16),
              Node(
                title: 'Задачи · ${items.length}',
                head: SpColors.headOrange,
                child: items.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text('Ничего на сегодня', style: SpType.text(14, color: SpColors.muted)),
                      )
                    : Column(children: [for (final (l, t) in items) _row(context, s, l, t)]),
              ),
              if (!wide) ...[const SizedBox(height: 16), _events(ev)],
            ],
          );
          if (!wide) return main;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: main),
              SizedBox(
                width: 340,
                child: ListView(padding: const EdgeInsets.fromLTRB(0, 20, 20, 20), children: [_events(ev)]),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _events(List<Json> ev) => Node(
    title: 'События · ${ev.length}',
    head: SpColors.headBlue,
    child: ev.isEmpty
        ? Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Встреч нет', style: SpType.text(13, color: SpColors.muted)),
          )
        : Column(
            children: [
              for (final e in ev)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 52,
                        child: Text(eventTime(e), style: SpType.label(11.5, color: SpColors.ink2)),
                      ),
                      Expanded(child: Text((e['summary'] ?? '(без названия)') as String, style: SpType.text(13.5))),
                    ],
                  ),
                ),
            ],
          ),
  );

  Widget _row(BuildContext context, AppState s, String listId, Json t) {
    final done = s.isDone(t);
    final due = dueToYmd(t['due'] as String?);
    final late = !done && due.isNotEmpty && due.compareTo(s.todayYmd) < 0;
    final slot = s.layTask(t['id'] as String)['slot'] as Map?;
    final prio = (s.layTask(t['id'] as String)['priority'] as num?)?.toInt();
    return InkWell(
      onTap: () => openTask(context, s, listId, t),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: SpColors.lineSoft)),
        ),
        child: Row(
          children: [
            Check(done: done, onTap: () => s.toggleDone(listId, t)),
            const SizedBox(width: 12),
            if (slot?['s'] != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(slot!['s'] as String, style: SpType.label(11.5, color: SpColors.accentInk)),
              ),
            if (prio == 1)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text('!!!', style: SpType.label(11.5, color: SpColors.red)),
              ),
            Expanded(
              child: Text(
                (t['title'] ?? '') as String,
                style: SpType.text(
                  14.5,
                  color: done ? SpColors.dim : SpColors.ink,
                ).copyWith(decoration: done ? TextDecoration.lineThrough : null),
              ),
            ),
            if (late) Text('${humanDay(due)} · ', style: SpType.label(11, color: SpColors.red)),
            Text(s.listName(listId), style: SpType.label(11)),
          ],
        ),
      ),
    );
  }

  static const _days = ['понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота', 'воскресенье'];
  static const _months = [
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

  String _title() {
    final d = DateTime.now();
    return 'Сегодня, ${d.day} ${_months[d.month - 1]} · ${_days[d.weekday - 1]}';
  }
}

/// «14:30» или «весь день».
String eventTime(Json e) {
  final dt = DateTime.tryParse(((e['start'] as Map?)?['dateTime'] ?? '') as String)?.toLocal();
  if (dt == null) return 'весь день';
  return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
