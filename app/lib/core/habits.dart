// Порт tracker/src/lib/habits.js — серии привычек, календарь месяца, окно времени, отметки, советы.
// Отметки: log["<habitId>|ГГГГ-ММ-ДД"] = { done, rest, skip, n, t }. Привычка — Map из слоя (habits[id]) с полем id.
// «Сейчас» берётся из habitsClock (в тестах подменяется), как Date в JS.
import 'dates.dart' show ymd;

typedef Json = Map<String, dynamic>;

DateTime Function() habitsClock = DateTime.now;

const weekdays = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
const milestones = [7, 21, 50, 100];
const monthNames = [
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
  'Август',
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
];
const _monthShort = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
const monthGen = [
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
const _weekdayFull = ['понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота', 'воскресенье'];

bool _t(Object? v) => v != null && v != false && v != 0 && v != '';
int _round(num x) => (x + 0.5).floor();

DateTime dayOffset(int n) {
  final d = habitsClock();
  return DateTime(d.year, d.month, d.day + n);
}

int dow(DateTime d) => d.weekday - 1; // пн = 0
String logKey(Object? habitId, String date) => '$habitId|$date';
Map? _entry(Map? log, Object? id, String date) => log?[logKey(id, date)] as Map?;
bool isDone(Map? log, Object? habitId, String date) => _t(_entry(log, habitId, date)?['done']);
bool isOff(Map? log, Object? habitId, String date) {
  final e = _entry(log, habitId, date);
  return (_t(e?['rest']) || _t(e?['skip'])) && !isDone(log, habitId, date);
}

int nextMilestone(num n) => milestones.firstWhere((m) => m > n, orElse: () => milestones.last);

double milestonePos(num n) {
  final pts = [0, ...milestones];
  for (var q = 1; q < pts.length; q++) {
    if (n <= pts[q]) return ((q - 1 + (n - pts[q - 1]) / (pts[q] - pts[q - 1])) / milestones.length) * 100;
  }
  return 100;
}

String plural(int n, List<String> forms) {
  final a = n % 10, b = n % 100;
  if (a == 1 && b != 11) return forms[0];
  if (a >= 2 && a <= 4 && (b < 12 || b > 14)) return forms[1];
  return forms[2];
}

List _daysOf(Json h) =>
    (h['days'] is List && (h['days'] as List).isNotEmpty) ? h['days'] as List : const [0, 1, 2, 3, 4, 5, 6];
num _perWeek(Json h) => h['perWeek'] is num ? h['perWeek'] as num : 0;
String? _created(Json h) => _t(h['createdAt']) ? (h['createdAt'] as String).substring(0, 10) : null;
DateTime _addD(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);
DateTime _mondayOf(DateTime d) => DateTime(d.year, d.month, d.day - dow(d));
DateTime _parseDay(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

/// Текущая серия, лучшая серия и сетка за 13 недель.
Json stats(Json habit, Map? log) {
  if (_perWeek(habit) > 0) return _weekStats(habit, log);
  final days = _daysOf(habit);
  bool scheduled(DateTime d) => days.contains(dow(d));
  final created = _created(habit) ?? ymd(dayOffset(-365));
  final id = habit['id'];
  final todayDone = isDone(log, id, ymd(dayOffset(0)));

  var streak = 0;
  for (var i = todayDone ? 0 : 1; i <= 730; i++) {
    final d = dayOffset(-i), s = ymd(d);
    if (s.compareTo(created) < 0 && !isDone(log, id, s)) break;
    if (!scheduled(d) || isOff(log, id, s)) continue;
    if (isDone(log, id, s)) {
      streak++;
    } else {
      break;
    }
  }

  var best = 0, run = 0;
  for (var i = 730; i >= 0; i--) {
    final d = dayOffset(-i), s = ymd(d);
    if (!scheduled(d) || isOff(log, id, s)) continue;
    if (isDone(log, id, s)) {
      run++;
      if (run > best) best = run;
    } else if (i != 0 && s.compareTo(created) >= 0) {
      run = 0;
    }
  }

  final today = dayOffset(0);
  final monday = dayOffset(-dow(today) - 7 * 12);
  final cells = <Json>[];
  final months = <Json>[];
  for (var w = 0; w < 13; w++) {
    for (var k = 0; k < 7; k++) {
      final d = _addD(monday, w * 7 + k);
      final s = ymd(d);
      final diff = (d.difference(today).inHours / 24).round();
      String state;
      if (diff > 0) {
        state = scheduled(d) ? 'plan' : 'future';
      } else if (isDone(log, id, s)) {
        state = 'done';
      } else if (!scheduled(d)) {
        state = 'rest';
      } else if (s.compareTo(created) < 0) {
        state = 'before';
      } else if (isOff(log, id, s)) {
        state = 'off';
      } else if (diff == 0) {
        state = 'today';
      } else {
        state = 'miss';
      }
      cells.add({'date': s, 'state': state, 'today': diff == 0, 'title': '${d.day} ${monthGen[d.month - 1]}'});
      if (k == 0 && (w == 0 || d.day <= 7)) months.add({'col': w, 'name': _monthShort[d.month - 1]});
    }
  }
  if (months.length > 1 && (months[1]['col'] as int) - (months[0]['col'] as int) < 3) months.removeAt(0);
  return {'streak': streak, 'best': best, 'todayDone': todayDone, 'cells': cells, 'months': months};
}

/// Календарь одного месяца (month — с 0, как в JS).
Json monthGrid(Json habit, Map? log, int year, int month) {
  final days = _daysOf(habit);
  final created = _created(habit) ?? '0000';
  final today = ymd(dayOffset(0));
  final first = DateTime(year, month + 1, 1);
  final dim = DateTime(year, month + 2, 0).day;
  final lead = dow(first);
  final cells = <Json>[];
  var done = 0, sched = 0;
  final total = ((lead + dim) / 7).ceil() * 7;
  for (var i = 0; i < total; i++) {
    final n = i - lead + 1;
    if (n < 1 || n > dim) {
      cells.add({'key': 'b$i', 'n': '', 'state': 'blank', 'title': ''});
      continue;
    }
    final d = DateTime(year, month + 1, n), s = ymd(d);
    final doneDay = isDone(log, habit['id'], s);
    final sch = days.contains(dow(d));
    String state, what;
    if (s.compareTo(today) > 0) {
      state = 'fut';
      what = sch ? 'по плану' : 'не по расписанию';
    } else if (doneDay) {
      state = s == today ? 'today done' : 'done';
      what = 'сделано';
      done++;
      sched++;
    } else if (s == today) {
      state = sch ? 'today' : 'off';
      what = sch ? 'сегодня' : 'не по расписанию';
      if (sch) sched++;
    } else if (s.compareTo(created) < 0) {
      state = 'off';
      what = 'привычки ещё не было';
    } else if (!sch) {
      state = 'off';
      what = 'не по расписанию';
    } else if (isOff(log, habit['id'], s)) {
      state = 'off';
      what = 'выходной, серия сохранена';
    } else {
      state = 'miss';
      what = 'пропуск';
      sched++;
    }
    cells.add({'key': s, 'n': n, 'state': state, 'title': '$n ${monthGen[month]} · $what'});
  }
  return {'cells': cells, 'done': done, 'sched': sched};
}

String scheduleLabel(List? days) {
  if (days == null || days.isEmpty || days.length == 7) return 'Каждый день';
  if (days.length == 5 && [0, 1, 2, 3, 4].every(days.contains)) return 'По будням';
  final s = [...days]..sort((a, b) => '$a'.compareTo('$b'));
  return s.map((d) => weekdays[d as int]).join(' · ');
}

// ---------- Привычки: карточки ----------

const parts = <Json>[
  {
    'id': 'morning',
    'name': 'Утро',
    'win': {'s': '06:00', 'e': '12:00'},
  },
  {
    'id': 'day',
    'name': 'День',
    'win': {'s': '12:00', 'e': '18:00'},
  },
  {
    'id': 'evening',
    'name': 'Вечер',
    'win': {'s': '18:00', 'e': '24:00'},
  },
  {'id': 'any', 'name': 'Когда угодно', 'win': null},
];

String partOf(Object? h) {
  final part = h is Map ? h['part'] : null;
  if (parts.any((p) => p['id'] == part)) return part as String;
  final time = h is Map ? h['time'] : null;
  final m = RegExp(r'^(\d{1,2}):').firstMatch(time is String ? time : '');
  if (m == null) return 'any';
  final hh = int.parse(m[1]!);
  return hh < 12
      ? 'morning'
      : hh < 18
      ? 'day'
      : 'evening';
}

String partName(Object? h) => parts.firstWhere((p) => p['id'] == partOf(h))['name'] as String;

final _hhmmRe = RegExp(r'^(\d{1,2}):(\d{2})$');
int? _minOf(Object? s) {
  final m = _hhmmRe.firstMatch(s is String ? s : '');
  if (m == null) return null;
  final h = int.parse(m[1]!), mi = int.parse(m[2]!);
  return h < 24 && mi < 60 ? h * 60 + mi : null;
}

String _hhmm(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
int? _minEnd(Object? s) => s == '24:00' ? 1440 : _minOf(s);
String _hhmmEnd(int m) => m >= 1440 ? '24:00' : _hhmm(m);

Json? partWin(Object? part) {
  for (final p in parts) {
    if (p['id'] == part) return p['win'] == null ? null : Map<String, dynamic>.from(p['win'] as Map);
  }
  return null;
}

Json? cleanWin(Object? w) {
  final s = _minOf(w is Map ? w['s'] : null), e = _minEnd(w is Map ? w['e'] : null);
  return s != null && e != null && e > s ? {'s': _hhmm(s), 'e': _hhmmEnd(e)} : null;
}

bool wholePart(Object? w) => parts.any(
  (p) => p['win'] != null && w is Map && (p['win'] as Map)['s'] == w['s'] && (p['win'] as Map)['e'] == w['e'],
);

Json? habitWin(Object? h) {
  final hm = h is Map ? h : const {};
  final w = cleanWin(hm['win']);
  if (w != null) return w;
  final s = _minOf(hm['time']);
  if (s != null) {
    return {
      's': _hhmm(s),
      'e': normEnd(hm['time'], hm['end']) ?? partWin(partOf({'time': hm['time']}))!['e'],
    };
  }
  return partWin(partOf(h));
}

Json winFields(Object? win) {
  final w = cleanWin(win);
  return w != null
      ? {'win': w, 'time': w['s'], 'end': w['e'] == '24:00' ? null : w['e']}
      : {'win': null, 'time': null, 'end': null};
}

Json? moveWin(Object? h, Object? time) {
  final w = habitWin(h), s = _minOf(time);
  if (s == null) return w;
  final len = w != null ? _minEnd(w['e'])! - _minOf(w['s'])! : 60;
  return cleanWin({'s': _hhmm(s), 'e': _hhmmEnd(s + len < 1440 ? s + len : 1440)});
}

String? normTime(Object? raw, [bool end = false]) {
  final t = (raw ?? '').toString().trim().replaceAll(RegExp(r'[.,\-\s]'), ':');
  final m = RegExp(r'^(\d{1,2})(?::?(\d{2}))?$').firstMatch(t);
  if (m == null) return null;
  final h = int.parse(m[1]!), mi = int.parse(m[2] ?? '0');
  if (end && h == 24 && mi == 0) return '24:00';
  return h < 24 && mi < 60 ? _hhmm(h * 60 + mi) : null;
}

String winLabel(Object? h) {
  final w = habitWin(h);
  return w != null ? '${w['s']}–${w['e']}' : '';
}

String? remindAt(Object? h) => habitWin(h)?['s'] as String?;
const habitLen = 30;

String? normEnd(Object? time, Object? end) {
  final s = _minOf(time), e = _minOf(end);
  return s != null && e != null && e > s ? _hhmm(e) : null;
}

Json? habitSpan(Object? h) {
  final hm = h is Map ? h : const {};
  if (_t(hm['win'])) {
    final w = cleanWin(hm['win']);
    return w == null || wholePart(w) ? null : {'s': _minOf(w['s']), 'e': _minEnd(w['e']), 'end': true};
  }
  final s = _minOf(hm['time']);
  if (s == null) return null;
  final e = _minOf(normEnd(hm['time'], hm['end']));
  return e != null
      ? {'s': s, 'e': e, 'end': true}
      : {'s': s, 'e': s + habitLen < 1440 ? s + habitLen : 1440, 'end': false};
}

String? endAfter(Object? time, [int min = 60]) {
  final s = _minOf(time);
  return s == null ? null : normEnd(time, _hhmm(s + min < 1439 ? s + min : 1439));
}

String? moveEnd(Object? h, Object? time) {
  final sp = habitSpan(h);
  return sp != null && sp['end'] == true ? endAfter(time, (sp['e'] as int) - (sp['s'] as int)) : null;
}

String spanLabel(Object? h) {
  final sp = habitSpan(h);
  if (sp == null) return '';
  return sp['end'] == true ? '${_hhmm(sp['s'])}–${_hhmm(sp['e'])}' : _hhmm(sp['s']);
}

/// Порядок карточек: по части дня, внутри — по времени.
List<Json> sortHabits(List<Json> list) {
  int pi(Json h) => parts.indexWhere((p) => p['id'] == partOf(h));
  final idx = List.generate(list.length, (i) => i);
  idx.sort((i, j) {
    final a = list[i], b = list[j];
    final d = pi(a) - pi(b);
    if (d != 0) return d;
    final c = ((a['time'] ?? '99') as String).compareTo((b['time'] ?? '99') as String);
    return c != 0 ? c : i - j;
  });
  return [for (final i in idx) list[i]];
}

int goalN(Object? h) {
  final g = h is Map ? h['goal'] : null;
  final n = g is Map ? g['n'] : null;
  return n is num && n > 1 ? _round(n) : 0;
}

int countOn(Map? log, Json h, String day) {
  final e = _entry(log, h['id'], day);
  if (e == null || _t(e['gone'])) return 0;
  if (e['n'] is num) return (e['n'] as num).toInt();
  return _t(e['done']) ? (goalN(h) > 0 ? goalN(h) : 1) : 0;
}

Json nextMark(Map? log, Json h, String day) {
  final g = goalN(h);
  if (g == 0) return {'done': !isDone(log, h['id'], day), 'rest': false, 'skip': false};
  if (isDone(log, h['id'], day)) return {'done': false, 'n': 0, 'skip': false};
  final n = countOn(log, h, day) + 1;
  return {'done': n >= g, 'n': n, 'skip': false};
}

Json dayMark(Json h, String state) {
  final g = goalN(h);
  if (state == 'done') return {'done': true, 'rest': false, 'skip': false, if (g > 0) 'n': g};
  if (state == 'skip') return {'done': false, 'rest': false, 'skip': true, if (g > 0) 'n': 0};
  return {'done': false, 'rest': false, 'skip': false, if (g > 0) 'n': 0};
}

({int done, int skip}) _weekCount(Json h, Map? log, DateTime monday) {
  var done = 0, skip = 0;
  for (var k = 0; k < 7; k++) {
    final s = ymd(_addD(monday, k));
    if (isDone(log, h['id'], s)) {
      done++;
    } else if (isOff(log, h['id'], s)) {
      skip++;
    }
  }
  return (done: done, skip: skip);
}

num _weekNeed(Json h, int skip) {
  final v = _perWeek(h) < 7 - skip ? _perWeek(h) : 7 - skip;
  return v > 1 ? v : 1;
}

Json _weekStats(Json h, Map? log) {
  final today = dayOffset(0);
  final created = _created(h) ?? ymd(dayOffset(-365));
  final mon0 = _mondayOf(today);
  final cur = _weekCount(h, log, mon0);
  final curOk = cur.done >= _weekNeed(h, cur.skip);
  var streak = curOk ? 1 : 0;
  for (var w = 1; w <= 104; w++) {
    final mon = _addD(mon0, -7 * w);
    final c = _weekCount(h, log, mon);
    if (ymd(_addD(mon, 6)).compareTo(created) < 0 && c.done == 0) break;
    if (c.done >= _weekNeed(h, c.skip)) {
      streak++;
    } else {
      break;
    }
  }
  var best = 0, run = 0;
  for (var w = 104; w >= 0; w--) {
    final mon = _addD(mon0, -7 * w);
    final c = _weekCount(h, log, mon);
    if (c.done >= _weekNeed(h, c.skip)) {
      run++;
      if (run > best) best = run;
    } else if (w != 0 && ymd(_addD(mon, 6)).compareTo(created) >= 0) {
      run = 0;
    }
  }
  return {
    'streak': streak,
    'best': best,
    'todayDone': isDone(log, h['id'], ymd(today)),
    'week': cur.done,
    'cells': <Json>[],
    'months': <Json>[],
  };
}

bool scheduledOn(Json h, Map? log, String day) {
  final d = _parseDay(day);
  if (_perWeek(h) > 0) {
    if (isDone(log, h['id'], day)) return true;
    final c = _weekCount(h, log, _mondayOf(d));
    return c.done < _weekNeed(h, c.skip);
  }
  return _daysOf(h).contains(dow(d));
}

List<String> unitForms(Json h) {
  if (_perWeek(h) > 0) return ['неделя', 'недели', 'недель'];
  final days = h['days'];
  return days is! List || days.isEmpty || days.length == 7
      ? ['день', 'дня', 'дней']
      : ['занятие', 'занятия', 'занятий'];
}

/// d — сделано, p — частично, m — пропуск, k — не считать, o — не по расписанию / не было, f — будущее, w — свободный день.
String dayState(Json h, Map? log, String day, [String? today]) {
  final td = today ?? ymd(dayOffset(0));
  final e = _entry(log, h['id'], day);
  if (isDone(log, h['id'], day)) return 'd';
  if (day.compareTo(td) > 0) return 'f';
  if (_t(e?['skip']) || _t(e?['rest'])) return 'k';
  if (goalN(h) > 0 && countOn(log, h, day) > 0) return 'p';
  final created = _created(h) ?? '0000';
  if (day.compareTo(created) < 0) return 'o';
  if (_perWeek(h) > 0) return 'w';
  if (!_daysOf(h).contains(dow(_parseDay(day)))) return 'o';
  return day == td ? 'w' : 'm';
}

List<Json> last7(Json h, Map? log, [DateTime? now]) {
  final n = now ?? habitsClock();
  final today = ymd(n);
  return [
    for (var i = 6; i >= 0; i--)
      (() {
        final d = _addD(DateTime(n.year, n.month, n.day), -i), s = ymd(d);
        return {'day': s, 'wd': weekdays[dow(d)], 'st': dayState(h, log, s, today), 'today': i == 0};
      })(),
  ];
}

Json monthRow(Json h, Map? log, int year, int month, [DateTime? now]) {
  final today = ymd(now ?? habitsClock());
  final dim = DateTime(year, month + 2, 0).day;
  final cells = <Json>[];
  var done = 0, sched = 0, miss = 0;
  for (var n = 1; n <= dim; n++) {
    final s = ymd(DateTime(year, month + 1, n));
    final st = dayState(h, log, s, today);
    cells.add({'day': s, 'n': n, 'st': st, 'today': s == today});
    if (st == 'd') done++;
    if (st == 'm') miss++;
    if (st == 'd' || st == 'm' || st == 'p') sched++;
  }
  if (_perWeek(h) > 0) {
    final created = _created(h) ?? '0000';
    final past = cells
        .where(
          (c) =>
              (c['day'] as String).compareTo(today) <= 0 &&
              (c['day'] as String).compareTo(created) >= 0 &&
              c['st'] != 'k',
        )
        .length;
    final need = ((past / 7) * _perWeek(h)).ceil();
    sched = done > need ? done : need;
    miss = 0;
  }
  return {
    'cells': cells,
    'done': done,
    'sched': sched,
    'miss': miss,
    'pct': sched > 0 ? _round(done / sched * 100) : null,
  };
}

Json monthSummary(List<Json> habits, Map? log, int year, int month, [DateTime? now]) {
  ({List<({Json h, Json r})> rows, int? pct}) sum(int y, int m) {
    var done = 0, sched = 0;
    final rows = [
      for (final h in habits)
        (() {
          final r = monthRow(h, log, y, m, now);
          done += r['done'] as int;
          sched += r['sched'] as int;
          return (h: h, r: r);
        })(),
    ];
    return (rows: rows, pct: sched > 0 ? _round(done / sched * 100) : null);
  }

  final cur = sum(year, month);
  final prev = sum(month > 0 ? year : year - 1, month > 0 ? month - 1 : 11);
  final clean = [
    for (final x in cur.rows)
      if (!_t(x.h['perWeek']) && (x.r['sched'] as int) >= 3 && !_t(x.r['miss'])) x.h['name'],
  ];
  final wd = List.generate(7, (_) => [0, 0]); // [d, s]
  for (final x in cur.rows) {
    for (final c in x.r['cells'] as List) {
      if (c['st'] != 'd' && c['st'] != 'm') continue;
      final k = dow(_parseDay(c['day'] as String));
      wd[k][1]++;
      if (c['st'] == 'd') wd[k][0]++;
    }
  }
  int? weak;
  for (var i = 0; i < 7; i++) {
    final x = wd[i];
    if (x[1] >= 2 && x[0] < x[1] && (weak == null || x[0] / x[1] < wd[weak][0] / wd[weak][1])) weak = i;
  }
  return {'pct': cur.pct, 'prev': prev.pct, 'clean': clean, 'weak': weak == null ? null : _weekdayFull[weak]};
}

String? milestoneDate(Json h, Map? log, int streak, [DateTime? now]) {
  if (_perWeek(h) > 0) return null;
  var left = nextMilestone(streak) - streak;
  if (left <= 0) return null;
  final n = now ?? habitsClock();
  final today = ymd(n);
  var d = DateTime(n.year, n.month, n.day);
  if (isDone(log, h['id'], today)) d = _addD(d, 1);
  for (var i = 0; i < 800; i++, d = _addD(d, 1)) {
    if (_daysOf(h).contains(dow(d)) && --left == 0) return '${d.day} ${monthGen[d.month - 1]}';
  }
  return null;
}

Json? broken(Json h, Map? log, [DateTime? now]) {
  if (_perWeek(h) > 0) return null;
  final n = now ?? habitsClock();
  final today = ymd(n);
  if (isDone(log, h['id'], today)) return null;
  final created = _created(h) ?? '0000';
  var d = _addD(DateTime(n.year, n.month, n.day), -1);
  var i = 0;
  for (; i < 60; i++, d = _addD(d, -1)) {
    final s = ymd(d);
    if (s.compareTo(created) < 0) return null;
    final st = dayState(h, log, s, today);
    if (st == 'm' || st == 'p') break;
    if (st == 'd') return null;
  }
  if (i >= 60) return null;
  var was = 0;
  for (d = _addD(d, -1); was < 800; d = _addD(d, -1)) {
    final st = dayState(h, log, ymd(d), today);
    if (st == 'd') {
      was++;
    } else if (st == 'o' || st == 'k') {
      continue;
    } else {
      break;
    }
  }
  return was >= 2 ? {'was': was} : null;
}

int? _toMin(Object? t) {
  final m = _hhmmRe.firstMatch(t is String ? t : '');
  return m == null ? null : int.parse(m[1]!) * 60 + int.parse(m[2]!);
}

String _fromMin(int n) => '${(n ~/ 60 % 24).toString().padLeft(2, '0')}:${(n % 60).toString().padLeft(2, '0')}';

/// Совет енота: перенести сорвавшуюся привычку сразу после самой надёжной той же части дня.
({Json habit, Json anchor, String time, int misses})? habitTip(List<Json> habits, Map? log, [DateTime? now]) {
  final n = now ?? habitsClock();
  final today = ymd(n);
  double reliability(Json h) {
    var d = 0, s = 0;
    for (var i = 1; i <= 14; i++) {
      final st = dayState(h, log, ymd(_addD(n, -i)), today);
      if (st == 'd') {
        d++;
        s++;
      } else if (st == 'm' || st == 'p') {
        s++;
      }
    }
    return s > 0 ? d / s : 0;
  }

  for (final h in habits) {
    if (!_t(h['time']) || _perWeek(h) > 0 || (_t(h['tipHide']) && (h['tipHide'] as String).compareTo(today) >= 0)) {
      continue;
    }
    var misses = 0;
    for (var i = 1; i <= 21 && misses < 3; i++) {
      final st = dayState(h, log, ymd(_addD(n, -i)), today);
      if (st == 'm' || st == 'p') {
        misses++;
      } else if (st == 'd') {
        break;
      }
    }
    if (misses < 3) continue;
    final part = partOf(h);
    final cands = habits
        .where((a) => a['id'] != h['id'] && _t(a['time']) && partOf(a) == part && reliability(a) >= 0.7)
        .toList();
    final idx = {for (var i = 0; i < cands.length; i++) cands[i]: i};
    cands.sort((a, b) {
      final r = reliability(b) - reliability(a);
      if (r != 0) return r.sign.toInt();
      final s = (stats(b, log)['streak'] as int) - (stats(a, log)['streak'] as int);
      return s != 0 ? s : idx[a]! - idx[b]!;
    });
    if (cands.isEmpty) continue;
    final anchor = cands.first;
    final time = _fromMin(_toMin(anchor['time'])! + 30);
    if (time == h['time']) continue;
    return (habit: h, anchor: anchor, time: time, misses: misses);
  }
  return null;
}

String cardLine(Json h, Map? log, [DateTime? now]) {
  final n = now ?? habitsClock();
  final today = ymd(n);
  final bits = [partName(h)];
  if (_perWeek(h) > 0) {
    final c = _weekCount(h, log, _mondayOf(n));
    bits.add('${c.done} из ${h['perWeek']} на неделе');
  } else if (goalN(h) > 0) {
    final unit = (h['goal'] as Map)['unit'];
    bits.add('${countOn(log, h, today)} из ${goalN(h)} ${_t(unit) ? unit : ''}'.trim());
  } else if (_t(h['win']) || _t(h['time'])) {
    bits.add(winLabel(h));
  }
  final days = h['days'];
  if (days is List && days.isNotEmpty && days.length < 7 && !_t(h['perWeek'])) {
    bits.add(scheduleLabel(days).toLowerCase());
  }
  return bits.join(' · ');
}

String scheduleLine(Json h) {
  final pw = _perWeek(h);
  final bits = [
    pw > 0
        ? '$pw ${plural(pw.toInt(), ['раз', 'раза', 'раз'])} в неделю'
        : scheduleLabel(h['days'] as List?).toLowerCase(),
    partName(h).toLowerCase(),
  ];
  if (_t(h['win']) || _t(h['time'])) bits.add(winLabel(h));
  if (_t(h['createdAt'])) {
    final d = _parseDay((h['createdAt'] as String).substring(0, 10));
    bits.add('с ${d.day} ${monthGen[d.month - 1]}');
  }
  return bits.join(' · ');
}

int totalDone(Json h, Map? log) => (log ?? const {}).entries
    .where(
      (e) =>
          (e.key as String).startsWith('${h['id']}|') && e.value is Map && _t(e.value['done']) && !_t(e.value['gone']),
    )
    .length;
