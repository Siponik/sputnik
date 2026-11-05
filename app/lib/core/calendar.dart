// Порт tracker/src/lib/calendar.js
// Календарь: раскладка событий, задач и привычек по дням. Только расчёты, без интерфейса.
import 'dates.dart' show ymd, dueToYmd;
import 'habits.dart' show dow, isDone, scheduledOn, habitSpan;

typedef Json = Map<String, dynamic>;

/// «Сейчас» — подменяется в тестах.
DateTime Function() calendarClock = DateTime.now;

const gridStart = 9 * 60;
const gridEnd = 21 * 60;
const hourPx = 40;
const hourEmpty = 12;
const bandMax = 36;

num _round2(num x) => (x * 100 + 0.5).floor() / 100;
String _p2(int n) => n.toString().padLeft(2, '0');
bool _t(Object? v) => v != null && v != false && v != 0 && v != '';

class HourLayout {
  final List<num> ht, y;
  final num height;
  final List<Json> labels, bands;
  final List<num> lines;
  final List<bool> busy;
  HourLayout(this.ht, this.y, this.height, this.labels, this.lines, this.bands, this.busy);
  num yAt(num min) {
    final m = min < 0 ? 0 : (min > 1440 ? 1440 : min);
    final hh = (m / 60).floor() < 23 ? (m / 60).floor() : 23;
    return y[hh] + ((m - hh * 60) / 60) * ht[hh];
  }

  Json toJson() => {'HT': ht, 'Y': y, 'height': height, 'labels': labels, 'lines': lines, 'bands': bands, 'busy': busy};
}

HourLayout hourLayout(List<Json> timedItems, [List<int> hot = const [], num fit = 0]) {
  final busy = List.filled(24, false);
  for (final h in hot) {
    if (h >= 0 && h < 24) busy[h] = true;
  }
  for (final it in timedItems) {
    final s = it['s'] as num, e = it['e'] as num;
    final a = (s / 60).floor() > 0 ? (s / 60).floor() : 0;
    final cb = ((e > s + 30 ? e : s + 30) / 60).ceil();
    final b = cb < 24 ? cb : 24;
    for (var q = a; q < b; q++) {
      busy[q] = true;
    }
  }
  final runs = <List<int>>[]; // [a, b, h]
  for (var h = 0; h < 24;) {
    if (busy[h]) {
      h++;
      continue;
    }
    final a = h;
    while (h < 24 && !busy[h]) {
      h++;
    }
    final hh = (h - a) * hourEmpty;
    runs.add([a, h, hh < bandMax ? hh : bandMax]);
  }
  final nBusy = busy.where((x) => x).length;
  num full = hourPx;
  if (fit > 0 && nBusy > 0) {
    final v = ((fit - runs.fold<int>(0, (n, r) => n + r[2])) / nBusy).floor();
    full = v < 30 ? 30 : (v > 72 ? 72 : v);
  }
  final ht = List<num>.filled(24, 0), y = List<num>.filled(25, 0);
  for (final r in runs) {
    for (var q = r[0]; q < r[1]; q++) {
      ht[q] = r[2] / (r[1] - r[0]);
    }
  }
  for (var q = 0; q < 24; q++) {
    if (busy[q]) ht[q] = full;
    y[q + 1] = _round2(y[q] + ht[q]);
  }
  final labels = <Json>[], lines = <num>[], bands = <Json>[];
  for (var h = 0; h < 24; h++) {
    if (!busy[h]) continue;
    labels.add({'key': 'h$h', 'text': '${_p2(h)}:00', 'top': h == 0 ? 2 : y[h] - 7, 'small': false});
    if (h > 0 && busy[h - 1]) lines.add(y[h]);
  }
  for (final r in runs) {
    final text = '${_p2(r[0])}–${_p2(r[1] == 24 ? 0 : r[1])}';
    bands.add({'top': y[r[0]], 'h': r[2], 'a': r[0], 'b': r[1], 'text': text});
    if (r[2] >= bandMax) labels.add({'key': 'b${r[0]}', 'text': text, 'top': y[r[0]] + r[2] / 2 - 7, 'small': true});
  }
  return HourLayout(ht, y, y[24], labels, lines, bands, busy);
}

const wdShort = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
const wdFull = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
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
  'декабря', //
];
const monthNom = [
  'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь', //
];

DateTime parseYmd(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n, d.hour, d.minute, d.second, d.millisecond);
DateTime startOfWeek(DateTime d) => DateTime(d.year, d.month, d.day - dow(d));
int toMin(String hhmm) {
  final p = hhmm.split(':').map(int.parse).toList();
  return p[0] * 60 + p[1];
}

String fromMin(int m) => '${_p2(m ~/ 60)}:${_p2(m % 60)}';
int nowMin() {
  final d = calendarClock();
  return d.hour * 60 + d.minute;
}

List<String> periodDays(String selYmd, String mode) {
  final sel = parseYmd(selYmd);
  final first = mode == 'week' ? startOfWeek(sel) : startOfWeek(DateTime(sel.year, sel.month, 1));
  return List.generate(mode == 'week' ? 7 : 42, (i) => ymd(addDays(first, i)));
}

String periodTitle(String selYmd, String mode) {
  final sel = parseYmd(selYmd);
  if (mode == 'month') return '${monthNom[sel.month - 1]} ${sel.year}';
  final a = startOfWeek(sel), b = addDays(a, 6);
  if (a.month == b.month) return '${a.day} – ${b.day} ${monthGen[b.month - 1]}';
  return '${a.day} ${monthGen[a.month - 1]} – ${b.day} ${monthGen[b.month - 1]}';
}

String shiftPeriod(String selYmd, String mode, int dir) {
  final sel = parseYmd(selYmd);
  if (mode == 'week') return ymd(addDays(sel, 7 * dir));
  final last = DateTime(sel.year, sel.month + dir + 1, 0).day;
  return ymd(DateTime(sel.year, sel.month + dir, sel.day < last ? sel.day : last));
}

const _typeByTemplate = {'work': 'work', 'asset3d': 'creative', 'personal': 'personal', 'study': 'study'};
String typeOfTemplate(String? tplId) => _typeByTemplate[tplId] ?? 'work';
String typeColor(String type) => 'var(--type-$type)';

Map<String, List<Json>> eventsByDay(List<Json> events, List<String> days) {
  final inRange = days.toSet();
  final out = <String, List<Json>>{};
  void put(String day, Json item) {
    if (inRange.contains(day)) (out[day] ??= []).add(item);
  }

  for (final e in events) {
    final start = e['start'] as Map?, end = e['end'] as Map?;
    final title = _t(e['summary']) ? e['summary'] : 'Без названия';
    Json base() => {'kind': e['kind'] ?? 'event', 'title': title, 'cal': e['calendar'], 'event': e};
    if (_t(start?['date'])) {
      final sd = start!['date'] as String;
      final ed = end?['date'];
      final last = ed is String && ed.compareTo(sd) > 0 ? ed : ymd(addDays(parseYmd(sd), 1));
      for (var d = parseYmd(sd); ymd(d).compareTo(last) < 0; d = addDays(d, 1)) {
        put(ymd(d), {...base(), 'id': '${e['id']}|${ymd(d)}', 's': null, 'e': null});
      }
      continue;
    }
    if (!_t(start?['dateTime'])) continue;
    final a = DateTime.parse(start!['dateTime']).toLocal();
    final b = DateTime.parse(end?['dateTime'] ?? start['dateTime']).toLocal();
    var d = DateTime(a.year, a.month, a.day);
    do {
      final dayEnd = addDays(d, 1);
      final lo = a.isAfter(d) ? a : d, hi = b.isBefore(dayEnd) ? b : dayEnd;
      final sm = (lo.difference(d).inMilliseconds / 60e3 + 0.5).floor();
      final em = (hi.difference(d).inMilliseconds / 60e3 + 0.5).floor();
      final whole = sm == 0 && em >= 1440;
      put(ymd(d), {
        ...base(),
        'id': '${e['id']}|${ymd(d)}',
        's': whole ? null : sm,
        'e': whole ? null : (em > sm ? em : sm),
      });
      d = dayEnd;
    } while (d.isBefore(b));
  }
  return out;
}

Map<String, List<Json>> tasksByDay(
  List<Json> lists,
  Map tasksByList,
  Map? layTasks,
  String Function(String listId, String taskId) typeOf,
  List<String> days,
) {
  final inRange = days.toSet();
  final today = ymd(calendarClock());
  final out = <String, List<Json>>{};
  for (final l in lists) {
    for (final t in (tasksByList[l['id']] as List?) ?? const []) {
      if (_t(t['parent']) || !_t(t['due'])) continue;
      final day = dueToYmd(t['due']);
      if (!inRange.contains(day)) continue;
      final slot = (layTasks?[t['id']] as Map?)?['slot'] as Map?;
      final done = t['status'] == 'completed';
      final s = slot?['s'], e = slot?['e'];
      (out[day] ??= []).add({
        'kind': 'task',
        'id': t['id'],
        'title': _t(t['title']) ? t['title'] : 'Без названия',
        'task': t,
        'listId': l['id'],
        'list': l['title'],
        'type': typeOf(l['id'], t['id']),
        'done': done,
        'overdue': !done && day.compareTo(today) < 0,
        's': _t(s) ? toMin(s) : null,
        'e': _t(e) ? toMin(e) : (_t(s) ? toMin(s) + 60 : null),
      });
    }
  }
  return out;
}

List<Json> layoutBlocks(List<Json> items, num Function(num) yAt) {
  num clamp(num m) => m > 1440 ? 1440 : (m < 0 ? 0 : m);
  num mx(num a, num b) => a > b ? a : b;
  final xs = [
    for (final i in items.where((i) => i['s'] != null))
      () {
        final a = clamp(i['s']), top = yAt(a) + 1;
        final ce = clamp(i['e']);
        final height = mx(20, yAt(mx(ce, a)) - yAt(a) - 2);
        return <String, dynamic>{
          ...i,
          'a': a,
          'top': top,
          'height': height,
          'bot': mx(yAt(mx(ce, a + 30)), top + height),
        };
      }(),
  ];
  final idx = {for (var k = 0; k < xs.length; k++) xs[k]: k};
  xs.sort((x, y) {
    final c = (x['top'] as num).compareTo(y['top']);
    if (c != 0) return c;
    final d = (y['bot'] as num).compareTo(x['bot']);
    return d != 0 ? d : idx[x]!.compareTo(idx[y]!);
  });
  final out = <Json>[];
  var cluster = <Json>[];
  num end = -1;
  void flush() {
    final cols = <num>[];
    for (final it in cluster) {
      var c = cols.indexWhere((last) => last <= it['top']);
      if (c < 0) {
        c = cols.length;
        cols.add(0);
      }
      cols[c] = it['bot'];
      it['col'] = c;
    }
    for (final it in cluster) {
      it['cols'] = cols.length;
    }
    out.addAll(cluster);
    cluster = [];
  }

  for (final it in xs) {
    if (cluster.isNotEmpty && it['top'] >= end) flush();
    cluster.add(it);
    end = mx(end, it['bot']);
  }
  if (cluster.isNotEmpty) flush();
  return out;
}

bool _isDoneItem(Json i) => (i['kind'] == 'task' || i['kind'] == 'habit') && _t(i['done']);

List<List<num>> busy(List<Json> items, [num lo = gridStart, num hi = gridEnd]) {
  final xs =
      [
        for (final (k, i) in items.indexed)
          if (i['s'] != null && !_isDoneItem(i))
            (k, [(i['s'] as num) > lo ? i['s'] as num : lo, (i['e'] as num) < hi ? i['e'] as num : hi]),
      ].where((x) => x.$2[1] > x.$2[0]).toList()..sort((x, y) {
        final c = x.$2[0].compareTo(y.$2[0]);
        return c != 0 ? c : x.$1.compareTo(y.$1);
      });
  final out = <List<num>>[];
  for (final (_, ab) in xs) {
    if (out.isNotEmpty && ab[0] <= out.last[1]) {
      if (ab[1] > out.last[1]) out.last[1] = ab[1];
    } else {
      out.add([ab[0], ab[1]]);
    }
  }
  return out;
}

num busyMinutes(List<Json> items) => busy(items).fold<num>(0, (m, ab) => m + ab[1] - ab[0]);

Json? bestWindow(Map dayItems, List<String> days) {
  final work = days.where((d) => dow(parseYmd(d)) < 5).toList();
  return _longestGap(dayItems, work) ?? _longestGap(dayItems, days.where((d) => !work.contains(d)).toList());
}

Json? _longestGap(Map dayItems, List<String> days) {
  final today = ymd(calendarClock());
  Json? best;
  for (final day in days) {
    if (day.compareTo(today) < 0) continue;
    final nm = (nowMin() / 30).ceil() * 30;
    final lo = day == today ? (gridStart > nm ? gridStart : nm) : gridStart;
    if (lo > gridEnd - 60) continue;
    num from = lo;
    final gaps = <List<num>>[];
    for (final ab in busy(((dayItems[day] as List?) ?? const []).cast<Json>(), lo)) {
      if (ab[0] > from) gaps.add([from, ab[0]]);
      from = from > ab[1] ? from : ab[1];
    }
    if (gridEnd > from) gaps.add([from, gridEnd]);
    for (final g in gaps) {
      final len = g[1] - g[0];
      if (len >= 60 && (best == null || len > best['len'])) {
        best = {'day': day, 's': g[0], 'e': g[0] + (len < 180 ? len : 180), 'len': len};
      }
    }
  }
  return best;
}

Json habitDay(Json habit, Map? log, String day, String today) {
  final done = isDone(log, habit['id'], day);
  final c = habit['createdAt'];
  final before = _t(c) && day.compareTo((c as String).substring(0, 10)) < 0;
  return {
    'sched': scheduledOn(habit, log, day) && (!before || done),
    'done': done,
    'isToday': day == today,
    'future': day.compareTo(today) > 0,
  };
}

List<Json> habitBlocks(List<Json> habits, Map? log, String day, String today) {
  final out = <Json>[];
  for (final h in habits) {
    final sp = habitSpan(h);
    if (sp == null) continue;
    final x = habitDay(h, log, day, today);
    if (x['sched'] != true) continue;
    out.add({
      'kind': 'habit',
      'id': 'hab:${h['id']}|$day',
      'title': h['name'],
      'h': h,
      's': sp['s'],
      'e': sp['e'],
      'end': sp['end'],
      ...x,
    });
  }
  return out;
}

Json dayLabel(String day) {
  final d = parseYmd(day);
  return {
    'weekday': wdFull[dow(d)],
    'short': wdShort[dow(d)],
    'title': '${d.day} ${monthGen[d.month - 1]}',
    'n': d.day,
    'month': d.month - 1,
  };
}

String whenLabel(String day) {
  final now = calendarClock();
  if (day == ymd(now)) return 'сегодня';
  if (day == ymd(addDays(now, 1))) return 'завтра';
  if (day == ymd(addDays(now, -1))) return 'вчера';
  return wdShort[dow(parseYmd(day))];
}

String hoursLabel(num? min) {
  if (!_t(min)) return '—';
  final v = (min! / 6 + 0.5).floor() / 10;
  final s = v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  return '${s.replaceAll('.', ',')} ч';
}
