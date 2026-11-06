// Поиск (Ctrl+K или /): задачи по названию и заметке (core/search.dart), переходы к разделам и спискам.
// ↑/↓ — выбор, Enter — открыть, Esc — закрыть.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/search.dart' as srch;
import '../../state/app_state.dart';
import '../theme/tokens.dart';
import 'task_dialog.dart';
import '../g/kit.dart';
import '../today/today_page.dart' show listHue;

/// onGo(tab, listId) — перейти в раздел или к списку на доске.
/// [anchor] — поле «Найти» в шапке: оно растёт до 400 px, результаты выпадают под ним (560 px, по правому краю).
Future<void> openSearch(
  BuildContext context,
  AppState s,
  void Function(int tab, String? listId) onGo, {
  Rect? anchor,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Закрыть',
  barrierColor: Colors.black26,
  transitionDuration: const Duration(milliseconds: 180),
  pageBuilder: (_, _, _) => _Search(s: s, onGo: onGo, anchor: anchor),
  transitionBuilder: (c, a, _, w) {
    final k = CurvedAnimation(parent: a, curve: const Cubic(.2, .8, .2, 1));
    return FadeTransition(
      opacity: k,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, -.01), end: Offset.zero).animate(k),
        child: w,
      ),
    );
  },
);

class _Search extends StatefulWidget {
  const _Search({required this.s, required this.onGo, this.anchor});
  final Rect? anchor;
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
    // (группа, название, справа, список, задача, действие)
    final rows = <(String, String, String, String?, Json?, VoidCallback)>[
      for (final r in ts)
        (
          'Задачи',
          (r.task['title'] ?? '') as String,
          '${r.parent != null ? 'в «${r.parent!['title']}» · ' : ''}${r.task['status'] == 'completed' ? 'сделано' : ''}',
          r.list['id'] as String,
          r.task,
          () {
            Navigator.pop(context);
            openTask(context, s, r.list['id'] as String, r.parent ?? r.task);
          },
        ),
      for (final p in pl)
        (
          'Разделы и списки',
          p['list'] != null ? 'Доска · ${p['name']}' : p['name'] as String,
          '',
          p['list'] as String?,
          null,
          () {
            Navigator.pop(context);
            widget.onGo(p['tab'] as int, p['list'] as String?);
          },
        ),
    ];
    if (sel >= rows.length) sel = rows.isEmpty ? 0 : rows.length - 1;
    final groups = <String, int>{};
    for (final r in rows) {
      groups[r.$1] = (groups[r.$1] ?? 0) + 1;
    }
    Widget hl(String t) {
      final i = text.isEmpty
          ? -1
          : t.toLowerCase().replaceAll('ё', 'е').indexOf(text.toLowerCase().replaceAll('ё', 'е'));
      final st = SpType.text(13.5);
      if (i < 0) return Text(t, style: st, maxLines: 1, overflow: TextOverflow.ellipsis);
      return Text.rich(
        TextSpan(
          style: st,
          children: [
            TextSpan(text: t.substring(0, i)),
            TextSpan(
              text: t.substring(i, i + text.length),
              style: st.copyWith(backgroundColor: SpColors.accent.withValues(alpha: .3)),
            ),
            TextSpan(text: t.substring(i + text.length)),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    Widget key(String k) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: SpColors.line),
      ),
      child: Text(k, style: gMicro()),
    );
    final list = <Widget>[];
    String? last;
    for (final (i, r) in rows.indexed) {
      if (r.$1 != last) {
        last = r.$1;
        list.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
            child: Text('${r.$1} · ${groups[r.$1]}', style: SpType.text(12, color: SpColors.muted)),
          ),
        );
      }
      final t = r.$5;
      list.add(
        InkWell(
          onTap: r.$6,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: i == sel ? SpColors.nodeHover : null,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                if (t != null) ...[
                  GCheck(done: t['status'] == 'completed'),
                  const SizedBox(width: 10),
                ] else if (r.$4 != null) ...[
                  GDot(listHue(s, r.$4!)),
                  const SizedBox(width: 10),
                ],
                Expanded(child: hl(r.$2)),
                if (t != null && r.$4 != null) ...[
                  GDot(listHue(s, r.$4!)),
                  const SizedBox(width: 6),
                  Text(s.listName(r.$4!), style: SpType.text(12, color: SpColors.muted)),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 70,
                    child: Text(
                      t['due'] == null ? r.$3 : humanDay((t['due'] as String).substring(0, 10)),
                      textAlign: TextAlign.right,
                      style: gMono(10.5, c: SpColors.ink2),
                    ),
                  ),
                ],
                if (t == null && i == sel) key('ENTER'),
              ],
            ),
          ),
        ),
      );
    }
    final field = TextField(
      controller: q,
      autofocus: true,
      style: SpType.text(15),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 11),
        prefixIcon: const Icon(Icons.search, size: 18, color: SpColors.muted),
        suffixIcon: Padding(padding: const EdgeInsets.all(12), child: key('ESC')),
        hintText: 'Найти задачу, список или раздел',
        hintStyle: SpType.text(15, color: SpColors.dim),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: SpColors.accent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: SpColors.accent, width: 1.3),
        ),
      ),
      onChanged: (_) => setState(() => sel = 0),
      onSubmitted: (_) {
        if (rows.isNotEmpty) rows[sel].$6();
      },
    );
    final keys = {
      const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
          setState(() => sel = (sel + 1).clamp(0, rows.length - 1)),
      const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
          setState(() => sel = (sel - 1).clamp(0, rows.length - 1)),
    };
    final a = widget.anchor;
    if (a != null) {
      // Поле шапки растёт до 400 px, под ним — результаты 560 px по правому краю.
      final scr = MediaQuery.sizeOf(context);
      final w = 560.0.clamp(0.0, scr.width - 24);
      return CallbackShortcuts(
        bindings: keys,
        child: Stack(
          children: [
            Positioned(
              top: a.top - 4,
              right: (scr.width - a.right).clamp(12.0, scr.width),
              width: w,
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: a.width, end: 400.0.clamp(0.0, w)),
                      duration: const Duration(milliseconds: 260),
                      curve: const Cubic(.2, .8, .2, 1),
                      builder: (_, v, c) => SizedBox(width: v, height: 40, child: c),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: SpColors.bg,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18)],
                        ),
                        child: field,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: (scr.height - a.bottom - 24).clamp(120.0, 520.0)),
                      child: GNode(
                        hub: true,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (text.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                                child: Text('${rows.length} найдено', style: gMicro(c: SpColors.muted)),
                              ),
                            Flexible(
                              child: rows.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Text(
                                        text.isEmpty
                                            ? 'Начни печатать — найду задачи, списки и разделы.'
                                            : 'Ничего не нашлось',
                                        style: SpType.text(13, color: SpColors.muted),
                                      ),
                                    )
                                  : ListView(
                                      shrinkWrap: true,
                                      padding: const EdgeInsets.only(bottom: 10),
                                      children: list,
                                    ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              decoration: const BoxDecoration(
                                border: Border(top: BorderSide(color: SpColors.line)),
                              ),
                              child: Row(
                                children: [
                                  key('↑ ↓'),
                                  const SizedBox(width: 6),
                                  Text('выбрать', style: SpType.text(12, color: SpColors.muted)),
                                  const SizedBox(width: 16),
                                  key('ENTER'),
                                  const SizedBox(width: 6),
                                  Text('открыть', style: SpType.text(12, color: SpColors.muted)),
                                  const Spacer(),
                                  Flexible(
                                    child: Text(
                                      'Ищу в названиях и заметках, ё = е',
                                      style: SpType.text(12, color: SpColors.muted),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
    return Dialog(
      alignment: const Alignment(0, -.6),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
        child: CallbackShortcuts(
          bindings: keys,
          child: GNode(
            hub: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GHead(hub: true, name: 'Поиск · Ctrl K', kind: text.isEmpty ? null : '${rows.length} найдено'),
                Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 4), child: field),
                Flexible(
                  child: rows.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            text.isEmpty ? 'Начни печатать — найду задачи, списки и разделы.' : 'Ничего не нашлось',
                            style: SpType.text(13, color: SpColors.muted),
                          ),
                        )
                      : ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 10), children: list),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: SpColors.line)),
                  ),
                  child: Row(
                    children: [
                      key('↑ ↓'),
                      const SizedBox(width: 6),
                      Text('выбрать', style: SpType.text(12, color: SpColors.muted)),
                      const SizedBox(width: 16),
                      key('ENTER'),
                      const SizedBox(width: 6),
                      Text('открыть', style: SpType.text(12, color: SpColors.muted)),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          'Ищу в названиях и заметках, ё = е',
                          style: SpType.text(12, color: SpColors.muted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
