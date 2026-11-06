// Окно задачи (упрощённое): название, колонка, приоритет, срок, заметка, удалить.
import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../state/app_state.dart';
import '../theme/tokens.dart';
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
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(s.listName(widget.listId).toUpperCase(), style: SpType.label(11)),
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
                      const Spacer(),
                      Text(
                        s.outbox.pendingFor(widget.id) ? 'Сохраняю…' : 'Сохранено в Google Tasks',
                        style: SpType.label(11),
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
