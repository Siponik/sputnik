// Вид «Конвейер» (строка = задача, дорожка этапов, группы по проектам) и вид «Список» (строки с меткой этапа).
// Плюс окно «Архив» списка.
import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/task_dialog.dart';
import 'card_menu.dart';

class ConveyorView extends StatelessWidget {
  const ConveyorView({super.key, required this.s, required this.listId});
  final AppState s;
  final String listId;

  @override
  Widget build(BuildContext context) {
    final cols = (s.board(listId)['cols'] as List).cast<Map>();
    final items = s.topTasks(listId, withDone: true);
    final groups = <String, List<Json>>{};
    for (final t in items) {
      final p = (s.layTask(t['id'] as String)['project'] ?? '') as String;
      (groups[p] ??= []).add(t);
    }
    final keys = groups.keys.toList()..sort((a, b) => a.isEmpty ? 1 : (b.isEmpty ? -1 : a.compareTo(b)));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        AddLine(
          hint: 'Новый ассет: название, «@проект» не нужен — проект выберешь в задаче',
          onSubmit: (v) => s.addTask(listId, v, col: cols.first['id'] as String),
        ),
        const SizedBox(height: 14),
        for (final k in keys) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 6),
            child: Text(
              '${k.isEmpty ? 'БЕЗ ПРОЕКТА' : k.toUpperCase()} · ${groups[k]!.length}',
              style: SpType.label(11, color: SpColors.ink2),
            ),
          ),
          Node(
            title: k.isEmpty ? 'Ассеты' : k,
            head: SpColors.headViolet,
            child: Column(children: [for (final t in groups[k]!) _row(context, t, cols)]),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, Json t, List<Map> cols) {
    final cur = s.colOf(t, cols);
    final i = cols.indexWhere((c) => c['id'] == cur);
    final due = dueToYmd(t['due'] as String?);
    final title = (t['title'] ?? '') as String;
    return GestureDetector(
      onSecondaryTapUp: (d) => cardMenu(context, s, listId, t, d.globalPosition),
      child: InkWell(
        onTap: () => openTask(context, s, listId, t),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: SpColors.lineSoft)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: SpColors.bg, borderRadius: BorderRadius.circular(SpRadius.button)),
                child: Text(
                  title.isEmpty ? '?' : title.substring(0, title.length < 2 ? 1 : 2).toUpperCase(),
                  style: SpType.label(12, color: SpColors.ink2),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 220,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SpType.text(14, color: s.isDone(t) ? SpColors.dim : SpColors.ink),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (due.isNotEmpty) Text(humanDay(due), style: SpType.label(10.5)),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    for (final (k, c) in cols.indexed)
                      Expanded(
                        child: Tooltip(
                          message: c['name'] as String,
                          child: InkWell(
                            onTap: () => s.setStage(listId, t, c['id'] as String),
                            child: Container(
                              height: 22,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: k < i
                                    ? SpColors.accentWash
                                    : k == i
                                    ? SpColors.accent
                                    : SpColors.bg,
                                borderRadius: BorderRadius.circular(SpRadius.socket),
                                border: Border.all(color: k <= i ? SpColors.accentLine : SpColors.lineSoft),
                              ),
                              child: Text(
                                c['name'] as String,
                                style: SpType.label(
                                  9.5,
                                  color: k == i ? SpColors.onAccent : SpColors.muted,
                                  spacing: 0,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (i < cols.length - 1)
                TextButton(
                  onPressed: () => s.setStage(listId, t, cols[i + 1]['id'] as String),
                  child: const Text('Этап →'),
                )
              else
                const SizedBox(width: 72),
            ],
          ),
        ),
      ),
    );
  }
}

class ListRowsView extends StatelessWidget {
  const ListRowsView({super.key, required this.s, required this.listId});
  final AppState s;
  final String listId;

  @override
  Widget build(BuildContext context) {
    final cols = (s.board(listId)['cols'] as List).cast<Map>();
    final items = s.topTasks(listId, withDone: true)..sort((a, b) => (s.isDone(a) ? 1 : 0) - (s.isDone(b) ? 1 : 0));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        AddLine(hint: 'Добавить задачу', onSubmit: (v) => s.addTask(listId, v)),
        const SizedBox(height: 12),
        Node(
          title: 'Задачи · ${items.length}',
          child: Column(
            children: [
              for (final t in items)
                GestureDetector(
                  onSecondaryTapUp: (d) => cardMenu(context, s, listId, t, d.globalPosition),
                  child: InkWell(
                    onTap: () => openTask(context, s, listId, t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: SpColors.lineSoft)),
                      ),
                      child: Row(
                        children: [
                          Check(done: s.isDone(t), onTap: () => s.toggleDone(listId, t)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              (t['title'] ?? '') as String,
                              style: SpType.text(14, color: s.isDone(t) ? SpColors.dim : SpColors.ink),
                            ),
                          ),
                          if (dueToYmd(t['due'] as String?).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: Text(humanDay(dueToYmd(t['due'] as String?)), style: SpType.label(11)),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: SpColors.bg,
                              borderRadius: BorderRadius.circular(SpRadius.socket),
                            ),
                            child: Text(
                              (cols.firstWhere((c) => c['id'] == s.colOf(t, cols))['name'] ?? '') as String,
                              style: SpType.label(10.5),
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
}

Future<void> archiveDialog(BuildContext context, AppState s, String listId) => showDialog<void>(
  context: context,
  builder: (_) => ListenableBuilder(
    listenable: s,
    builder: (context, _) {
      final items = s.archived(listId);
      return Dialog(
        backgroundColor: SpColors.node,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Архив · ${s.listName(listId)}', style: SpType.text(18, w: FontWeight.w600)),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 18)),
                  ],
                ),
                Text(
                  'Выполненные за последние 14 дней, ушедшие с доски',
                  style: SpType.text(12.5, color: SpColors.muted),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Text('Пусто', style: SpType.text(14, color: SpColors.muted)),
                        )
                      : ListView(
                          children: [
                            for (final t in items)
                              ListTile(
                                dense: true,
                                title: Text((t['title'] ?? '') as String, style: SpType.text(14)),
                                subtitle: Text(
                                  'сделано ${humanDay(dueToYmd(t['completed'] as String?))}',
                                  style: SpType.label(10.5),
                                ),
                                trailing: TextButton(
                                  onPressed: () => s.toggleDone(listId, t),
                                  child: const Text('Вернуть'),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  ),
);
