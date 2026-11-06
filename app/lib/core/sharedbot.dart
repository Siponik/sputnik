// Порт tracker/src/lib/sharedbot.js — только чистая часть. Запросы к боту (link, test, unlink, inbox, ack, push) —
// это сеть, их место в data/.
// Общий Telegram-бот Спутника: трекер шлёт ему напоминания и задачи на неделю, забирает написанное боту.
import 'dart:math';

import 'route.dart' show parseLine, route;
import 'today.dart' show taskFrom;

typedef Json = Map<String, dynamic>;

/// «Сейчас» — подменяется в тестах.
DateTime Function() sharedbotClock = DateTime.now;

const botUrl = 'https://sputnik-bot.siponikdev.workers.dev';
const botName = 'SputnikTasksBot';
const botLink = 'https://t.me/$botName';

bool _t(Object? v) => v != null && v != false && v != 0 && v != '';
String _p2(int n) => n.toString().padLeft(2, '0');
String _ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_p2(d.month)}-${_p2(d.day)}';

/// Ключ привязки: 32 случайных байта в hex.
String newKey() {
  final r = Random.secure();
  return List.generate(32, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

/// Открытые задачи со сроком до +7 дней (и просроченные) — для /today и /week в боте.
List<Json> snapshot(List<Map> lists, Map tasksByList, [Map? layTasks, DateTime? now]) {
  now ??= sharedbotClock();
  final end = _ymd(DateTime(now.year, now.month, now.day + 7));
  final out = <(int, Json)>[];
  for (final l in lists) {
    for (final t in (tasksByList[l['id']] as List?) ?? const []) {
      if (t['status'] == 'completed' || _t(t['deleted']) || _t(t['parent']) || !_t(t['due'])) continue;
      final due = (t['due'] as String).substring(0, 10);
      if (due.compareTo(end) > 0) continue;
      final s = ((layTasks?[t['id']] as Map?)?['slot'] as Map?)?['s'];
      out.add((
        out.length,
        {'title': _t(t['title']) ? t['title'] : 'Без названия', 'due': due, if (_t(s)) 'time': s, 'list': l['title']},
      ));
    }
  }
  out.sort((a, b) {
    final c = (a.$2['due'] as String).compareTo(b.$2['due']);
    if (c != 0) return c;
    final d = ((a.$2['time'] ?? '99') as String).compareTo((b.$2['time'] ?? '99') as String);
    return d != 0 ? d : a.$1.compareTo(b.$1);
  });
  return [for (final x in out.take(300)) x.$2];
}

/// Для догадки в боте: списки, основной (первый) и выученные слова settings.route → { основа: listId }.
Json guessCtx(List<Map> lists, Map? layer) {
  final ids = {for (final l in lists) l['id']};
  final route = (((layer?['settings'] as Map?)?['route']) as Map?) ?? const {};
  final words = [
    for (final e in route.entries)
      if (e.value is Map && ids.contains((e.value as Map)['list'])) e,
  ];
  final idx = {for (final (i, e) in words.indexed) e.key: i};
  num n(MapEntry e) => ((e.value as Map)['n'] ?? 1) as num;
  words.sort((a, b) {
    final c = n(b).compareTo(n(a));
    return c != 0 ? c : idx[a.key]!.compareTo(idx[b.key]!);
  });
  return {
    'lists': [
      for (final l in lists.take(100)) {'id': l['id'], 'title': _t(l['title']) ? l['title'] : 'Без названия'},
    ],
    'def': lists.isNotEmpty ? lists[0]['id'] : null,
    'words': {for (final e in words.take(300)) e.key: (e.value as Map)['list']},
  };
}

String _cut(String s, int n) => s.length > n ? s.substring(0, n) : s;

/// Карточка из бота (поля уже выбраны человеком) → задача для quickCreate. Тип и повтор — из исходного текста.
/// rem: null — напоминание по умолчанию, 'off' — без него, число — за N минут до начала.
Json? fromDraft(Map x, {required List<Map> lists, Json? layer, Map tasks = const {}, DateTime? today}) {
  final base = _t(x['src']) ? fromText(x['src'], lists: lists, layer: layer, tasks: tasks, today: today) : null;
  final listId = lists.any((l) => l['id'] == x['listId'])
      ? x['listId']
      : (base?['listId'] ??
            fromText('${x['title'] ?? ''}', lists: lists, layer: layer, tasks: tasks, today: today)?['listId']);
  if (!_t(listId) || !_t(x['title'])) return null;
  final hm = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
  String plus(String t) {
    final v = int.parse(t.substring(0, 2)) * 60 + int.parse(t.substring(3)) + 60;
    final m = v < 1439 ? v : 1439;
    return '${_p2(m ~/ 60)}:${_p2(m % 60)}';
  }

  final layer2 = <String, dynamic>{...?(base?['layer'] as Map?)?.cast<String, dynamic>()};
  layer2.remove('topic');
  layer2.remove('project');
  if ([1, 2, 3].contains(x['prio'])) {
    layer2['priority'] = x['prio'];
  } else {
    layer2.remove('priority');
  }
  final rem = x['rem'];
  if (rem == 'off') {
    layer2['remind'] = null;
  } else if (rem is num && rem == rem.roundToDouble() && rem >= 0) {
    layer2['remind'] = {'kind': 'lead', 'min': rem.toInt()};
  }
  final due = x['due'] is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(x['due']) ? x['due'] as String : null;
  final time = x['time'] is String ? x['time'] as String : '';
  return {
    'title': _cut('${x['title']}', 250),
    'listId': listId,
    'due': due,
    'slot': due != null && hm.hasMatch(time) ? {'s': time, 'e': plus(time)} : null,
    'layer': layer2,
    'notes': _cut('${x['notes'] ?? ''}', 4000),
  };
}

/// Сообщение боту → задача для quickCreate. Без даты — без срока (в отличие от строки «Сегодня»).
Json? fromText(Object? text, {required List<Map> lists, Json? layer, Map tasks = const {}, DateTime? today}) {
  today ??= sharedbotClock();
  final parts = '$text'.split('\n');
  final p = parseLine(parts.first, today: today);
  if (!_t(p['title']) || lists.isEmpty) return null;
  final src = [_t(p['at']) ? '@${p['at']}' : '', _t(p['tag']) ? '#${p['tag']}' : '', p['rest']].join(' ').trim();
  final ranked = route(src, lists: lists, layer: layer, tasks: tasks);
  final top = ranked.isNotEmpty ? ranked[0] : null;
  final t = taskFrom(p, _ymd(today), (top?['listId'] ?? lists[0]['id']) as String, top ?? const {});
  return {...t, 'due': p['day'], 'notes': parts.skip(1).join('\n').trim()};
}
