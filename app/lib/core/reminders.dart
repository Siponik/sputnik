// Порт tracker/src/lib/reminders.js (без работы с Drive: ensureFolder/publish — это data/).
// Правило напоминания хранится в слое tasks[id].remind: одно правило или массив.
//   { kind: 'before', days, time } — за N дней до срока в это время; { kind: 'at', at: 'YYYY-MM-DDTHH:MM' };
//   { kind: 'lead', min } — за N минут до начала (срок + slot.s, без времени — срок в defaultTime).
import 'dart:convert';

import 'calendar.dart' show habitDay;
import 'dates.dart' show dueToYmd, ymd;
import 'habits.dart' show remindAt, habitWin;

typedef Json = Map<String, dynamic>;

/// «Сейчас» — подменяется в тестах.
DateTime Function() remindersClock = DateTime.now;

const before = [
  {'days': 0, 'name': 'В день срока'},
  {'days': 1, 'name': 'За 1 день'},
  {'days': 2, 'name': 'За 2 дня'},
  {'days': 3, 'name': 'За 3 дня'},
  {'days': 7, 'name': 'За неделю'},
  {'days': 30, 'name': 'За месяц'},
];
const leads = [
  {'min': 0, 'name': 'В момент начала'},
  {'min': 5, 'name': 'За 5 минут'},
  {'min': 15, 'name': 'За 15 минут'},
  {'min': 60, 'name': 'За час'},
  {'min': 1440, 'name': 'За день'},
  {'min': 10080, 'name': 'За неделю'},
  {'min': 43200, 'name': 'За месяц'},
];
const bdayLeads = [
  {'min': 0, 'name': 'В день рождения'},
  {'min': 1440, 'name': 'За день'},
  {'min': 4320, 'name': 'За 3 дня'},
  {'min': 10080, 'name': 'За неделю'},
  {'min': 43200, 'name': 'За месяц'},
];
List<Map<String, Object>> leadsFor(String kind) => kind == 'birthday' ? bdayLeads : leads;
const _defaults = {
  'task': [60],
  'event': [15],
  'birthday': [1440, 0],
};

bool _t(Object? v) => v != null && v != false && v != 0 && v != '';

List defaultMins(Map? settings, [String kind = 'task']) {
  final r = settings?['remind'];
  if (r is Map && r[kind] is List) return r[kind];
  if (kind == 'task' && r is Map && r.containsKey('min')) return r['min'] == null ? [] : [r['min']];
  return _defaults[kind]!;
}

Object? defaultRule(Map? settings) => minsToRule(defaultMins(settings, 'task'));
Object? minsToRule(List mins) {
  final u = mins.cast<num>().toSet().toList()..sort((a, b) => b.compareTo(a));
  final rules = [
    for (final m in u) {'kind': 'lead', 'min': m},
  ];
  return rules.isEmpty ? null : (rules.length == 1 ? rules[0] : rules);
}

List rulesOf(Object? r) => !_t(r) ? [] : (r is List ? r : [r]);

String leadName(num min, [String kind = 'task']) {
  for (final l in [...leadsFor(kind), ...leads]) {
    if (l['min'] == min) return l['name'] as String;
  }
  return 'За $min мин';
}

String leadsText(List mins, [String kind = 'task']) =>
    ([...mins.cast<num>()]..sort((a, b) => b.compareTo(a))).map((m) => leadName(m, kind).toLowerCase()).join(' и ');

String defaultTime = '10:00';
bool noTimeOff = false;

void setDefaultTime(String? t) {
  noTimeOff = t == 'off';
  defaultTime = RegExp(r'^\d\d:\d\d$').hasMatch(t ?? '') ? t! : '10:00';
}

List<int> _hm(String s) => s.split(':').map(int.parse).toList();
List<int> _ymdParts(String s) => s.split('-').map(int.parse).toList();

DateTime? fireAt(Object? remind, Map task, [Map? slot]) {
  if (remind is! Map) return null;
  final kind = remind['kind'];
  if (kind == 'lead') {
    final d = dueToYmd(task['due']);
    if (d.isEmpty || (!_t(slot?['s']) && noTimeOff)) return null;
    final p = _ymdParts(d), t = _hm(_t(slot?['s']) ? slot!['s'] : defaultTime);
    return DateTime(p[0], p[1], p[2], t[0], t[1] - ((remind['min'] ?? 0) as num).toInt());
  }
  if (kind == 'at') {
    return _t(remind['at']) ? _parseLocal(remind['at']) : null;
  }
  if (kind == 'before') {
    final d = dueToYmd(task['due']);
    if (d.isEmpty) return null;
    final p = _ymdParts(d), t = _hm(_t(remind['time']) ? remind['time'] : defaultTime);
    return DateTime(p[0], p[1], p[2] - ((remind['days'] ?? 0) as num).toInt(), t[0], t[1]);
  }
  return null;
}

DateTime? _parseLocal(String s) {
  final m = RegExp(r'^(\d{4})-(\d\d)-(\d\d)T(\d\d):(\d\d)$').firstMatch(s);
  if (m != null) {
    return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!), int.parse(m[4]!), int.parse(m[5]!));
  }
  return DateTime.tryParse(s);
}

const _monShort = ['янв.', 'февр.', 'мар.', 'апр.', 'мая', 'июн.', 'июл.', 'авг.', 'сент.', 'окт.', 'нояб.', 'дек.'];
String _p2(int n) => n.toString().padLeft(2, '0');

String remindLabel(Object? remind, Map task, [Map? slot]) {
  final all = rulesOf(remind).map((r) => fireAt(r, task, slot)).whereType<DateTime>().toList()
    ..sort((a, b) => a.compareTo(b));
  if (all.isEmpty) return '';
  final now = remindersClock();
  final at = all.firstWhere((d) => d.isAfter(now), orElse: () => all.last);
  return '${at.day} ${_monShort[at.month - 1]}, ${_p2(at.hour)}:${_p2(at.minute)}';
}

String _iso(DateTime d) => d.toUtc().toIso8601String();

/// Тело последнего записанного файла напоминаний (ставит data/): прошедшее «до начала» из него не выкидываем —
/// скрипт может заглянуть в файл на пару минут позже срабатывания.
String lastBody = '';
String _publishedFrom = '';
Set<Object?> _published = {};
bool _wasPublished(String key) {
  if (_publishedFrom != lastBody) {
    _publishedFrom = lastBody;
    final b = lastBody.isEmpty ? const [] : jsonDecode(lastBody);
    final xs = b is List ? b : ((b as Map)['items'] as List? ?? const []);
    _published = {for (final x in xs) x['key']};
  }
  return _published.contains(key);
}

String _first(Object? s) {
  final l = (s as String? ?? '').split('\n')[0];
  return l.length > 200 ? l.substring(0, 200) : l;
}

List<Json> collect(
  List<Map> lists,
  Map tasksByList,
  Map? layTasks, [
  Map? habitList,
  List<Map> cheers = const [],
  List<Map> events = const [],
]) {
  final now = remindersClock().millisecondsSinceEpoch;
  final items = <Json>[];
  for (final l in lists) {
    for (final t in (tasksByList[l['id']] as List?) ?? const []) {
      if (t['status'] == 'completed' || _t(t['deleted'])) continue;
      final lt = layTasks?[t['id']] as Map?;
      for (final r in rulesOf(lt?['remind'])) {
        final at = fireAt(r, t, lt?['slot']);
        if (at == null || at.millisecondsSinceEpoch < now - 864e5) continue;
        final key = '${t['id']}|${_iso(at)}';
        if (r['kind'] == 'lead' && at.millisecondsSinceEpoch < now - 120e3 && !_wasPublished(key)) continue;
        items.add({
          'key': key,
          'taskId': t['id'],
          'listId': l['id'],
          'list': l['title'],
          'title': _t(t['title']) ? t['title'] : 'Без названия',
          'note': _first(t['notes']),
          'due': dueToYmd(t['due']),
          'fireAt': _iso(at),
        });
      }
    }
  }
  for (final e in events) {
    final priv = (e['extendedProperties'] as Map?)?['private'] as Map?;
    final mins = '${priv?['sputnikRemind'] ?? ''}'.split(',').where((x) => x != '').map(num.tryParse);
    final start = e['start'] as Map;
    final allDay = !_t(start['dateTime']);
    late final DateTime startAt;
    if (allDay) {
      final p = _ymdParts(start['date']), t = _hm(defaultTime);
      startAt = DateTime(p[0], p[1], p[2], t[0], t[1]);
    } else {
      startAt = DateTime.parse(start['dateTime']);
    }
    final birthday = priv?['sputnik'] == 'birthday';
    for (final min in mins) {
      if (min == null) continue;
      final at = startAt.subtract(Duration(milliseconds: (min * 60e3).round()));
      final key = 'ev|${e['id']}|${_iso(at)}';
      final ms = at.millisecondsSinceEpoch;
      if (ms < now - 120e3 && !(_wasPublished(key) && ms > now - 864e5)) continue;
      items.add({
        'key': key,
        'kind': birthday ? 'birthday' : 'event',
        'title': birthday
            ? '${e['summary'] ?? ''}'.replaceFirst(RegExp(r'^🎂\s*'), '')
            : (_t(e['summary']) ? e['summary'] : 'Событие'),
        'note': _first(e['description']),
        'list': birthday ? 'День рождения' : 'Google Календарь',
        'due': allDay ? start['date'] : '',
        'start': allDay ? '' : start['dateTime'],
        'lead': leadName(min, birthday ? 'birthday' : 'event'),
        'fireAt': _iso(at),
      });
    }
  }
  if (habitList != null) {
    for (final c in cheers) {
      items.add({
        'key': 'cheer|${c['habit']['id']}|${c['key']}',
        'kind': 'milestone',
        'taskId': c['habit']['id'],
        'listId': habitList['id'],
        'list': habitList['title'],
        'title': '🎉 ${c['text']}',
        'note': 'Новая веха серии. Енот празднует!',
        'due': '',
        'fireAt': c['at'],
      });
    }
  }
  final idx = {for (final (i, x) in items.indexed) x: i};
  items.sort((a, b) {
    final c = (a['fireAt'] as String).compareTo(b['fireAt']);
    return c != 0 ? c : idx[a]!.compareTo(idx[b]!);
  });
  return items;
}

List<Json> assignedItems(List<Map> lists, Map tasksByList, Map? layTasks, [int? now]) {
  now ??= remindersClock().millisecondsSinceEpoch;
  final items = <Json>[];
  for (final l in lists) {
    for (final t in (tasksByList[l['id']] as List?) ?? const []) {
      final g = (layTasks?[t['id']] as Map?)?['given'] as Map?;
      if (!_t(g?['at']) || t['status'] == 'completed' || _t(t['deleted'])) continue;
      final d = DateTime.tryParse(g!['at']);
      if (d == null || !(d.millisecondsSinceEpoch > now - 864e5)) continue;
      items.add({
        'key': 'given|${t['id']}|${g['at']}',
        'kind': 'assigned',
        'title': _t(t['title']) ? t['title'] : 'Без названия',
        'note': '${_t(g['name']) ? g['name'] : 'Участник'} отдаёт тебе задачу',
        'list': l['title'],
        'due': dueToYmd(t['due']),
        'fireAt': _iso(d),
      });
    }
  }
  return items;
}

List<Json> habitItems(List<Json> habits, Map? log, [DateTime? now]) {
  now ??= remindersClock();
  final items = <Json>[];
  final today = ymd(now);
  for (final h in habits) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(remindAt(h) ?? '');
    if (m == null || (h['remind'] as Map?)?['tg'] == false) continue;
    for (var i = 0; i < 7; i++) {
      final at = DateTime(now.year, now.month, now.day + i, int.parse(m[1]!), int.parse(m[2]!));
      final day = ymd(at);
      final d = habitDay(h, log, day, today);
      if (d['sched'] != true || d['done'] == true || at.millisecondsSinceEpoch < now.millisecondsSinceEpoch - 120e3) {
        continue;
      }
      final goal = h['goal'] as Map?;
      final n = goal?['n'];
      items.add({
        'key': 'habit|${h['id']}|$day',
        'kind': 'habit',
        'title': h['name'],
        'note': [
          n is num && n > 1 ? 'Цель на день: $n ${_t(goal!['unit']) ? goal['unit'] : 'раз'}' : '',
          'Отметь до ${habitWin(h)!['e']}',
        ].where((x) => x.isNotEmpty).join(' · '),
        'list': 'Привычки',
        'due': '',
        'fireAt': _iso(at),
      });
    }
  }
  return items;
}

List<Json> habitWinDue(List<Json> habits, Map? log, [List sent = const [], DateTime? now]) {
  now ??= remindersClock();
  final today = ymd(now);
  int mins(String s) {
    final p = _hm(s);
    return p[0] * 60 + p[1];
  }

  return habits.where((h) {
    if (!_t((h['remind'] as Map?)?['win']) || sent.contains('${h['id']}|$today')) return false;
    final w = habitWin(h);
    if (w == null) return false;
    final cur = now!.hour * 60 + now.minute;
    final d = habitDay(h, log, today, today);
    return d['sched'] == true && d['done'] != true && cur >= mins(w['s']) && cur < mins(w['e']);
  }).toList();
}
