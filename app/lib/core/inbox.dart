// Порт tracker/src/lib/inbox.js
// «Входящие от Claude»: задачи, которые Apps Script (reminders/Inbox.gs) создал по запросам из чатов.
// Решение хранится в слое: tasks[id].inbox = 'accepted' | 'rejected'.
import 'spheres.dart' show spheresFrom, sphereColors, sphereIcons;
import 'stickers.dart' show topicsOf;
import 'templates.dart' show templatesFrom, views;

typedef Json = Map<String, dynamic>;

/// «Сейчас» — подменяется в тестах.
DateTime Function() inboxClock = DateTime.now;

bool _t(Object? v) => v != null && v != false && v != 0 && v != '';

/// taskId → { from, at } для задач, созданных из чатов (без дублей).
Json claudeTasks(Map? status) {
  final out = <String, dynamic>{};
  for (final p in ((status?['processed'] as Map?) ?? const {}).values) {
    if (p is! Map || !_t(p['ok'])) continue;
    for (final c in (p['created'] as List?) ?? const []) {
      if (c is Map && c['op'] == 'task.create' && _t(c['taskId']) && !_t(c['existed'])) {
        out[c['taskId']] = {'from': _t(p['from']) ? p['from'] : '', 'at': p['at']};
      }
    }
  }
  return out;
}

/// Ещё не разобранные: задача есть, открыта и решения по ней нет.
List<Json> pending(Map? status, List<Map> lists, Map tasksByList, Map? layTasks) {
  final ids = claudeTasks(status);
  final items = <(int, Json)>[];
  for (final l in lists) {
    for (final t in (tasksByList[l['id']] as List?) ?? const []) {
      if (ids[t['id']] == null || t['status'] == 'completed' || _t((layTasks?[t['id']] as Map?)?['inbox'])) continue;
      items.add((items.length, {'task': t, 'listId': l['id'], 'list': l['title'], ...ids[t['id']] as Map}));
    }
  }
  String at(Json x) => _t(x['at']) ? x['at'] : '';
  items.sort((a, b) {
    final c = at(b.$2).compareTo(at(a.$2));
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final x in items) x.$2];
}

const _type = {'work': 'work', 'meeting': 'work', 'creative': 'creative', 'study': 'study', 'personal': 'personal'};

String? _str(Object? v, int max) => v is String && v.trim().isNotEmpty && v.length <= max ? v.trim() : null;
const _maxLead = 60 * 24 * 62;
Json? _lead(Object? m) =>
    m is num && m == m.roundToDouble() && m >= 0 && m <= _maxLead ? {'kind': 'lead', 'min': m.toInt()} : null;
String _p2(int n) => n.toString().padLeft(2, '0');
String _plusHour(String hm) {
  final v = int.parse(hm.substring(0, 2)) * 60 + int.parse(hm.substring(3)) + 60;
  final m = v < 23 * 60 + 59 ? v : 23 * 60 + 59;
  return '${_p2(m ~/ 60)}:${_p2(m % 60)}';
}

String _norm(Object? x) => (x ?? '').toString().trim().toLowerCase().replaceAll('ё', 'е');
String _numStr(num n) => n == n.roundToDouble() && n.abs() < 1e15 ? n.toInt().toString() : n.toString();

final _hm = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
bool _isHm(Object? s) => s is String && _hm.hasMatch(s);

/// Поля слоя из pendingLayer, которые ещё не перенесены: [[taskId, patch], …].
/// topicOf(listId, тема) → id темы стикеров; без него тема берётся как есть.
List<List> layerPatches(Map? status, Map? layTasks, [String? Function(Object? listId, String name)? topicOf]) {
  final out = <List>[];
  for (final e in ((status?['pendingLayer'] as Map?) ?? const {}).entries) {
    final id = e.key, f = e.value as Map;
    if (_t((layTasks?[id] as Map?)?['pulled'])) continue;
    final patch = <String, dynamic>{'pulled': true};
    if (_type[f['type']] != null) patch['type'] = _type[f['type']];
    if (f['project'] is String) patch['project'] = f['project'];
    if (f['tags'] is List) patch['tags'] = (f['tags'] as List).whereType<String>().toList();
    if ([1, 2, 3].contains(f['priority'])) patch['priority'] = f['priority'];
    if (f['stage'] is String) patch['stage'] = f['stage'];
    final every = (f['repeat'] is Map) ? (f['repeat'] as Map)['every'] : null;
    if (['day', 'weekdays', 'week', 'month', 'year'].contains(every)) patch['repeat'] = {'every': every};
    final slot = f['slot'];
    if (slot is Map && _isHm(slot['s']) && _isHm(slot['e']) && (slot['s'] as String).compareTo(slot['e']) < 0) {
      patch['slot'] = {'s': slot['s'], 'e': slot['e']};
    } else if (slot is Map && _isHm(slot['s']) && slot['e'] == null) {
      patch['slot'] = {'s': slot['s'], 'e': _plusHour(slot['s'])};
    }
    final col = _str(f['status'], 40);
    if (col != null && RegExp(r'^[\w-]+$').hasMatch(col)) {
      patch['status'] = col;
      final at = f['at'] is String ? DateTime.tryParse(f['at']) : null;
      patch['stageAt'] = {col: (at ?? inboxClock()).millisecondsSinceEpoch};
    }
    final topic = _str(f['topic'], 40);
    if (topic != null) {
      final tid = topicOf != null ? topicOf(f['listId'], topic) : topic;
      if (_t(tid)) patch['topic'] = tid;
    }
    if (f['pin'] == true) patch['pin'] = true;
    final client = _str(f['client'], 100);
    final money = f['money'] is num ? _numStr(f['money']) : _str(f['money'], 40);
    if (client != null) patch['client'] = client;
    if (_t(money)) patch['money'] = money;
    final rems = (f['remind'] is List ? f['remind'] as List : [f['remind']]).map(_lead).whereType<Json>().toList();
    if (rems.isNotEmpty) patch['remind'] = rems.length > 1 ? rems : rems[0];
    final spent = f['spent'];
    if (spent is num && spent.isFinite && spent > 0 && spent < 1e5) patch['spent'] = (spent + 0.5).floor();
    if (f['accept'] == true) patch['inbox'] = 'accepted';
    out.add([id, patch]);
  }
  return out;
}

String _slug(String name, Set<String> taken) {
  var base = _norm(name).replaceAll(RegExp(r'[^a-zа-я0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
  if (base.length > 24) base = base.substring(0, 24);
  if (base.isEmpty) base = 'x';
  var id = base, i = 2;
  while (taken.contains(id)) {
    id = '$base-${i++}';
  }
  taken.add(id);
  return id;
}

/// Всё, что прислали чаты, одним набором правок слоя: { spheres, lists, tasks } — каждое [[id, patch], …].
Json pullPatches(Map? status, Json? lay) {
  final spheres = <String, Json>{}, lists = <String, Json>{};
  final known = spheresFrom(lay);
  final tpls = templatesFrom(lay);
  final colorIds = [for (final c in sphereColors) c['id'] as String];
  final sphereIds = <String>{...((lay?['spheres'] as Map?) ?? const {}).keys.cast<String>()};
  num order = 0;
  for (final s in known) {
    final o = (s['order'] ?? 0) as num;
    if (o > order) order = o;
  }

  String sphereId(String name, Object? color, Object? icon) {
    for (final s in known) {
      if (_norm(s['name']) == _norm(name)) return s['id'];
    }
    for (final e in spheres.entries) {
      if (_norm(e.value['name']) == _norm(name)) return e.key;
    }
    final id = 'sp-${_slug(name, sphereIds)}';
    spheres[id] = {
      'name': name.trim(),
      'color': colorIds.contains(color) ? color : colorIds[(known.length + spheres.length) % colorIds.length],
      'icon': sphereIcons[icon] != null ? icon : 'star',
      'order': ++order,
      'removed': false,
    };
    return id;
  }

  List<Json> topicList(List raw) {
    final taken = <String>{};
    final out = <Json>[];
    for (final (i, x) in raw.indexed) {
      final name = _str(x is String ? x : (x is Map ? x['name'] : null), 40);
      if (name == null || out.any((t) => _norm(t['name']) == _norm(name))) continue;
      Map? def;
      for (final t in topicsOf(null)) {
        if (_norm(t['name']) == _norm(name)) {
          def = t;
          break;
        }
      }
      final xc = x is Map ? x['color'] : null;
      final color = colorIds.contains(xc) ? xc : (def?['color'] ?? colorIds[i % colorIds.length]);
      String tid;
      if (def != null && !taken.contains(def['id'])) {
        taken.add(def['id']);
        tid = def['id'];
      } else {
        tid = _slug(name, taken);
      }
      out.add({'id': tid, 'name': name, 'color': color});
    }
    return out.length > 12 ? out.sublist(0, 12) : out;
  }

  for (final e in ((status?['pendingLists'] as Map?) ?? const {}).entries) {
    final id = e.key as String, f = e.value;
    if (f is! Map) continue;
    if (_t(f['at']) && ((lay?['lists'] as Map?)?[id] as Map?)?['pulled'] == f['at']) continue;
    final patch = <String, dynamic>{'pulled': _t(f['at']) ? f['at'] : true};
    if (_str(f['template'], 60) != null) {
      for (final t in tpls) {
        if (t['id'] == f['template'] || _norm(t['name']) == _norm(f['template'])) {
          patch['template'] = t['id'];
          break;
        }
      }
    }
    if (views.any((v) => v['id'] == f['view'])) patch['view'] = f['view'];
    final sp = _str(f['sphere'], 40);
    if (sp != null) patch['sphere'] = sphereId(sp, f['sphereColor'], f['sphereIcon']);
    if (f['topics'] is List) {
      final t = topicList(f['topics']);
      if (t.isNotEmpty) patch['topics'] = t;
    }
    if (['topic', 'when'].contains(f['group'])) patch['group'] = f['group'];
    lists[id] = patch;
  }

  String? topicOf(Object? listId, String name) {
    if (!_t(listId)) return null;
    final cur = (lists[listId]?['topics'] as List?) ?? topicsOf((lay?['lists'] as Map?)?[listId]);
    for (final t in cur) {
      if (t['id'] == name || _norm(t['name']) == _norm(name)) return t['id'];
    }
    final taken = <String>{for (final t in cur) t['id'] as String};
    final t = {'id': _slug(name, taken), 'name': name, 'color': colorIds[cur.length % colorIds.length]};
    lists[listId as String] = {
      ...(lists[listId] ?? const {}),
      'topics': [...cur, t],
    };
    return t['id'];
  }

  final tasks = layerPatches(status, lay?['tasks'] as Map?, topicOf);
  return {
    'spheres': [
      for (final e in spheres.entries) [e.key, e.value],
    ],
    'lists': [
      for (final e in lists.entries) [e.key, e.value],
    ],
    'tasks': tasks,
  };
}
