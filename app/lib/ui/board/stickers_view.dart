// Вид «Стикеры»: стена по темам или по срокам, стикер с кружком «сделано», закреп, «баночка» сделанного.
// Логика раскладки — core/stickers.dart.
import 'package:flutter/material.dart';

import '../../core/stickers.dart' as stk;
import '../../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/task_dialog.dart';
import 'card_menu.dart';

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
    final jar = stk.jarCount(s.topTasks(listId, withDone: true).where(s.isDone).toList());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'topic', label: Text('По темам')),
                  ButtonSegment(value: 'when', label: Text('По срокам')),
                ],
                selected: {group == 'when' ? 'when' : 'topic'},
                onSelectionChanged: (v) => s.setListField(listId, {'group': v.first}),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 380,
                child: AddLine(
                  hint: 'Новый стикер: «купить хлеб завтра #покупки»',
                  onSubmit: (v) {
                    final p = stk.parseSticker(v, topics);
                    final title = (p['title'] ?? v) as String;
                    s.addTask(
                      listId,
                      title,
                      due: p['day'] as String?,
                      layerPatch: {
                        if (p['topic'] != null) 'topic': p['topic'],
                        if (p['priority'] != null) 'priority': p['priority'],
                        if (p['time'] != null) 'slot': {'s': p['time']},
                        if (p['repeat'] != null) 'repeat': p['repeat'],
                      },
                    );
                  },
                ),
              ),

              Text('в баночке · $jar', style: SpType.label(11, color: SpColors.gold)),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: [
              for (final lane in lanes)
                SizedBox(
                  width: 250,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: DragTarget<(String, Json)>(
                      onWillAcceptWithDetails: (d) => d.data.$1 == listId,
                      onAcceptWithDetails: (d) {
                        final id = d.data.$2['id'] as String;
                        if (group == 'when') {
                          final due = stk.whenDue(
                            lane['id'] as String,
                            (d.data.$2['due'] as String?)?.substring(0, 10),
                            today,
                          );
                          s.setDue(listId, d.data.$2, due);
                        } else {
                          s.setTask(id, {'topic': lane['id'] == '' ? null : lane['id']});
                        }
                      },
                      builder: (context, cand, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(color: cssColor(lane['c']), shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${(lane['name'] as String).toUpperCase()} · ${(lane['items'] as List).length}',
                                style: SpType.label(11, color: SpColors.ink2),
                              ),
                            ],
                          ),
                          if ((lane['sub'] ?? '') != '')
                            Text(lane['sub'] as String, style: SpType.text(11.5, color: SpColors.dim)),
                          const SizedBox(height: 10),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: cand.isNotEmpty ? SpColors.accent : Colors.transparent),
                                borderRadius: BorderRadius.circular(SpRadius.node),
                              ),
                              child: ListView(
                                children: [
                                  for (final t in (lane['items'] as List).cast<Json>())
                                    _sticker(context, t, cssColor(lane['c']), today),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
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
    final body = Transform.rotate(
      angle: stk.tilt(t['id']) * 3.1416 / 180,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color.alphaBlend(c.withValues(alpha: .14), SpColors.node),
          borderRadius: BorderRadius.circular(SpRadius.button),
          border: Border(top: BorderSide(color: c, width: 3)),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => openTask(context, s, listId, t),
                    child: Text((t['title'] ?? '') as String, style: SpType.text(14, w: FontWeight.w500)),
                  ),
                ),
                InkWell(
                  onTap: () => s.setTask(t['id'] as String, {'pin': !pin}),
                  child: Icon(
                    pin ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 15,
                    color: pin ? SpColors.accent : SpColors.dim,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Check(done: s.isDone(t), onTap: () => s.toggleDone(listId, t)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    due['text'] as String,
                    style: SpType.label(10.5, color: due['cls'] == 'late' ? SpColors.red : SpColors.muted),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return GestureDetector(
      onSecondaryTapUp: (d) => cardMenu(context, s, listId, t, d.globalPosition),
      child: Draggable<(String, Json)>(
        data: (listId, t),
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(width: 234, child: body),
        ),
        childWhenDragging: Opacity(opacity: .3, child: body),
        child: body,
      ),
    );
  }
}
