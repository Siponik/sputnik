// Индекс «Знаний» (docs/knowledge.md, шаг 2): все заметки в памяти, разрешённые ссылки, обратные ссылки,
// заметки, которых ещё нет, упоминания без ссылки, поиск по началу слов и данные для графа.
// Всегда пересобирается из текстов файлов — своего формата хранения у него нет.
import 'parse.dart';

/// Ссылка с найденным файлом (или null — заметки ещё нет).
class ResolvedLink {
  final String from;
  final NoteLink link;
  final String? to;
  const ResolvedLink(this.from, this.link, this.to);
}

/// Обратная ссылка: кто ссылается и кусок строки вокруг.
class Backlink {
  final String from;
  final int line;
  final String snippet;
  const Backlink(this.from, this.line, this.snippet);

  Map<String, dynamic> toJson() => {'from': from, 'line': line, 'snippet': snippet};
}

/// Найденное поиском.
class NoteHit {
  final String path;
  final int score;

  /// Строка с совпадением (или начало текста), до ~90 знаков.
  final String snippet;
  final int line;
  const NoteHit(this.path, this.score, this.snippet, this.line);

  Map<String, dynamic> toJson() => {'path': path, 'score': score, 'snippet': snippet, 'line': line};
}

/// Ребро графа (без направления и без повторов): `a < b` по строке.
class GraphEdge {
  final String a;
  final String b;
  const GraphEdge(this.a, this.b);
  @override
  bool operator ==(Object other) => other is GraphEdge && other.a == a && other.b == b;
  @override
  int get hashCode => Object.hash(a, b);
  @override
  String toString() => '$a—$b';
}

/// Для поиска: строчные, ё = е.
String foldText(String s) => s.toLowerCase().replaceAll('ё', 'е');

final _word = RegExp(r'[\p{L}\p{N}]+', unicode: true);

/// Слова текста для поиска.
List<String> words(String s) => [for (final m in _word.allMatches(foldText(s))) m[0]!];

/// Кусок строки вокруг позиции [at], не длиннее [max].
String snippetAround(String line, int at, {int max = 90}) {
  final l = line.trim();
  if (l.length <= max) return l;
  final shift = line.length - line.trimLeft().length;
  var a = (at - shift - max ~/ 3).clamp(0, l.length);
  final b = (a + max).clamp(0, l.length);
  if (b - a < max) a = (b - max).clamp(0, l.length);
  return '${a > 0 ? '…' : ''}${l.substring(a, b).trim()}${b < l.length ? '…' : ''}';
}

class NoteIndex {
  final Map<String, NoteDoc> _docs = {};
  final Map<String, String> _texts = {};

  /// Файлы, которые не заметки (картинки, pdf) — на них тоже ведут ссылки.
  final Set<String> _files = {};

  Map<String, List<ResolvedLink>> _out = {};
  Map<String, List<ResolvedLink>> _in = {};

  /// Заметки, которых нет: ключ имени → ссылки на него.
  Map<String, List<ResolvedLink>> _missing = {};

  // Поисковые слова по заметке.
  final Map<String, _Words> _w = {};

  bool _dirty = true;

  NoteIndex();

  /// Индекс из текстов: `путь → текст` и список прочих файлов.
  factory NoteIndex.of(Map<String, String> notes, {Iterable<String> files = const []}) {
    final ix = NoteIndex();
    notes.forEach(ix._put);
    ix._files.addAll(files);
    return ix;
  }

  static bool isNote(String path) => path.toLowerCase().endsWith('.md');

  Iterable<String> get paths => _docs.keys;
  Iterable<String> get files => _files;
  int get length => _docs.length;
  NoteDoc? doc(String path) => _docs[path];
  String? text(String path) => _texts[path];

  void _put(String path, String text) {
    final d = parseNote(path, text);
    _docs[path] = d;
    _texts[path] = text;
    _w[path] = _Words.of(d, text);
    _dirty = true;
  }

  /// Заметка добавлена или изменилась.
  void update(String path, String text) {
    if (!isNote(path)) {
      _files.add(path);
      _dirty = true;
      return;
    }
    _put(path, text);
  }

  /// Файл удалён.
  void remove(String path) {
    _docs.remove(path);
    _texts.remove(path);
    _w.remove(path);
    _files.remove(path);
    _dirty = true;
  }

  /// Файл переименован (содержимое то же).
  void rename(String from, String to) {
    final t = _texts[from];
    if (t != null) {
      remove(from);
      update(to, t);
    } else if (_files.remove(from)) {
      _files.add(to);
      _dirty = true;
    }
  }

  void _build() {
    if (!_dirty) return;
    _dirty = false;
    final all = [..._docs.keys, ..._files];
    final aliases = {
      for (final e in _docs.entries)
        if (e.value.aliases.isNotEmpty) e.key: e.value.aliases,
    };
    final out = <String, List<ResolvedLink>>{};
    final inn = <String, List<ResolvedLink>>{};
    final miss = <String, List<ResolvedLink>>{};
    final keys = _docs.keys.toList()..sort();
    for (final p in keys) {
      final d = _docs[p]!;
      final list = <ResolvedLink>[];
      for (final l in d.links) {
        final to = resolveLink(l.target, p, all, aliases: aliases);
        final r = ResolvedLink(p, l, to);
        list.add(r);
        if (to == null) {
          miss.putIfAbsent(nameKey(baseName(l.target)), () => []).add(r);
        } else if (to != p) {
          inn.putIfAbsent(to, () => []).add(r);
        }
      }
      out[p] = list;
    }
    _out = out;
    _in = inn;
    _missing = miss;
  }

  /// Ссылки из заметки по порядку.
  List<ResolvedLink> outgoing(String path) {
    _build();
    return _out[path] ?? const [];
  }

  /// Куда ссылается заметка: пути без повторов, по порядку первой ссылки (вставки картинок — тоже).
  List<String> linksTo(String path) {
    final seen = <String>{};
    return [
      for (final r in outgoing(path))
        if (r.to != null && r.to != path && seen.add(r.to!)) r.to!,
    ];
  }

  /// Ссылки на несуществующие заметки из этой: названия без повторов.
  List<String> missingFrom(String path) {
    final seen = <String>{};
    return [
      for (final r in outgoing(path))
        if (r.to == null && !r.link.embed && seen.add(nameKey(baseName(r.link.target)))) baseName(r.link.target),
    ];
  }

  /// Все ссылки на файл [path] по заметкам — для переименования с обновлением ссылок (без ссылок заметки на себя).
  Map<String, List<NoteLink>> referencing(String path) {
    _build();
    final out = <String, List<NoteLink>>{};
    for (final r in _in[path] ?? const <ResolvedLink>[]) {
      out.putIfAbsent(r.from, () => []).add(r.link);
    }
    return out;
  }

  /// Кто ссылается на заметку: по строке ссылки, порядок — по пути и строке.
  List<Backlink> backlinks(String path) {
    _build();
    final out = <Backlink>[];
    final seen = <String>{};
    for (final r in _in[path] ?? const <ResolvedLink>[]) {
      if (!seen.add('${r.from}|${r.link.line}')) continue;
      final t = _texts[r.from]!;
      final line = _lineAt(t, r.link.line);
      out.add(Backlink(r.from, r.link.line, snippetAround(line, r.link.start - _lineStart(t, r.link.line))));
    }
    out.sort((a, b) {
      final c = a.from.compareTo(b.from);
      return c != 0 ? c : a.line.compareTo(b.line);
    });
    return out;
  }

  /// Сколько связей у заметки (входящие от разных заметок + исходящие на разные): для размера точки и сортировки.
  int degree(String path) {
    _build();
    final s = <String>{...linksTo(path).where(_docs.containsKey)};
    for (final r in _in[path] ?? const <ResolvedLink>[]) {
      s.add(r.from);
    }
    return s.length;
  }

  /// Заметки, которых ещё нет: название → кто на них ссылается (пути без повторов).
  Map<String, List<String>> missing() {
    _build();
    final out = <String, List<String>>{};
    final names = _missing.keys.toList()..sort();
    for (final k in names) {
      final rs = _missing[k]!;
      if (rs.every((r) => r.link.embed)) continue; // битая картинка — не «ненаписанная заметка»
      final name = baseName(rs.first.link.target);
      out[name] = ({for (final r in rs) r.from}.toList()..sort());
    }
    return out;
  }

  /// Упоминания названия заметки (или её aliases) в других заметках без ссылки на неё — для «Связать».
  List<Backlink> mentions(String path) {
    _build();
    final d = _docs[path];
    if (d == null) return const [];
    final names = {foldText(d.title.trim()), for (final a in d.aliases) foldText(a.trim())}..removeWhere((n) => n.length < 3);
    if (names.isEmpty) return const [];
    final linked = {for (final r in _in[path] ?? const <ResolvedLink>[]) r.from};
    final out = <Backlink>[];
    final others = _docs.keys.where((p) => p != path && !linked.contains(p)).toList()..sort();
    for (final p in others) {
      final od = _docs[p]!;
      final t = _texts[p]!;
      final body = t.substring(od.bodyStart);
      final lines = body.split('\n');
      var found = false;
      for (var i = 0; i < lines.length && !found; i++) {
        final fl = foldText(lines[i]);
        for (final n in names) {
          final at = _wholeWord(fl, n);
          if (at < 0) continue;
          // Внутри чужой [[ссылки]] — не упоминание.
          if (_insideBrackets(lines[i], at)) continue;
          out.add(Backlink(p, od.bodyLine + i, snippetAround(lines[i], at)));
          found = true;
          break;
        }
      }
    }
    return out;
  }

  /// Поиск: все слова запроса должны начинать какое-то слово заметки (ё = е, без регистра).
  /// Выше — совпадения в названии, потом aliases, теги, заголовки, свойства, текст. Равные — по названию.
  List<NoteHit> search(String query, {int limit = 50}) {
    final q = words(query);
    if (q.isEmpty) return const [];
    final hits = <NoteHit>[];
    for (final e in _w.entries) {
      final w = e.value;
      var score = 0;
      var ok = true;
      for (final x in q) {
        final s = w.score(x);
        if (s == 0) {
          ok = false;
          break;
        }
        score += s;
      }
      if (!ok) continue;
      // Все слова подряд в названии — ещё выше.
      if (foldText(w.title).contains(q.join(' '))) score += 5;
      final sn = _snippet(e.key, q);
      hits.add(NoteHit(e.key, score, sn.$1, sn.$2));
    }
    hits.sort((a, b) {
      final c = b.score.compareTo(a.score);
      if (c != 0) return c;
      final t = foldText(_docs[a.path]!.title).compareTo(foldText(_docs[b.path]!.title));
      return t != 0 ? t : a.path.compareTo(b.path);
    });
    return hits.length > limit ? hits.sublist(0, limit) : hits;
  }

  (String, int) _snippet(String path, List<String> q) {
    final d = _docs[path]!;
    final lines = _texts[path]!.substring(d.bodyStart).split('\n');
    for (var i = 0; i < lines.length; i++) {
      final fl = foldText(lines[i]);
      for (final x in q) {
        final m = RegExp('(^|[^\\p{L}\\p{N}])${RegExp.escape(x)}', unicode: true).firstMatch(fl);
        if (m != null) return (snippetAround(lines[i], m.start + m[1]!.length), d.bodyLine + i);
      }
    }
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim().isNotEmpty) return (snippetAround(lines[i], 0), d.bodyLine + i);
    }
    return ('', d.bodyLine);
  }

  /// Рёбра графа между заметками (и вложениями, если [withFiles]); [withMissing] — и с ещё не созданными (`?Название`).
  Set<GraphEdge> edges({bool withFiles = false, bool withMissing = false}) {
    _build();
    final out = <GraphEdge>{};
    for (final e in _out.entries) {
      for (final r in e.value) {
        String? to = r.to;
        if (to == null) {
          if (!withMissing || r.link.embed) continue;
          to = '?${baseName(r.link.target)}';
        } else if (!_docs.containsKey(to) && !withFiles) {
          continue;
        }
        if (to == e.key) continue;
        out.add(e.key.compareTo(to) < 0 ? GraphEdge(e.key, to) : GraphEdge(to, e.key));
      }
    }
    return out;
  }

  /// Соседи заметки до глубины [depth] (сама заметка — тоже), для локального графа.
  Set<String> neighbours(String path, {int depth = 1}) {
    final ed = edges();
    final adj = <String, Set<String>>{};
    for (final e in ed) {
      adj.putIfAbsent(e.a, () => {}).add(e.b);
      adj.putIfAbsent(e.b, () => {}).add(e.a);
    }
    final seen = {path};
    var front = {path};
    for (var i = 0; i < depth; i++) {
      final next = <String>{};
      for (final p in front) {
        for (final n in adj[p] ?? const <String>{}) {
          if (seen.add(n)) next.add(n);
        }
      }
      front = next;
    }
    return seen;
  }

  /// Все теги с числом заметок, частые выше.
  List<(String, int)> tags() {
    final count = <String, int>{};
    final shown = <String, String>{};
    for (final d in _docs.values) {
      for (final t in d.tags) {
        final k = t.toLowerCase();
        shown.putIfAbsent(k, () => t);
        count[k] = (count[k] ?? 0) + 1;
      }
    }
    final out = [for (final e in count.entries) (shown[e.key]!, e.value)];
    out.sort((a, b) {
      final c = b.$2.compareTo(a.$2);
      return c != 0 ? c : foldText(a.$1).compareTo(foldText(b.$1));
    });
    return out;
  }

  /// Заметки с тегом (без регистра; `лор` находит и `лор/фракции`).
  List<String> withTag(String tag) {
    final k = tag.toLowerCase();
    return [
      for (final e in _docs.entries)
        if (e.value.tags.any((t) => t.toLowerCase() == k || t.toLowerCase().startsWith('$k/'))) e.key,
    ]..sort();
  }
}

String _lineAt(String text, int line) {
  final ls = text.split('\n');
  final l = line < ls.length ? ls[line] : '';
  return l.endsWith('\r') ? l.substring(0, l.length - 1) : l;
}

int _lineStart(String text, int line) {
  var off = 0;
  for (var i = 0; i < line; i++) {
    final n = text.indexOf('\n', off);
    if (n < 0) return text.length;
    off = n + 1;
  }
  return off;
}

/// Позиция [w] целым словом в [s] (уже приведённых foldText), иначе -1.
int _wholeWord(String s, String w) {
  var from = 0;
  final edge = RegExp(r'[\p{L}\p{N}]', unicode: true);
  while (true) {
    final i = s.indexOf(w, from);
    if (i < 0) return -1;
    final before = i == 0 ? '' : s[i - 1];
    final after = i + w.length >= s.length ? '' : s[i + w.length];
    if ((before.isEmpty || !edge.hasMatch(before)) && (after.isEmpty || !edge.hasMatch(after))) return i;
    from = i + 1;
  }
}

bool _insideBrackets(String line, int at) {
  final open = line.lastIndexOf('[[', at);
  if (open < 0) return false;
  final close = line.lastIndexOf(']]', at);
  return close < open;
}

class _Words {
  final String title;
  final List<String> t, a, g, h, p, b;
  _Words(this.title, this.t, this.a, this.g, this.h, this.p, this.b);

  factory _Words.of(NoteDoc d, String text) {
    String props(Object? v) {
      if (v is Map) return v.entries.map((e) => '${e.key} ${props(e.value)}').join(' ');
      if (v is List) return v.map(props).join(' ');
      return v?.toString() ?? '';
    }

    return _Words(
      d.title,
      words(d.title),
      words(d.aliases.join(' ')),
      words(d.tags.join(' ')),
      words(d.headings.map((x) => x.text).join(' ')),
      words(props(d.props)),
      words(text.substring(d.bodyStart)).toSet().toList(),
    );
  }

  static bool _pre(List<String> ws, String x) => ws.any((w) => w.startsWith(x));

  int score(String x) {
    if (_pre(t, x)) return t.contains(x) ? 10 : 8;
    if (_pre(a, x)) return 6;
    if (_pre(g, x)) return 5;
    if (_pre(h, x)) return 4;
    if (_pre(p, x)) return 3;
    if (_pre(b, x)) return 1;
    return 0;
  }
}
