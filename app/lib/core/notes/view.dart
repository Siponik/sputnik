// Расчёты для экрана «Знания» (docs/knowledge.md, шаг 6): дерево папок левой колонки, счётчик слов,
// куски строки для подсветки ссылок и заголовков. Без Flutter — проверяется тестом.
import 'parse.dart';

/// Строка дерева: папка или заметка, с отступом.
class TreeRow {
  final String path;
  final String name;
  final int depth;
  final bool folder;

  /// Заметок внутри (для папки, со всеми подпапками).
  final int count;
  final bool open;
  const TreeRow(this.path, this.name, this.depth, this.folder, {this.count = 0, this.open = false});
  @override
  String toString() => '${'  ' * depth}${folder ? (open ? '▾ ' : '▸ ') : ''}$name${folder ? ' $count' : ''}';
}

/// Дерево папок и заметок. Открыты — папки из [open]; заметки внутри — по названию, папки — выше заметок.
/// В открытой папке больше [cap] заметок — остальные строкой «ещё N» (путь `…more:папка`).
List<TreeRow> folderTree(Iterable<String> notes, Set<String> open, {int cap = 0}) {
  final kids = <String, Set<String>>{}; // папка → подпапки
  final inDir = <String, List<String>>{}; // папка → заметки
  final count = <String, int>{};
  for (final p in notes) {
    final dir = folderOf(p);
    (inDir[dir] ??= []).add(p);
    var d = dir;
    while (true) {
      count[d] = (count[d] ?? 0) + 1;
      if (d.isEmpty) break;
      final up = folderOf(d);
      (kids[up] ??= {}).add(d);
      d = up;
    }
  }
  int cmp(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());
  final out = <TreeRow>[];
  void walk(String dir, int depth) {
    for (final d in (kids[dir]?.toList() ?? <String>[])..sort((a, b) => cmp(baseName(a), baseName(b)))) {
      final o = open.contains(d);
      out.add(TreeRow(d, d.substring(d.lastIndexOf('/') + 1), depth, true, count: count[d] ?? 0, open: o));
      if (o) walk(d, depth + 1);
    }
    final ns = (inDir[dir] ?? <String>[])..sort((a, b) => cmp(baseName(a), baseName(b)));
    final shown = cap > 0 && ns.length > cap && !open.contains('…all:$dir') ? ns.sublist(0, cap) : ns;
    for (final n in shown) {
      out.add(TreeRow(n, baseName(n), depth, false));
    }
    if (shown.length < ns.length) out.add(TreeRow('…more:$dir', 'ещё ${ns.length - shown.length}', depth, false));
  }

  walk('', 0);
  return out;
}

/// Имя папки из полного пути на диске (и с `\`, и с `/`): `C:\\Users\\я\\Знания\\` → `Знания`.
String dirName(String abs) {
  final parts = abs.split(RegExp(r'[\\/]')).where((p) => p.isNotEmpty).toList();
  return parts.isEmpty ? abs : parts.last;
}

/// Сколько слов в тексте заметки (без шапки свойств; у ссылки с подписью считается подпись).
int wordCount(String text) {
  final fs = frontSpan(text);
  final body = fs == null ? text : text.substring(fs.bodyStart);
  return RegExp(r'[\p{L}\p{N}]+', unicode: true).allMatches(body.replaceAllMapped(RegExp(r'\[\[(?:[^\]|]*\|)?([^\]]*)\]\]'), (m) => ' ${m[1]} ')).length;
}

enum SpanKind { text, link, missing, heading, tag, code, front }

/// Кусок текста для подсветки: [start, end) в исходном тексте.
class TextPiece {
  final int start;
  final int end;
  final SpanKind kind;

  /// Для ссылки — найденный путь заметки.
  final String? to;
  const TextPiece(this.start, this.end, this.kind, [this.to]);
  @override
  String toString() => '${kind.name}[$start,$end)${to == null ? '' : '→$to'}';
}

/// Разметить текст заметки для редактора: шапка свойств, заголовки, ссылки (найденные и нет), теги.
/// Куски идут подряд и покрывают весь текст.
List<TextPiece> pieces(String path, String text, String? Function(NoteLink l) resolve) {
  final doc = parseNote(path, text);
  final marks = <TextPiece>[];
  final fs = frontSpan(text);
  if (fs != null) marks.add(TextPiece(0, fs.bodyStart, SpanKind.front));
  var off = 0;
  for (final line in text.split('\n')) {
    final s = off;
    off += line.length + 1;
    if (fs != null && s < fs.bodyStart) continue;
    if (RegExp(r'^#{1,6}\s').hasMatch(line)) marks.add(TextPiece(s, s + line.length, SpanKind.heading));
  }
  for (final l in doc.links) {
    final to = resolve(l);
    marks.add(TextPiece(l.start, l.end, to == null ? SpanKind.missing : SpanKind.link, to));
  }
  for (final m in RegExp(r'(^|\s)#([\p{L}\p{N}_/-]+)', unicode: true).allMatches(text)) {
    final st = m.start + m.group(1)!.length;
    if (fs != null && st < fs.bodyStart) continue;
    marks.add(TextPiece(st, m.end, SpanKind.tag));
  }
  // Ссылки и теги внутри заголовка важнее заголовка: режем заголовок по ним.
  marks.sort((a, b) => a.start != b.start ? a.start.compareTo(b.start) : (a.kind == SpanKind.heading ? -1 : 1));
  final out = <TextPiece>[];
  var at = 0;
  void plain(int to, SpanKind k) {
    if (to > at) out.add(TextPiece(at, to, k));
    at = to;
  }

  final heads = marks.where((m) => m.kind == SpanKind.heading || m.kind == SpanKind.front).toList();
  final inner = marks.where((m) => m.kind != SpanKind.heading && m.kind != SpanKind.front).toList();
  SpanKind base(int pos) {
    for (final h in heads) {
      if (pos >= h.start && pos < h.end) return h.kind;
    }
    return SpanKind.text;
  }

  void fillTo(int to) {
    while (at < to) {
      final k = base(at);
      var e = to;
      for (final h in heads) {
        if (h.start > at && h.start < e) e = h.start;
        if (h.end > at && h.end < e) e = h.end;
      }
      plain(e, k);
    }
  }

  for (final m in inner) {
    if (m.start < at) continue;
    if (base(m.start) == SpanKind.front) continue;
    fillTo(m.start);
    out.add(m);
    at = m.end;
  }
  fillTo(text.length);
  return out;
}
