// Порт tracker/src/lib/stickers.js — вид «Стикеры»: раскладка по темам / срокам / людям, порядок, сроки, наклон.
// Даты — 'ГГГГ-ММ-ДД', today передаётся снаружи.
import 'repeat.dart' show takeRepeat;
import 'spheres.dart' show sphereColors;
import 'when.dart' show parseWhen;

typedef Json = Map<String, dynamic>;

const defaultTopics = <Json>[
  {'id': 'docs', 'name': 'Документы', 'color': 'clay'},
  {'id': 'buy', 'name': 'Покупки', 'color': 'gold'},
  {'id': 'call', 'name': 'Звонки', 'color': 'work'},
  {'id': 'health', 'name': 'Здоровье', 'color': 'study'},
  {'id': 'home', 'name': 'Дом', 'color': 'personal'},
];
const misc = <String, dynamic>{'id': '', 'name': 'Разное', 'c': 'var(--ink-faint)'};

bool _t(Object? v) => v != null && v != false && v != 0 && v != '';

List topicsOf(Object? layList) =>
    layList is Map && layList['topics'] is List ? layList['topics'] as List : defaultTopics;

String topicColor(Object? t) {
  if (!_t(t) || t is! Map) return misc['c'] as String;
  return sphereColors.firstWhere((c) => c['id'] == t['color'], orElse: () => sphereColors[0])['v'] as String;
}

DateTime _parse(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String plusDays(String s, int n) {
  final d = _parse(s);
  return _fmt(DateTime(d.year, d.month, d.day + n));
}

int _dow(String s) => _parse(s).weekday % 7; // вс = 0, как getDay
bool _isSunday(String s) => _dow(s) == 0;
int _diff(String a, String b) => (_parse(a).difference(_parse(b)).inHours / 24).round();

String weekEnd(String today) => _isSunday(today) ? plusDays(today, 7) : plusDays(today, 7 - _dow(today));

/// today | week | later.
String bucket(String? due, String today) {
  if (!_t(due)) return 'later';
  if (due!.compareTo(today) <= 0) return 'today';
  return due.compareTo(weekEnd(today)) <= 0 ? 'week' : 'later';
}

const whenLanes = <Json>[
  {'id': 'today', 'name': 'Сегодня', 'c': 'var(--clay)'},
  {'id': 'week', 'name': 'На неделе', 'c': 'var(--ink-faint)', 'sub': 'до воскресенья'},
  {'id': 'later', 'name': 'Когда-нибудь', 'c': 'var(--ink-faint)', 'sub': 'без срока или позже'},
];

String? whenDue(String target, String? cur, String today) {
  if (target == 'today') return today;
  if (target == 'later') return null;
  if (_t(cur) && bucket(cur, today) == 'week') return cur;
  return _isSunday(today) ? weekEnd(today) : plusDays(today, 1);
}

String? newDue(String target, String today) => target == 'today'
    ? today
    : target == 'week'
    ? plusDays(today, 1)
    : null;

const _wd = ['вс', 'пн', 'вт', 'ср', 'чт', 'пт', 'сб'];
const _mon = ['янв.', 'февр.', 'мар.', 'апр.', 'мая', 'июн.', 'июл.', 'авг.', 'сент.', 'окт.', 'нояб.', 'дек.'];
const _monGen = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];
String _short(String s) {
  final d = _parse(s);
  return '${d.day} ${_mon[d.month - 1]}';
}

/// Подпись срока: { text, cls: late | soon | '' }.
Json dueLabel(String? due, String today, [Object? slot, bool hideToday = false]) {
  if (!_t(due)) return {'text': '', 'cls': ''};
  final n = _diff(due!, today);
  if (n < 0) return {'text': 'просрочено · ${n == -1 ? 'вчера' : _short(due)}', 'cls': 'late'};
  final s = slot is Map ? slot['s'] : null;
  final at = _t(s) ? ', $s' : '';
  if (n == 0) return {'text': hideToday && at.isEmpty ? '' : 'сегодня$at', 'cls': 'soon'};
  if (n == 1) return {'text': 'завтра$at', 'cls': ''};
  if (due.compareTo(weekEnd(today)) <= 0) return {'text': _wd[_dow(due)] + at, 'cls': ''};
  return {'text': _short(due) + at, 'cls': ''};
}

String todaySub(String today) {
  final d = _parse(today);
  return '${_wd[_dow(today)]}, ${d.day} ${_monGen[d.month - 1]} · и просроченное';
}

/// Порядок в колонке: закреплённые; при sort = due — просроченные и ближайшие; потом свой порядок ord, потом position.
List<Json> order(List<Json> items, Map? layTasks, String today, [String sort = 'pin']) {
  Map L(Json t) => (layTasks?[t['id']] as Map?) ?? const {};
  String due(Json t) => _t(t['due']) ? (t['due'] as String).substring(0, 10) : '';
  double ord(Json t) => L(t)['ord'] is num ? (L(t)['ord'] as num).toDouble() : double.infinity;
  int byOrd(Json a, Json b) {
    final oa = ord(a), ob = ord(b);
    final d = (oa == ob) ? 0 : (oa - ob).sign.toInt(); // Infinity - Infinity = NaN → 0, как || 0 в JS
    if (d != 0) return d;
    return ((a['position'] ?? '') as String).compareTo((b['position'] ?? '') as String).sign;
  }

  final idx = List.generate(items.length, (i) => i);
  idx.sort((i, j) {
    final a = items[i], b = items[j];
    final p = (_t(L(b)['pin']) ? 1 : 0) - (_t(L(a)['pin']) ? 1 : 0);
    if (p != 0) return p;
    if (sort == 'due') {
      final la = due(a).isNotEmpty && due(a).compareTo(today) < 0 ? 0 : 1;
      final lb = due(b).isNotEmpty && due(b).compareTo(today) < 0 ? 0 : 1;
      if (la != lb) return la - lb;
      final da = due(a).isEmpty ? '9999' : due(a), db = due(b).isEmpty ? '9999' : due(b);
      if (da != db) return da.compareTo(db) < 0 ? -1 : 1;
    }
    final c = byOrd(a, b);
    return c != 0 ? c : i - j;
  });
  return [for (final i in idx) items[i]];
}

/// Колонки стены [{ id, name, c, sub, items }].
List<Json> lanes(
  List<Json> tasks, {
  String group = 'topic',
  List topics = defaultTopics,
  Map? layTasks = const {},
  required String today,
  String sort = 'pin',
  List people = const [],
  String me = '',
}) {
  if (group == 'people') {
    return peopleLanes(tasks, layTasks: layTasks, today: today, sort: sort, people: people, me: me);
  }
  if (group == 'when') {
    return [
      for (final w in whenLanes)
        {
          ...w,
          'sub': w['id'] == 'today' ? todaySub(today) : w['sub'],
          'items': order(
            tasks
                .where((t) => bucket(_t(t['due']) ? (t['due'] as String).substring(0, 10) : '', today) == w['id'])
                .toList(),
            layTasks,
            today,
            'due',
          ),
        },
    ];
  }
  final known = {for (final t in topics) t['id']};
  String topicId(Json t) {
    final tp = (layTasks?[t['id']] as Map?)?['topic'];
    return known.contains(tp) ? tp as String : '';
  }

  final out = <Json>[
    for (final tp in topics)
      {
        'id': tp['id'],
        'name': tp['name'],
        'c': topicColor(tp),
        'sub': '',
        'items': order(tasks.where((t) => topicId(t) == tp['id']).toList(), layTasks, today, sort),
      },
  ];
  final m = tasks.where((t) => topicId(t) == '').toList();
  if (m.isNotEmpty) out.add({...misc, 'sub': '', 'items': order(m, layTasks, today, sort)});
  return out;
}

/// «По людям»: «Я» первым, потом остальные, «Ничьи» последней.
List<Json> peopleLanes(
  List<Json> tasks, {
  Map? layTasks = const {},
  required String today,
  String sort = 'pin',
  List people = const [],
  String me = '',
}) {
  String whoOf(Json t) {
    final w = (layTasks?[t['id']] as Map?)?['who'];
    return _t(w) ? w as String : '';
  }

  final ppl = [...people.where((p) => p['email'] == me), ...people.where((p) => p['email'] != me)];
  final out = <Json>[];
  for (final p in ppl) {
    final items = tasks.where((t) => whoOf(t) == p['email']).toList();
    if (!_t(p['joined']) && items.isEmpty) continue;
    out.add({
      'id': p['email'],
      'name': p['email'] == me ? 'Я' : p['name'],
      'c': p['color'],
      'm': p,
      'sub': '',
      'items': order(items, layTasks, today, sort),
    });
  }
  final known = {for (final l in out) l['id']};
  final none = tasks.where((t) => whoOf(t).isEmpty || !known.contains(whoOf(t))).toList();
  out.add({
    'id': '',
    'name': 'Ничьи',
    'c': 'var(--ink-faint)',
    'm': null,
    'sub': '',
    'items': order(none, layTasks, today, sort),
  });
  return out;
}

/// Следующая раскладка: to — нужная, иначе по кругу.
String nextGroup(String cur, Object? to, [bool shared = false]) {
  final all = shared ? ['topic', 'when', 'people'] : ['topic', 'when'];
  if (to is String && all.contains(to)) return to;
  return all[(all.indexOf(cur) + 1) % all.length];
}

/// Какие колонки показать: { shown, hidden }.
({List<Json> shown, List<Json> hidden}) visibleLanes(List<Json> all, {String group = 'topic', Object? keep}) {
  bool empty(Json l) => (l['items'] as List).isEmpty;
  if (group == 'when' || group == 'people' || all.every(empty)) return (shown: all, hidden: <Json>[]);
  bool vis(Json l) => !empty(l) || (keep != null && l['id'] == keep);
  return (shown: all.where(vis).toList(), hidden: all.where((l) => !vis(l)).toList());
}

Object? topicOfTask(Json task, Map? layTasks, List topics) {
  final tp = (layTasks?[task['id']] as Map?)?['topic'];
  for (final t in topics) {
    if (t['id'] == tp) return t;
  }
  return null;
}

/// Наклон −1,5°…+1,5°, постоянный для задачи (FNV-1a по id).
double tilt(Object? id) {
  var h = 2166136261;
  for (final cp in '$id'.runes) {
    h = (h ^ cp) & 0xFFFFFFFF;
    h = (h * 16777619) & 0xFFFFFFFF;
  }
  return ((h % 31) - 15) / 10;
}

/// Сделано за 7 дней — число в «баночке».
int jarCount(List<Json> tasks, [int? now]) {
  final n = now ?? DateTime.now().millisecondsSinceEpoch;
  return tasks
      .where(
        (t) =>
            !_t(t['parent']) &&
            t['status'] == 'completed' &&
            _t(t['completed']) &&
            n - DateTime.parse(t['completed'] as String).millisecondsSinceEpoch <= 7 * 864e5,
      )
      .length;
}

/// «купить батарейки #покуп в пятницу 17:00 !!!» → { title, topic, day, time, priority, repeat }.
Json parseSticker(String raw, [List topics = defaultTopics, DateTime? today]) {
  var txt = ' $raw ';
  int? priority;
  final pm = RegExp(r'\s(!{1,3})(?=\s)').firstMatch(txt);
  if (pm != null) {
    priority = 4 - pm[1]!.length;
    txt = txt.replaceFirst(pm[0]!, ' ');
  }
  String? topic;
  final tg = RegExp(r'(^|\s)#([^\s#]+)').firstMatch(txt);
  if (tg != null) {
    final k = tg[2]!.toLowerCase().replaceAll('ё', 'е');
    for (final t in topics) {
      if ((t['name'] as String).toLowerCase().replaceAll('ё', 'е').startsWith(k)) {
        topic = t['id'] as String;
        txt = txt.replaceFirst(tg[0]!, ' ');
        break;
      }
    }
  }
  final rp = takeRepeat(txt);
  final w = parseWhen(rp.rest, today ?? DateTime.now());
  final t = w.rest.trim();
  return {
    'title': t.isEmpty ? t : t[0].toUpperCase() + t.substring(1),
    'topic': topic,
    'day': w.day,
    'time': w.time,
    'priority': priority,
    'repeat': rp.rule,
  };
}
