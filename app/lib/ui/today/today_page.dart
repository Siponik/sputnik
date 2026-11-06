// «Сегодня» по макету G_Today: слева источники (списки, «От Claude», привычки) проводами сходятся в главную ноду
// «Сегодня» (строка добавления, задачи по порядку, «Дальше» раскрыто, входящие, привычки-таблетки), справа вывод —
// «Дальше», «Итог дня» с занятостью 09–21, енот со свободным окном и штамп листа. Узко — одна колонка без проводов.
import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/habits.dart' as hb;
import '../../core/meta.dart' as meta;
import '../../core/spheres.dart' as sph;
import '../../state/app_state.dart';
import '../board/card_menu.dart';
import '../board/share_dialog.dart';
import '../g/kit.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/task_dialog.dart';

const _wd = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];
String _two(int x) => x.toString().padLeft(2, '0');

/// Цвет списка — цвет его сферы (без сферы — оранжевый, как «работа» в макете).
Color listHue(AppState s, String listId) {
  final sid = s.sphereOf(listId);
  if (sid == null) return SpColors.accent;
  final sp = s.spheres.firstWhere((x) => x['id'] == sid, orElse: () => {});
  return sp.isEmpty ? SpColors.accent : cssColor(sph.sphereColor(sp));
}

String viewName(AppState s, String listId) => switch (s.board(listId)['view']) {
  'pipe' => 'конвейер',
  'stickers' => 'стикеры',
  'list' => 'список',
  _ => 'канбан',
};

class TodayPage extends StatelessWidget {
  const TodayPage({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => DotGround(
    child: LayoutBuilder(
      builder: (context, box) {
        final m = _Model(state);
        if (box.maxWidth < 1060) return _narrow(context, m);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: Center(
            child: SizedBox(
              width: 1180,
              child: WireBoard(
                wires: m.wires(),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 230, child: _Sources(m: m)),
                    const SizedBox(width: 130),
                    SizedBox(width: 470, child: _Hub(m: m)),
                    const SizedBox(width: 70),
                    SizedBox(width: 280, child: _Output(m: m)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _narrow(BuildContext context, _Model m) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _Hub(m: m),
      const SizedBox(height: 16),
      _Output(m: m),
      const SizedBox(height: 16),
      _Sources(m: m),
    ],
  );
}

/// Всё, что нужно экрану, посчитано один раз.
class _Model {
  _Model(this.s) {
    items = s.todayItems;
    final open = [
      for (final x in items)
        if (!s.isDone(x.$2)) {'task': x.$2, 'listId': x.$1},
    ];
    final p = meta.pickNext(open, lt, s.todayYmd);
    next = p == null ? null : (p['listId'] as String, p['task'] as Json);
    habits = s.habits.where((h) => hb.scheduledOn(h, s.habitLog, s.todayYmd)).toList();
    inbox = s.inboxItems;
    for (final (l, _) in items) {
      if (!bySrc.contains(l)) bySrc.add(l);
    }
  }

  final AppState s;
  late final List<(String, Json)> items;
  late final (String, Json)? next;
  late final List<Json> habits;
  late final List<Json> inbox;
  final bySrc = <String>[];

  Map<String, dynamic>? get lt => (s.layer['tasks'] as Map?)?.cast<String, dynamic>();
  int get open => items.where((x) => !s.isDone(x.$2)).length;
  int get habitsDone => habits.where((h) => hb.isDone(s.habitLog, h['id'], s.todayYmd)).length;

  String timeOf(Json t) {
    final slot = s.layTask(t['id'] as String)['slot'] as Map?;
    if (slot?['s'] != null) return slot!['s'] as String;
    final due = dueToYmd(t['due'] as String?);
    if (due.isNotEmpty && due.compareTo(s.todayYmd) < 0) return humanDay(due).toUpperCase();
    return 'ДЕНЬ';
  }

  bool late(Json t) {
    final due = dueToYmd(t['due'] as String?);
    return !s.isDone(t) && due.isNotEmpty && due.compareTo(s.todayYmd) < 0;
  }

  List<Wire> wires() => [
    for (final (l, t) in items)
      Wire(
        'src:${t['id']}',
        'hub:${t['id']}',
        s.isDone(t) ? const Color(0xFF7C7E88) : listHue(s, l),
        width: next?.$2['id'] == t['id'] ? 2 : 1.5,
      ),
    for (final x in inbox) Wire('src:in:${(x['task'] as Json)['id']}', 'hub:inbox', SpColors.grey, dash: true),
    for (final h in habits) Wire('src:hb:${h['id']}', 'hub:habits', SpColors.gold),
    if (next != null) const Wire('hub:next', 'out:next', SpColors.accent, width: 2),
    const Wire('hub:sum', 'out:sum', SpColors.ink),
  ];

  /// Занятость 09–21 по часам: 0 — свободно, иначе цвет.
  List<Color?> busy() {
    final out = List<Color?>.filled(12, null);
    for (final e in s.eventsOn(s.todayYmd)) {
      final a = DateTime.tryParse(((e['start'] as Map?)?['dateTime'] ?? '') as String)?.toLocal();
      final b = DateTime.tryParse(((e['end'] as Map?)?['dateTime'] ?? '') as String)?.toLocal();
      if (a == null || b == null) continue;
      for (var h = a.hour; h < (b.minute > 0 ? b.hour + 1 : b.hour); h++) {
        if (h >= 9 && h < 21) out[h - 9] = SpColors.headBlue;
      }
    }
    for (final (l, t) in items) {
      final slot = s.layTask(t['id'] as String)['slot'] as Map?;
      final a = int.tryParse(((slot?['s'] ?? '') as String).split(':').first);
      if (a == null) continue;
      final e = int.tryParse(((slot?['e'] ?? '') as String).split(':').first) ?? a + 1;
      for (var h = a; h < (e <= a ? a + 1 : e); h++) {
        if (h >= 9 && h < 21) out[h - 9] = headFill(listHue(s, l));
      }
    }
    return out;
  }

  /// Самое длинное свободное окно с текущего часа до 21:00 (час и больше).
  (int, int)? freeWindow() {
    final b = busy();
    final now = DateTime.now().hour + 1;
    (int, int)? best;
    var i = (now - 9).clamp(0, 12);
    while (i < 12) {
      if (b[i] != null) {
        i++;
        continue;
      }
      var j = i;
      while (j < 12 && b[j] == null) {
        j++;
      }
      if (best == null || j - i > best.$2 - best.$1) best = (i, j);
      i = j;
    }
    return best == null ? null : (best.$1 + 9, best.$2 + 9);
  }
}

// ---------- 01 · источники ----------

class _Sources extends StatelessWidget {
  const _Sources({required this.m});
  final _Model m;

  @override
  Widget build(BuildContext context) {
    final s = m.s;
    var n = 0;
    String num() => _two(++n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ColHead('01 · ИСТОЧНИКИ'),
        for (final l in m.bySrc) ...[
          GNode(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GHead(num: num(), name: s.listName(l), kind: viewName(s, l), color: listHue(s, l)),
                for (final (ll, t) in m.items)
                  if (ll == l)
                    SockRow(
                      right: Sock('src:${t['id']}', s.isDone(t) ? const Color(0xFF7C7E88) : listHue(s, l)),
                      child: SrcRow(
                        (t['title'] ?? '') as String,
                        m.timeOf(t),
                        strike: s.isDone(t),
                        tc: s.isDone(t)
                            ? SpColors.dim
                            : (m.next?.$2['id'] == t['id'] ? SpColors.accentInk : SpColors.ink),
                        rc: s.isDone(t)
                            ? SpColors.dim
                            : (m.late(t)
                                  ? SpColors.red
                                  : (m.next?.$2['id'] == t['id'] ? SpColors.accentInk : SpColors.muted)),
                        onTap: () => openTask(context, s, l, t),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 28),
        ],
        if (m.inbox.isNotEmpty) ...[
          GNode(
            wait: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GHead(num: num(), name: 'От Claude', kind: 'ждут', color: SpColors.grey),
                for (final x in m.inbox)
                  SockRow(
                    right: Sock('src:in:${(x['task'] as Json)['id']}', SpColors.grey, ring: true),
                    child: SrcRow(
                      ((x['task'] as Json)['title'] ?? '') as String,
                      '→ ${(x['list'] ?? '').toString().toUpperCase()}',
                      rc: SpColors.blue,
                      onTap: () async {
                        final to = await pickList(context, s);
                        if (to != null) {
                          s.acceptInbox([
                            {...x, 'dest': to},
                          ]);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),
        ],
        if (m.habits.isNotEmpty)
          GNode(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GHead(num: num(), name: 'Привычки', kind: 'серии', color: SpColors.gold),
                for (final h in m.habits)
                  SockRow(
                    right: Sock('src:hb:${h['id']}', SpColors.gold),
                    child: SrcRow(
                      (h['name'] ?? '') as String,
                      _streak(h),
                      rc: hb.isDone(s.habitLog, h['id'], s.todayYmd) ? SpColors.gold : SpColors.muted,
                      onTap: () => s.toggleHabit(h),
                    ),
                  ),
              ],
            ),
          ),
        if (m.bySrc.isEmpty && m.inbox.isEmpty && m.habits.isEmpty)
          Text('Сегодня ни в одном списке нет дел', style: SpType.text(12.5, color: SpColors.dim)),
      ],
    );
  }

  String _streak(Json h) {
    final st = hb.stats(h, m.s.habitLog);
    final n = st['streak'] as int;
    final week = h['perWeek'] is num && (h['perWeek'] as num) > 0;
    return '$n ${week ? 'НЕД' : 'ДН'}';
  }
}

// ---------- 02 · сборка дня ----------

class _Hub extends StatelessWidget {
  const _Hub({required this.m});
  final _Model m;

  @override
  Widget build(BuildContext context) {
    final s = m.s;
    final d = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ColHead('02 · СБОРКА ДНЯ'),
        InviteBar(s: s),
        GNode(
          hub: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GHead(
                hub: true,
                height: 34,
                name: 'Сегодня  ${_wd[d.weekday - 1]} ${_two(d.day)}.${_two(d.month)}',
                kind: '${m.open} ${_tasksWord(m.open)} · ${m.habits.length} ${_habitsWord(m.habits.length)}',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: _Add(s: s),
              ),
              if (m.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                  child: Text('На сегодня ничего. Добавь строкой выше.', style: SpType.text(13, color: SpColors.dim)),
                ),
              for (final (i, (l, t)) in m.items.indexed)
                SockRow(
                  left: Sock('hub:${t['id']}', s.isDone(t) ? const Color(0xFF7C7E88) : listHue(s, l)),
                  right: m.next?.$2['id'] == t['id'] ? const Sock('hub:next', SpColors.accent) : null,
                  child: m.next?.$2['id'] == t['id']
                      ? _NextRow(m: m, n: i + 1, listId: l, t: t)
                      : _Row(m: m, n: i + 1, listId: l, t: t),
                ),
              if (m.inbox.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: SockRow(
                    left: const Sock('hub:inbox', SpColors.grey, ring: true),
                    child: Dashed(
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 22,
                              child: Text('+${m.inbox.length}', style: gMono(10.5, c: SpColors.dim)),
                            ),
                            Expanded(
                              child: Text(
                                'От Claude ждут ${m.inbox.length} ${_tasksWord(m.inbox.length)}: взять в день?',
                                style: SpType.text(13, color: SpColors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            GBtn('Принять', sm: true, border: kWait, onTap: () => s.acceptInbox(m.inbox)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (m.habits.isNotEmpty)
                SockRow(
                  left: const Sock('hub:habits', SpColors.gold),
                  right: const Sock('hub:sum', SpColors.ink),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFF8A7424))),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text('ПРИВЫЧКИ', style: gLbl(c: SpColors.gold)),
                            const Spacer(),
                            Text('${m.habitsDone} / ${m.habits.length}', style: gLbl(c: SpColors.dim)),
                          ],
                        ),
                        const SizedBox(height: 9),
                        Wrap(spacing: 6, runSpacing: 6, children: [for (final h in m.habits) _pill(s, h)]),
                      ],
                    ),
                  ),
                )
              else
                SockRow(right: const Sock('hub:sum', SpColors.ink), child: const SizedBox(height: 16)),
              const SizedBox(height: 4),
            ],
          ),
        ),
        const SizedBox(height: 14),
        DimLine(_dimText(m)),
      ],
    );
  }

  Widget _pill(AppState s, Json h) {
    final done = hb.isDone(s.habitLog, h['id'], s.todayYmd);
    final g = hb.goalN(h);
    final n = hb.stats(h, s.habitLog)['streak'] as int;
    final label = done
        ? '${h['name']}${n > 0 ? ' · $n' : ''}'
        : (g > 0 ? '${h['name']} ${hb.countOn(s.habitLog, h, s.todayYmd)}/$g' : '${h['name']}');
    return HabitPill(label, done: done, onTap: () => s.toggleHabit(h));
  }

  String _dimText(_Model m) {
    final b = m.busy();
    final h = b.where((x) => x != null).length;
    final w = m.freeWindow();
    return '09:00 — 21:00 · ЗАНЯТО $h Ч${w == null ? '' : ' · СВОБОДНО ${w.$1}—${w.$2}'}';
  }
}

String _tasksWord(int n) => hb.plural(n, ['задача', 'задачи', 'задач']);
String _habitsWord(int n) => hb.plural(n, ['привычка', 'привычки', 'привычек']);

class _Add extends StatefulWidget {
  const _Add({required this.s});
  final AppState s;
  @override
  State<_Add> createState() => _AddState();
}

class _AddState extends State<_Add> {
  final c = TextEditingController();
  final f = FocusNode();

  @override
  Widget build(BuildContext context) => Container(
    height: 36,
    padding: const EdgeInsets.fromLTRB(10, 0, 8, 0),
    decoration: BoxDecoration(
      color: SpColors.bg,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: SpColors.line),
    ),
    child: Row(
      children: [
        Text(
          '+',
          style: SpType.text(13, color: SpColors.accent, w: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: c,
            focusNode: f,
            autofocus: true,
            style: SpType.text(13),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: 'Добавить: «завтра 17:00 рендер щита»',
              hintStyle: SpType.text(13, color: SpColors.dim),
            ),
            onSubmitted: (v) {
              if (v.trim().isEmpty) return;
              final r = widget.s.addLine(v);
              if (r != null) widget.s.say('Добавлено в «${widget.s.listName(r.listId)}»: ${r.title}');
              c.clear();
              f.requestFocus();
            },
          ),
        ),
        Text('ENTER', style: SpType.label(10, color: SpColors.dim, spacing: .1)),
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.m, required this.n, required this.listId, required this.t});
  final _Model m;
  final int n;
  final String listId;
  final Json t;

  @override
  Widget build(BuildContext context) {
    final s = m.s;
    final done = s.isDone(t);
    final prio = (s.layTask(t['id'] as String)['priority'] as num?)?.toInt();
    return InkWell(
      onTap: () => openTask(context, s, listId, t),
      child: Container(
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: SpColors.lineSoft)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              child: Text(_two(n), style: gMono(10.5, c: SpColors.dim)),
            ),
            const SizedBox(width: 12),
            GCheck(
              done: done,
              color: SpColors.muted,
              onTap: () {
                s.toggleDone(listId, t);
                if (!done) s.say('Готово · ${t['title']}', () => s.toggleDone(listId, t));
              },
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 42,
              child: Text(
                m.timeOf(t),
                style: gMono(11.5, c: done ? SpColors.dim : (m.late(t) ? SpColors.red : SpColors.muted)),
                maxLines: 1,
                overflow: TextOverflow.clip,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                (t['title'] ?? '') as String,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SpType.text(
                  13,
                  color: done ? SpColors.dim : SpColors.ink,
                ).copyWith(decoration: done ? TextDecoration.lineThrough : null, decorationColor: SpColors.dim),
              ),
            ),
            if (prio == 1 && !done) Text('!!!  ', style: gMono(10.5, c: SpColors.red)),
            GDot(listHue(s, listId)),
          ],
        ),
      ),
    );
  }
}

/// «Дальше» прямо в списке: оранжевая рамка со штриховкой, этапы, «Начать» и «Перенести».
class _NextRow extends StatelessWidget {
  const _NextRow({required this.m, required this.n, required this.listId, required this.t});
  final _Model m;
  final int n;
  final String listId;
  final Json t;

  @override
  Widget build(BuildContext context) {
    final s = m.s;
    final cols = (s.board(listId)['cols'] as List).cast<Map>();
    final cur = s.colOf(t, cols);
    final ci = cols.indexWhere((c) => c['id'] == cur);
    final why = meta.nextReason(t, m.lt, s.todayYmd, humanDay);
    final slot = s.layTask(t['id'] as String)['slot'] as Map?;
    final prio = (s.layTask(t['id'] as String)['priority'] as num?)?.toInt();
    final right = [
      if (slot?['e'] != null) 'ДО ${slot!['e']}',
      if (prio == 1) '!!!' else if (prio == 2) '!!',
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SpColors.accentWash,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SpColors.accent),
      ),
      child: CustomPaint(
        painter: _Hatch(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => openTask(context, s, listId, t),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    child: Text(_two(n), style: gMono(10.5, c: SpColors.accent)),
                  ),
                  const SizedBox(width: 12),
                  GCheck(
                    done: false,
                    color: SpColors.accent,
                    onTap: () {
                      s.toggleDone(listId, t);
                      s.say('Готово · ${t['title']}', () => s.toggleDone(listId, t));
                    },
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 42,
                    child: Text(m.timeOf(t), style: gMono(11.5, c: SpColors.accentInk)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      (t['title'] ?? '') as String,
                      style: SpType.text(14, w: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('ДАЛЬШЕ · ${why.toUpperCase()}', style: gLbl(c: SpColors.accent, size: 10)),
                ],
              ),
            ),
            if (cols.length > 2) ...[
              const SizedBox(height: 9),
              Padding(
                padding: const EdgeInsets.only(left: 82),
                child: GStages(done: ci < 0 ? 0 : ci, now: ci, total: cols.length),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 82),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final (i, c) in cols.indexed)
                      Flexible(
                        child: Text(
                          ((c['name'] ?? '') as String).toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SpType.label(10, color: i == ci ? SpColors.accent : SpColors.dim, spacing: .1),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 9),
            Padding(
              padding: const EdgeInsets.only(left: 82),
              child: Row(
                children: [
                  Flexible(
                    flex: 4,
                    child: GBtn(
                      ci >= 0 && ci < cols.length - 2 ? '▶ Дальше: ${cols[ci + 1]['name']}' : '▶ Начать',
                      kind: BtnKind.acc,
                      sm: true,
                      onTap: () {
                        if (ci >= 0 && ci < cols.length - 2) {
                          s.setStage(listId, t, cols[ci + 1]['id'] as String);
                        } else if (cols.length > 1) {
                          s.setStage(listId, t, cols[1]['id'] as String);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  GBtn(
                    'Перенести',
                    sm: true,
                    border: SpColors.accentLine,
                    onTap: () {
                      final tm = ymd(DateTime.now().add(const Duration(days: 1)));
                      s.setDue(listId, t, tm);
                      s.say('Перенесено на завтра · ${t['title']}');
                    },
                  ),
                  const Spacer(),
                  if (right.isNotEmpty)
                    Text(right, style: SpType.label(10, color: const Color(0xFFD8C2A5), spacing: .1)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hatch extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x12F0A04B)
      ..strokeWidth = 1;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var x = -size.height; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------- 03 · вывод ----------

class _Output extends StatelessWidget {
  const _Output({required this.m});
  final _Model m;

  @override
  Widget build(BuildContext context) {
    final s = m.s;
    final nx = m.next;
    final b = m.busy();
    final w = m.freeWindow();
    final tasksDone = m.items.where((x) => s.isDone(x.$2)).length;
    final d = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ColHead('03 · ВЫВОД'),
        if (nx != null) ...[
          GNode(
            child: SockRow(
              left: const Sock('out:next', SpColors.accent),
              child: InkWell(
                onTap: () => openTask(context, s, nx.$1, nx.$2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GHead(
                      num: 'В1',
                      name: 'Дальше',
                      kind: meta.nextReason(nx.$2, m.lt, s.todayYmd, humanDay),
                      color: SpColors.accent,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_thumb(s, nx.$2) case final Widget img) ...[img, const SizedBox(height: 8)],
                          Text((nx.$2['title'] ?? '') as String, style: SpType.text(14, w: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text(
                            _nextMeta(s, nx.$1, nx.$2),
                            style: SpType.label(10.5, color: SpColors.muted, spacing: .08),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 36),
        ],
        GNode(
          child: SockRow(
            left: const Sock('out:sum', SpColors.ink),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const GHead(num: 'В2', name: 'Итог дня', color: SpColors.grey),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sumRow('Задачи', '$tasksDone / ${m.items.length}'),
                      _sumRow('Привычки', '${m.habitsDone} / ${m.habits.length}'),
                      const SizedBox(height: 8),
                      const DimLine('12 Ч'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (final (i, c) in b.indexed) ...[
                            if (i > 0) const SizedBox(width: 2),
                            Expanded(
                              child: c == null && w != null && i + 9 >= w.$1 && i + 9 < w.$2
                                  ? Dashed(r: 2, child: Container(height: 14, color: SpColors.bg))
                                  : Container(
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: c ?? const Color(0xFF36373D),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (final t in ['09', '15', '21']) Text(t, style: gMicro()),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 26),
        CoonTip(
          pose: s.offline ? 'oops' : (m.open == 0 && m.items.isNotEmpty ? 'cheer' : (w != null ? 'think' : 'hi')),
          text: s.offline
              ? 'Нет связи с Google. Всё, что сделаешь, уйдёт, когда она вернётся.'
              : m.open == 0 && m.items.isNotEmpty
              ? 'На сегодня всё сделано. Можно отдохнуть.'
              : w == null
              ? 'Сегодня плотно. Делай по одной.'
              : 'С ${w.$1} до ${w.$2} свободно.${_spare(m) == null ? '' : ' Поставить туда «${_spare(m)!.$2['title']}»?'}',
          action: w != null && _spare(m) != null && !s.offline ? 'Поставить' : null,
          onAction: () {
            final x = _spare(m);
            if (x == null || w == null) return;
            s.schedule(x.$1, x.$2, s.todayYmd, {'s': '${_two(w.$1)}:00', 'e': '${_two(w.$1 + 1)}:00'});
            s.say('«${x.$2['title']}» — сегодня в ${_two(w.$1)}:00');
          },
        ),
        const SizedBox(height: 22),
        Stamp(
          sheet: 'СЕГОДНЯ',
          date: '${_two(d.day)}.${_two(d.month)}.${_two(d.year % 100)}',
          a: 'ВХОДОВ ${_two(m.bySrc.length + (m.inbox.isEmpty ? 0 : 1) + (m.habits.isEmpty ? 0 : 1))}',
          b: 'ЗАДАЧ ${_two(m.items.length)}',
        ),
      ],
    );
  }

  /// Открытая задача на сегодня без времени — кандидат в свободное окно.
  (String, Json)? _spare(_Model m) {
    for (final (l, t) in m.items) {
      if (m.s.isDone(t)) continue;
      if ((m.s.layTask(t['id'] as String)['slot'] as Map?)?['s'] == null) return (l, t);
    }
    return null;
  }

  Widget _sumRow(String a, String b) => Container(
    padding: const EdgeInsets.only(bottom: 6, top: 2),
    margin: const EdgeInsets.only(bottom: 6),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: SpColors.lineSoft)),
    ),
    child: Row(
      children: [
        Text(a, style: SpType.text(12.5)),
        const Spacer(),
        Text(b, style: gMono(12.5, c: SpColors.ink)),
      ],
    ),
  );

  String _nextMeta(AppState s, String listId, Json t) {
    final slot = s.layTask(t['id'] as String)['slot'] as Map?;
    final cols = (s.board(listId)['cols'] as List).cast<Map>();
    final ci = cols.indexWhere((c) => c['id'] == s.colOf(t, cols));
    return [
      if (slot?['s'] != null) '${slot!['s']}${slot['e'] != null ? '—${slot['e']}' : ''}',
      s.listName(listId).toUpperCase(),
      if (cols.length > 2 && ci >= 0) 'ЭТАП ${ci + 1}/${cols.length}',
    ].join(' · ');
  }

  Widget? _thumb(AppState s, Json t) {
    final th = (s.layTask(t['id'] as String)['preview'] as Map?)?['thumb'];
    if (th is! String || !th.startsWith('data:image')) return null;
    try {
      final bytes = UriData.parse(th).contentAsBytes();
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(bytes, height: 110, width: double.infinity, fit: BoxFit.cover),
      );
    } catch (_) {
      return null;
    }
  }
}

/// «14:30» или «весь день».
String eventTime(Json e) {
  final dt = DateTime.tryParse(((e['start'] as Map?)?['dateTime'] ?? '') as String)?.toLocal();
  if (dt == null) return 'весь день';
  return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
