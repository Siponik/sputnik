// Меню задачи (⋯ или правый клик): колонка, приоритет, срок, в другой список, дублировать, удалить.
import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../state/app_state.dart';
import '../theme/tokens.dart';

Future<void> cardMenu(BuildContext context, AppState s, String listId, Json t, Offset at) async {
  final cols = (s.board(listId)['cols'] as List).cast<Map>();
  final cur = s.colOf(t, cols);
  final today = DateTime.now();
  final v = await showMenu<String>(
    context: context,
    color: SpColors.node,
    position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx + 1, at.dy + 1),
    items: [
      for (final c in cols)
        CheckedPopupMenuItem(value: 'col:${c['id']}', checked: cur == c['id'], child: Text('→ ${c['name']}')),
      const PopupMenuDivider(),
      const PopupMenuItem(value: 'p:1', child: Text('!!! Высокий приоритет')),
      const PopupMenuItem(value: 'p:2', child: Text('!! Обычный')),
      const PopupMenuItem(value: 'p:3', child: Text('! Низкий')),
      const PopupMenuItem(value: 'p:0', child: Text('Без приоритета')),
      const PopupMenuDivider(),
      const PopupMenuItem(value: 'd:0', child: Text('Срок: сегодня')),
      const PopupMenuItem(value: 'd:1', child: Text('Срок: завтра')),
      const PopupMenuItem(value: 'd:7', child: Text('Срок: через неделю')),
      const PopupMenuItem(value: 'd:-', child: Text('Без срока')),
      const PopupMenuDivider(),
      const PopupMenuItem(value: 'move', child: Text('В другой список…')),
      const PopupMenuItem(value: 'dup', child: Text('Дублировать')),
      const PopupMenuItem(value: 'del', child: Text('Удалить')),
    ],
  );
  if (v == null || !context.mounted) return;
  if (v.startsWith('col:')) return s.setStage(listId, t, v.substring(4));
  if (v.startsWith('p:')) {
    final n = int.parse(v.substring(2));
    return s.setPriority(t, n == 0 ? null : n);
  }
  if (v == 'd:-') return s.setDue(listId, t, null);
  if (v.startsWith('d:')) {
    return s.setDue(listId, t, ymd(DateTime(today.year, today.month, today.day + int.parse(v.substring(2)))));
  }
  if (v == 'dup') return s.duplicate(listId, t);
  if (v == 'del') return s.remove(listId, t);
  if (v == 'move') {
    final to = await pickList(context, s, exclude: listId);
    if (to != null) s.moveToList(listId, t, to);
  }
}

/// Выбор списка (по сферам не группируем — просто по алфавиту Google).
Future<String?> pickList(BuildContext context, AppState s, {String? exclude, String title = 'Куда'}) =>
    showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        backgroundColor: SpColors.node,
        title: Text(title, style: SpType.text(16, w: FontWeight.w600)),
        children: [
          for (final (i, l) in s.boardLists.where((l) => l['id'] != exclude).indexed)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, l['id'] as String),
              child: Row(
                children: [
                  SizedBox(width: 22, child: Text(i < 9 ? '${i + 1}' : '', style: SpType.label(11))),
                  Text((l['title'] ?? '') as String, style: SpType.text(14)),
                ],
              ),
            ),
        ],
      ),
    );
