// Порт tracker/src/lib/create.js
// Окно «Создать» v2 — чистые помощники: подписи дат, день рождения, свободное время, чек-лист этапа, подсказка вида,
// разбор строки привычки, подарок ко дню рождения. Даты — 'ГГГГ-ММ-ДД', today передаётся снаружи.
import 'stickers.dart' show bucket;

typedef Json = Map<String, dynamic>;

bool _t(Object? v) => v != null && v != false && v != 0 && v != '';
String _pad(int n) => n.toString().padLeft(2, '0');
DateTime _parse(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

String _fmt(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_pad(d.month)}-${_pad(d.day)}';
String plus(String s, int n) {
  final d = _parse(s);
  return _fmt(DateTime(d.year, d.month, d.day + n));
}

int toMin(String s) {
  final p = s.split(':').map(int.parse).toList();
  return p[0] * 60 + p[1];
}

String fromMin(int m) {
  final x = m < 1439 ? m : 1439;
  return '${_pad(x ~/ 60)}:${_pad(x % 60)}';
}

String addMin(String hhmm, int n) => fromMin(toMin(hhmm) + n);

const _wd = ['вс', 'пн', 'вт', 'ср', 'чт', 'пт', 'сб'];
const _wdf = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
const _mon = ['янв.', 'февр.', 'мар.', 'апр.', 'мая', 'июн.', 'июл.', 'авг.', 'сент.', 'окт.', 'нояб.', 'дек.'];
const _mong = [
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
  'декабря', //
];
int _day(DateTime d) => d.weekday % 7; // как getDay(): вс = 0

String shortDay(String s) {
  final d = _parse(s);
  return '${_wd[_day(d)]}, ${d.day} ${_mon[d.month - 1]}';
}

String longDay(String s) {
  final d = _parse(s);
  return '${_wdf[_day(d)]}, ${d.day} ${_mong[d.month - 1]}';
}

String eventDay(String s, String today) {
  final d = _parse(s), base = '${_wd[_day(d)]} ${d.day} ${_mong[d.month - 1]}';
  return s == today ? 'сегодня, $base' : (s == plus(today, 1) ? 'завтра, $base' : base);
}

String dayMonth(String s) {
  final d = _parse(s);
  return '${d.day} ${_mong[d.month - 1]}';
}

String weekday(String s) => _wd[_day(_parse(s))];

String dueShort(String? due, String today, [Map? slot]) {
  if (!_t(due)) return '';
  final t = _t(slot?['s']) ? ', ${slot!['s']}' : '';
  if (due == today) return 'сегодня$t';
  if (due == plus(today, 1)) return 'завтра$t';
  if (due!.compareTo(today) < 0) return 'просрочено';
  if (bucket(due, today) == 'week') return weekday(due) + t;
  final d = _parse(due);
  return '${d.day} ${_mon[d.month - 1]}$t';
}

String whenChip(String? due, String today) {
  if (!_t(due)) return 'later';
  final b = bucket(due, today);
  return b == 'later' ? 'date' : b;
}

// ---------- день рождения ----------

RegExp _ri(String s) => RegExp(s, caseSensitive: false);

String dative(Object? name) {
  final n = (name ?? '').toString().trim();
  if (n.isEmpty || RegExp(r'\s').hasMatch(n)) return n;
  final cut = n.substring(0, n.length - 1);
  if (_ri(r'ия$').hasMatch(n)) return '$cutи';
  if (_ri(r'[ая]$').hasMatch(n)) return '$cutе';
  if (_ri(r'[йь]$').hasMatch(n)) return '$cutю';
  if (_ri(r'[бвгджзклмнпрстфхцчшщ]$').hasMatch(n)) return '$nу';
  return n;
}

String nextBirthday(String day, String today) {
  final d = _parse(day), t = _parse(today);
  var x = DateTime(t.year, d.month, d.day);
  if (x.isBefore(t)) x = DateTime(t.year + 1, d.month, d.day);
  return _fmt(x);
}

int? ageAt(Object? year, String day, String today) {
  final y = year is num ? year : (year == null ? 0 : (num.tryParse(year.toString().trim()) ?? 0));
  if (y == 0 || y < 1900 || y > 2100) return null;
  final a = int.parse(nextBirthday(day, today).substring(0, 4)) - y;
  return a > 0 && a < 130 ? a.toInt() : null;
}

String _plural(int n, String one, String few, String many) {
  final a = n.remainder(100), b = n.remainder(10);
  return '$n ${a > 10 && a < 20 ? many : (b == 1 ? one : (b > 1 && b < 5 ? few : many))}';
}

String daysTill(String day, String today) {
  final ms = _parse(day).difference(_parse(today)).inMilliseconds;
  return _plural((ms / 864e5 + 0.5).floor(), 'день', 'дня', 'дней');
}

String years(int n) => _plural(n, 'год', 'года', 'лет');

// ---------- событие: свободно ли время ----------

List<Json> _timedOf(List? events, String day) {
  final out = <Json>[];
  for (final x in events ?? const []) {
    final s = (x['start'] as Map?)?['dateTime'], e = (x['end'] as Map?)?['dateTime'];
    if (!_t(s) || !_t(e)) continue;
    if ((s as String).substring(0, 10).compareTo(day) > 0 || (e as String).substring(0, 10).compareTo(day) < 0) {
      continue;
    }
    final a = DateTime.parse(s).toLocal(), b = DateTime.parse(e).toLocal();
    final am = _fmt(a).compareTo(day) < 0 ? 0 : a.hour * 60 + a.minute;
    final bm = _fmt(b).compareTo(day) > 0 ? 1440 : b.hour * 60 + b.minute;
    out.add({'a': am, 'b': bm, 'title': _t(x['summary']) ? x['summary'] : 'событие'});
  }
  return out;
}

Json dayChunk(List? events, String day, Map? slot, [String title = '', int hours = 5]) {
  final s = _t(slot?['s']) ? toMin(slot!['s']) : null;
  int start;
  if (s == null) {
    start = 9;
  } else {
    final v = s ~/ 60 - 1;
    final hi = 24 - hours;
    start = v < hi ? (v > 0 ? v : 0) : (hi > 0 ? hi : 0);
  }
  final from = start * 60, to = from + hours * 60;
  Json? piece(int a, int b, Object? t, bool mine) {
    if (b <= from || a >= to) return null;
    final lo = a > from ? a : from, hi = b < to ? b : to;
    final h = (hi - lo) / 60;
    return {'top': (lo - from) / 60, 'h': h > 0.25 ? h : 0.25, 'title': t, 'mine': mine};
  }

  final items = [for (final x in _timedOf(events, day)) piece(x['a'], x['b'], x['title'], false)];
  if (s != null) items.add(piece(s, _t(slot!['e']) ? toMin(slot['e']) : s + 60, title, true));
  return {'hours': List.generate(hours, (i) => start + i), 'items': items.whereType<Json>().toList()};
}

Json? freeCheck(List? events, String day, Map? slot) {
  if (!_t(slot?['s'])) return null;
  final s = toMin(slot!['s']), e = toMin(_t(slot['e']) ? slot['e'] : slot['s']);
  final timed = _timedOf(events, day);
  for (final x in timed) {
    if (x['a'] < e && x['b'] > s) return {'clash': x['title']};
  }
  Json? next;
  for (final x in timed) {
    if (x['a'] >= e && (next == null || x['a'] < next['a'])) next = x;
  }
  return next != null ? {'until': fromMin(next['a'])} : {'free': true};
}

// ---------- доски ----------

Iterable<Map> _inCol(List listTasks, Map? layTasks, Object? colId, Object? firstCol) => listTasks.cast<Map>().where(
  (t) =>
      !_t(t['parent']) && t['status'] != 'completed' && ((layTasks?[t['id']] as Map?)?['status'] ?? firstCol) == colId,
);

int colCount(List listTasks, Map? layTasks, Object? colId, Object? firstCol) =>
    _inCol(listTasks, layTasks, colId, firstCol).length;

num topOrd(List listTasks, Map? layTasks, Object? colId, Object? firstCol) {
  num m = 0;
  for (final (i, t) in _inCol(listTasks, layTasks, colId, firstCol).indexed) {
    final o = ((layTasks?[t['id']] as Map?)?['ord'] ?? i) as num;
    if (o < m) m = o;
  }
  return m - 1;
}

List<Json> _stableSort(Iterable<Map> xs, int Function(Map, Map) cmp) {
  final l = [for (final (i, x) in xs.indexed) (i, x)];
  l.sort((a, b) {
    final c = cmp(a.$2, b.$2);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final x in l) x.$2.cast<String, dynamic>()];
}

List<Json> stageChecklist(List listTasks, Map? layTasks) {
  final all = listTasks.cast<Map>();
  final tops = _stableSort(
    all.where((t) => !_t(t['parent'])),
    (a, b) => ((b['updated'] ?? '') as String).compareTo(a['updated'] ?? ''),
  );
  for (final top in tops) {
    final subs = _stableSort(
      all.where((t) => t['parent'] == top['id'] && _t((layTasks?[t['id']] as Map?)?['stage'])),
      (a, b) => ((_t(a['position']) ? a['position'] : '') as String).compareTo(_t(b['position']) ? b['position'] : ''),
    );
    if (subs.isNotEmpty) {
      return [
        for (final s in subs) {'title': s['title'], 'stage': layTasks![s['id']]['stage']},
      ];
    }
  }
  return [];
}

String initials(Object? title) {
  final s = (title ?? '').toString().replaceAll(_ri(r'[^a-zа-яё0-9]'), '');
  final two = s.length > 2 ? s.substring(0, 2) : s;
  return (two.isEmpty ? '··' : two).toUpperCase();
}

// ---------- подсказка вида ----------

RegExp _w(String re) => _ri('(?:^|[^а-яёa-z0-9])(?:$re)(?=\$|[^а-яёa-z0-9])');
final _meet = _w(
  r'созвон\S*|встреч[аиеуы]|встречу|врач\S*|к врачу|стоматолог\S*|собеседовани\S*|митинг\S*|свидани\S*|консультаци\S*',
);
final _with = RegExp(
  r'(?:^|\s)(?:с|со)\s+(?:[А-ЯЁ][а-яё]+|(?:клиент|заказчик|команд|друз|друг|мам|пап|коллег|ребят)[а-яё]*)',
);
final _habit = _w(
  r'каждый день|каждое утро|каждый вечер|ежедневно|по утрам|по вечерам|по будням|\d+\s+раза?\s+в\s+неделю',
);
final _bday = _w(r'день рождени[яе]|дня рождения|днюх[аиу]|др');

Json? suggestKind(Object? text, [Map p = const {}]) {
  final t = (text ?? '').toString();
  if (_bday.hasMatch(t) && _t(p['day'])) return {'kind': 'birthday', 'what': 'день рождения', 'why': 'раз в год'};
  final h = _habit.firstMatch(t);
  final every = (p['repeat'] as Map?)?['every'];
  if (h != null || every == 'day' || every == 'weekdays') {
    final phrase = h != null ? h[0]!.trim().toLowerCase() : (every == 'day' ? 'каждый день' : 'по будням');
    return {'kind': 'habit', 'what': 'привычку', 'why': 'повторяется $phrase'};
  }
  final meet = _meet.hasMatch(t), withSb = _with.hasMatch(t), time = _t(p['time']);
  if (meet || (time && withSb)) {
    final why = time && withSb
        ? 'у неё есть время и с кем-то'
        : (time ? 'у неё есть время' : (withSb ? 'она с кем-то' : 'её не отмечают сделанной'));
    return {'kind': 'event', 'what': 'встречу', 'why': why};
  }
  return null;
}

Json? kindHint(Object? text, Map p, String kind) {
  final s = suggestKind(text, p);
  if (s == null || s['kind'] == kind || kind == 'birthday') return null;
  if (kind == 'event' && s['kind'] == 'habit') return null;
  return s;
}

// ---------- повтор события ----------

const _rrules = {
  'day': 'FREQ=DAILY',
  'weekdays': 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR',
  'week': 'FREQ=WEEKLY',
  'month': 'FREQ=MONTHLY',
  'year': 'FREQ=YEARLY',
};
List<String>? recurrenceOf(Map? rule) {
  final r = _rrules[rule?['every']];
  return r != null ? ['RRULE:$r'] : null;
}

// ---------- привычка: умная строка ----------

RegExp _p(String re) => _ri('(?:^|[^а-яёa-z0-9])($re)(?=\$|[^а-яёa-z0-9])');
int _clamp(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);
final _hFreq = <(RegExp, Json Function(RegExpMatch), String Function(RegExpMatch))>[
  (
    _p(r'(\d+)\s+раза?\s+в\s+неделю'),
    (m) => {'freq': 'week', 'perWeek': _clamp(int.parse(m[2]!), 1, 6)},
    (m) {
      final n = int.parse(m[2]!);
      return '${m[2]} ${n % 10 >= 2 && n % 10 <= 4 ? 'раза' : 'раз'} в неделю';
    },
  ),
  (
    _p('по будням'),
    (_) => {
      'freq': 'days',
      'days': [0, 1, 2, 3, 4],
    },
    (_) => 'по будням',
  ),
  (
    _p('по выходным'),
    (_) => {
      'freq': 'days',
      'days': [5, 6],
    },
    (_) => 'по выходным',
  ),
  (_p('каждый день|ежедневно'), (_) => {'freq': 'daily'}, (_) => 'каждый день'),
];
final _hPart = [
  (_p('каждое утро|по утрам|утром'), 'morning', 'утро'),
  (_p('днём|днем|после обеда'), 'day', 'день'),
  (_p('каждый вечер|по вечерам|вечером|перед сном'), 'evening', 'вечер'),
];
final _hUnits = [
  (RegExp(r'^стакан'), 'стаканов'),
  (RegExp(r'^страниц'), 'страниц'),
  (RegExp(r'^мин'), 'минут'),
  (RegExp(r'^км$'), 'км'),
  (RegExp(r'^шаг'), 'шагов'),
  (RegExp(r'^раз'), 'раз'),
];
final _hGoal = _p(
  r'(\d{1,5})\s+(стакан[а-яё]*|страниц[а-яё]*|минут[а-яё]*|мин|км|шаг[а-яё]*|раз|раза|отжиман[а-яё]*|приседан[а-яё]*|глав[а-яё]*|слов[а-яё]*)',
);

Json parseHabit(Object? raw, [Map off = const {}]) {
  final text = (raw ?? '').toString();
  final marks = <Json>[], toks = <Json>[];
  final out = <String, dynamic>{'marks': marks, 'toks': toks};
  final taken = <List<int>>[];
  bool free(int a, int b) => taken.every((x) => b <= x[0] || a >= x[1]);
  bool take(RegExpMatch m, String kind) {
    final from = m.start + m[0]!.length - m[1]!.length, to = from + m[1]!.length;
    if (!free(from, to)) return false;
    taken.add([from, to]);
    marks.add({'from': from, 'to': to, 'kind': kind});
    return true;
  }

  if (!_t(off['freq'])) {
    for (final (re, val, label) in _hFreq) {
      final m = re.firstMatch(text);
      if (m != null && take(m, 'freq')) {
        out.addAll(val(m));
        toks.add({'k': 'freq', 'l': label(m)});
        break;
      }
    }
  }
  if (!_t(off['part'])) {
    for (final (re, part, label) in _hPart) {
      final m = re.firstMatch(text);
      if (m != null && take(m, 'part')) {
        out['part'] = part;
        toks.add({'k': 'part', 'l': label});
        if (!_t(out['freq']) && _ri(r'^кажд').hasMatch(m[1]!)) out['freq'] = 'daily';
        break;
      }
    }
  }
  if (!_t(off['goal'])) {
    final m = _hGoal.firstMatch(text);
    if (m != null && int.parse(m[2]!) > 1 && take(m, 'goal')) {
      final word = m[3]!.toLowerCase();
      var unit = word;
      for (final (re, u) in _hUnits) {
        if (re.hasMatch(word)) {
          unit = u;
          break;
        }
      }
      final n = int.parse(m[2]!);
      out['goal'] = {'n': n < 999 ? n : 999, 'unit': unit};
      toks.insert(0, {'k': 'goal', 'l': 'цель ${out['goal']['n']} $unit'});
    }
  }
  final idx = {for (final (i, m) in marks.indexed) m: i};
  marks.sort((a, b) {
    final c = (a['from'] as int).compareTo(b['from']);
    return c != 0 ? c : idx[a]!.compareTo(idx[b]!);
  });
  var name = '';
  var i = 0;
  for (final mk in marks) {
    name += '${text.substring(i, mk['from'])} ';
    i = mk['to'];
  }
  name = (name + text.substring(i)).replaceAll(RegExp(r'\s+'), ' ').trim();
  out['name'] = name.isEmpty ? name : name[0].toUpperCase() + name.substring(1);
  return out;
}

// ---------- подарок ко дню рождения ----------

const giftDays = [
  [3, 'за 3 дня'],
  [7, 'за неделю'],
  [14, 'за 2 недели'],
  [30, 'за месяц'],
];

String giftDate(String bday, int days) => plus(bday, -days);

String bdayName(Object? summary) =>
    (summary ?? '').toString().replaceFirst(RegExp(r'^[^\p{L}]+', unicode: true), '').trim();

List<Json> giftsDue(List? events, String today) {
  final out = <Json>[];
  for (final e in events ?? const []) {
    final p = ((e['extendedProperties'] as Map?)?['private'] as Map?) ?? const {};
    final g = p['sputnikGift'];
    final days = g is num ? g : (g == null ? double.nan : (num.tryParse(g.toString().trim()) ?? double.nan));
    final bday = (e['start'] as Map?)?['date'];
    if (p['sputnik'] != 'birthday' || !(days > 0) || !_t(bday)) continue;
    final from = giftDate(bday, days.toInt());
    if (today.compareTo(from) < 0 || today.compareTo(bday) > 0) continue;
    final name = bdayName(e['summary']);
    if (name.isEmpty) continue;
    out.add({
      'key': '${_t(e['recurringEventId']) ? e['recurringEventId'] : e['id']}|${(bday as String).substring(0, 4)}',
      'title': 'Подарок ${dative(name)}',
      'due': from,
      'bday': bday,
      'listId': _t(p['sputnikGiftList']) ? p['sputnikGiftList'] : null,
    });
  }
  return out;
}
