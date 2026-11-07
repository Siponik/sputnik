// Папка как «Список | Карточки | Таблица | Граф» (docs/knowledge.md, шаг 11; макеты G_NotesCards, G_NotesTable).
// Карточки — обложка из первой картинки заметки, «N фото», теги. Таблица — колонки из свойств шапок,
// условия-чипы «тип: НПС ×», сортировка по клику на заголовок, правка ячейки меняет только эту строку шапки,
// «＋ Новая строка» — новая заметка в папке сразу с этими свойствами.
import 'package:flutter/material.dart';

import '../../core/notes/folder_view.dart';
import '../../core/notes/parse.dart';
import '../../core/notes/view.dart' show wordCount;
import '../../state/notes_state.dart';
import '../theme/tokens.dart';
import 'hue.dart';

class FolderView extends StatefulWidget {
  const FolderView({super.key, required this.st, required this.folder});
  final NotesState st;
  final String folder;
  @override
  State<FolderView> createState() => _FolderViewState();
}

class _FolderViewState extends State<FolderView> {
  final List<PropCond> _conds = [];
  String _sort = '';
  bool _asc = true;

  NotesState get st => widget.st;

  @override
  void didUpdateWidget(FolderView old) {
    super.didUpdateWidget(old);
    if (old.folder != widget.folder) {
      _conds.clear();
      _sort = '';
      _asc = true;
    }
  }

  String? Function(NoteLink) _resolver(String path) {
    final to = {for (final r in st.index.outgoing(path)) r.link.start: r.to};
    return (l) => to[l.start];
  }

  @override
  Widget build(BuildContext context) {
    final folder = widget.folder;
    final mode = st.folderMode(folder);
    final all = [for (final p in notesIn(st.index.paths, folder)) st.index.doc(p)!];
    final docs = all.where((d) => matchConds(d, _conds)).toList();
    final images = {for (final d in docs) d.path: imagesOf(d, _resolver(d.path))};
    final pics = images.values.fold<int>(0, (a, b) => a + b.length);
    final title = folder.isEmpty ? 'Вся база' : folder.replaceAll('/', ' › ');

    Widget body;
    switch (mode) {
      case 'cards':
        body = _cards(docs, images);
      case 'table':
        body = _table(docs, all);
      default:
        body = _list(docs);
    }

    return Container(
      decoration: BoxDecoration(
        color: SpColors.node,
        borderRadius: BorderRadius.circular(SpRadius.hub),
        border: Border.all(color: SpColors.accentLine),
        boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 40, offset: Offset(0, 18))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 44,
          padding: const EdgeInsets.only(left: 16, right: 10),
          decoration: BoxDecoration(color: folderHead('$folder/', st.index.paths), borderRadius: const BorderRadius.vertical(top: Radius.circular(SpRadius.hub - 1))),
          child: Row(children: [
            Flexible(child: Text(title.toUpperCase(), overflow: TextOverflow.ellipsis, style: SpType.label(11, w: FontWeight.w500, color: Colors.white, spacing: .14))),
            const SizedBox(width: 14),
            Text('${docs.length} ${_pl(docs.length, 'ЗАМЕТКА', 'ЗАМЕТКИ', 'ЗАМЕТОК')}${pics > 0 ? ' · $pics ${_pl(pics, 'КАРТИНКА', 'КАРТИНКИ', 'КАРТИНОК')}' : ''}',
                style: SpType.label(10, color: const Color(0xCCFFFFFF))),
            const Spacer(),
            TextButton(
              onPressed: () => st.show('note'),
              style: TextButton.styleFrom(minimumSize: const Size(0, 28), padding: const EdgeInsets.symmetric(horizontal: 10), foregroundColor: Colors.white),
              child: Text('← К заметке', style: SpType.text(12.5, w: FontWeight.w500, color: Colors.white)),
            ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 14, 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: SpColors.line))),
          child: Row(children: [
            Expanded(
              child: Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                for (final c in _conds)
                  _Chip(
                    '${c.key == '#' ? '#' : '${c.key.toUpperCase()}: '}${c.value.isEmpty ? '—' : c.value.toUpperCase()}',
                    onRemove: () => setState(() => _conds.remove(c)),
                  ),
                _AddCond(docs: all, onPick: (c) => setState(() => _conds.add(c))),
              ]),
            ),
            _Segment(
              value: mode,
              items: const [('list', 'СПИСОК'), ('cards', 'КАРТОЧКИ'), ('table', 'ТАБЛИЦА'), ('graph', 'ГРАФ')],
              onPick: (v) => v == 'graph' ? st.show('graph') : st.setFolderMode(folder, v),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _newRow(),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 30),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                backgroundColor: SpColors.accent,
                foregroundColor: SpColors.onAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SpRadius.button)),
              ),
              child: Text('＋ Заметка', style: SpType.text(12.5, w: FontWeight.w600, color: SpColors.onAccent)),
            ),
          ]),
        ),
        Expanded(child: docs.isEmpty ? _empty() : body),
      ]),
    );
  }

  Widget _empty() => Center(
        child: Text(_conds.isEmpty ? 'В папке пока нет заметок' : 'Под условия ничего не подходит', style: SpType.text(13.5, color: SpColors.muted)),
      );

  Future<void> _newRow() async {
    final name = await _askText(context, 'Новая заметка', 'Название', '');
    if (name == null || name.isEmpty) return;
    await st.create(widget.folder, name, text0: frontFromConds(_conds));
  }

  // ---------- список ----------

  Widget _list(List<NoteDoc> docs) {
    final all = st.index.paths.toList();
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: docs.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: SpColors.lineSoft),
      itemBuilder: (_, i) {
        final d = docs[i];
        final first = st.index.text(d.path) ?? '';
        final body = first.substring(d.bodyStart).trim().split('\n').firstWhere((l) => l.trim().isNotEmpty && !l.startsWith('#'), orElse: () => '');
        return InkWell(
          onTap: () => st.openNote(d.path),
          hoverColor: SpColors.nodeHover,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Row(children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: folderHue(d.path, all), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              SizedBox(width: 240, child: Text(d.title, overflow: TextOverflow.ellipsis, style: SpType.text(13.5, w: FontWeight.w500))),
              Expanded(child: Text(body, maxLines: 1, overflow: TextOverflow.ellipsis, style: SpType.text(12.5, color: SpColors.muted))),
              const SizedBox(width: 10),
              Text('${wordCount(first)} сл.', style: SpType.label(10.5, color: SpColors.dim, spacing: 0)),
              const SizedBox(width: 12),
              SizedBox(width: 44, child: Text(_date(st.mtimeOf(d.path)), textAlign: TextAlign.right, style: SpType.label(10.5, color: SpColors.dim, spacing: 0))),
            ]),
          ),
        );
      },
    );
  }

  // ---------- карточки ----------

  Widget _cards(List<NoteDoc> docs, Map<String, List<String>> images) {
    final all = st.index.paths.toList();
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 240, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: .86),
      itemCount: docs.length,
      itemBuilder: (_, i) {
        final d = docs[i];
        final pics = images[d.path] ?? const [];
        final hue = folderHue(d.path, all);
        return Material(
          color: SpColors.nodeHover,
          borderRadius: BorderRadius.circular(SpRadius.node),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => st.openNote(d.path),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: pics.isNotEmpty && st.vault != null
                    ? Image.file(st.vault!.file(pics.first), fit: BoxFit.cover, errorBuilder: (_, _, _) => _cover(hue, d.title))
                    : _cover(hue, d.title),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: SpType.text(13.5, w: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(children: [
                    if (pics.isNotEmpty) ...[Text('${pics.length} ФОТО', style: SpType.label(9.5, color: SpColors.dim)), const SizedBox(width: 8)],
                    Expanded(
                      child: Text(d.tags.take(3).map((t) => '#$t').join(' '), maxLines: 1, overflow: TextOverflow.ellipsis, style: SpType.text(11.5, color: SpColors.blue)),
                    ),
                  ]),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _cover(Color hue, String title) => Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(center: const Alignment(-.4, -.6), radius: 1.2, colors: [hue.withValues(alpha: .33), Colors.transparent]),
          color: const Color(0xFF222328),
        ),
        alignment: Alignment.center,
        child: Text(title.isEmpty ? '¶' : title.characters.first.toUpperCase(), style: SpType.text(34, w: FontWeight.w200, color: hue.withValues(alpha: .8))),
      );

  // ---------- таблица ----------

  Widget _table(List<NoteDoc> docs, List<NoteDoc> all) {
    final cols = propColumns(all);
    final nums = _sort == '~links' ? {for (final d in docs) d.path: st.index.degree(d.path)} : {for (final d in docs) d.path: st.mtimeOf(d.path) ?? 0};
    final rows = sortDocs(docs, _sort, asc: _asc, numbers: nums);
    const nameW = 200.0, colW = 150.0, tagsW = 170.0, linksW = 64.0, dateW = 74.0;
    Widget head(String label, String key, double w) => InkWell(
          onTap: () => setState(() {
            if (_sort == key) {
              _asc = !_asc;
            } else {
              _sort = key;
              _asc = true;
            }
          }),
          child: Container(
            width: w,
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.centerLeft,
            child: Row(children: [
              Flexible(child: Text(label.toUpperCase(), overflow: TextOverflow.ellipsis, style: SpType.label(9.5, color: _sort == key ? SpColors.ink : SpColors.muted))),
              if (_sort == key) Text(_asc ? ' ↑' : ' ↓', style: SpType.label(9.5, color: SpColors.accent)),
            ]),
          ),
        );
    Widget cell(String text, double w, {VoidCallback? onTap, TextStyle? style}) => InkWell(
          onTap: onTap,
          child: Container(
            width: w,
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.centerLeft,
            child: Text(text.isEmpty ? '—' : text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style ?? SpType.text(13, color: text.isEmpty ? SpColors.dim : SpColors.body)),
          ),
        );
    final width = nameW + cols.length * colW + tagsW + linksW + dateW;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Row(children: [
          Text('ТАБЛИЦА ПО СВОЙСТВАМ', style: SpType.label(9.5, color: SpColors.ink)),
          const SizedBox(width: 10),
          Text('СВОЙСТВА — ИЗ ШАПКИ ЗАМЕТОК (YAML)', style: SpType.label(9.5, color: SpColors.dim)),
        ]),
      ),
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: SizedBox(
            width: width,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: SpColors.line))),
                child: Row(children: [
                  head('Название', '', nameW),
                  for (final c in cols) head(c, c, colW),
                  head('Теги', '#', tagsW),
                  head('Связи', '~links', linksW),
                  head('Изменено', '~mtime', dateW),
                ]),
              ),
              Expanded(
                child: ListView(children: [
                  for (final d in rows)
                    Container(
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: SpColors.lineSoft))),
                      child: Row(children: [
                        cell(d.title, nameW, onTap: () => st.openNote(d.path), style: SpType.text(13, w: FontWeight.w600)),
                        for (final c in cols) cell(cellText(d.props[c]), colW, onTap: () => _editCell(d, c)),
                        cell(d.tags.map((t) => '#$t').join(' '), tagsW, style: SpType.text(12.5, color: SpColors.blue)),
                        cell('↔ ${st.index.degree(d.path)}', linksW, style: SpType.label(11, color: SpColors.muted, spacing: 0)),
                        cell(_date(st.mtimeOf(d.path)), dateW, style: SpType.label(11, color: SpColors.dim, spacing: 0)),
                      ]),
                    ),
                  InkWell(
                    onTap: _newRow,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
                      child: Text(
                        '＋ Новая строка — новая заметка в ${widget.folder.isEmpty ? 'корне' : baseName(widget.folder)}${_conds.isEmpty ? '' : ' с этими свойствами'}',
                        style: SpType.text(12.5, color: SpColors.muted),
                      ),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }

  Future<void> _editCell(NoteDoc d, String key) async {
    final v = await _askText(context, d.title, key, cellText(d.props[key]));
    if (v == null) return;
    st.setProp(d.path, key, v.isEmpty ? null : (num.tryParse(v) ?? v));
  }
}

String _date(int? ms) {
  if (ms == null || ms == 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
}

String _pl(int n, String one, String few, String many) {
  final m10 = n % 10, m100 = n % 100;
  if (m10 == 1 && m100 != 11) return one;
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few;
  return many;
}

Future<String?> _askText(BuildContext context, String title, String label, String initial) {
  final c = TextEditingController(text: initial)..selection = TextSelection(baseOffset: 0, extentOffset: initial.length);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: SpColors.node,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SpRadius.hub), side: BorderSide(color: SpColors.line)),
      title: Text(title, style: SpType.text(17, w: FontWeight.w600)),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: SpType.text(13, color: SpColors.muted)),
          const SizedBox(height: 8),
          TextField(
            controller: c,
            autofocus: true,
            style: SpType.text(14),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            decoration: InputDecoration(
              filled: true,
              fillColor: SpColors.bg,
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: SpColors.lineStrong)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: SpColors.accent)),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Отмена', style: SpType.text(13))),
        TextButton(
          onPressed: () => Navigator.pop(ctx, c.text.trim()),
          style: TextButton.styleFrom(backgroundColor: SpColors.accent),
          child: Text('Готово', style: SpType.text(13, w: FontWeight.w600, color: SpColors.onAccent)),
        ),
      ],
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {required this.onRemove});
  final String text;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) => Container(
        height: 26,
        padding: const EdgeInsets.only(left: 10, right: 4),
        decoration: BoxDecoration(color: SpColors.accentWash, border: Border.all(color: SpColors.accentLine), borderRadius: BorderRadius.circular(13)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(text, style: SpType.label(10, color: SpColors.accentInk)),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(10),
            child: Padding(padding: const EdgeInsets.all(4), child: Text('×', style: SpType.text(12, color: SpColors.accentInk))),
          ),
        ]),
      );
}

/// «＋ Условие»: свойство и одно из его значений (частые сверху), или тег.
class _AddCond extends StatelessWidget {
  const _AddCond({required this.docs, required this.onPick});
  final List<NoteDoc> docs;
  final ValueChanged<PropCond> onPick;
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<PropCond>(
      tooltip: 'Добавить условие',
      color: SpColors.node,
      onSelected: onPick,
      itemBuilder: (_) {
        final items = <PopupMenuEntry<PropCond>>[];
        for (final k in propColumns(docs).take(6)) {
          final vs = valuesOf(docs, k).take(6).toList();
          if (vs.isEmpty) continue;
          items.add(PopupMenuItem(enabled: false, height: 26, child: Text(k.toUpperCase(), style: SpType.label(9.5))));
          for (final v in vs) {
            items.add(PopupMenuItem(value: PropCond(k, v), height: 32, child: Text(v, style: SpType.text(13))));
          }
        }
        final tags = <String, int>{};
        for (final d in docs) {
          for (final t in d.tags) {
            tags[t] = (tags[t] ?? 0) + 1;
          }
        }
        if (tags.isNotEmpty) {
          items.add(PopupMenuItem(enabled: false, height: 26, child: Text('ТЕГИ', style: SpType.label(9.5))));
          for (final t in (tags.keys.toList()..sort((a, b) => tags[b]!.compareTo(tags[a]!))).take(8)) {
            items.add(PopupMenuItem(value: PropCond('#', t), height: 32, child: Text('#$t', style: SpType.text(13, color: SpColors.blue))));
          }
        }
        if (items.isEmpty) items.add(PopupMenuItem(enabled: false, child: Text('У заметок нет свойств', style: SpType.text(13, color: SpColors.muted))));
        return items;
      },
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: SpColors.line), borderRadius: BorderRadius.circular(13)),
        child: Text('＋ УСЛОВИЕ', style: SpType.label(10)),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.value, required this.items, required this.onPick});
  final String value;
  final List<(String, String)> items;
  final ValueChanged<String> onPick;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(border: Border.all(color: SpColors.line), borderRadius: BorderRadius.circular(7)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final (id, label) in items)
            InkWell(
              onTap: () => onPick(id),
              borderRadius: BorderRadius.circular(5),
              child: Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: id == value ? SpColors.ink : Colors.transparent, borderRadius: BorderRadius.circular(5)),
                child: Text(label, style: SpType.label(10.5, w: FontWeight.w500, color: id == value ? SpColors.bg : SpColors.muted)),
              ),
            ),
        ]),
      );
}
