// Поиск (Ctrl+K или /): задачи по названию и заметке (core/search.dart), переходы к разделам и спискам.
// ↑/↓ — выбор, Enter — открыть, Esc — закрыть.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/search.dart' as srch;
import '../../state/app_state.dart';
import '../theme/tokens.dart';
import 'task_dialog.dart';

/// onGo(tab, listId) — перейти в раздел или к списку на доске.
Future<void> openSearch(BuildContext context, AppState s, void Function(int tab, String? listId) onGo) =>
    showDialog<void>(
      context: context,
      builder: (_) => _Search(s: s, onGo: onGo),
    );

class _Search extends StatefulWidget {
  const _Search({required this.s, required this.onGo});
  final AppState s;
  final void Function(int tab, String? listId) onGo;
  @override
  State<_Search> createState() => _SearchState();
}

class _SearchState extends State<_Search> {
  final q = TextEditingController();
  int sel = 0;

  List<Json> get places => [
    {
      'name': 'Сегодня',
      'tab': 0,
      'alias': ['today'],
    },
    {
      'name': 'Календарь',
      'tab': 1,
      'alias': ['calendar'],
    },
    {
      'name': 'Доска',
      'tab': 2,
      'alias': ['board'],
    },
    {
      'name': 'Привычки',
      'tab': 3,
      'alias': ['habits'],
    },
    {
      'name': 'Настройки',
      'tab': 4,
      'alias': ['settings'],
    },
    for (final l in widget.s.boardLists) {'name': l['title'], 'tab': 2, 'list': l['id'], 'alias': <String>[]},
  ];

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final text = q.text.trim();
    final pl = text.isEmpty ? <Json>[] : srch.findPlaces(text, places).take(5).toList();
    final ts = text.isEmpty ? const [] : srch.findTasks(text, s.boardLists, s.tasks, 20);
    final rows = <(String, String, VoidCallback)>[
      for (final p in pl)
        (
          '→ ${p['name']}',
          p['list'] != null ? 'список' : 'раздел',
          () {
            Navigator.pop(context);
            widget.onGo(p['tab'] as int, p['list'] as String?);
          },
        ),
      for (final r in ts)
        (
          (r.task['title'] ?? '') as String,
          '${r.list['title']}${r.parent != null ? ' · в «${r.parent!['title']}»' : ''}${r.task['status'] == 'completed' ? ' · сделано' : ''}',
          () {
            Navigator.pop(context);
            openTask(context, s, r.list['id'] as String, r.parent ?? r.task);
          },
        ),
    ];
    if (sel >= rows.length) sel = rows.isEmpty ? 0 : rows.length - 1;
    return Dialog(
      alignment: const Alignment(0, -.6),
      backgroundColor: SpColors.node,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 520),
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                setState(() => sel = (sel + 1).clamp(0, rows.length - 1)),
            const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                setState(() => sel = (sel - 1).clamp(0, rows.length - 1)),
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: q,
                  autofocus: true,
                  style: SpType.text(16),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Найти задачу, список или раздел',
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() => sel = 0),
                  onSubmitted: (_) {
                    if (rows.isNotEmpty) rows[sel].$3();
                  },
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: rows.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          text.isEmpty ? 'Начни печатать' : 'Ничего не нашлось',
                          style: SpType.text(13, color: SpColors.muted),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final (i, r) in rows.indexed)
                            ListTile(
                              dense: true,
                              selected: i == sel,
                              selectedTileColor: SpColors.nodeHover,
                              title: Text(r.$1, style: SpType.text(14)),
                              subtitle: Text(r.$2, style: SpType.label(10.5)),
                              onTap: r.$3,
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
