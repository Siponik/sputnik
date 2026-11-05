// Порт tracker/src/lib/today.js — строка быстрого добавления «Сегодня»: что понято и задача из строки.
// p — результат route.parseLine (Map: title, day, time, priority, repeat, tag), r — выбранная строка route.route.
import 'meta.dart' show priorityOf, typeLabel;
import 'repeat.dart' show repeatLabel;
import 'when.dart' show whenText;

typedef Json = Map<String, dynamic>;

/// #тег → тип задачи (старые русские теги тоже).
const typeTag = {
  'asset': 'creative', 'work': 'work', 'client': 'work', 'study': 'study', 'personal': 'personal', //
  'ассет': 'creative', 'работа': 'work', 'клиент': 'work', 'учеба': 'study', 'учёба': 'study', 'личное': 'personal',
};

DateTime _dateOf(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

int _toMin(String t) {
  final p = t.split(':').map(int.parse).toList();
  return p[0] * 60 + p[1];
}

String _hhmm(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
bool _t(Object? v) => v != null && v != false && v != 0 && v != '';
String? _type(Json p) => _t(p['tag']) ? typeTag[(p['tag'] as String).toLowerCase()] : null;

/// Чипы «Понял:» [{ kind, text }].
List<Json> understood(Json? p, String today) {
  if (p == null || !_t(p['title'])) return [];
  final day = (p['day'] ?? today) as String;
  final date = day == today ? 'сегодня' : whenText(day, null, _dateOf(today)).date.toLowerCase();
  final out = <Json>[
    {'kind': 'when', 'text': _t(p['time']) ? '$date · ${p['time']}' : date},
  ];
  final pr = priorityOf(p['priority']);
  if (pr != null) out.add({'kind': 'prio', 'text': '${pr['mark']} ${(pr['label'] as String).toLowerCase()}'});
  if (_t(p['repeat'])) out.add({'kind': 'repeat', 'text': '↻ ${repeatLabel(p['repeat'])}'});
  final type = _type(p);
  if (type != null) out.add({'kind': 'type', 'text': '#${typeLabel(type)}'});
  return out;
}

/// Задача из строки: { title, listId, due, slot, layer }.
Json taskFrom(Json p, String today, String dest, [Json r = const {}]) {
  final layer = <String, dynamic>{};
  final type = _type(p);
  if (type != null) layer['type'] = type;
  final tag = (p['tag'] as String?)?.toLowerCase();
  if (tag == 'client' || tag == 'клиент') layer['tags'] = ['client'];
  if (_t(p['priority'])) layer['priority'] = p['priority'];
  if (_t(p['repeat'])) layer['repeat'] = p['repeat'];
  if (r['listId'] == dest && _t(r['topic'])) layer['topic'] = r['topic'];
  if (r['listId'] == dest && _t(r['project'])) layer['project'] = r['project'];
  final time = p['time'] as String?;
  final slot = _t(time) ? {'s': time, 'e': _hhmm(_toMin(time!) + 60 < 1439 ? _toMin(time) + 60 : 1439)} : null;
  return {'title': p['title'], 'listId': dest, 'due': p['day'] ?? today, 'slot': slot, 'layer': layer};
}
