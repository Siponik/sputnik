// Поиск Ctrl K (docs/knowledge.md, шаг 10; макет G_NotesSearch): группа «Заметки» — совпадения подсвечены,
// под названием кусок текста и папка, группа «Задачи» — из Спутника; «＋ Новая заметка «…»», если такой нет.
// Стрелки — выбор, Enter — открыть, Esc — закрыть. Открывается из любого раздела.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/notes/parse.dart';
import '../../core/notes/view.dart';
import '../../state/notes_state.dart';
import '../theme/tokens.dart';
import 'hue.dart';

/// Задача для поиска: название и список.
typedef SearchTask = ({String title, String list});

/// Что выбрали: путь заметки, задачу или «новая заметка».
sealed class SearchPick {}

class PickNote extends SearchPick {
  PickNote(this.path);
  final String path;
}

class PickTask extends SearchPick {
  PickTask(this.task);
  final SearchTask task;
}

class PickNew extends SearchPick {
  PickNew(this.title);
  final String title;
}

Future<SearchPick?> showNotesSearch(BuildContext context, NotesState st, {List<SearchTask> tasks = const []}) => showDialog<SearchPick>(
      context: context,
      barrierColor: const Color(0x99000000),
      builder: (_) => Align(
        alignment: const Alignment(0, -.55),
        child: _Search(st: st, tasks: tasks),
      ),
    );

class _Search extends StatefulWidget {
  const _Search({required this.st, required this.tasks});
  final NotesState st;
  final List<SearchTask> tasks;
  @override
  State<_Search> createState() => _SearchState();
}

class _SearchState extends State<_Search> {
  final _q = TextEditingController();
  int _at = 0;

  List<SearchPick> _items() {
    final q = _q.text.trim();
    final st = widget.st;
    if (q.isEmpty) return [for (final p in st.config.recent.take(6)) PickNote(p)];
    final notes = st.index.search(q, limit: 8);
    final tasks = widget.tasks.where((t) => matchesAll(t.title, q)).take(5);
    final exact = notes.any((h) => baseName(h.path).toLowerCase() == q.toLowerCase());
    return [
      for (final h in notes) PickNote(h.path),
      for (final t in tasks) PickTask(t),
      if (!exact && st.hasFolder) PickNew(q),
    ];
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items();
    if (_at >= items.length) _at = items.isEmpty ? 0 : items.length - 1;
    final q = _q.text.trim();
    final hits = {for (final h in q.isEmpty ? const [] : widget.st.index.search(q, limit: 8)) h.path: h};
    final notes = items.whereType<PickNote>().length;
    final tasks = items.whereType<PickTask>().length;
    final all = widget.st.index.paths.toList();
    final rows = <Widget>[];
    var i = 0;
    void group(String t) => rows.add(Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Text(t, style: SpType.label(9.5))));
    if (notes > 0) group(q.isEmpty ? 'НЕДАВНИЕ' : 'ЗАМЕТКИ · $notes');
    for (final it in items) {
      final me = i;
      if (it is PickTask && (me == 0 || items[me - 1] is! PickTask)) group('ЗАДАЧИ · $tasks');
      Widget row;
      switch (it) {
        case PickNote(:final path):
          final h = hits[path];
          row = _row(
            me,
            icon: Icons.description_outlined,
            title: _hl(baseName(path), q, SpType.text(13.5, w: FontWeight.w500)),
            sub: h == null || h.snippet.isEmpty ? null : _hl('«${h.snippet}»', q, SpType.text(12, color: SpColors.muted)),
            right: folderOf(path).isEmpty ? null : folderOf(path).split('/').first,
            dot: folderHue(path, all),
          );
        case PickTask(:final task):
          row = _row(me, icon: Icons.radio_button_unchecked, title: _hl(task.title, q, SpType.text(13.5)), right: task.list);
        case PickNew(:final title):
          row = _row(me, icon: Icons.add, title: Text('Новая заметка «$title»', style: SpType.text(13.5, color: SpColors.accent)));
      }
      rows.add(row);
      i++;
    }
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 620,
        constraints: const BoxConstraints(maxHeight: 520),
        decoration: BoxDecoration(
          color: SpColors.node,
          borderRadius: BorderRadius.circular(SpRadius.hub),
          border: Border.all(color: SpColors.accentLine),
          boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 40, offset: Offset(0, 18))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: SpColors.headMain, borderRadius: BorderRadius.vertical(top: Radius.circular(SpRadius.hub - 1))),
            child: Row(children: [
              Text('ПОИСК · CTRL K', style: SpType.label(10.5, w: FontWeight.w500, color: Colors.white, spacing: .14)),
              const Spacer(),
              if (q.isNotEmpty) Text('${notes + tasks} НАЙДЕНО', style: SpType.label(10, color: const Color(0xCCFFFFFF))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Focus(
              onKeyEvent: (_, e) {
                if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
                // Shift+Enter — открыть найденную заметку сразу на графе.
                if (e.logicalKey == LogicalKeyboardKey.enter && HardwareKeyboard.instance.isShiftPressed && items.isNotEmpty) {
                  searchToGraph = true;
                  Navigator.pop(context, items[_at]);
                  return KeyEventResult.handled;
                }
                if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
                  setState(() => _at = items.isEmpty ? 0 : (_at + 1) % items.length);
                  return KeyEventResult.handled;
                }
                if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
                  setState(() => _at = items.isEmpty ? 0 : (_at - 1 + items.length) % items.length);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                controller: _q,
                autofocus: true,
                style: SpType.text(16),
                onChanged: (_) => setState(() => _at = 0),
                onSubmitted: (_) {
                  if (items.isNotEmpty) Navigator.pop(context, items[_at]);
                },
                decoration: InputDecoration(
                  hintText: 'Заметка, задача…',
                  hintStyle: SpType.text(16, color: SpColors.dim),
                  prefixIcon: Icon(Icons.search, size: 18, color: SpColors.muted),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(border: Border.all(color: SpColors.line), borderRadius: BorderRadius.circular(4)),
                      child: Text('ESC', style: SpType.label(9)),
                    ),
                  ),
                  filled: true,
                  fillColor: SpColors.bg,
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: SpColors.lineStrong)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: SpColors.accent)),
                ),
              ),
            ),
          ),
          Flexible(
            child: items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                    child: Text(q.isEmpty ? 'Начни писать — найду заметки и задачи.' : 'Ничего не нашёл', style: SpType.text(13, color: SpColors.muted)),
                  )
                : ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 8), children: rows),
          ),
        ]),
      ),
    );
  }

  Widget _row(int i, {required IconData icon, required Widget title, Widget? sub, String? right, Color? dot}) {
    final on = i == _at;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: on ? SpColors.accentWash : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => Navigator.pop(context, _items()[i]),
          onHover: (h) {
            if (h && _at != i) setState(() => _at = i);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: on ? BoxDecoration(border: Border(left: BorderSide(color: SpColors.accent, width: 2))) : null,
            child: Row(children: [
              SizedBox(width: 18, child: Icon(icon, size: 14, color: SpColors.dim)),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [title, ?sub])),
              if (right != null) ...[
                const SizedBox(width: 10),
                if (dot != null) ...[
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 6),
                ],
                Text(right, style: SpType.text(12, color: SpColors.muted)),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  /// Текст с подсвеченными совпадениями.
  Widget _hl(String text, String q, TextStyle base) {
    final rs = matchRanges(text, q);
    if (rs.isEmpty) return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: base);
    final kids = <TextSpan>[];
    var at = 0;
    for (final (a, b) in rs) {
      if (a > at) kids.add(TextSpan(text: text.substring(at, a)));
      kids.add(TextSpan(text: text.substring(a, b), style: TextStyle(color: SpColors.accentInk, backgroundColor: Color(0x336A5238))));
      at = b;
    }
    if (at < text.length) kids.add(TextSpan(text: text.substring(at)));
    return Text.rich(TextSpan(style: base, children: kids), maxLines: 1, overflow: TextOverflow.ellipsis);
  }
}

/// Поиск закрыт по Shift+Enter: открыть заметку на графе. Сбрасывает тот, кто прочитал.
bool searchToGraph = false;
