// Порт tracker/src/lib/boardedit.js — правки черновика доски { view, fields, cols } в редакторе.
// VIEW_ICONS и иконки полей — SVG старого трекера; во Flutter значки рисует тема, здесь их нет.
import 'templates.dart' show palette;

typedef Json = Map<String, dynamic>;

const fieldInfoList = <Json>[
  {'id': 'due', 'name': 'Срок', 'group': 'card', 'what': 'чип «пт» / «сегодня»'},
  {'id': 'prio', 'name': 'Приоритет', 'group': 'card', 'what': '!!! слева от названия и полоска'},
  {'id': 'type', 'name': 'Тип', 'group': 'card', 'what': 'цвет полоски и чип «#работа»'},
  {'id': 'subtasks', 'name': 'Подзадачи', 'group': 'card', 'what': '«☑ 2 из 4» на карточке'},
  {'id': 'time', 'name': 'Учёт времени', 'group': 'card', 'what': '«⏱ 1 ч 15 мин», кнопка таймера'},
  {'id': 'stage', 'name': 'Дорожка этапов', 'group': 'card', 'what': 'полоска этапов под названием'},
  {'id': 'progress', 'name': 'Прогресс', 'group': 'card', 'what': '«3 из 10 уроков» — для учёбы'},
  {'id': 'client', 'name': 'Клиент', 'group': 'drawer', 'what': 'поле в окне задачи + на карточке'},
  {'id': 'money', 'name': 'Сумма', 'group': 'drawer', 'what': 'поле в окне задачи, итог колонки'},
];

Json? fieldInfo(Object? id) {
  for (final f in fieldInfoList) {
    if (f['id'] == id) return f;
  }
  return null;
}

Json draftOf(Json b) => {
  'view': b['view'],
  'fields': [...((b['fields'] ?? const []) as List)],
  'cols': [
    for (final c in b['cols'] as List)
      {'id': c['id'], 'name': c['name'], 'color': c['color'] ?? 0, 'limit': c['limit'] ?? 0},
  ],
};

/// Переставить колонку: «Готово» (последняя) не двигается, после неё ничего не встаёт.
List moveCol(List cols, int from, int to) {
  final end = cols.length - 1;
  if (from == end || from < 0 || from > end) return cols;
  final t = to < 0 ? 0 : (to > end - 1 ? end - 1 : to);
  if (t == from) return cols;
  final out = [...cols];
  final c = out.removeAt(from);
  out.insert(t, c);
  return out;
}

Json recolor(Json c) => {...c, 'color': (((c['color'] ?? 0) as int) + 1) % palette.length};

Json relimit(Json c, int d) {
  final v = ((c['limit'] ?? 0) as int) + d;
  return {...c, 'limit': v < 0 ? 0 : (v > 20 ? 20 : v)};
}

Json newCol([int? now]) => {
  'id': 'c${(now ?? DateTime.now().millisecondsSinceEpoch).toRadixString(36)}',
  'name': 'Новая колонка',
  'color': 0,
  'limit': 0,
};

/// Удалить колонку i (задачи — в соседнюю). null — нельзя.
Json? dropCol(List cols, int i, [List removed = const [], int n = 0]) {
  final end = cols.length - 1;
  if (cols.length <= 2 || i == end || i < 0) return null;
  final c = cols[i], to = cols[i > 0 ? i - 1 : i + 1];
  return {
    'cols': [
      for (var k = 0; k < cols.length; k++)
        if (k != i) cols[k],
    ],
    'removed': [
      for (final r in removed)
        r['to'] == c['id'] ? {...(r as Map).cast<String, dynamic>(), 'to': to['id'], 'toName': to['name']} : r,
      {'id': c['id'], 'name': c['name'], 'to': to['id'], 'toName': to['name'], 'n': n},
    ],
  };
}

List toggleField(List fields, Object? f) => fields.contains(f) ? fields.where((x) => x != f).toList() : [...fields, f];

String _word(int n, String one, String few, String many) {
  final a = n % 10, b = n % 100;
  return '$n ${a == 1 && b != 11
      ? one
      : a >= 2 && a <= 4 && (b < 12 || b > 14)
      ? few
      : many}';
}

String tasksWord(int n) => _word(n, 'задача', 'задачи', 'задач');
String listsWord(int n) => _word(n, 'список', 'списка', 'списков');

bool colIsOwn(Json c, [List baseCols = const []]) {
  for (final b in baseCols) {
    if (b['id'] == c['id']) return '${b['name']}'.trim() != '${c['name']}'.trim();
  }
  return true;
}

/// Что поменялось в черновике — короткими словами.
List<String> changes(Json from, Json draft) {
  final out = <String>[];
  final fc = (from['cols'] as List).cast<Map>(), dc = (draft['cols'] as List).cast<Map>();
  final ids = {for (final c in fc) c['id']};
  Map? old(Object? id) {
    for (final x in fc) {
      if (x['id'] == id) return x;
    }
    return null;
  }

  for (final c in dc.where((c) => !ids.contains(c['id']))) {
    out.add('колонка «${c['name']}»');
  }
  for (final c in fc.where((c) => !dc.any((x) => x['id'] == c['id']))) {
    out.add('убрана «${c['name']}»');
  }
  for (final c in dc.where((c) => ids.contains(c['id']) && old(c['id'])!['name'] != c['name'])) {
    out.add('«${c['name']}»');
  }
  final kept = [
    for (final c in dc)
      if (ids.contains(c['id'])) c['id'],
  ];
  final was = [
    for (final c in fc)
      if (kept.contains(c['id'])) c['id'],
  ];
  if (kept.join(',') != was.join(',')) out.add('порядок колонок');
  if (dc.any((c) {
    final o = old(c['id']);
    return o != null && ((o['color'] ?? 0) != (c['color'] ?? 0) || (o['limit'] ?? 0) != (c['limit'] ?? 0));
  })) {
    out.add('цвет или лимит');
  }
  String f(Json x) => ([...(x['fields'] as List).map((e) => '$e')]..sort()).join(',');
  if (f(from) != f(draft)) out.add('поля');
  if (from['view'] != draft['view']) out.add('вид');
  return out;
}

bool _t(Object? v) => v != null && v != false && v != 0 && v != '';

/// Задача для превью карточки: открытая, с бо́льшим числом видимых полей.
Json? sampleTask([List<Json> tasks = const [], Map? layTasks, List Function(Object? id)? subsOf]) {
  int score(Json t) {
    final L = (layTasks?[t['id']] as Map?) ?? const {};
    return (_t(t['due']) ? 2 : 0) +
        (_t(L['priority']) ? 2 : 0) +
        (_t(L['type']) ? 1 : 0) +
        ((subsOf?.call(t['id']) ?? const []).isNotEmpty ? 2 : 0) +
        (_t(L['spent']) ? 1 : 0) +
        (_t(L['client']) ? 1 : 0);
  }

  Json? best;
  for (final t in tasks) {
    if (_t(t['parent']) || t['status'] == 'completed') continue;
    if (best == null || score(t) > score(best)) best = t;
  }
  return best;
}

int previewCount(int? n, int i, int total) {
  final v = n ?? (i == 0 ? 3 : (i == total - 1 ? 2 : 1));
  return v < 3 ? v : 3;
}
