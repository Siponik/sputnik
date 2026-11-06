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
                    const SizedBox(height: 28),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: (w * 2 + gap).clamp(320.0, 520.0),
                        child: _jar(context, done, week, topics),
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

  /// Баночка: банка, в которую падают цветные квадратики сделанного (цвет темы).
  Widget _jar(BuildContext context, List<Json> done, int week, List topics) {
    final sorted = [...done]
      ..sort((a, b) => ((b['completed'] ?? '') as String).compareTo((a['completed'] ?? '') as String));
    final last = sorted.firstOrNull;
    Color hue(Json t) {
      final tp = s.layTask(t['id'] as String)['topic'];
      final m = topics.cast<Map>().where((x) => x['id'] == tp).firstOrNull;
      return m == null ? SpColors.grey : cssColor(m['c']);
    }

    final sq = [for (final t in sorted.take(9)) hue(t)];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SpColors.node,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpColors.line),
      ),
      child: Row(
        children: [
          _Jar(colors: sq),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Баночка · $week за неделю', style: SpType.text(13.5, w: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  last == null
                      ? 'Пока пусто. Сделанный стикер падает сюда.'
                      : 'Последнее: «${last['title']}». Сделанный стикер падает сюда.',
                  style: SpType.text(12.5, color: SpColors.ink2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => archiveDialog(context, s, listId),
                  child: Text(
                    'Открыть баночку',
                    style: SpType.text(
                      12.5,
                      color: SpColors.accent,
                    ).copyWith(decoration: TextDecoration.underline, decorationColor: SpColors.accent),
                  ),
                ),
              ],
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
              Flexible(
                child: Text(
                  lane['name'] as String,
                  style: SpType.text(13.5, w: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text('${items.length}', style: SpType.text(12.5, color: SpColors.muted)),
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

  /// Стикер — бумажка цвета темы: тёмный оттенок, светлый текст, наклон −2…2°, скотч или красная кнопка,
  /// мягкая тень, загнутый угол. Кружок «сделано» и срок — внизу.
  Widget _sticker(BuildContext context, Json t, Color c, String today) {
    final id = t['id'] as String;
    final L = s.layTask(id);
    final pin = L['pin'] == true;
    final due = stk.dueLabel(
      (t['due'] as String?)?.substring(0, 10),
      today,
      L['slot'],
      (s.layList(listId)['group'] ?? 'topic') == 'when',
    );
    final isToday = dueToYmd(t['due'] as String?) == today;
    final late = due['cls'] == 'late';
    final paper = Color.lerp(c, const Color(0xFF15161A), .74)!;
    final ink = Color.lerp(c, Colors.white, .45)!;
    final h = id.codeUnits.fold(7, (a, b) => (a * 31 + b) & 0xFFFF);
    final turn = ((h % 41) - 20) / 10 * 3.14159 / 180; // −2…2°
    final done = s.isDone(t);
    Widget body = Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
      decoration: BoxDecoration(
        color: paper,
        borderRadius: BorderRadius.circular(4),
        border: isToday ? Border.all(color: SpColors.accent, width: 1.5) : null,
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => openTask(context, s, listId, t),
            child: Text(
              (t['title'] ?? '') as String,
              style: SpType.text(14, w: FontWeight.w500, color: ink),
            ),
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              InkResponse(
                onTap: () => s.toggleDone(listId, t),
                radius: 14,
                child: Container(
                  width: 17,
                  height: 17,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? ink : null,
                    border: Border.all(color: ink.withValues(alpha: .8), width: 1.3),
                  ),
                  child: done ? Icon(Icons.check, size: 11, color: paper) : null,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  ((due['text'] ?? '') as String).isEmpty ? 'без срока' : due['text'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SpType.text(12, color: late ? SpColors.red : ink.withValues(alpha: .75)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    body = CustomPaint(foregroundPainter: _Fold(paper), child: body);
    body = Stack(
      clipBehavior: Clip.none,
      children: [
        body,
        Positioned(
          top: -6,
          left: 0,
          right: 0,
          child: Center(
            child: pin
                ? InkWell(
                    onTap: () => s.setTask(id, {'pin': false}),
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8604C),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Color(0x88000000), blurRadius: 3, offset: Offset(0, 2))],
                      ),
                    ),
                  )
                : Container(width: 54, height: 12, color: const Color(0x55A3A5AE)),
          ),
        ),
      ],
    );
    body = Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 4),
      child: Transform.rotate(angle: turn, child: body),
    );
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

/// Загнутый правый нижний угол.
class _Fold extends CustomPainter {
  _Fold(this.paper);
  final Color paper;
  @override
  void paint(Canvas canvas, Size s) {
    const k = 14.0;
    canvas.drawPath(
      Path()
        ..moveTo(s.width - k, s.height)
        ..lineTo(s.width, s.height - k)
        ..lineTo(s.width, s.height)
        ..close(),
      Paint()..color = SpColors.ground,
    );
    canvas.drawPath(
      Path()
        ..moveTo(s.width - k, s.height)
        ..lineTo(s.width, s.height - k)
        ..lineTo(s.width - k, s.height - k)
        ..close(),
      Paint()..color = Color.lerp(paper, Colors.white, .12)!,
    );
  }

  @override
  bool shouldRepaint(_Fold o) => o.paper != paper;
}

/// Банка с падающими квадратиками.
class _Jar extends StatelessWidget {
  const _Jar({required this.colors});
  final List<Color> colors;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 70,
    height: 90,
    child: Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _JarGlass())),
        for (final (i, c) in colors.indexed)
          TweenAnimationBuilder<double>(
            key: ValueKey('$i$c'),
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 420 + i * 60),
            curve: Curves.bounceOut,
            builder: (_, v, w) =>
                Positioned(left: 9.0 + (i % 3) * 18, top: -12 + (80 - 18.0 * (i ~/ 3 + 1) - (-12)) * v, child: w!),
            child: Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
            ),
          ),
      ],
    ),
  );
}

class _JarGlass extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = SpColors.lineStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(1, 10, s.width - 2, s.height - 11), const Radius.circular(10)),
      p,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(8, 0, s.width - 16, 10), const Radius.circular(3)),
      Paint()..color = SpColors.line,
    );
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
