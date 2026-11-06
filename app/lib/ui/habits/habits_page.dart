// «Привычки»: карточки (значок, серия, точки за 7 дней, отметка), чипы части дня, «Сегодня | Месяц»,
// панель привычки с календарём месяца, окно новой/правки привычки. Логика — core/habits.dart.
import 'package:flutter/material.dart';

import '../../core/habits.dart' as hb;
import '../../state/app_state.dart';
import '../theme/tokens.dart';
import '../g/kit.dart';

const habitIcons = <String, IconData>{
  'cup': Icons.local_cafe_outlined,
  'gym': Icons.fitness_center,
  'pencil': Icons.edit_outlined,
  'book': Icons.menu_book_outlined,
  'moon': Icons.bedtime_outlined,
  'lang': Icons.translate,
  'walk': Icons.directions_walk,
  'heart': Icons.favorite_border,
  'leaf': Icons.eco_outlined,
  'music': Icons.music_note_outlined,
};
const habitColors = <String, Color>{
  'work': SpColors.blue,
  'clay': SpColors.accent,
  'gold': SpColors.gold,
  'personal': SpColors.green,
  'study': SpColors.violet,
  'done': Color(0xFF6FB6CF),
};

/// С какого вида открываются привычки (для снимков).
bool habitsStartMonth = false;

IconData iconOf(Json h, int i) => habitIcons[h['icon']] ?? habitIcons.values.elementAt(i % 6);
Color colorOf(Json h, int i) => habitColors[h['color']] ?? habitColors.values.elementAt(i % habitColors.length);

const presets = <Json>[
  {
    'name': 'Вода',
    'icon': 'cup',
    'color': 'work',
    'part': 'morning',
    'goal': {'n': 8, 'unit': 'стаканов'},
  },
  {'name': 'Зарядка', 'icon': 'gym', 'color': 'clay', 'part': 'morning'},
  {'name': 'Скетч 15 минут', 'icon': 'pencil', 'color': 'gold', 'part': 'evening'},
  {
    'name': 'Чтение',
    'icon': 'book',
    'color': 'personal',
    'part': 'evening',
    'goal': {'n': 20, 'unit': 'страниц'},
  },
  {'name': 'Английский', 'icon': 'lang', 'color': 'study', 'part': 'any', 'perWeek': 3},
];

class HabitsPage extends StatefulWidget {
  const HabitsPage({super.key, required this.state});
  final AppState state;

  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  String part = 'all';
  bool month = habitsStartMonth;
  DateTime shown = DateTime.now();
  String? open;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final all = s.habits;
    final list = part == 'all' ? all : all.where((h) => hb.partOf(h) == part).toList();
    final log = s.habitLog;
    final todays = all.where((h) => hb.scheduledOn(h, log, s.todayYmd)).toList();
    final doneN = todays.where((h) => hb.isDone(log, h['id'], s.todayYmd)).length;
    return DotGround(
      child: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= 1180;
          final sel = wide
              ? (list.where((h) => h['id'] == open).firstOrNull ?? (list.isEmpty ? null : list.first))
              : null;
          final main = ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            children: [
              _top(context, s, all, todays.length, doneN),
              const SizedBox(height: 18),
              if (todays.isNotEmpty && !month) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text('СЕГОДНЯ', style: gLbl(c: SpColors.gold)),
                    ),
                    for (final h in todays)
                      HabitPill(
                        _pillText(s, h),
                        done: hb.isDone(log, h['id'], s.todayYmd),
                        color: colorOf(h, all.indexOf(h)),
                        onTap: () => s.toggleHabit(h),
                      ),
                    const SizedBox(width: 12),
                    if (doneN < todays.length)
                      GBtn(
                        'Отметить все',
                        sm: true,
                        onTap: () {
                          for (final h in todays) {
                            while (!hb.isDone(s.habitLog, h['id'], s.todayYmd)) {
                              s.toggleHabit(h);
                            }
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 18),
              ],
              if (all.isEmpty)
                _empty(context, s)
              else if (month)
                _month(s, list, log)
              else
                _cards(context, s, list, log, sel?['id'] as String?, wide),
              if (all.isNotEmpty && !month) ...[
                const SizedBox(height: 26),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: _tip(s, all, log)),
                    const SizedBox(width: 28),
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Stamp(
                          sheet: 'ПРИВЫЧКИ',
                          date: _date(),
                          a: 'ВСЕГО ${all.length.toString().padLeft(2, '0')}',
                          b: 'СЕГОДНЯ $doneN/${todays.length}',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
          if (sel == null || month) return main;
          return WireBoard(
            wires: [Wire('hb:card:${sel['id']}', 'hb:panel', colorOf(sel, all.indexOf(sel)), vertical: false)],
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: main),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 18 + 52 + 18 + 50, 16, 16),
                  child: SizedBox(
                    width: 380,
                    child: HabitPanel(s: s, id: sel['id'] as String, i: all.indexOf(sel), sock: 'hb:panel'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _date() {
    final d = DateTime.now();
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${two(d.year % 100)}';
  }

  String _pillText(AppState s, Json h) {
    final g = hb.goalN(h);
    final done = hb.isDone(s.habitLog, h['id'], s.todayYmd);
    if (g > 0 && !done) return '${h['name']} ${hb.countOn(s.habitLog, h, s.todayYmd)}/$g';
    return h['name'] as String;
  }

  Widget _top(BuildContext context, AppState s, List<Json> all, int today, int done) => GNode(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          const GCoon('flag', size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('ПРИВЫЧКИ', style: gLbl(c: SpColors.ink)),
                Text(
                  '${all.length} ${hb.plural(all.length, ['привычка', 'привычки', 'привычек'])} · сегодня $done / $today'
                      .toUpperCase(),
                  style: gMicro(),
                ),
                const SizedBox(width: 8),
                for (final (id, name) in [('all', 'Все'), ('morning', 'Утро'), ('day', 'День'), ('evening', 'Вечер')])
                  GChip(name, on: part == id, onTap: () => setState(() => part = id)),
              ],
            ),
          ),
          GSeg(items: const ['Сегодня', 'Месяц'], active: month ? 1 : 0, onTap: (i) => setState(() => month = i == 1)),
          const SizedBox(width: 12),
          GBtn('+ Привычка', kind: BtnKind.acc, onTap: () => editHabit(context, s, null)),
        ],
      ),
    ),
  );

  Widget _tip(AppState s, List<Json> all, Map log) {
    Json? best;
    var n = 0;
    for (final h in all) {
      final k = hb.stats(h, log)['streak'] as int;
      if (k > n) {
        n = k;
        best = h;
      }
    }
    final broken = all.where((h) => hb.broken(h, log) != null).toList();
    final parts = <String>[
      if (best != null)
        '$n ${hb.plural(n, ['день', 'дня', 'дней'])} «${best['name']}» подряд. Следующая веха — ${hb.nextMilestone(n)}.',
      if (broken.isNotEmpty) '«${broken.first['name']}» вчера сорвалось — начнём заново сегодня?',
    ];
    return CoonTip(
      pose: n >= 7 ? 'cheer' : 'flag',
      color: const Color(0xFF8A7424),
      text: parts.isEmpty ? 'Отмечай привычки каждый день — серия растёт, вехи на 7, 21, 50 и 100.' : parts.join(' '),
    );
  }

  Widget _empty(BuildContext context, AppState s) => GNode(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GHead(name: 'Начни с одной', color: SpColors.gold),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, p) in presets.indexed)
                GPick(
                  p['name'] as String,
                  dot: colorOf(p, i),
                  onTap: () => editHabit(context, s, null, preset: p),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _cards(BuildContext context, AppState s, List<Json> list, Map log, String? sel, bool wide) => LayoutBuilder(
    builder: (context, box) {
      final n = box.maxWidth > 820 ? 3 : (box.maxWidth > 540 ? 2 : 1);
      final w = (box.maxWidth - (n - 1) * 18) / n;
      return Wrap(
        spacing: 18,
        runSpacing: 18,
        children: [
          for (final (i, h) in list.indexed)
            SizedBox(
              width: w,
              child: _card(context, s, h, !s.habits.contains(h) ? i : s.habits.indexOf(h), log, sel == h['id'], wide),
            ),
        ],
      );
    },
  );

  Widget _card(BuildContext context, AppState s, Json h, int i, Map log, bool on, bool wide) {
    final st = hb.stats(h, log);
    final done = hb.isDone(log, h['id'], s.todayYmd);
    final g = hb.goalN(h);
    final c = colorOf(h, i);
    final week = (h['perWeek'] ?? 0) as num > 0;
    final streak = st['streak'] as int;
    final kind = [
      week
          ? '${h['perWeek']} в нед'
          : (g > 0 ? '$g ${(h['goal'] as Map)['unit'] ?? ''}' : hb.scheduleLabel(h['days'] as List?)),
      if (hb.partOf(h) != 'any') hb.partName(h),
    ].join(' · ').toUpperCase();
    final foot = switch ((g > 0, week, done)) {
      (true, _, false) => '${hb.countOn(log, h, s.todayYmd)} / $g СЕГОДНЯ',
      (_, true, _) => '${hb.stats(h, log)['week'] ?? 0} / ${h['perWeek']} НА НЕДЕЛЕ',
      _ =>
        hb.broken(h, log) != null
            ? 'ВЧЕРА ПРОПУСК'
            : '→ ${hb.nextMilestone(streak)} · ЧЕРЕЗ ${hb.nextMilestone(streak) - streak} ДН',
    };
    final card = GNode(
      hub: on,
      child: InkWell(
        borderRadius: BorderRadius.circular(on ? 12 : 8),
        onTap: () => wide
            ? setState(() => open = h['id'] as String)
            : showDialog<void>(
                context: context,
                builder: (_) => Dialog(
                  backgroundColor: Colors.transparent,
                  child: SizedBox(
                    width: 400,
                    child: HabitPanel(s: s, id: h['id'] as String, i: i, close: true),
                  ),
                ),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SockRow(
              right: on ? Sock('hb:card:${h['id']}', c) : null,
              child: Container(
                height: 34,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: SpColors.line)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        ((h['name'] ?? '?') as String).characters.first.toUpperCase(),
                        style: SpType.text(10.5, w: FontWeight.w600, color: kDark),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        (h['name'] ?? '') as String,
                        style: SpType.text(13.5, w: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(kind, style: gMicro(), maxLines: 1),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$streak', style: SpType.text(48, w: FontWeight.w200, height: 54)),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      streak == 0 ? 'СЕРИЯ НА ПАУЗЕ' : (week ? 'НЕД ПОДРЯД' : 'ДН ПОДРЯД'),
                      style: gMicro(c: SpColors.muted),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Row(
                children: [
                  for (final (k, d) in hb.last7(h, log).indexed) ...[
                    if (k > 0) const SizedBox(width: 10),
                    Expanded(child: _sq(d['st'] as String, d['today'] == true, d['wd'] as String, c)),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      foot,
                      style: gMicro(c: foot.startsWith('→') ? SpColors.gold : SpColors.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _markBtn(done, g > 0 && !done, c, () => s.toggleHabit(h)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return card;
  }

  Widget _sq(String st, bool today, String wd, Color c) => Column(
    children: [
      AspectRatio(
        aspectRatio: 1,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 24, maxHeight: 24),
          decoration: BoxDecoration(
            color: switch (st) {
              'd' => c,
              'p' => c.withValues(alpha: .35),
              'm' => null,
              _ => null,
            },
            borderRadius: BorderRadius.circular(4),
            border: st == 'd'
                ? null
                : Border.all(
                    color: today
                        ? c
                        : st == 'm'
                        ? SpColors.red.withValues(alpha: .7)
                        : (st == 'k' ? const Color(0xFF6FB6CF) : SpColors.line),
                  ),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(wd.toUpperCase(), style: SpType.label(9, color: today ? SpColors.accent : SpColors.dim)),
    ],
  );

  Widget _markBtn(bool done, bool plus, Color c, VoidCallback on) => Material(
    color: done ? c : Colors.transparent,
    shape: StadiumBorder(side: done ? BorderSide.none : BorderSide(color: c)),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: on,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (done) ...[const Icon(Icons.check, size: 14, color: kDark), const SizedBox(width: 4)],
            Text(
              done ? 'Сделано' : (plus ? '+1' : 'Отметить'),
              style: SpType.text(12.5, w: FontWeight.w600, color: done ? kDark : SpColors.ink),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _month(AppState s, List<Json> list, Map log) {
    final y = shown.year, m = shown.month - 1;
    final days = DateTime(y, m + 2, 0).day;
    const wd = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];
    const name = 200.0, cell = 30.0, pct = 60.0;
    final today = DateTime.now();
    Widget sq(String st, bool isToday, Color c) => Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: switch (st) {
          'd' => c,
          'p' => c.withValues(alpha: .4),
          _ => null,
        },
        borderRadius: BorderRadius.circular(4),
        border: st == 'd'
            ? null
            : Border.all(
                color: isToday
                    ? SpColors.accent
                    : switch (st) {
                        'm' => SpColors.red.withValues(alpha: .8),
                        'k' => const Color(0xFF6FB6CF),
                        'f' || 'o' => SpColors.lineSoft,
                        _ => SpColors.line,
                      },
              ),
      ),
    );
    return GNode(
      hub: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GHead(
            name: 'Привычка × день',
            color: SpColors.gold,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => setState(() => shown = DateTime(y, shown.month - 1)),
                  child: Text('‹', style: gMono(13, c: Colors.white)),
                ),
                const SizedBox(width: 10),
                Text(_monthName[m].toUpperCase(), style: gLbl(c: Colors.white)),
                const SizedBox(width: 10),
                InkWell(
                  onTap: () => setState(() => shown = DateTime(y, shown.month + 1)),
                  child: Text('›', style: gMono(13, c: Colors.white)),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: SpColors.line)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: name,
                        child: Text('ПРИВЫЧКА', style: gMicro()),
                      ),
                      for (var n = 1; n <= days; n++)
                        () {
                          final d = DateTime(y, m + 1, n);
                          final isT = d.year == today.year && d.month == today.month && d.day == today.day;
                          final c = isT ? SpColors.accent : (d.weekday >= 6 ? SpColors.gold : SpColors.dim);
                          return SizedBox(
                            width: cell,
                            child: Column(
                              children: [
                                Text(wd[d.weekday - 1], style: gMicro(c: c)),
                                const SizedBox(height: 2),
                                Text('$n', style: gMono(10.5, c: isT ? SpColors.accent : SpColors.ink2)),
                              ],
                            ),
                          );
                        }(),
                      SizedBox(
                        width: pct,
                        child: Text('%', textAlign: TextAlign.right, style: gMicro()),
                      ),
                    ],
                  ),
                ),
                for (final (i, h) in list.indexed)
                  () {
                    final r = hb.monthRow(h, log, y, m);
                    final c = colorOf(h, i);
                    final p = r['pct'];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: SpColors.lineSoft)),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: name,
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
                                  child: Text(
                                    (h['name'] as String).characters.first.toUpperCase(),
                                    style: gMono(10.5, c: kDark, w: FontWeight.w600),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    h['name'] as String,
                                    style: SpType.text(13, w: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          for (final cc in r['cells'] as List)
                            SizedBox(
                              width: cell,
                              child: Center(
                                child: PopupMenuButton<String>(
                                  tooltip: cc['day'] as String,
                                  enabled: cc['st'] != 'f',
                                  padding: EdgeInsets.zero,
                                  color: SpColors.node,
                                  onSelected: (v) => s.setHabitDay(h, cc['day'] as String, v),
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      value: 'done',
                                      child: Text('Сделано', style: SpType.text(13)),
                                    ),
                                    PopupMenuItem(
                                      value: 'none',
                                      child: Text('Пропуск', style: SpType.text(13)),
                                    ),
                                    PopupMenuItem(
                                      value: 'skip',
                                      child: Text('Не считать этот день', style: SpType.text(13)),
                                    ),
                                  ],
                                  child: sq(cc['st'] as String, cc['today'] == true, c),
                                ),
                              ),
                            ),
                          SizedBox(
                            width: pct,
                            child: Text(
                              p == null ? '' : '$p',
                              textAlign: TextAlign.right,
                              style: gMono(11, c: p == 100 ? SpColors.gold : SpColors.muted),
                            ),
                          ),
                        ],
                      ),
                    );
                  }(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Wrap(
              spacing: 18,
              runSpacing: 6,
              children: [
                for (final (st, t) in [('d', 'сделано'), ('p', 'не всё'), ('m', 'пропуск'), ('k', 'не считать')])
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      sq(st, false, SpColors.gold),
                      const SizedBox(width: 6),
                      Text(t, style: SpType.text(12, color: SpColors.muted)),
                    ],
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    sq('f', true, SpColors.gold),
                    const SizedBox(width: 6),
                    Text('сегодня', style: SpType.text(12, color: SpColors.muted)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _monthName = [
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
  'Август',
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
];

/// Панель привычки (G_Habits справа): серия, дорожка вех 7·21·50·100, календарь месяца с отметками задним числом,
/// цифры (лучшая, всего, за месяц), окно, напоминание, правка и удаление.
class HabitPanel extends StatelessWidget {
  const HabitPanel({super.key, required this.s, required this.id, required this.i, this.close = false, this.sock});
  final AppState s;
  final String id;
  final int i;
  final bool close;
  final String? sock;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: s,
    builder: (context, _) {
      final h = s.habits.where((x) => x['id'] == id).firstOrNull;
      if (h == null) return const SizedBox();
      final log = s.habitLog;
      final st = hb.stats(h, log);
      final now = DateTime.now();
      final r = hb.monthRow(h, log, now.year, now.month - 1);
      final streak = st['streak'] as int;
      final first = DateTime(now.year, now.month, 1).weekday - 1;
      final c = colorOf(h, i);
      final passed = hb.milestones.contains(streak);
      return GNode(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SockRow(
              left: sock == null ? null : Sock(sock, c),
              child: GHead(
                name: '${h['name']} · панель',
                kind: hb.scheduleLine(h),
                color: c,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => editHabit(context, s, h),
                      child: const Icon(Icons.edit_outlined, size: 14, color: Colors.white),
                    ),
                    if (close) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$streak', style: SpType.text(56, w: FontWeight.w200, height: 62)),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            '${(h['perWeek'] ?? 0) as num > 0 ? 'НЕД' : hb.plural(streak, ['ДЕНЬ', 'ДНЯ', 'ДНЕЙ'])} ПОДРЯД${passed ? ' · ВЕХА ПРОЙДЕНА' : ''}',
                            style: gMicro(c: c),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('ВЕХИ', style: gMicro(c: SpColors.muted)),
                  const SizedBox(height: 10),
                  _Milestones(streak: streak, color: c),
                  const SizedBox(height: 18),
                  Text(_monthName[now.month - 1].toUpperCase(), style: gMicro(c: SpColors.muted)),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, box) {
                      final w = (box.maxWidth - 6 * 6) / 7;
                      return Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (var k = 0; k < first; k++) SizedBox(width: w, height: 24),
                          for (final cc in r['cells'] as List)
                            SizedBox(
                              width: w,
                              height: 24,
                              child: PopupMenuButton<String>(
                                enabled: cc['st'] != 'f',
                                tooltip: '',
                                onSelected: (v) => s.setHabitDay(h, cc['day'] as String, v),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'done', child: Text('Сделано')),
                                  PopupMenuItem(value: 'skip', child: Text('Не считать')),
                                  PopupMenuItem(value: 'none', child: Text('Не сделано')),
                                ],
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: cc['st'] == 'd' ? c : null,
                                    borderRadius: BorderRadius.circular(4),
                                    border: cc['st'] == 'd'
                                        ? null
                                        : Border.all(color: cc['today'] == true ? c : SpColors.line),
                                  ),
                                  child: Text(
                                    '${cc['n']}',
                                    style: gMono(9.5, c: cc['st'] == 'd' ? kDark : SpColors.muted),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: SpColors.line),
                    ),
                    child: Row(
                      children: [
                        for (final (k, (v, l)) in [
                          ('${st['best']}', 'ЛУЧШАЯ'),
                          ('${hb.totalDone(h, log)}', 'ВСЕГО'),
                          (r['pct'] == null ? '—' : '${r['pct']}%', 'ЗА МЕСЯЦ'),
                        ].indexed)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                              decoration: BoxDecoration(
                                border: k == 0 ? null : const Border(left: BorderSide(color: SpColors.line)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(v, style: SpType.text(20, w: FontWeight.w400)),
                                  Text(l, style: gMicro()),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text('ОКНО', style: gMicro(c: SpColors.muted)),
                      ),
                      Expanded(
                        child: Text(
                          hb.winLabel(h).isEmpty ? 'когда угодно' : hb.winLabel(h),
                          style: gMono(12, c: SpColors.ink),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text('НАПОМНИТЬ', style: gMicro(c: SpColors.muted)),
                      ),
                      GChip(
                        'Telegram',
                        on: ((h['remind'] as Map?)?['tg']) != false,
                        color: c,
                        onTap: () => s.saveHabit(id, {
                          'remind': {...?(h['remind'] as Map?), 'tg': ((h['remind'] as Map?)?['tg']) == false},
                        }),
                      ),
                      const SizedBox(width: 6),
                      GChip(
                        'Windows',
                        on: ((h['remind'] as Map?)?['win']) == true,
                        color: c,
                        onTap: () => s.saveHabit(id, {
                          'remind': {...?(h['remind'] as Map?), 'win': ((h['remind'] as Map?)?['win']) != true},
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GBtn(
                      'Удалить привычку',
                      kind: BtnKind.ghost,
                      sm: true,
                      onTap: () {
                        if (close) Navigator.pop(context);
                        s.removeHabit(id);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _Milestones extends StatelessWidget {
  const _Milestones({required this.streak, required this.color});
  final int streak;
  final Color color;
  @override
  Widget build(BuildContext context) {
    const ms = [7, 21, 50, 100];
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            double x(int k) => k / (ms.length - 1) * (w - 12) + 6;
            final pos = hb.milestonePos(streak).clamp(0, 100) / 100 * (w - 12) + 6;
            return SizedBox(
              height: 14,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(left: 6, right: 6, top: 6.5, child: Container(height: 1, color: SpColors.lineStrong)),
                  Positioned(
                    left: 6,
                    width: (pos - 6).clamp(0, w),
                    top: 6,
                    child: Container(height: 2, color: color),
                  ),
                  for (final (k, m) in ms.indexed)
                    Positioned(
                      left: x(k) - 6,
                      top: 1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: streak >= m ? color : SpColors.node,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: streak >= m ? color : SpColors.lineStrong),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [for (final m in ms) Text('$m', style: gMicro(c: streak >= m ? color : SpColors.dim))],
        ),
      ],
    );
  }
}

/// Панель привычки в окне (узкий экран и вызов из других мест).
Future<void> habitPanel(BuildContext context, AppState s, String id, int i) => showDialog<void>(
  context: context,
  builder: (_) => Dialog(
    backgroundColor: Colors.transparent,
    child: SizedBox(
      width: 400,
      child: HabitPanel(s: s, id: id, i: i, close: true),
    ),
  ),
);

/// Окно привычки: название, значок, цвет, часть дня, дни или «N раз в неделю», цель-количество.
Future<void> editHabit(BuildContext context, AppState s, Json? h, {Json? preset}) => showDialog<void>(
  context: context,
  builder: (_) => _HabitEdit(s: s, h: h, preset: preset),
);

class _HabitEdit extends StatefulWidget {
  const _HabitEdit({required this.s, this.h, this.preset});
  final AppState s;
  final Json? h;
  final Json? preset;

  @override
  State<_HabitEdit> createState() => _HabitEditState();
}

class _HabitEditState extends State<_HabitEdit> {
  late final TextEditingController name;
  late final TextEditingController goal;
  late final TextEditingController unit;
  late String? icon;
  late String? color;
  late String part;
  late Set<int> days;
  late int perWeek;

  @override
  void initState() {
    super.initState();
    final src = widget.h ?? widget.preset ?? const {};
    name = TextEditingController(text: (src['name'] ?? '') as String);
    final g = src['goal'] as Map?;
    goal = TextEditingController(text: g?['n'] == null ? '' : '${g!['n']}');
    unit = TextEditingController(text: (g?['unit'] ?? '') as String);
    icon = src['icon'] as String?;
    color = src['color'] as String?;
    part = src['part'] as String? ?? (widget.h == null ? 'any' : hb.partOf(src));
    final d = src['days'] as List?;
    days = d == null || d.isEmpty ? {0, 1, 2, 3, 4, 5, 6} : d.map((x) => (x as num).toInt()).toSet();
    perWeek = ((src['perWeek'] ?? 0) as num).toInt();
  }

  void _save() {
    final n = name.text.trim();
    if (n.isEmpty) return;
    final gn = int.tryParse(goal.text.trim());
    final fields = <String, dynamic>{
      'icon': icon,
      'color': color,
      'part': part,
      'days': days.length == 7 ? <int>[] : (days.toList()..sort()),
      'perWeek': perWeek > 0 ? perWeek : null,
      'goal': gn != null && gn > 1 ? {'n': gn, 'unit': unit.text.trim()} : null,
    };
    final h = widget.h;
    if (h == null) {
      widget.s.addHabit(n, fields);
    } else {
      if (n != h['name']) widget.s.renameHabit(h['id'] as String, n);
      widget.s.saveHabit(h['id'] as String, fields);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: SpColors.node,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.h == null ? 'Новая привычка' : 'Привычка', style: SpType.label(11)),
            TextField(
              controller: name,
              autofocus: true,
              style: SpType.text(20, w: FontWeight.w600),
              decoration: const InputDecoration(border: InputBorder.none, hintText: 'Название'),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: [
                for (final e in habitIcons.entries)
                  IconButton(
                    isSelected: icon == e.key,
                    onPressed: () => setState(() => icon = e.key),
                    icon: Icon(e.value, size: 20, color: icon == e.key ? SpColors.accent : SpColors.muted),
                  ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final e in habitColors.entries)
                  InkWell(
                    onTap: () => setState(() => color = e.key),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: e.value,
                        shape: BoxShape.circle,
                        border: Border.all(color: color == e.key ? SpColors.ink : Colors.transparent, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text('КОГДА', style: SpType.label(10.5)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                for (final p in hb.parts)
                  ChoiceChip(
                    label: Text(p['name'] as String),
                    selected: part == p['id'],
                    onSelected: (_) => setState(() => part = p['id'] as String),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 4,
              children: [
                for (var d = 0; d < 7; d++)
                  FilterChip(
                    label: Text(hb.weekdays[d]),
                    selected: perWeek == 0 && days.contains(d),
                    onSelected: perWeek > 0
                        ? null
                        : (on) => setState(() => on ? days.add(d) : (days.length > 1 ? days.remove(d) : null)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('или раз в неделю:', style: SpType.text(13, color: SpColors.muted)),
                const SizedBox(width: 8),
                for (final n in [0, 1, 2, 3, 4, 5])
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ChoiceChip(
                      label: Text(n == 0 ? 'нет' : '$n'),
                      selected: perWeek == n,
                      onSelected: (_) => setState(() => perWeek = n),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('Цель в день:', style: SpType.text(13, color: SpColors.muted)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: goal,
                    decoration: const InputDecoration(hintText: '1', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: unit,
                    decoration: const InputDecoration(hintText: 'стаканов', isDense: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
                const SizedBox(width: 8),
                FilledButton(onPressed: _save, child: Text(widget.h == null ? 'Добавить' : 'Сохранить')),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
