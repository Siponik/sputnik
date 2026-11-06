// «Привычки»: карточки (значок, серия, точки за 7 дней, отметка), чипы части дня, «Сегодня | Месяц»,
// панель привычки с календарём месяца, окно новой/правки привычки. Логика — core/habits.dart.
import 'package:flutter/material.dart';

import '../../core/habits.dart' as hb;
import '../../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

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
  bool month = false;
  DateTime shown = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final all = s.habits;
    final list = part == 'all' ? all : all.where((h) => hb.partOf(h) == part).toList();
    final log = s.habitLog;
    return DotGround(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Привычки', style: SpType.text(24, w: FontWeight.w600)),
              const SizedBox(width: 12),
              Text(
                all.isEmpty ? '' : (s.habitsLeft == 0 ? 'всё отмечено сегодня' : 'осталось ${s.habitsLeft}'),
                style: SpType.text(13, color: SpColors.muted),
              ),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Сегодня')),
                  ButtonSegment(value: true, label: Text('Месяц')),
                ],
                selected: {month},
                onSelectionChanged: (v) => setState(() => month = v.first),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () => editHabit(context, s, null),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Привычка'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            children: [
              for (final (id, name) in [
                ('all', 'Все'),
                ('morning', 'Утро'),
                ('day', 'День'),
                ('evening', 'Вечер'),
                ('any', 'Когда угодно'),
              ])
                ChoiceChip(label: Text(name), selected: part == id, onSelected: (_) => setState(() => part = id)),
            ],
          ),
          const SizedBox(height: 16),
          if (all.isEmpty) _empty(context, s) else if (month) _month(s, list, log) else _cards(context, s, list, log),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context, AppState s) => Node(
    title: 'Начни с одной',
    head: SpColors.headGold,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (i, p) in presets.indexed)
            ActionChip(
              avatar: Icon(iconOf(p, i), size: 16, color: colorOf(p, i)),
              label: Text(p['name'] as String),
              onPressed: () => editHabit(context, s, null, preset: p),
            ),
        ],
      ),
    ),
  );

  Widget _cards(BuildContext context, AppState s, List<Json> list, Map log) => LayoutBuilder(
    builder: (context, box) {
      final n = box.maxWidth > 1000 ? 3 : (box.maxWidth > 620 ? 2 : 1);
      final w = (box.maxWidth - (n - 1) * 12) / n;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [for (final (i, h) in list.indexed) SizedBox(width: w, child: _card(context, s, h, i, log))],
      );
    },
  );

  Widget _card(BuildContext context, AppState s, Json h, int i, Map log) {
    final st = hb.stats(h, log);
    final done = hb.isDone(log, h['id'], s.todayYmd);
    final g = hb.goalN(h);
    final c = colorOf(h, i);
    return InkWell(
      borderRadius: BorderRadius.circular(SpRadius.node),
      onTap: () => habitPanel(context, s, h['id'] as String, i),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: SpColors.node,
          borderRadius: BorderRadius.circular(SpRadius.node),
          border: Border.all(color: done ? SpColors.accentLine : SpColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(iconOf(h, i), color: c, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(h['name'] as String, style: SpType.text(15, w: FontWeight.w600)),
                      Text(hb.cardLine(h, log), style: SpType.text(12, color: SpColors.muted)),
                    ],
                  ),
                ),
                _mark(done, g > 0 && !done ? '${hb.countOn(log, h, s.todayYmd)}/$g' : null, () => s.toggleHabit(h)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${st['streak']}',
                  style: SpType.text(30, w: FontWeight.w700, color: SpColors.gold),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${(h['perWeek'] ?? 0) as num > 0 ? 'нед.' : 'дн.'} подряд · лучшая ${st['best']}',
                      style: SpType.label(11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                for (final d in hb.last7(h, log)) _dot(d['st'] as String, d['today'] == true, d['wd'] as String),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mark(bool done, String? count, VoidCallback onTap) => InkResponse(
    onTap: onTap,
    radius: 22,
    child: AnimatedContainer(
      duration: SpMotion.fast,
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? SpColors.gold : Colors.transparent,
        border: Border.all(color: done ? SpColors.gold : SpColors.lineStrong, width: 1.5),
      ),
      child: done
          ? const Icon(Icons.check, size: 18, color: SpColors.ground)
          : count != null
          ? Text(count, style: SpType.label(10, color: SpColors.ink))
          : null,
    ),
  );

  Widget _month(AppState s, List<Json> list, Map log) {
    final y = shown.year, m = shown.month - 1;
    final days = DateTime(y, m + 2, 0).day;
    return Node(
      title: '${_monthName[m]} $y',
      head: SpColors.headGold,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => shown = DateTime(y, shown.month - 1)),
            child: const Icon(Icons.chevron_left, size: 18),
          ),
          InkWell(
            onTap: () => setState(() => shown = DateTime(y, shown.month + 1)),
            child: const Icon(Icons.chevron_right, size: 18),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(width: 160),
                for (var n = 1; n <= days; n++)
                  SizedBox(
                    width: 24,
                    child: Center(child: Text('$n', style: SpType.label(10))),
                  ),
                const SizedBox(width: 50),
              ],
            ),
            for (final (i, h) in list.indexed)
              () {
                final r = hb.monthRow(h, log, y, m);
                return Row(
                  children: [
                    SizedBox(
                      width: 160,
                      child: Row(
                        children: [
                          Icon(iconOf(h, i), size: 16, color: colorOf(h, i)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(h['name'] as String, style: SpType.text(13), overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                    for (final c in r['cells'] as List)
                      SizedBox(
                        width: 24,
                        height: 28,
                        child: Center(
                          child: PopupMenuButton<String>(
                            tooltip: c['day'] as String,
                            enabled: c['st'] != 'f',
                            padding: EdgeInsets.zero,
                            onSelected: (v) => s.setHabitDay(h, c['day'] as String, v),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'done', child: Text('Сделано')),
                              PopupMenuItem(value: 'skip', child: Text('Не считать')),
                              PopupMenuItem(value: 'none', child: Text('Не сделано')),
                            ],
                            child: _dot(c['st'] as String, c['today'] == true, null),
                          ),
                        ),
                      ),
                    SizedBox(
                      width: 50,
                      child: Text(
                        r['pct'] == null ? '' : '${r['pct']}%',
                        style: SpType.label(11),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                );
              }(),
          ],
        ),
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

/// Точка дня: d — сделано (золото), p — часть, k — не считать, m — пропуск, w — ждёт, o — не по расписанию, f — будущее.
Widget _dot(String st, bool today, String? label) {
  final dot = Container(
    width: 12,
    height: 12,
    margin: const EdgeInsets.symmetric(horizontal: 2),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: switch (st) {
        'd' => SpColors.gold,
        'p' => SpColors.accentWash,
        'm' => SpColors.lineSoft,
        _ => Colors.transparent,
      },
      border: Border.all(
        color: today
            ? SpColors.accent
            : switch (st) {
                'd' => SpColors.gold,
                'p' => SpColors.gold,
                'k' => const Color(0xFF6FB6CF),
                'o' || 'f' => SpColors.lineSoft,
                _ => SpColors.line,
              },
        width: today ? 1.5 : 1,
      ),
    ),
  );
  if (label == null) return dot;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: SpType.label(9, color: SpColors.dim)),
      const SizedBox(height: 3),
      dot,
    ],
  );
}

/// Панель привычки: серия, вехи, календарь месяца с отметками задним числом, правка и удаление.
Future<void> habitPanel(BuildContext context, AppState s, String id, int i) => showDialog<void>(
  context: context,
  builder: (_) => ListenableBuilder(
    listenable: s,
    builder: (context, _) {
      final h = s.habits.where((x) => x['id'] == id).firstOrNull;
      if (h == null) return const SizedBox();
      final log = s.habitLog;
      final st = hb.stats(h, log);
      final now = DateTime.now();
      final r = hb.monthRow(h, log, now.year, now.month - 1);
      final next = hb.nextMilestone(st['streak'] as num);
      final first = DateTime(now.year, now.month, 1).weekday - 1;
      return Dialog(
        backgroundColor: SpColors.node,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(iconOf(h, i), color: colorOf(h, i)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(h['name'] as String, style: SpType.text(20, w: FontWeight.w600)),
                    ),
                    IconButton(
                      tooltip: 'Изменить',
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => editHabit(context, s, h),
                    ),
                    IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                Text(hb.scheduleLine(h), style: SpType.text(13, color: SpColors.muted)),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${st['streak']}',
                      style: SpType.text(40, w: FontWeight.w700, color: SpColors.gold),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('подряд · лучшая ${st['best']} · до вехи $next', style: SpType.label(11.5)),
                    ),
                  ],
                ),
                LinearProgressIndicator(
                  value: hb.milestonePos(st['streak'] as num).clamp(0, 100) / 100,
                  color: SpColors.gold,
                  backgroundColor: SpColors.lineSoft,
                ),
                const SizedBox(height: 16),
                Text(
                  '${_monthName[now.month - 1]} · сделано ${r['done']}${r['pct'] == null ? '' : ' · ${r['pct']}%'}',
                  style: SpType.label(11),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final w in hb.weekdays)
                      SizedBox(
                        width: 56,
                        child: Center(child: Text(w, style: SpType.label(10))),
                      ),
                    for (var k = 0; k < first; k++) const SizedBox(width: 56, height: 34),
                    for (final c in r['cells'] as List)
                      SizedBox(
                        width: 56,
                        height: 34,
                        child: PopupMenuButton<String>(
                          enabled: c['st'] != 'f',
                          tooltip: '',
                          onSelected: (v) => s.setHabitDay(h, c['day'] as String, v),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'done', child: Text('Сделано')),
                            PopupMenuItem(value: 'skip', child: Text('Не считать')),
                            PopupMenuItem(value: 'none', child: Text('Не сделано')),
                          ],
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: c['st'] == 'd' ? SpColors.gold : SpColors.bg,
                              borderRadius: BorderRadius.circular(SpRadius.socket),
                              border: Border.all(color: c['today'] == true ? SpColors.accent : SpColors.lineSoft),
                            ),
                            child: Text(
                              '${c['n']}',
                              style: SpType.label(11, color: c['st'] == 'd' ? SpColors.ground : SpColors.ink2),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text('Всего отмечено: ${hb.totalDone(h, log)}', style: SpType.label(11)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        s.removeHabit(id);
                      },
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Удалить привычку'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
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
