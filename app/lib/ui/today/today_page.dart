// «Сегодня»: умная строка сверху, задачи на сегодня и просроченные, справа — события дня.
import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/task_dialog.dart';
import '../../core/habits.dart' as hb;
import '../../core/meta.dart' as meta;
import '../board/card_menu.dart';

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
              const SizedBox(height: 12),
              ..._next(context, s, items),
              ..._habits(s),
              ..._inbox(context, s),
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

  List<Widget> _next(BuildContext context, AppState s, List<(String, Json)> items) {
    final open = [
      for (final x in items)
        if (!s.isDone(x.$2)) {'task': x.$2, 'listId': x.$1},
    ];
    final pick = meta.pickNext(open, (s.layer['tasks'] as Map?)?.cast<String, dynamic>(), s.todayYmd);
    if (pick == null) return [];
    final n = pick['task'] as Json;
    final listId = pick['listId'] as String;
    final why = meta.nextReason(n, (s.layer['tasks'] as Map?)?.cast<String, dynamic>(), s.todayYmd, humanDay);
    return [
      InkWell(
        onTap: () => openTask(context, s, listId, n),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SpColors.accentWash,
            borderRadius: BorderRadius.circular(SpRadius.node),
            border: Border.all(color: SpColors.accentLine),
          ),
          child: Row(
            children: [
              Text('ДАЛЬШЕ', style: SpType.label(10.5, color: SpColors.accentInk)),
              const SizedBox(width: 12),
              Expanded(
                child: Text((n['title'] ?? '') as String, style: SpType.text(15, w: FontWeight.w600)),
              ),
              Text(why, style: SpType.label(11, color: SpColors.accentInk)),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
    ];
  }

  List<Widget> _habits(AppState s) {
    final hs = s.habits.where((h) => hb.scheduledOn(h, s.habitLog, s.todayYmd)).toList();
    if (hs.isEmpty) return [];
    return [
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final h in hs)
            () {
              final done = hb.isDone(s.habitLog, h['id'], s.todayYmd);
              final g = hb.goalN(h);
              return FilterChip(
                selected: done,
                selectedColor: SpColors.gold.withValues(alpha: .3),
                checkmarkColor: SpColors.gold,
                label: Text('${h['name']}${g > 0 && !done ? ' ${hb.countOn(s.habitLog, h, s.todayYmd)}/$g' : ''}'),
                onSelected: (_) => s.toggleHabit(h),
              );
            }(),
        ],
      ),
      const SizedBox(height: 12),
    ];
  }

  List<Widget> _inbox(BuildContext context, AppState s) {
    final items = s.inboxItems;
    if (items.isEmpty) return [];
    return [
      Node(
        title: 'Входящие от Claude · ${items.length}',
        head: SpColors.headViolet,
        trailing: InkWell(
          onTap: () => s.acceptInbox(items),
          child: Text('ПРИНЯТЬ ВСЕ', style: SpType.label(10.5, color: SpColors.ink)),
        ),
        child: Column(
          children: [
            for (final x in items)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: SpColors.lineSoft)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => openTask(context, s, x['listId'] as String, x['task'] as Json),
                        child: Text(((x['task'] as Json)['title'] ?? '') as String, style: SpType.text(14)),
                      ),
                    ),
                    ActionChip(
                      label: Text('→ ${x['list']}'),
                      onPressed: () async {
                        final to = await pickList(context, s);
                        if (to != null) {
                          s.acceptInbox([
                            {...x, 'dest': to},
                          ]);
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Принять',
                      onPressed: () => s.acceptInbox([x]),
                      icon: const Icon(Icons.check, size: 18, color: SpColors.green),
                    ),
                    IconButton(
                      tooltip: 'Отклонить',
                      onPressed: () => s.rejectInbox(x),
                      icon: const Icon(Icons.close, size: 18, color: SpColors.muted),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
    ];
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
            Check(
              done: done,
              onTap: () {
                s.toggleDone(listId, t);
                if (!done) s.say('Готово · ${t['title']}', () => s.toggleDone(listId, t));
              },
            ),
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
