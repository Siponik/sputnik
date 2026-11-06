// Разбор одной заметки «Знаний» (docs/knowledge.md, шаг 1): шапка YAML, [[ссылки]], #теги, чек-листы,
// заголовки, вставки картинок. Своего JS-источника нет — модуль новый. Правила ссылок — как в Obsidian/Foam,
// чтобы та же папка одинаково читалась и другими программами.
//
// Только чистая логика: ни файлов, ни Flutter. Путь заметки — относительный, через «/», с расширением (`3D/Щит.md`).
import 'dart:convert';

import 'package:yaml/yaml.dart';

/// Ссылка из заметки: `[[цель#раздел^блок|подпись]]`, `![[вставка]]` или обычная Markdown-ссылка на `.md`.
class NoteLink {
  /// Куда ведёт, как написано (без раздела и подписи): «Щит паладина», «3D/Щит», «карта.png».
  final String target;
  final String? heading;
  final String? block;
  final String? alias;

  /// `![[…]]` — вставка (картинка или кусок другой заметки).
  final bool embed;

  /// `[текст](путь.md)` вместо `[[…]]`.
  final bool markdown;

  /// Номер строки (с 0) во всём файле и смещения в тексте файла.
  final int line;
  final int start;
  final int end;

  const NoteLink({
    required this.target,
    this.heading,
    this.block,
    this.alias,
    this.embed = false,
    this.markdown = false,
    required this.line,
    required this.start,
    required this.end,
  });

  /// Текст, который видит человек: подпись или цель.
  String get label => alias ?? (heading != null && target.isEmpty ? heading! : target);

  Map<String, dynamic> toJson() => {
        'target': target,
        if (heading != null) 'heading': heading,
        if (block != null) 'block': block,
        if (alias != null) 'alias': alias,
        if (embed) 'embed': true,
        if (markdown) 'markdown': true,
        'line': line,
      };
}

/// Строка чек-листа `- [ ] текст` / `- [x] текст`.
class NoteTask {
  final int line;
  final bool done;
  final String text;
  final int indent;
  const NoteTask({required this.line, required this.done, required this.text, this.indent = 0});

  Map<String, dynamic> toJson() => {'line': line, 'done': done, 'text': text, if (indent > 0) 'indent': indent};
}

/// Заголовок `## Текст`.
class NoteHeading {
  final int line;
  final int level;
  final String text;
  const NoteHeading({required this.line, required this.level, required this.text});

  Map<String, dynamic> toJson() => {'line': line, 'level': level, 'text': text};
}

/// Разобранная заметка.
class NoteDoc {
  final String path;

  /// Название: `title` из шапки, иначе имя файла без расширения.
  final String title;

  /// Свойства из шапки (обычные Map/List/String/num/bool). Шапки нет или она испорчена — пусто.
  final Map<String, dynamic> props;

  /// Шапка есть, но YAML не читается: показать предупреждение, файл не трогать.
  final bool frontError;

  /// Текст шапки как есть (между `---`) — для бережной правки одной строки.
  final String? frontRaw;

  /// Смещение, с которого начинается текст после шапки.
  final int bodyStart;

  /// Строка, с которой начинается текст после шапки.
  final int bodyLine;

  final List<NoteLink> links;

  /// Теги без «#», в исходном написании, без повторов (сравнение без регистра), порядок появления: шапка, потом текст.
  final List<String> tags;

  /// Другие названия из `aliases` — по ним тоже находится ссылка.
  final List<String> aliases;

  final List<NoteTask> tasks;
  final List<NoteHeading> headings;

  const NoteDoc({
    required this.path,
    required this.title,
    required this.props,
    required this.frontError,
    required this.frontRaw,
    required this.bodyStart,
    required this.bodyLine,
    required this.links,
    required this.tags,
    required this.aliases,
    required this.tasks,
    required this.headings,
  });

  /// Текст без шапки.
  String body(String text) => text.substring(bodyStart);
}

/// Имя файла без папки и без `.md`.
String baseName(String path) {
  final i = path.lastIndexOf('/');
  final f = i < 0 ? path : path.substring(i + 1);
  return f.toLowerCase().endsWith('.md') ? f.substring(0, f.length - 3) : f;
}

/// Папка файла (`3D/Техники`), у файла в корне — ''.
String folderOf(String path) {
  final i = path.lastIndexOf('/');
  return i < 0 ? '' : path.substring(0, i);
}

/// Обычные Dart-значения из YAML (YamlMap → Map и т. п.).
dynamic plainYaml(dynamic v) {
  if (v is YamlMap) return {for (final e in v.entries) e.key.toString(): plainYaml(e.value)};
  if (v is YamlList) return [for (final x in v) plainYaml(x)];
  if (v is Map) return {for (final e in v.entries) e.key.toString(): plainYaml(e.value)};
  if (v is List) return [for (final x in v) plainYaml(x)];
  return v;
}

final _frontOpen = RegExp(r'^---[ \t]*\r?\n');
final _frontClose = RegExp(r'^(---|\.\.\.)[ \t]*(\r?\n|$)', multiLine: true);

/// Где шапка YAML: начало и конец её текста (между `---`) и начало остального текста. Нет шапки — null.
/// Шапка — только в самом начале файла (после необязательного BOM).
({int rawStart, int rawEnd, int bodyStart})? frontSpan(String text) {
  final off = text.startsWith('\uFEFF') ? 1 : 0;
  final s = text.substring(off);
  final m = _frontOpen.matchAsPrefix(s);
  if (m == null) return null;
  final c = _frontClose.firstMatch(s.substring(m.end));
  if (c == null) return null;
  return (rawStart: off + m.end, rawEnd: off + m.end + c.start, bodyStart: off + m.end + c.end);
}

/// Шапка YAML: `(raw, bodyStart)` или null, если её нет.
(String, int)? splitFront(String text) {
  final f = frontSpan(text);
  if (f == null) return null;
  return (text.substring(f.rawStart, f.rawEnd), f.bodyStart);
}

final _tagChar = RegExp(r'[\p{L}\p{N}_\-/]', unicode: true);
final _onlyDigits = RegExp(r'^[0-9]+$');

/// Тег из строки шапки: без «#», без пробелов по краям. Пусто или только цифры — не тег.
String? cleanTag(Object? v) {
  var t = (v ?? '').toString().trim();
  while (t.startsWith('#')) {
    t = t.substring(1);
  }
  if (t.isEmpty || _onlyDigits.hasMatch(t)) return null;
  for (final r in t.runes) {
    if (!_tagChar.hasMatch(String.fromCharCode(r))) return null;
  }
  return t;
}

List<String> _listProp(Object? v) {
  if (v == null) return const [];
  if (v is List) return [for (final x in v) if (x != null) x.toString()];
  // «tags: a, b» и «tags: a b» — так тоже пишут.
  return v.toString().split(RegExp(r'[,\s]+')).where((x) => x.isNotEmpty).toList();
}

final _fence = RegExp(r'^\s{0,3}(`{3,}|~{3,})');
final _heading = RegExp(r'^\s{0,3}(#{1,6})[ \t]+(.*?)[ \t#]*$');
final _task = RegExp(r'^(\s*)(?:[-*+]|\d+[.)])[ \t]+\[([ xX])\][ \t]+(.*)$');
final _wiki = RegExp(r'(!?)\[\[([^\[\]\n]+?)\]\]');
final _mdLink = RegExp(r'(!?)\[([^\]\n]*)\]\(<?([^)\s>]+)>?(?:\s+"[^"]*")?\)');
final _inlineCode = RegExp(r'`+');
final _tagIn = RegExp(r'(^|[\s(\[{,;:!?«"])#([\p{L}\p{N}_\-/]+)', unicode: true);
final _letter = RegExp(r'[\p{L}_\-/]', unicode: true);

/// Куски строки внутри `кода` — их не разбираем.
List<(int, int)> _codeSpans(String line) {
  final out = <(int, int)>[];
  final ticks = _inlineCode.allMatches(line).toList();
  var i = 0;
  while (i < ticks.length) {
    final open = ticks[i];
    var j = i + 1;
    while (j < ticks.length && ticks[j].group(0)!.length != open.group(0)!.length) {
      j++;
    }
    if (j >= ticks.length) break;
    out.add((open.start, ticks[j].end));
    i = j + 1;
  }
  return out;
}

bool _inSpans(List<(int, int)> spans, int a) => spans.any((s) => a >= s.$1 && a < s.$2);

/// Разбор `[[цель#раздел^блок|подпись]]` (внутренность скобок).
({String target, String? heading, String? block, String? alias}) splitWiki(String inner) {
  String? alias;
  var s = inner;
  // В таблицах Markdown «|» экранируют: [[цель\|подпись]].
  final bar = s.indexOf(RegExp(r'\\?\|'));
  if (bar >= 0) {
    final m = RegExp(r'\\?\|').matchAsPrefix(s, bar)!;
    alias = s.substring(m.end).trim();
    s = s.substring(0, bar);
    if (alias.isEmpty) alias = null;
  }
  String? heading, block;
  final caret = s.indexOf('#^');
  if (caret >= 0) {
    block = s.substring(caret + 2).trim();
    s = s.substring(0, caret);
  } else {
    final hash = s.indexOf('#');
    if (hash >= 0) {
      heading = s.substring(hash + 1).trim();
      s = s.substring(0, hash);
      if (heading.isEmpty) heading = null;
    }
  }
  return (target: s.trim(), heading: heading, block: block, alias: alias);
}

/// «%20» и другие %XX → символы; остальное (в т. ч. кириллица как есть) не трогаем. Битая запись остаётся как была.
String percentDecode(String s) {
  if (!s.contains('%')) return s;
  return s.replaceAllMapped(RegExp(r'(?:%[0-9A-Fa-f]{2})+'), (m) {
    final bytes = [for (var i = 0; i < m[0]!.length; i += 3) int.parse(m[0]!.substring(i + 1, i + 3), radix: 16)];
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return m[0]!;
    }
  });
}

bool _external(String url) => RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*:').hasMatch(url) || url.startsWith('#');

/// Разобрать заметку. [path] — путь в папке заметок (`3D/Техники/Запекание нормалей.md`).
NoteDoc parseNote(String path, String text) {
  Map<String, dynamic> props = {};
  var frontError = false;
  String? frontRaw;
  var bodyStart = 0;
  final front = splitFront(text);
  if (front != null) {
    frontRaw = front.$1;
    bodyStart = front.$2;
    if (frontRaw.trim().isNotEmpty) {
      try {
        final y = loadYaml(frontRaw);
        if (y is YamlMap) {
          props = Map<String, dynamic>.from(plainYaml(y) as Map);
        } else if (y != null) {
          frontError = true;
        }
      } catch (_) {
        frontError = true;
      }
    }
  }
  final bodyLine = '\n'.allMatches(text.substring(0, bodyStart)).length;

  final tags = <String>[];
  final seenTags = <String>{};
  void addTag(String? t) {
    if (t == null) return;
    if (seenTags.add(t.toLowerCase())) tags.add(t);
  }

  for (final t in _listProp(props['tags'] ?? props['tag'])) {
    addTag(cleanTag(t));
  }
  // У aliases строкой делят только запятые: «aliases: Мира, Мира Тёрн».
  final aliasProp = props['aliases'] ?? props['alias'];
  final aliasList = [
    for (final a in (aliasProp is List ? aliasProp.map((x) => '${x ?? ''}') : '${aliasProp ?? ''}'.split(',')))
      if (a.trim().isNotEmpty) a.trim(),
  ];

  final links = <NoteLink>[];
  final tasks = <NoteTask>[];
  final headings = <NoteHeading>[];

  final lines = text.substring(bodyStart).split('\n');
  var off = bodyStart;
  String? fence;
  for (var n = 0; n < lines.length; n++) {
    final raw = lines[n];
    final line = raw.endsWith('\r') ? raw.substring(0, raw.length - 1) : raw;
    final ln = bodyLine + n;
    final f = _fence.firstMatch(line);
    if (fence != null) {
      if (f != null && f.group(1)![0] == fence[0] && f.group(1)!.length >= fence.length) fence = null;
      off += raw.length + 1;
      continue;
    }
    if (f != null) {
      fence = f.group(1);
      off += raw.length + 1;
      continue;
    }
    // Отступ 4 пробела или таб — блок кода (кроме вложенных пунктов списка).
    final indentedCode = RegExp(r'^( {4}|\t)').hasMatch(line) && !RegExp(r'^\s*([-*+]|\d+[.)])\s').hasMatch(line);
    if (indentedCode) {
      off += raw.length + 1;
      continue;
    }

    final h = _heading.firstMatch(line);
    if (h != null) headings.add(NoteHeading(line: ln, level: h.group(1)!.length, text: h.group(2)!.trim()));

    final t = _task.firstMatch(line);
    if (t != null) {
      tasks.add(NoteTask(
        line: ln,
        done: t.group(2)!.toLowerCase() == 'x',
        text: t.group(3)!.trim(),
        indent: t.group(1)!.replaceAll('\t', '    ').length,
      ));
    }

    final code = _codeSpans(line);
    final taken = <(int, int)>[];
    for (final m in _wiki.allMatches(line)) {
      if (_inSpans(code, m.start)) continue;
      final p = splitWiki(m.group(2)!);
      if (p.target.isEmpty && p.heading == null && p.block == null) continue;
      taken.add((m.start, m.end));
      links.add(NoteLink(
        target: p.target,
        heading: p.heading,
        block: p.block,
        alias: p.alias,
        embed: m.group(1) == '!',
        line: ln,
        start: off + m.start,
        end: off + m.end,
      ));
    }
    for (final m in _mdLink.allMatches(line)) {
      if (_inSpans(code, m.start) || _inSpans(taken, m.start)) continue;
      var url = m.group(3)!;
      if (_external(url)) continue;
      url = percentDecode(url);
      String? heading;
      final hash = url.indexOf('#');
      if (hash >= 0) {
        heading = url.substring(hash + 1);
        url = url.substring(0, hash);
        if (heading.isEmpty) heading = null;
      }
      final embed = m.group(1) == '!';
      // Обычная ссылка считается связью только на заметку; картинки — как вставки.
      if (!embed && !url.toLowerCase().endsWith('.md')) continue;
      final label = m.group(2)!.trim();
      taken.add((m.start, m.end));
      links.add(NoteLink(
        target: url,
        heading: heading,
        alias: label.isEmpty ? null : label,
        embed: embed,
        markdown: true,
        line: ln,
        start: off + m.start,
        end: off + m.end,
      ));
    }
    for (final m in _tagIn.allMatches(line)) {
      final at = m.start + m.group(1)!.length;
      if (_inSpans(code, at) || _inSpans(taken, at)) continue;
      // «# Заголовок» — не тег: после # пробел, сюда не попадёт. «#123» — не тег.
      final name = m.group(2)!;
      if (!name.runes.any((r) => _letter.hasMatch(String.fromCharCode(r)))) continue;
      addTag(name);
    }
    off += raw.length + 1;
  }

  final ft = props['title'];
  final title = (ft is String && ft.trim().isNotEmpty) ? ft.trim() : baseName(path);

  return NoteDoc(
    path: path,
    title: title,
    props: props,
    frontError: frontError,
    frontRaw: frontRaw,
    bodyStart: bodyStart,
    bodyLine: bodyLine,
    links: links,
    tags: tags,
    aliases: aliasList,
    tasks: tasks,
    headings: headings,
  );
}

/// Ключ для сравнения имён заметок: без регистра, пробелы схлопнуты. Как в Obsidian, ё и е — разные буквы.
String nameKey(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

String _normPath(String p) {
  final parts = <String>[];
  for (final s in p.replaceAll('\\', '/').split('/')) {
    if (s.isEmpty || s == '.') continue;
    if (s == '..') {
      if (parts.isNotEmpty) parts.removeLast();
      continue;
    }
    parts.add(s);
  }
  return parts.join('/');
}

/// Найти файл, на который ведёт ссылка [target] из заметки [from].
///
/// [paths] — все файлы папки (заметки и вложения), [aliases] — другие названия заметок (`путь → названия`).
/// Правила (как в Obsidian): путь с папкой — по концу пути; просто имя — по имени файла без регистра, `.md` можно
/// не писать; несколько одинаковых имён — сначала та же папка, потом самый короткий путь, потом по алфавиту.
/// Не нашли файл — по `aliases`. Ничего нет — null (заметки ещё нет).
String? resolveLink(String target, String from, Iterable<String> paths, {Map<String, List<String>> aliases = const {}}) {
  final t0 = target.trim();
  if (t0.isEmpty) return from; // [[#Раздел]] — ссылка внутри своей заметки
  final all = paths.toList();
  final byLower = <String, List<String>>{};
  for (final p in all) {
    byLower.putIfAbsent(p.toLowerCase(), () => []).add(p);
  }

  String? pick(List<String> c) {
    if (c.isEmpty) return null;
    if (c.length == 1) return c.first;
    final dir = folderOf(from).toLowerCase();
    final same = c.where((p) => folderOf(p).toLowerCase() == dir).toList();
    final pool = same.isNotEmpty ? same : c;
    pool.sort((a, b) {
      final d = a.split('/').length.compareTo(b.split('/').length);
      if (d != 0) return d;
      final l = a.length.compareTo(b.length);
      return l != 0 ? l : a.compareTo(b);
    });
    return pool.first;
  }

  final t = t0.replaceAll('\\', '/');
  final cands = <String>{t.toLowerCase()};
  if (!t.toLowerCase().endsWith('.md')) cands.add('${t.toLowerCase()}.md');

  // Относительный путь от папки заметки: [](../Щит.md), [[./Щит]].
  if (t.startsWith('./') || t.startsWith('../')) {
    final rel = _normPath('${folderOf(from)}/$t').toLowerCase();
    for (final c in [rel, if (!rel.endsWith('.md')) '$rel.md']) {
      final hit = byLower[c];
      if (hit != null) return pick(List.of(hit));
    }
    return null;
  }

  final clean = _normPath(t);
  if (clean.contains('/')) {
    final key = clean.toLowerCase();
    // Полный путь от корня папки.
    for (final c in [key, if (!key.endsWith('.md')) '$key.md']) {
      final hit = byLower[c];
      if (hit != null) return pick(List.of(hit));
    }
    // Конец пути: [[Техники/Запекание]] находит «3D/Техники/Запекание.md».
    final ends = all.where((p) {
      final lp = p.toLowerCase();
      return cands.any((c) => lp.endsWith('/${_normPath(c)}'));
    }).toList();
    final r = pick(ends);
    if (r != null) return r;
  } else {
    final name = clean.toLowerCase();
    final byName = all.where((p) {
      final i = p.lastIndexOf('/');
      final f = (i < 0 ? p : p.substring(i + 1)).toLowerCase();
      return f == name || f == '$name.md';
    }).toList();
    final r = pick(byName);
    if (r != null) return r;
  }

  final key = nameKey(baseName(clean));
  final byAlias = [
    for (final e in aliases.entries)
      if (e.value.any((a) => nameKey(a) == key)) e.key,
  ];
  return pick(byAlias);
}
