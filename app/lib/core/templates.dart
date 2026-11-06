// Порт tracker/src/lib/templates.js — шаблоны досок, доска списка (шаблон + своя копия), перенос задач между колонками,
// порядок задач в колонке, архив. Цвета — имена CSS-переменных старого трекера (во Flutter переводит тема).
import 'dart:convert';

typedef Json = Map<String, dynamic>;

const palette = <Json>[
  {'v': 'var(--ink-faint)', 'name': 'серый'},
  {'v': 'var(--type-work)', 'name': 'синий'},
  {'v': 'var(--clay)', 'name': 'глина'},
  {'v': 'var(--gold)', 'name': 'золото'},
  {'v': 'var(--type-study)', 'name': 'фиолетовый'},
  {'v': 'var(--type-personal)', 'name': 'зелёный'},
  {'v': 'var(--signal-done)', 'name': 'бирюзовый'},
];

String colColor(Object? c) {
  final i = c is Map ? (c['color'] ?? 0) : 0;
  return i is int && i >= 0 && i < palette.length ? palette[i]['v'] as String : palette[0]['v'] as String;
}

const views = <Json>[
  {
    'id': 'kanban',
    'name': 'Канбан',
    'hint': 'Колонки рядом, карточки перетаскиваются. Подходит, когда задач много и они быстро двигаются.',
  },
  {
    'id': 'pipe',
    'name': 'Конвейер',
    'hint': 'Строка = задача, колонки — этапы по порядку. Для долгих задач с этапами: ассеты, большие заказы.',
  },
  {
    'id': 'stickers',
    'name': 'Стикеры',
    'hint': 'Дела-стикеры по темам или по срокам, кружок — сделано. Для простых дел без этапов: покупки, звонки, дом.',
  },
  {'id': 'list', 'name': 'Список', 'hint': 'Простой список с этапом в виде метки. Для курсов и дел, где этапов мало.'},
];

const fieldsList = <Json>[
  {'id': 'due', 'name': 'Срок'},
  {'id': 'prio', 'name': 'Приоритет'},
  {'id': 'type', 'name': 'Тип'},
  {'id': 'stage', 'name': 'Дорожка этапов'},
  {'id': 'subtasks', 'name': 'Подзадачи'},
  {'id': 'time', 'name': 'Учёт времени'},
  {'id': 'progress', 'name': 'Прогресс (3 из 10)'},
  {'id': 'client', 'name': 'Клиент'},
  {'id': 'money', 'name': 'Сумма'},
];

Json _col(String id, String name, [int color = 0, int limit = 0]) => {
  'id': id,
  'name': name,
  'color': color,
  'limit': limit,
};

final builtin = <Json>[
  {
    'id': 'work', 'name': 'Работа', 'title': 'Работа', 'hint': 'Задачи: входящие → в работе → ревью → готово', //
    'view': 'kanban', 'fields': ['due', 'prio', 'type'],
    'cols': [
      _col('inbox', 'Входящие', 0),
      _col('doing', 'В работе', 2, 3),
      _col('review', 'На ревью', 3),
      _col('done', 'Готово', 6),
    ],
  },
  {
    'id': 'client',
    'name': 'Заказы клиентов',
    'title': 'Заказы',
    'hint': 'Заявка → смета → работа → правки → сдано → оплачено',
    'view': 'kanban',
    'fields': ['due', 'prio', 'client', 'money'],
    'cols': [
      _col('request', 'Заявка', 0),
      _col('estimate', 'Смета', 3),
      _col('doing', 'В работе', 2, 2),
      _col('revise', 'Правки', 4),
      _col('delivered', 'Сдано', 1),
      _col('done', 'Оплачено', 6),
    ],
  },
  {
    'id': 'asset3d',
    'name': '3D-ассеты',
    'title': '3D-проекты',
    'hint': 'Каждая строка — модель, этапы пайплайна по порядку',
    'view': 'pipe',
    'fields': ['due', 'stage', 'subtasks', 'time'],
    'cols': [
      _col('refs', 'Референсы', 0),
      _col('blockout', 'Блокаут', 1),
      _col('sculpt', 'Скульпт', 4),
      _col('retopo', 'Ретопология', 2),
      _col('uv', 'UV', 3),
      _col('textures', 'Текстуры', 5),
      _col('render', 'Рендер', 3),
      _col('done', 'Готово', 6),
    ],
  },
  {
    'id': 'personal',
    'name': 'Личное',
    'title': 'Личное',
    'hint': 'Простые дела стикерами: по темам или по срокам',
    'view': 'stickers',
    'fields': ['due'],
    'cols': [_col('inbox', 'Надо сделать', 0), _col('doing', 'Делаю', 2, 3), _col('done', 'Готово', 6)],
  },
  {
    'id': 'study',
    'name': 'Учёба',
    'title': 'Учёба',
    'hint': 'Курсы и уроки: в планах → прохожу → пройдено',
    'view': 'list',
    'fields': ['due', 'progress'],
    'cols': [_col('inbox', 'В планах', 0), _col('doing', 'Прохожу', 4, 2), _col('done', 'Пройдено', 6)],
  },
];

bool isBuiltin(Object? id) => builtin.any((t) => t['id'] == id);

/// Новый свой шаблон «Надо → Делаю → Готово» (now — мс, для id колонок).
Json blankTemplate([String name = 'Свой шаблон', int? now]) {
  final n = now ?? DateTime.now().millisecondsSinceEpoch;
  return {
    'name': name,
    'view': 'kanban',
    'fields': ['due', 'prio'],
    'cols': [
      _col('c${n.toRadixString(36)}', 'Надо', 0),
      _col('c${(n + 1).toRadixString(36)}', 'Делаю', 2),
      _col('done', 'Готово', 6),
    ],
  };
}

Object? _clone(Object? x) => jsonDecode(jsonEncode(x));
bool _t(Object? v) => v != null && v != false && v != 0 && v != '';

Json _pick(Json t) => {
  if (t.containsKey('name') && t['name'] != null) 'name': t['name'],
  'view': t['view'],
  'fields': [...(t['fields'] as List)],
  'cols': [for (final c in t['cols'] as List) Map<String, dynamic>.from(c as Map)],
};

/// Все шаблоны с учётом слоя: встроенные (с правками) и свои.
List<Json> templatesFrom(Json? lay) {
  final out = <Json>[];
  for (final b in builtin) {
    final e = (lay?['templatesEdit'] as Map?)?[b['id']];
    if (e is Map && !_t(e['removed'])) {
      out.add({
        ...(_clone(b) as Json),
        ..._pick({...b, ...e.cast<String, dynamic>()}),
        'changed': true,
      });
    } else {
      out.add({...(_clone(b) as Json), 'changed': false});
    }
  }
  for (final en in ((lay?['templates'] ?? const {}) as Map).entries) {
    final t = en.value;
    if (t is! Map || _t(t['removed']) || t['cols'] is! List || (t['cols'] as List).isEmpty) continue;
    out.add({
      'id': en.key,
      'title': t['name'],
      'hint': (t['cols'] as List).map((c) => (c as Map)['name']).join(' → '),
      ..._pick({'view': 'kanban', 'fields': <Object?>[], ...t.cast<String, dynamic>()}),
      'mine': true,
    });
  }
  return out;
}

/// Шаблон по id; неизвестный — «Работа».
Json templateOf(Object? id, [Json? lay]) {
  final all = templatesFrom(lay);
  return all.firstWhere((t) => t['id'] == id, orElse: () => all[0]);
}

String shortName(Json t) =>
    const {'work': 'работа', 'client': 'заказы', 'asset3d': '3D', 'personal': 'дела', 'study': 'учёба'}[t['id']] ??
    'свой';

const habitsTemplate = 'habits';

bool isHabitList(Json list, Json? lay) =>
    ((lay?['lists'] as Map?)?[list['id']] as Map?)?['template'] == habitsTemplate ||
    RegExp(r'(^|\s)привычки$', caseSensitive: false).hasMatch((list['title'] ?? '') as String);

bool _okCols(Object? c) => c is List && c.length >= 2 && c.last is Map && (c.last as Map)['id'] == 'done';

/// Своё ли у списка (колонки или поля отвязаны от шаблона).
bool isOwn(Object? L) => L is Map && (_okCols(L['cols']) || L['fields'] is List);

/// Доска списка: шаблон с наложенной копией списка.
Json boardOf(String listId, Json? lay) {
  final L = ((lay?['lists'] as Map?)?[listId] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
  final base = templateOf(L['template'], lay);
  final cols = _okCols(L['cols'])
      ? [for (final c in L['cols'] as List) Map<String, dynamic>.from(c as Map)]
      : base['cols'];
  final fields = L['fields'] is List ? [...(L['fields'] as List)] : base['fields'];
  return {
    ...base,
    'view': L['view'] ?? base['view'] ?? 'kanban',
    'cols': cols,
    'fields': fields,
    'own': isOwn(L),
    'base': base,
  };
}

/// Идёт ли список за шаблоном tid (без своей копии).
bool follows(String listId, Json? lay, String tid) =>
    boardOf(listId, lay)['id'] == tid && !isOwn((lay?['lists'] as Map?)?[listId]);

/// Что записать в lists[id], чтобы сохранить доску «только для этого списка».
Json ownPatch(Json draft) => {
  'view': draft['view'],
  'fields': [...(draft['fields'] as List)],
  'cols': [
    for (final c in draft['cols'] as List)
      {
        'id': c['id'],
        'name': (c['name'] ?? '').toString().trim().isEmpty ? 'Без названия' : (c['name'] ?? '').toString().trim(),
        'color': c['color'] ?? 0,
        'limit': c['limit'] ?? 0,
      },
  ],
};

bool sameShape(Json a, Json b) {
  String f(Json x) => ([...((x['fields'] ?? const []) as List).map((e) => '$e')]..sort()).join(',');
  return jsonEncode(ownPatch(a)['cols']) == jsonEncode(ownPatch(b)['cols']) && f(a) == f(b);
}

Json resetPatch() => {'cols': null, 'fields': null, 'view': null};

String _norm(Object? s) => (s ?? '').toString().trim().toLowerCase().replaceAll('ё', 'е');

/// Куда переедут задачи при смене колонок: по названию, тот же id, по порядку; «готово» — в последнюю.
Map<String, String> matchCols(List oldCols, List newCols) {
  final last = newCols.length - 1;
  final out = <String, String>{};
  final byName = <String, String>{};
  for (final c in newCols) {
    byName[_norm(c['name'])] = c['id'] as String;
  }
  for (var i = 0; i < oldCols.length; i++) {
    final c = oldCols[i];
    final id = c['id'] as String;
    if (id == 'done') {
      out[id] = newCols[last]['id'] as String;
      continue;
    }
    final n = byName[_norm(c['name'])];
    if (n != null && n != 'done') {
      out[id] = n;
    } else if (newCols.any((x) => x['id'] == id && x['id'] != 'done')) {
      out[id] = id;
    } else {
      final k = i < (last - 1 < 0 ? 0 : last - 1) ? i : (last - 1 < 0 ? 0 : last - 1);
      out[id] = newCols[k]['id'] as String;
    }
  }
  return out;
}

/// Правки [{ id, status }] для задач из пропавших колонок (цепочки разворачиваются).
List<Json> relocate(List? taskList, Map? layTasks, Map moves) {
  final out = <Json>[];
  for (final t in taskList ?? const []) {
    final from = ((layTasks?[t['id']]) as Map?)?['status'];
    if (!_t(from) || !moves.containsKey(from) || moves[from] == from) continue;
    var s = from;
    var guard = 0;
    while (moves.containsKey(s) && moves[s] != s && guard++ < 20) {
      s = moves[s];
    }
    if (s != from) out.add({'id': t['id'], 'status': s});
  }
  return out;
}

/// Колонки, которые пропадут, — куда уедут их задачи.
Map<String, String> lostMoves(List oldCols, List newCols) {
  final keep = {for (final c in newCols) c['id']};
  final m = matchCols(oldCols, newCols);
  return {
    for (final c in oldCols)
      if (!keep.contains(c['id'])) c['id'] as String: m[c['id']]!,
  };
}

Json saveListPlan(Json? lay, String listId, Json draft, List? taskList, [List removed = const []]) {
  final cur = boardOf(listId, lay);
  final moves = {...lostMoves(cur['cols'] as List, draft['cols'] as List), for (final r in removed) r['id']: r['to']};
  return {'patch': ownPatch(draft), 'moves': relocate(taskList, lay?['tasks'] as Map?, moves)};
}

Json resetListPlan(Json? lay, String listId, List? taskList) {
  final cur = boardOf(listId, lay);
  return {
    'patch': resetPatch(),
    'moves': relocate(
      taskList,
      lay?['tasks'] as Map?,
      lostMoves(cur['cols'] as List, (cur['base'] as Json)['cols'] as List),
    ),
  };
}

/// «Колонки из другого шаблона»: список переходит на newTplId и снова идёт за ним.
Json switchPlan(Json? lay, String listId, String newTplId, List? taskList, [Map? mapping]) {
  final cur = boardOf(listId, lay), next = templateOf(newTplId, lay);
  final curCols = cur['cols'] as List, nextCols = next['cols'] as List;
  final map = <String, dynamic>{...matchCols(curCols, nextCols), ...?mapping?.cast<String, dynamic>()};
  final ids = {for (final c in nextCols) c['id']};
  final last = nextCols.last['id'];
  final moves = <Json>[];
  for (final t in taskList ?? const []) {
    if (_t(t['parent']) || t['status'] == 'completed') continue;
    final s = ((lay?['tasks'] as Map?)?[t['id']] as Map?)?['status'];
    final from = _t(s) && s != 'done' && curCols.any((c) => c['id'] == s) ? s : curCols[0]['id'];
    var to = map[from] ?? nextCols[0]['id'];
    if (to == last || !ids.contains(to)) to = nextCols[0]['id'];
    final now = _t(s) && s != 'done' && ids.contains(s) ? s : nextCols[0]['id'];
    if (to != now) moves.add({'id': t['id'], 'status': to});
  }
  final curFields = (cur['fields'] ?? const []) as List;
  return {
    'patch': {'template': next['id'], ...resetPatch()},
    'moves': moves,
    'map': map,
    'fresh': ((next['fields'] ?? const []) as List).where((f) => !curFields.contains(f)).toList(),
  };
}

const sorts = <Json>[
  {'id': 'own', 'name': 'Свой'},
  {'id': 'due', 'name': 'Срок'},
  {'id': 'prio', 'name': 'Приоритет'},
];

String sortOf(Object? L) {
  final s = L is Map ? L['sort'] : null;
  return s == 'due' || s == 'prio' ? s as String : 'own';
}

int _rank(Object? n) => n == 1
    ? 0
    : n == 2
    ? 1
    : n == 3
    ? 3
    : 2;
String _dueKey(Json t) => _t(t['due']) ? (t['due'] as String).substring(0, 10) : '9999';
int _pos(Json a, Json b) => ((a['position'] ?? '') as String).compareTo((b['position'] ?? '') as String).sign;

List<T> _stableSort<T>(List<T> xs, int Function(T a, T b) cmp) {
  final idx = List.generate(xs.length, (i) => i);
  idx.sort((i, j) {
    final c = cmp(xs[i], xs[j]);
    return c != 0 ? c : i - j;
  });
  return [for (final i in idx) xs[i]];
}

/// Задачи колонки в порядке списка: own — свой (tasks[id].ord, без него — приоритет), due, prio.
List<Json> orderTasks(List<Json> items, Map? layTasks, [String sort = 'own']) {
  int pr(Json t) => _rank(((layTasks?[t['id']]) as Map?)?['priority']);
  if (sort == 'due') {
    return _stableSort(items, (a, b) {
      final c = _dueKey(a).compareTo(_dueKey(b));
      if (c != 0) return c;
      final p = pr(a) - pr(b);
      return p != 0 ? p : _pos(a, b);
    });
  }
  if (sort == 'prio') {
    return _stableSort(items, (a, b) {
      final p = pr(a) - pr(b);
      if (p != 0) return p;
      final c = _dueKey(a).compareTo(_dueKey(b));
      return c != 0 ? c : _pos(a, b);
    });
  }
  final base = _stableSort(items, (a, b) {
    final p = pr(a) - pr(b);
    return p != 0 ? p : _pos(a, b);
  });
  final key = <Object?, num>{};
  for (var i = 0; i < base.length; i++) {
    key[base[i]['id']] = (((layTasks?[base[i]['id']]) as Map?)?['ord'] as num?) ?? i - 0.5;
  }
  return _stableSort(base, (a, b) => (key[a['id']]! - key[b['id']]!).sign.toInt());
}

const archiveAfterDays = 3;
const archiveChoices = [0, 3, 7];

int archiveDays(Object? L) {
  final a = L is Map ? L['archive'] : null;
  return a is int && archiveChoices.contains(a) ? a : archiveAfterDays;
}

bool isArchived(Json task, [int days = archiveAfterDays, int? now]) {
  if (task['status'] != 'completed' || !_t(task['completed'])) return false;
  final n = now ?? DateTime.now().millisecondsSinceEpoch;
  return n - DateTime.parse(task['completed'] as String).millisecondsSinceEpoch > days * 864e5;
}
