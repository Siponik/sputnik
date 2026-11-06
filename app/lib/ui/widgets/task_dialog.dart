// Окно задачи (упрощённое): название, колонка, приоритет, срок, заметка, удалить.
import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../state/app_state.dart';
import '../theme/tokens.dart';
import '../../core/reminders.dart' as rem;
import '../../core/repeat.dart' as repeats;
import '../board/card_menu.dart';
import 'common.dart';

Future<void> openTask(BuildContext context, AppState s, String listId, Json t) => showDialog<void>(
  context: context,
  barrierColor: const Color(0x88000000),
  builder: (_) => _TaskDialog(s: s, listId: listId, id: t['id'] as String),
);

class _TaskDialog extends StatefulWidget {
  const _TaskDialog({required this.s, required this.listId, required this.id});
  final AppState s;
  final String listId;
  final String id;

  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  late final TextEditingController title;
  late final TextEditingController notes;

  Json? get t => widget.s.task(widget.listId, widget.id);

  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: (t?['title'] ?? '') as String);
    notes = TextEditingController(text: (t?['notes'] ?? '') as String);
  }

  void _commit() {
    final x = t;
    if (x == null) return;
    if (title.text.trim().isNotEmpty && title.text != x['title']) widget.s.rename(widget.listId, x, title.text.trim());
    if (notes.text != (x['notes'] ?? '')) widget.s.setNotes(widget.listId, x, notes.text);
  }

  @override
  void dispose() {
    _commit();
    title.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final x = t;
        if (x == null) return const SizedBox();
        final cols = s.board(widget.listId)['cols'] as List;
        final cur = s.colOf(x, cols);
        final prio = (s.layTask(widget.id)['priority'] as num?)?.toInt();
        final due = dueToYmd(x['due'] as String?);
        return Dialog(
          backgroundColor: SpColors.node,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SpRadius.hub)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.list, size: 15),
                        label: Text(s.listName(widget.listId)),
                        tooltip: 'Перенести в другой список',
                        onPressed: () async {
                          final to = await pickList(context, s, exclude: widget.listId);
                          if (to == null || !context.mounted) return;
                          Navigator.pop(context);
                          s.moveToList(widget.listId, x, to);
                        },
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Удалить',
                        icon: const Icon(Icons.delete_outline, size: 18, color: SpColors.muted),
                        onPressed: () {
                          Navigator.pop(context);
                          s.remove(widget.listId, x);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: SpColors.muted),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  TextField(
                    controller: title,
                    maxLines: null,
                    style: SpType.text(20, w: FontWeight.w600),
                    decoration: const InputDecoration(border: InputBorder.none, hintText: 'Название'),
                    onSubmitted: (_) => _commit(),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in cols)
                        ChoiceChip(
                          label: Text((c as Map)['name'] as String),
                          selected: cur == c['id'],
                          onSelected: (_) => s.setStage(widget.listId, x, c['id'] as String),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final (n, label) in [(1, '!!! высокий'), (2, '!! обычный'), (3, '! низкий')])
                        ChoiceChip(
                          label: Text(label),
                          selected: prio == n,
                          onSelected: (on) => s.setPriority(x, on ? n : null),
                        ),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.event, size: 16),
                        label: Text(due.isEmpty ? 'Без срока' : _human(due)),
                        onPressed: () async {
                          final now = DateTime.now();
                          final d = await showDatePicker(
                            context: context,
                            locale: const Locale('ru'),
                            initialDate: due.isEmpty ? now : DateTime.parse(due),
                            firstDate: DateTime(now.year - 2),
                            lastDate: DateTime(now.year + 5),
                          );
                          if (d != null) s.setDue(widget.listId, x, ymd(d));
                        },
                      ),
                      if (due.isNotEmpty)
                        ActionChip(label: const Text('Убрать срок'), onPressed: () => s.setDue(widget.listId, x, null)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _more(context, x),
                  const SizedBox(height: 14),
                  TextField(
                    controller: notes,
                    minLines: 3,
                    maxLines: 12,
                    style: SpType.text(14, color: SpColors.body),
                    decoration: InputDecoration(
                      hintText: 'Заметка',
                      filled: true,
                      fillColor: SpColors.bg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(SpRadius.button)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Check(done: s.isDone(x), onTap: () => s.toggleDone(widget.listId, x)),
                      const SizedBox(width: 8),
                      Text(
                        s.isDone(x) ? 'Сделано' : 'Отметить сделанным',
                        style: SpType.text(13, color: SpColors.muted),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.outbox.pendingFor(widget.id) ? 'Сохраняю…' : 'Сохранено в Google Tasks',
                          style: SpType.label(11),
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

extension on _TaskDialogState {
  Widget _more(BuildContext context, Json x) {
    final s = widget.s;
    final id = widget.id;
    final L = s.layTask(id);
    final slot = L['slot'] as Map?;
    final rules = L['remind'] is List ? (L['remind'] as List) : (L['remind'] is Map ? [L['remind']] : const []);
    final mins = {
      for (final r in rules)
        if (r is Map && r['kind'] == 'lead') (r['min'] as num).toInt(),
    };
    final rep = (L['repeat'] as Map?)?['every'];
    final subs = s.subtasks(widget.listId, id);
    final view = s.board(widget.listId)['view'];
    final fields = (s.board(widget.listId)['fields'] as List?) ?? const [];
    Widget label(String t) => Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Text(t.toUpperCase(), style: SpType.label(10.5)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label('Время'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ActionChip(
              avatar: const Icon(Icons.schedule, size: 16),
              label: Text(
                slot?['s'] == null ? 'Без времени' : '${slot!['s']}${slot['e'] == null ? '' : '–${slot['e']}'}',
              ),
              onPressed: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: const TimeOfDay(hour: 10, minute: 0),
                  builder: (c, w) =>
                      MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: w!),
                );
                if (t == null) return;
                final st = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                final e = t.hour >= 23
                    ? '23:59'
                    : '${(t.hour + 1).toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                s.setTask(id, {
                  'slot': {'s': st, 'e': e},
                });
              },
            ),
            if (slot?['s'] != null)
              ActionChip(label: const Text('Убрать время'), onPressed: () => s.setTask(id, {'slot': null})),
          ],
        ),
        label('Напомнить'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final l in rem.leads)
              FilterChip(
                label: Text(l['name'] as String),
                selected: mins.contains(l['min']),
                onSelected: (on) {
                  final next = {...mins};
                  on ? next.add(l['min'] as int) : next.remove(l['min']);
                  s.setTask(id, {
                    'remind': next.isEmpty
                        ? null
                        : [
                            for (final m in next) {'kind': 'lead', 'min': m},
                          ],
                  });
                },
              ),
          ],
        ),
        label('Повтор'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('Нет'),
              selected: rep == null,
              onSelected: (_) => s.setTask(id, {'repeat': null}),
            ),
            for (final r in repeats.repeats)
              ChoiceChip(
                label: Text(r.label),
                selected: rep == r.id,
                onSelected: (_) => s.setTask(id, {
                  'repeat': {'every': r.id},
                }),
              ),
          ],
        ),
        if (view == 'pipe') ...[
          label('Проект'),
          _field(L['project'], 'Название проекта', (v) => s.setTask(id, {'project': v.isEmpty ? null : v})),
        ],
        if (fields.contains('client')) ...[
          label('Клиент и сумма'),
          Row(
            children: [
              Expanded(child: _field(L['client'], 'Клиент', (v) => s.setTask(id, {'client': v.isEmpty ? null : v}))),
              const SizedBox(width: 8),
              SizedBox(
                width: 140,
                child: _field(
                  L['money'],
                  'Сумма',
                  (v) => s.setTask(id, {'money': num.tryParse(v.replaceAll(' ', ''))}),
                ),
              ),
            ],
          ),
        ],
        label('Подзадачи · ${subs.where(s.isDone).length}/${subs.length}'),
        for (final st in subs)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Check(done: s.isDone(st), onTap: () => s.toggleDone(widget.listId, st)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    (st['title'] ?? '') as String,
                    style: SpType.text(13.5, color: s.isDone(st) ? SpColors.dim : SpColors.ink),
                  ),
                ),
                InkWell(
                  onTap: () => s.remove(widget.listId, st),
                  child: const Icon(Icons.close, size: 14, color: SpColors.dim),
                ),
              ],
            ),
          ),
        AddLine(hint: 'Подзадача', onSubmit: (v) => s.addSubtask(widget.listId, id, v)),
      ],
    );
  }

  Widget _field(Object? v, String hint, void Function(String) save) => TextFormField(
    initialValue: v == null ? '' : '$v',
    decoration: InputDecoration(isDense: true, hintText: hint, filled: true, fillColor: SpColors.bg),
    onFieldSubmitted: save,
    onTapOutside: (_) {},
    onChanged: save,
  );
}

const _mon = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];

String _human(String day) {
  final d = DateTime.parse(day);
  final now = DateTime.now();
  final diff = DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  if (diff == 0) return 'Сегодня';
  if (diff == 1) return 'Завтра';
  if (diff == -1) return 'Вчера';
  return '${d.day} ${_mon[d.month - 1]}';
}

String humanDay(String day) => _human(day);
