// Порт tracker/src/lib/route.js
// Окно «Создать» v2: умная строка и авто-определение списка. Алгоритм очков, без ИИ и без сети.
//   parseLine(строка, today:, off:) → { title, rest, day, time, priority, repeat, at, tag, marks }
//   route(текст, lists:, layer:, tasks:, current:, now:) → [{ listId, score, why, topic?, project? }] по убыванию
//   learn(route, title, listId, topic) → новые записи settings.route
import 'repeat.dart' show takeRepeat;
import 'stickers.dart' show topicsOf;
import 'templates.dart' show boardOf;
import 'when.dart' show parseWhen;

typedef Json = Map<String, dynamic>;

bool _t(Object? v) => v != null && v != false && v != 0 && v != '';
String _norm(Object? s) => (s ?? '').toString().toLowerCase().replaceAll('ё', 'е');
const _stop = {
  'для', 'над', 'под', 'про', 'или', 'это', 'того', 'чтобы', 'надо', 'нужно', 'потом', 'когда', 'после', 'перед', //
  'через', 'около', 'возле', 'всех', 'всем', 'свой', 'свою', 'своё', 'мне', 'тебе',
};
final _split = RegExp(r'[^a-zа-я0-9]+');

/// Значимые слова: без предлогов и коротких, строчными, ё = е.
List<String> words(Object? text) =>
    _norm(text).split(_split).where((w) => w.length >= 4 && !_stop.contains(w)).toList();

/// Основа слова — первые 5 букв.
String stem(String w) {
  final n = _norm(w);
  return n.length > 5 ? n.substring(0, 5) : n;
}

/// Одно слово в разных формах: общее начало не короче 4 букв.
bool sameWord(String a, String b) {
  final n = a.length < b.length ? a.length : b.length;
  var i = 0;
  while (i < n && a[i] == b[i]) {
    i++;
  }
  return i >= 4 || (i == n && n >= 3);
}

// ---------- умная строка ----------

Json parseLine(String raw, {DateTime? today, Map off = const {}}) {
  today ??= DateTime.now();
  var txt = ' $raw ';
  final found = <(String, String)>[]; // (text, kind)
  RegExpMatch? cut(RegExp re, String kind) {
    final m = re.firstMatch(txt);
    if (m == null) return null;
    found.add((m[2] ?? m[1]!, kind));
    txt = txt.replaceFirst(m[0]!, m[0]!.startsWith(' ') ? ' ' : '');
    return m;
  }

  String? at, tag;
  int? priority;
  Json? repeat;
  if (!_t(off['at'])) {
    final m = cut(RegExp(r'(\s)(@[^\s@]+)'), 'at');
    if (m != null) at = m[2]!.substring(1);
  }
  if (!_t(off['prio'])) {
    final m = cut(RegExp(r'(\s)(!{1,3})(?=\s)'), 'prio');
    if (m != null) priority = 4 - m[2]!.length;
  }
  if (!_t(off['tag'])) {
    final m = cut(RegExp(r'(\s)(#[^\s#]+)'), 'tag');
    if (m != null) tag = m[2]!.substring(1);
  }
  if (!_t(off['repeat'])) {
    final r = takeRepeat(txt);
    if (r.rule != null) {
      repeat = r.rule;
      for (final g in _diffWords(txt, r.rest)) {
        found.add((g, 'when'));
      }
      txt = ' ${r.rest} ';
    }
  }
  String? day, time;
  if (!_t(off['when'])) {
    final w = parseWhen(txt, today);
    day = w.day;
    time = w.time;
    for (final g in _diffWords(txt, w.rest)) {
      found.add((g, 'when'));
    }
    txt = w.rest;
  }
  final rest = txt.replaceAll(RegExp(r'\s+'), ' ').trim();
  return {
    'title': rest.isEmpty ? rest : rest[0].toUpperCase() + rest.substring(1),
    'rest': rest,
    'day': day,
    'time': time,
    'priority': priority,
    'repeat': repeat,
    'at': at,
    'tag': tag,
    'marks': _locate(raw, found),
  };
}

List<String> _ws(String s) => s.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

List<String> _diffWords(String a, String b) {
  final aw = _ws(a), bw = _ws(b);
  final out = <String>[];
  var j = 0;
  var cur = <String>[];
  for (final w in aw) {
    if (j < bw.length && bw[j] == w) {
      j++;
      if (cur.isNotEmpty) {
        out.add(cur.join(' '));
        cur = [];
      }
    } else {
      cur.add(w);
    }
  }
  if (cur.isNotEmpty) out.add(cur.join(' '));
  return out;
}

List<Json> _locate(String raw, List<(String, String)> found) {
  final marks = <Json>[];
  final lower = raw.toLowerCase();
  for (final (text, kind) in found) {
    final needle = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    var pos = 0, from = -1;
    while (true) {
      from = pos <= lower.length ? lower.indexOf(needle, pos) : -1;
      final f = from;
      if (f < 0 || !marks.any((m) => f < m['to'] && f + needle.length > m['from'])) break;
      pos = f + 1;
    }
    if (from < 0) continue;
    marks.add({'from': from, 'to': from + needle.length, 'kind': kind});
  }
  final idx = {for (final (i, m) in marks.indexed) m: i};
  marks.sort((a, b) {
    final c = (a['from'] as int).compareTo(b['from']);
    return c != 0 ? c : idx[a]!.compareTo(idx[b]!);
  });
  final out = <Json>[];
  for (final m in marks) {
    final last = out.isEmpty ? null : out.last;
    if (last != null &&
        last['kind'] == m['kind'] &&
        (m['from'] <= last['to'] ? '' : raw.substring(last['to'], m['from'])).trim().isEmpty) {
      last['to'] = m['to'];
    } else {
      out.add({...m});
    }
  }
  return out;
}

// ---------- словари ----------

const _work = ['клиент', 'смет', 'макет', 'правк', 'ревью', 'созвон', 'бриф', 'счет', 'заказ'];
const dict = <String, List<String>>{
  'asset3d': [
    'lowpoly', 'highpoly', 'ретоп', 'скульпт', 'uv', 'развертк', 'текстур', 'запек', 'рендер', 'модел', 'ассет', //
    'пропс', 'блокаут',
  ],
  'work': _work,
  'study': ['урок', 'курс', 'лекци', 'глав', 'конспект'],
  'personal': [
    'купить', 'забрать', 'оплатить', 'позвонить', 'записаться', 'продлить', 'убрать', 'почистить', 'починить', //
    'подарок',
  ],
  'client': _work,
};

const topicWords = <String, List<String>>{
  'покупки': ['купи', 'куплю', 'заказа', 'забра', 'посылк'],
  'звонки': ['позвон', 'набра', 'напис'],
  'здоровье': ['врач', 'стоматолог', 'анализ', '=зал'],
  'документы': ['продл', 'полис', 'паспорт', 'налог', 'оплат'],
  'дом': ['убра', 'почист', 'почин', 'постира'],
};
bool _hit(String w, String entry) => entry.startsWith('=') ? w == entry.substring(1) : w.startsWith(entry);
List<String> _allWords(String text) => _norm(text).split(_split).where((w) => w.length >= 2).toList();

// ---------- маршрут ----------

const tagTpl = <String, List<String>>{
  'asset': ['asset3d'],
  'work': ['work', 'client'],
  'client': ['client', 'work'],
  'study': ['study'],
  'personal': ['personal'],
  'ассет': ['asset3d'],
  'работа': ['work', 'client'],
  'клиент': ['client', 'work'],
  'учеба': ['study'],
  'личное': ['personal'],
};

const _wAt = 1000, _wTag = 8, _wLearn = 6, _wWord = 4, _wTopic = 3, _wSim = 3, _wSimMax = 4, _wProject = 4;
const _wCurrent = 2, _minScore = 4;
const _month = 30 * 864e5;

/// Вид доски списка: свой или вид шаблона.
String viewOf(String listId, Json? layer) => boardOf(listId, layer)['view'] as String;

/// Проекты списка (Конвейер): имена из tasks[id].project, по частоте.
List<String> projectsOf([List? listTasks, Map? layTasks]) {
  final n = <String, int>{};
  for (final t in listTasks ?? const []) {
    final p = _t(t['parent']) ? null : (layTasks?[t['id']] as Map?)?['project'];
    if (_t(p)) n[p] = (n[p] ?? 0) + 1;
  }
  final e = n.entries.toList();
  final idx = {for (final (i, x) in e.indexed) x.key: i};
  e.sort((a, b) {
    final c = b.value.compareTo(a.value);
    return c != 0 ? c : idx[a.key]!.compareTo(idx[b.key]!);
  });
  return [for (final x in e) x.key];
}

/// «@раб» → список: точное совпадение, начало названия, часть названия.
Map? findList(List<Map> lists, String word) {
  String k(Object? s) => _norm(s).replaceAll(RegExp(r'[\s\-_·.]+'), '');
  final w = k(word);
  if (w.isEmpty) return null;
  for (final test in <bool Function(String)>[(t) => t == w, (t) => t.startsWith(w), (t) => t.contains(w)]) {
    for (final l in lists) {
      if (test(k(l['title']))) return l;
    }
  }
  return null;
}

final _tagStrip = RegExp(r'(?:^|\s)[@#]\S+');

List<Json> route(
  String text, {
  List<Map> lists = const [],
  Json? layer,
  Map tasks = const {},
  String? current,
  int? now,
}) {
  if (lists.isEmpty) return [];
  layer ??= {};
  now ??= DateTime.now().millisecondsSinceEpoch;
  final at = RegExp(r'(?:^|\s)@([^\s@]+)').firstMatch(text);
  final atList = at != null ? findList(lists, at[1]!) : null;
  final tagM = RegExp(r'(?:^|\s)#([^\s#]+)').firstMatch(text);
  final tagT = tagM != null ? tagTpl[_norm(tagM[1])] ?? const [] : const <String>[];
  final stripped = text.replaceAll(_tagStrip, ' ');
  final ws = words(stripped);
  final all = _allWords(stripped);
  final learned = ((layer['settings'] as Map?)?['route'] as Map?) ?? const {};
  final layTasks = (layer['tasks'] as Map?) ?? const {};

  final out = <Json>[];
  for (final (i, l) in lists.indexed) {
    final r = <String, dynamic>{'listId': l['id'], 'score': 0, 'i': i, 'parts': <String, num>{}};
    final parts = r['parts'] as Map<String, num>;
    void add(String kind, num pts) {
      r['score'] = (r['score'] as num) + pts;
      parts[kind] = (parts[kind] ?? 0) + pts;
    }

    final board = boardOf(l['id'], layer);
    final tpl = board['id'];
    final view = board['view'];

    if (atList != null && atList['id'] == l['id']) add('at', _wAt);
    if (tagT.contains(tpl)) add('tag', tagT[0] == tpl ? _wTag : _wTag / 2);

    for (final w in ws) {
      final e = learned[stem(w)];
      if (e is Map && e['list'] == l['id']) {
        final n = (e['n'] ?? 1) as num;
        add('learn', _wLearn + 2 * (n < 5 ? n : 5));
        r['learnWord'] ??= w;
        if (_t(e['topic']) && !_t(r['topic'])) {
          r['topic'] = e['topic'];
          r['topicWord'] = w;
          r['topicWhy'] = 'learn';
        }
      }
    }
    for (final w in all) {
      if ((dict[tpl] ?? const []).any((e) => _hit(w, e))) {
        add('word', _wWord);
        r['word'] ??= w;
      }
    }
    if (view == 'stickers') {
      final topics = topicsOf((layer['lists'] as Map?)?[l['id']]);
      outer:
      for (final w in all) {
        for (final t in topics) {
          final nm = _norm(t['name']);
          if (sameWord(w, nm) || (topicWords[nm] ?? const []).any((e) => _hit(w, e))) {
            add('word', _wTopic);
            r['word'] ??= w;
            if (!_t(r['topic'])) {
              r['topic'] = t['id'];
              r['topicWord'] = w;
            }
            break outer;
          }
        }
      }
    }
    final titleWords = words(l['title']);
    final known = [...titleWords];
    for (final t in (tasks[l['id']] as List?) ?? const []) {
      if (_t(t['parent'])) continue;
      if (t['status'] == 'completed') {
        final d = DateTime.tryParse('${t['completed'] ?? t['updated'] ?? ''}');
        if (!(d != null && d.millisecondsSinceEpoch > now - _month)) continue;
      }
      known.addAll(words(t['title']));
    }
    final simHits = ws.where((w) => known.any((k) => sameWord(w, k))).toList();
    r['simN'] = simHits.length;
    r['titleHit'] = simHits.any((w) => titleWords.any((k) => sameWord(w, k)));
    if (simHits.isNotEmpty) add('sim', _wSim * (simHits.length < _wSimMax ? simHits.length : _wSimMax));
    if (view == 'pipe') {
      for (final p in projectsOf(tasks[l['id']], layTasks)) {
        final pw = words(p);
        final hits = ws.where((w) => pw.any((k) => sameWord(w, k)));
        if (hits.isNotEmpty) {
          add('project', _wProject);
          r['project'] = p;
          r['projectWord'] = hits.first;
          break;
        }
      }
    }
    if (l['id'] == current) add('current', _wCurrent);
    out.add(r);
  }

  int cur(Json r) => r['listId'] == current ? 1 : 0;
  out.sort((a, b) {
    final c = (b['score'] as num).compareTo(a['score']);
    if (c != 0) return c;
    final d = cur(b) - cur(a);
    return d != 0 ? d : (a['i'] as int).compareTo(b['i']);
  });
  num own(Json r) => (r['score'] as num) - ((r['parts'] as Map)['current'] ?? 0);
  if (own(out[0]) < _minScore) {
    final k = out.indexWhere((r) => r['listId'] == current);
    if (k >= 0) out.insert(0, out.removeAt(k));
  }
  return [
    for (final (i, r) in out.indexed)
      {
        'listId': r['listId'],
        'score': r['score'],
        'why': _whyOf(r, i == 0 && own(r) < _minScore, at?[1], tagM?[1]),
        if (_t(r['topic'])) ...{
          'topic': r['topic'],
          'topicWhy': r['topicWhy'] == 'learn' ? 'запомнил «${r['topicWord']}»' : 'по слову «${r['topicWord']}»',
        },
        if (_t(r['project'])) ...{'project': r['project'], 'projectWord': r['projectWord']},
      },
  ];
}

String _whyOf(Json r, bool weak, String? atWord, String? tagWord) {
  final p = r['parts'] as Map;
  bool has(String k) => _t(p[k]);
  if (has('at')) return 'указано @$atWord';
  if (has('tag')) return 'указано #$tagWord';
  if (weak) return has('current') ? 'текущая доска' : 'по умолчанию';
  if (has('learn')) return 'запомнил «${r['learnWord']}»';
  if (((r['simN'] as int) >= 3 && r['titleHit'] == true) || (has('sim') && !has('word'))) {
    return 'похоже на задачи этой доски';
  }
  if (has('word')) return 'по слову «${r['word']}»';
  if (has('project')) return 'проект «${r['project']}»';
  return has('current') ? 'текущая доска' : 'по умолчанию';
}

/// Обучение: 1–2 значимых слова названия → записи settings.route { основа: { list, topic?, n } }.
Json learn(Map? current, String title, String listId, [String? topic]) {
  final out = <String, dynamic>{};
  for (final w in words(title).take(2)) {
    final k = stem(w);
    final e = current?[k];
    final same = e is Map && e['list'] == listId;
    out[k] = {'list': listId, if (_t(topic)) 'topic': topic, 'n': same ? ((e['n'] ?? 1) as num) + 1 : 1};
  }
  return out;
}
