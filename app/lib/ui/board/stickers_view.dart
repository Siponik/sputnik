// Вид «Стикеры» по макету G_Stickers: колонки-темы (точка, ЗАГЛАВНЫЕ, счётчик, линия), стикер — карточка с кружком
// «сделано», сроком и закрепом, сегодняшний — оранжевый со штриховкой; «+ Стикер» в теме, «+ Тема», внизу «Баночка»
// со столбиками за неделю, совет енота и штамп. Логика раскладки — core/stickers.dart.
import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/stickers.dart' as stk;
import '../../state/app_state.dart';
import '../g/kit.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/task_dialog.dart';
import 'card_menu.dart';
import 'rows_view.dart' show archiveDialog;

class StickersView extends StatelessWidget {
  const StickersView({super.key, required this.s, required this.listId});
  final AppState s;
  final String listId;

  @override
  Widget build(BuildContext context) {
    final L = s.layList(listId);
    final group = (L['group'] ?? 'topic') as String;
    final topics = stk.topicsOf(L);
    final today = s.todayYmd;
    final lanes = stk
        .lanes(
          s.topTasks(listId),
          group: group == 'when' ? 'when' : 'topic',
          topics: topics,
          layTasks: s.layer['tasks'] as Map?,
          today: today,
          sort: L['sort'] == 'due' ? 'due' : 'pin',
        )
        .where((l) => group == 'when' || (l['items'] as List).isNotEmpty)
        .toList();
    final done = s.topTasks(listId, withDone: true).where(s.isDone).toList();
    final week = stk.jarCount(done);
    final open = s.topTasks(listId).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            GSeg(
              items: const ['По темам', 'По срокам'],
              active: group == 'when' ? 1 : 0,
              onTap: (i) => s.setListField(listId, {'group': i == 1 ? 'when' : 'topic'}),
            ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              const gap = 16.0;
              final add = group == 'when' ? 0.0 : 110.0 + gap;
              final w = ((box.maxWidth - add - gap * (lanes.length - 1)) / lanes.length).clamp(200.0, 320.0);
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final (i, lane) in lanes.indexed) ...[
                            if (i > 0) const SizedBox(width: gap),
                            SizedBox(width: w, child: _lane(context, lane, group, today, topics)),
                          ],
                          if (group != 'when') ...[
                            const SizedBox(width: gap),
                            SizedBox(
                              width: 110,
                              height: 120,
                              child: InkWell(
                                onTap: () => _newTopic(context),
                                child: Dashed(
                                  child: Center(
                                    child: Text('+ ТЕМА', style: gMicro(c: SpColors.muted)),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      height: 120,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 5, child: _jar(context, done, week)),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 5,
                            child: CoonTip(
                              pose: open == 0 ? 'cheer' : 'think',
                              text: open == 0
                                  ? 'Все стикеры сделаны. Красота.'
                                  : 'Сделанное уходит в баночку сразу. Осталось $open.',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Stamp(
                              width: 220,
                              sheet: 'ДОСКА · СТИКЕРЫ',
                              date: _date(),
                              a: 'ТЕМ ${topics.length.toString().padLeft(2, '0')}',
                              b: 'ДЕЛ ${open.toString().padLeft(2, '0')}',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _date() {
    final d = DateTime.now();
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${two(d.year % 100)}';
  }

  Future<void> _newTopic(BuildContext context) async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: SpColors.node,
        title: const Text('Новая тема'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Покупки, Дом, Кот…'),
          onSubmitted: (v) => Navigator.pop(d, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(d, c.text), child: const Text('Добавить')),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    final ts = [...stk.topicsOf(s.layList(listId))];
    final id = name.trim().toLowerCase().replaceAll(' ', '-');
    if (ts.any((t) => (t as Map)['id'] == id)) return;
    ts.add({'id': id, 'name': name.trim(), 'c': 'var(--type-work)'});
    s.setListField(listId, {'topics': ts});
  }

  Widget _jar(BuildContext context, List<Json> done, int week) {
    final now = DateTime.now();
    final mon = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final per = List<int>.filled(7, 0);
    Json? last;
    for (final t in done) {
      final c = DateTime.tryParse((t['completed'] ?? '') as String)?.toLocal();
      if (c == null) continue;
      if (last == null || ((last['completed'] ?? '') as String).compareTo(t['completed'] as String) < 0) last = t;
      final k = DateTime(c.year, c.month, c.day).difference(mon).inDays;
      if (k >= 0 && k < 7) per[k]++;
    }
    final mx = per.fold(1, (a, b) => b > a ? b : a);
    return GNode(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GHead(name: 'Баночка · сделано', kind: '$week за неделю', color: SpColors.green),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (final (k, v) in per.indexed) ...[
                                if (k > 0) const SizedBox(width: 5),
                                Container(
                                  width: 12,
                                  height: v == 0 ? 8 : 8 + 30 * v / mx,
                                  decoration: BoxDecoration(
                                    color: v == 0 ? kBar : SpColors.green,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('ПН ВТ СР ЧТ ПТ СБ ВС', style: SpType.label(8, color: SpColors.dim, spacing: .1)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: last == null ? 'Пока пусто. ' : 'Последнее: «${last['title']}». ',
                        children: [
                          WidgetSpan(
                            child: InkWell(
                              onTap: () => archiveDialog(context, s, listId),
                              child: Text(
                                'Открыть баночку',
                                style: SpType.text(
                                  12.5,
                                  color: SpColors.accent,
                                ).copyWith(decoration: TextDecoration.underline, decorationColor: SpColors.accent),
                              ),
                            ),
                          ),
                        ],
                      ),
                      style: SpType.text(12.5, color: SpColors.ink2),
                      maxLines: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lane(BuildContext context, Json lane, String group, String today, List topics) {
    final c = cssColor(lane['c']);
    final items = (lane['items'] as List).cast<Json>();
    return DragTarget<(String, Json)>(
      onWillAcceptWithDetails: (d) => d.data.$1 == listId,
      onAcceptWithDetails: (d) {
        final id = d.data.$2['id'] as String;
        if (group == 'when') {
          final due = stk.whenDue(lane['id'] as String, (d.data.$2['due'] as String?)?.substring(0, 10), today);
          s.setDue(listId, d.data.$2, due);
        } else {
          s.setTask(id, {'topic': lane['id'] == '' ? null : lane['id']});
        }
      },
      builder: (context, cand, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GDot(c),
              const SizedBox(width: 8),
              Text((lane['name'] as String).toUpperCase(), style: gLbl(c: SpColors.ink, size: 10)),
              const SizedBox(width: 8),
              Text('${items.length}', style: gMicro()),
              const SizedBox(width: 10),
              const Expanded(child: Divider(height: 1, color: SpColors.line)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: cand.isNotEmpty
                ? BoxDecoration(
                    border: Border.all(color: SpColors.accent),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final t in items) _sticker(context, t, c, today),
                _NewSticker(
                  onAdd: (v) {
                    final p = stk.parseSticker(v, topics);
                    final title = (p['title'] ?? v) as String;
                    s.addTask(
                      listId,
                      title,
                      due: (p['day'] as String?) ?? (group == 'when' ? stk.newDue(lane['id'] as String, today) : null),
                      layerPatch: {
                        'topic': ?(p['topic'] ?? (group == 'when' || lane['id'] == '' ? null : lane['id'])),
                        'priority': ?p['priority'],
                        if (p['time'] != null) 'slot': {'s': p['time']},
                        'repeat': ?p['repeat'],
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sticker(BuildContext context, Json t, Color c, String today) {
    final L = s.layTask(t['id'] as String);
    final pin = L['pin'] == true;
    final due = stk.dueLabel(
      (t['due'] as String?)?.substring(0, 10),
      today,
      L['slot'],
      (s.layList(listId)['group'] ?? 'topic') == 'when',
    );
    final isToday = dueToYmd(t['due'] as String?) == today;
    final late = due['cls'] == 'late';
    Widget body = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: isToday ? SpColors.accentWash : SpColors.node,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isToday ? SpColors.accent : SpColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkResponse(
                onTap: () => s.toggleDone(listId, t),
                radius: 14,
                child: Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: s.isDone(t) ? SpColors.green : null,
                    border: Border.all(color: SpColors.green, width: 1.3),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => openTask(context, s, listId, t),
                  child: Text((t['title'] ?? '') as String, style: SpType.text(13.5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                ((due['text'] ?? '') as String).toUpperCase(),
                style: gMicro(c: isToday ? SpColors.accent : (late ? SpColors.red : SpColors.dim)),
              ),
              if (pin) ...[
                const SizedBox(width: 10),
                InkWell(
                  onTap: () => s.setTask(t['id'] as String, {'pin': false}),
                  child: Text('◉ ЗАКРЕП', style: gMicro(c: SpColors.accent)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
    if (isToday) body = CustomPaint(foregroundPainter: _Hatch(), child: body);
    return GestureDetector(
      onSecondaryTapUp: (d) => cardMenu(context, s, listId, t, d.globalPosition),
      child: Draggable<(String, Json)>(
        data: (listId, t),
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(width: 220, child: body),
        ),
        childWhenDragging: Opacity(opacity: .3, child: body),
        child: body,
      ),
    );
  }
}

class _Hatch extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x10F0A04B)
      ..strokeWidth = 1;
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height - 10), const Radius.circular(8)),
    );
    for (var x = -size.height; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NewSticker extends StatefulWidget {
  const _NewSticker({required this.onAdd});
  final void Function(String) onAdd;
  @override
  State<_NewSticker> createState() => _NewStickerState();
}

class _NewStickerState extends State<_NewSticker> {
  bool open = false;
  final c = TextEditingController();
  final f = FocusNode();
  @override
  Widget build(BuildContext context) => open
      ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: SpColors.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: SpColors.accent),
          ),
          child: TextField(
            controller: c,
            focusNode: f,
            autofocus: true,
            style: SpType.text(13),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: '«купить хлеб завтра»',
            ),
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) widget.onAdd(v.trim());
              c.clear();
              f.requestFocus();
            },
            onTapOutside: (_) => setState(() => open = false),
          ),
        )
      : InkWell(
          onTap: () => setState(() => open = true),
          child: Dashed(
            child: SizedBox(
              height: 40,
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Text('+ Стикер', style: SpType.text(13, color: SpColors.muted)),
                ],
              ),
            ),
          ),
        );
}
