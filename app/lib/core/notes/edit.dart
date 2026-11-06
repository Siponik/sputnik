// Бережные правки текста заметки «Знаний» (docs/knowledge.md, «Бережность к файлам»):
// одно свойство шапки меняет только свою строку, переименование правит только сами ссылки.
// Всё остальное в файле остаётся байт в байт.
import 'parse.dart';

final _plain = RegExp(r'^[\p{L}\p{N}_][\p{L}\p{N}_ .\-/]*$', unicode: true);
final _special = RegExp(r'^(true|false|yes|no|on|off|null|~|[-+]?(\d[\d_]*(\.\d*)?|\.\d+)([eE][-+]?\d+)?|0x[0-9a-fA-F]+)$', caseSensitive: false);

/// Строка YAML для значения: просто текст без кавычек, если можно; иначе в двойных кавычках.
String yamlScalar(Object? v, {bool inList = false}) {
  if (v == null) return 'null';
  if (v is bool || v is num) return v.toString();
  final s = v.toString();
  final needQuotes = s.isEmpty ||
      s != s.trim() ||
      !_plain.hasMatch(s) ||
      _special.hasMatch(s) ||
      s.contains(': ') ||
      s.contains(' #') ||
      (inList && RegExp(r'[,\[\]{}]').hasMatch(s));
  if (!needQuotes) return s;
  final e = s.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll('\n', r'\n').replaceAll('\t', r'\t');
  return '"$e"';
}

/// Значение свойства целиком: список — в квадратных скобках в одну строку.
String yamlValue(Object? v) {
  if (v is List) return '[${v.map((x) => yamlScalar(x, inList: true)).join(', ')}]';
  return yamlScalar(v);
}

String _eol(String text) => text.contains('\r\n') ? '\r\n' : '\n';

/// Поменять (или добавить, или с `null` — убрать) одно свойство верхнего уровня в шапке.
///
/// Меняются только строки этого свойства (вместе с его вложенными строками и пунктами списка). Шапки нет —
/// создаётся в начале файла. Свойства во вложенных уровнях не трогаем — для них нужен целый YAML.
String setFrontProp(String text, String key, Object? value) {
  final nl = _eol(text);
  final front = frontSpan(text);
  final line = value == null ? null : '$key: ${yamlValue(value)}';
  if (front == null) {
    if (line == null) return text;
    final bom = text.startsWith('\uFEFF') ? '\uFEFF' : '';
    return '$bom---$nl$line$nl---$nl${text.substring(bom.length)}';
  }
  final rawStart = front.rawStart;
  final raw = text.substring(rawStart, front.rawEnd);
  final lines = raw.split('\n');
  final keyRe = RegExp('^${RegExp.escape(key)}\\s*:(\\s|\$)');
  var at = -1;
  for (var i = 0; i < lines.length; i++) {
    if (keyRe.hasMatch(lines[i].replaceAll('\r', ''))) {
      at = i;
      break;
    }
  }
  if (at < 0) {
    if (line == null) return text;
    // Добавить последней строкой шапки (у пустой шапки raw = '').
    final insertAt = rawStart + raw.length;
    final needNl = raw.isNotEmpty && !raw.endsWith('\n');
    return '${text.substring(0, insertAt)}${needNl ? nl : ''}$line$nl${text.substring(insertAt)}';
  }
  // Строки этого свойства: сама строка + следующие с отступом или «- » (блочный список).
  var end = at + 1;
  while (end < lines.length) {
    final l = lines[end].replaceAll('\r', '');
    if (l.isEmpty && end == lines.length - 1) break;
    if (l.startsWith(' ') || l.startsWith('\t') || l.startsWith('- ') || l == '-') {
      end++;
    } else {
      break;
    }
  }
  final cr = lines[at].endsWith('\r') ? '\r' : '';
  final out = [
    ...lines.sublist(0, at),
    if (line != null) '$line$cr',
    ...lines.sublist(end),
  ];
  return text.substring(0, rawStart) + out.join('\n') + text.substring(rawStart + raw.length);
}

/// Отметить или снять отметку чек-листа в строке [line] (номер строки файла). Строка не та — текст как был.
String setTaskDone(String text, int line, bool done) {
  final lines = text.split('\n');
  if (line < 0 || line >= lines.length) return text;
  final m = RegExp(r'^(\s*(?:[-*+]|\d+[.)])[ \t]+\[)([ xX])(\])').firstMatch(lines[line]);
  if (m == null) return text;
  lines[line] = '${m[1]}${done ? 'x' : ' '}${m[3]}${lines[line].substring(m.end)}';
  return lines.join('\n');
}

/// Относительный путь от папки [from] до файла [to] (для Markdown-ссылок), пробелы → %20.
String relativePath(String from, String to) {
  final a = folderOf(from).split('/').where((s) => s.isNotEmpty).toList();
  final b = to.split('/');
  var i = 0;
  while (i < a.length && i < b.length - 1 && a[i] == b[i]) {
    i++;
  }
  final up = List.filled(a.length - i, '..');
  return [...up, ...b.sublist(i)].join('/').replaceAll(' ', '%20');
}

/// Как назвать файл в `[[…]]` после переименования: просто имя, если оно единственное в папке заметок,
/// иначе путь без `.md` (чтобы ссылка не ушла к другой заметке с тем же именем).
String wikiTargetFor(String newPath, Iterable<String> allPaths) {
  final name = baseName(newPath);
  final isNote = newPath.toLowerCase().endsWith('.md');
  final shown = isNote ? name : newPath.substring(newPath.lastIndexOf('/') + 1);
  final same = allPaths.where((p) => p != newPath && baseName(p).toLowerCase() == name.toLowerCase()).length;
  if (same == 0) return shown;
  return isNote ? newPath.substring(0, newPath.length - 3) : newPath;
}

/// Переписать ссылки в тексте заметки [path]: каждая [links] (из разбора этого же текста) теперь ведёт на [newPath].
/// Раздел, блок, подпись и «!» остаются. Возвращает новый текст и число изменённых ссылок.
(String, int) rewriteLinks(String path, String text, List<NoteLink> links, String newPath, Iterable<String> allPaths) {
  if (links.isEmpty) return (text, 0);
  final sorted = [...links]..sort((a, b) => b.start.compareTo(a.start));
  var out = text;
  var n = 0;
  final wikiName = wikiTargetFor(newPath, allPaths);
  for (final l in sorted) {
    String repl;
    if (l.markdown) {
      final rel = relativePath(path, newPath);
      final hash = l.heading != null ? '#${l.heading!.replaceAll(' ', '%20')}' : '';
      final label = l.alias ?? '';
      repl = '${l.embed ? '!' : ''}[$label]($rel$hash)';
    } else {
      final tail = [
        if (l.block != null) '#^${l.block}' else if (l.heading != null) '#${l.heading}',
      ].join();
      final alias = l.alias != null ? '|${l.alias}' : '';
      repl = '${l.embed ? '!' : ''}[[$wikiName$tail$alias]]';
    }
    if (out.substring(l.start, l.end) == repl) continue;
    out = out.replaceRange(l.start, l.end, repl);
    n++;
  }
  return (out, n);
}

/// Свободное имя файла: «Имя.md», «Имя 2.md», «Имя 3.md»… (сравнение без регистра, как в Windows).
String freeName(String wanted, Iterable<String> taken) {
  final lower = {for (final t in taken) t.toLowerCase()};
  if (!lower.contains(wanted.toLowerCase())) return wanted;
  final dot = wanted.lastIndexOf('.');
  final slash = wanted.lastIndexOf('/');
  final hasExt = dot > slash;
  final stem = hasExt ? wanted.substring(0, dot) : wanted;
  final ext = hasExt ? wanted.substring(dot) : '';
  for (var i = 2;; i++) {
    final c = '$stem $i$ext';
    if (!lower.contains(c.toLowerCase())) return c;
  }
}

/// Имя файла из названия заметки: без запрещённых в Windows знаков, без точек и пробелов по краям.
String safeFileName(String title) {
  var s = title.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F#^\[\]]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  s = s.replaceAll(RegExp(r'^[.\s]+|[.\s]+$'), '');
  if (s.isEmpty) s = 'Без названия';
  if (RegExp(r'^(con|prn|aux|nul|com\d|lpt\d)$', caseSensitive: false).hasMatch(s)) s = '$s _';
  return s.length > 120 ? s.substring(0, 120).trim() : s;
}
