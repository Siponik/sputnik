// Папка как список, карточки или таблица по свойствам (docs/knowledge.md, шаг 11; макеты G_NotesCards, G_NotesTable).
// Колонки таблицы — свойства из шапок заметок папки, условия-чипы «тип: НПС», сортировка, картинки для обложек.
// Без Flutter — проверяется тестом.
import 'index.dart' show foldText;
import 'parse.dart';

/// Заметки папки [folder] со всеми подпапками ('' — вся база), по названию.
List<String> notesIn(Iterable<String> paths, String folder) {
  final pre = folder.isEmpty ? '' : '$folder/';
  return paths.where((p) => p.startsWith(pre)).toList()..sort((a, b) => foldText(baseName(a)).compareTo(foldText(baseName(b))));
}

const _hiddenProps = {'tags', 'tag', 'aliases', 'alias', 'cssclasses', 'cssclass', 'position'};

/// Колонки таблицы: свойства, которые есть хотя бы у одной заметки; чаще встречающиеся — левее, `type`/`тип` — первым.
List<String> propColumns(Iterable<NoteDoc> docs) {
  final count = <String, int>{};
  final first = <String, int>{};
  var i = 0;
  for (final d in docs) {
    for (final k in d.props.keys) {
      if (_hiddenProps.contains(k.toLowerCase())) continue;
      count[k] = (count[k] ?? 0) + 1;
      first.putIfAbsent(k, () => i++);
    }
  }
  bool isType(String k) => k.toLowerCase() == 'type' || k.toLowerCase() == 'тип';
  return count.keys.toList()
    ..sort((a, b) {
      if (isType(a) != isType(b)) return isType(a) ? -1 : 1;
      final c = count[b]!.compareTo(count[a]!);
      return c != 0 ? c : first[a]!.compareTo(first[b]!);
    });
}

/// Значение свойства как текст ячейки: список — через запятую, ссылки — без скобок, нет — пусто.
String cellText(Object? v) {
  if (v == null) return '';
  if (v is List) return v.map(cellText).where((s) => s.isNotEmpty).join(', ');
  if (v is bool) return v ? 'да' : 'нет';
  if (v is DateTime) return '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
  return '$v'.replaceAllMapped(RegExp(r'\[\[(?:[^\]|]*\|)?([^\]]*)\]\]'), (m) => m[1]!).trim();
}

/// Условие «свойство = значение». Значение '' — «свойство не заполнено».
class PropCond {
  final String key;
  final String value;
  const PropCond(this.key, this.value);
  @override
  bool operator ==(Object other) => other is PropCond && other.key == key && other.value == value;
  @override
  int get hashCode => Object.hash(key, value);
  @override
  String toString() => '$key: ${value.isEmpty ? '—' : value}';
}

/// Подходит ли заметка под все условия (без регистра, ё = е; у списка — если есть такой элемент).
/// Условие по тегу — ключ `#`.
bool matchConds(NoteDoc d, List<PropCond> conds) {
  for (final c in conds) {
    final want = foldText(c.value.trim());
    if (c.key == '#') {
      if (!d.tags.any((t) => foldText(t) == want || foldText(t).startsWith('$want/'))) return false;
      continue;
    }
    final v = d.props[c.key];
    final vals = v is List ? v.map(cellText).toList() : [cellText(v)];
    if (want.isEmpty) {
      if (vals.any((s) => s.isNotEmpty)) return false;
    } else if (!vals.any((s) => foldText(s) == want)) {
      return false;
    }
  }
  return true;
}

/// Какие значения есть у свойства в этих заметках (для выбора условия), частые выше.
List<String> valuesOf(Iterable<NoteDoc> docs, String key) {
  final count = <String, int>{};
  final shown = <String, String>{};
  for (final d in docs) {
    final v = d.props[key];
    for (final s in (v is List ? v.map(cellText) : [cellText(v)])) {
      if (s.isEmpty) continue;
      final k = foldText(s);
      shown.putIfAbsent(k, () => s);
      count[k] = (count[k] ?? 0) + 1;
    }
  }
  return (count.keys.toList()..sort((a, b) => count[b] != count[a] ? count[b]!.compareTo(count[a]!) : a.compareTo(b))).map((k) => shown[k]!).toList();
}

/// Сортировка строк таблицы по колонке: '' — название, `#` — теги, `~…` — число из [numbers] (связи, время),
/// иначе — свойство. Пустые — всегда внизу; числа — как числа.
List<NoteDoc> sortDocs(List<NoteDoc> docs, String key, {bool asc = true, Map<String, int> numbers = const {}}) {
  Object? val(NoteDoc d) => key.isEmpty
      ? d.title
      : key == '#'
          ? d.tags.join(' ')
          : key.startsWith('~')
              ? numbers[d.path]
              : cellText(d.props[key]);
  int cmp(NoteDoc a, NoteDoc b) {
    final x = val(a), y = val(b);
    final xe = x == null || x == '', ye = y == null || y == '';
    if (xe || ye) return xe == ye ? foldText(a.title).compareTo(foldText(b.title)) : (xe ? 1 : -1);
    int c;
    if (x is int && y is int) {
      c = x.compareTo(y);
    } else {
      final nx = num.tryParse('$x'.replaceAll(',', '.')), ny = num.tryParse('$y'.replaceAll(',', '.'));
      c = nx != null && ny != null ? nx.compareTo(ny) : foldText('$x').compareTo(foldText('$y'));
    }
    if (c == 0) c = foldText(a.title).compareTo(foldText(b.title));
    return asc ? c : -c;
  }

  return [...docs]..sort((a, b) {
      final c = cmp(a, b);
      // Пустые внизу и при обратном порядке.
      final xe = val(a) == null || val(a) == '', ye = val(b) == null || val(b) == '';
      if (xe != ye) return xe ? 1 : -1;
      return c;
    });
}

/// Картинки заметки — вставки `![[…]]` и `![](…)`, которые нашлись среди файлов; для обложки карточки и «8 фото».
List<String> imagesOf(NoteDoc d, String? Function(NoteLink l) resolve) {
  final out = <String>[];
  for (final l in d.links) {
    if (!l.embed) continue;
    final to = resolve(l);
    if (to != null && RegExp(r'\.(png|jpe?g|gif|webp)$', caseSensitive: false).hasMatch(to) && !out.contains(to)) out.add(to);
  }
  return out;
}

/// Шапка новой заметки из условий («＋ Новая строка» в таблице с фильтром «тип: НПС» — заметка сразу с `тип: НПС`).
String frontFromConds(List<PropCond> conds) {
  final props = [for (final c in conds) if (c.key != '#' && c.value.isNotEmpty) c];
  final tags = [for (final c in conds) if (c.key == '#' && c.value.isNotEmpty) c.value];
  if (props.isEmpty && tags.isEmpty) return '';
  final b = StringBuffer('---\n');
  for (final c in props) {
    b.writeln('${c.key}: ${c.value}');
  }
  if (tags.isNotEmpty) b.writeln('tags: [${tags.join(', ')}]');
  b.write('---\n');
  return b.toString();
}
