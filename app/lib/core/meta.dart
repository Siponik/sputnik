// Порт tracker/src/lib/meta.js — тип и приоритет задачи (tasks[id].type, tasks[id].priority).
// autosize из JS — это поведение поля ввода, оно будет в виджете.
typedef Json = Map<String, dynamic>;

const types = <Json>[
  {'id': 'work', 'label': 'work'},
  {'id': 'creative', 'label': 'asset'},
  {'id': 'study', 'label': 'study'},
  {'id': 'personal', 'label': 'personal'},
];

String typeLabel(Object? id) =>
    (types.firstWhere((t) => t['id'] == id, orElse: () => const {})['label'] ?? '') as String;

const priorities = <Json>[
  {'id': 1, 'label': 'Высокий', 'mark': '!!!', 'cls': 'p1'},
  {'id': 2, 'label': 'Средний', 'mark': '!!', 'cls': 'p2'},
  {'id': 3, 'label': 'Низкий', 'mark': '!', 'cls': 'p3'},
];

Json? priorityOf(Object? n) {
  for (final p in priorities) {
    if (p['id'] == n) return p;
  }
  return null;
}

/// Высокий выше, без приоритета — после среднего, перед низким.
int priorityRank(Object? n) => n == 1
    ? 0
    : n == 2
    ? 1
    : n == 3
    ? 3
    : 2;

String _due(Json t) {
  final d = t['due'] as String?;
  return d != null && d.isNotEmpty ? d.substring(0, 10) : '9999';
}

Object? _prio(Map<String, dynamic>? lay, Json t) {
  final r = lay?[t['id']];
  return r is Map ? r['priority'] : null;
}

/// С чего начать: просроченное, приоритет, срок, порядок в списке.
Json? pickNext(List<Json> items, Map<String, dynamic>? layTasks, String today) {
  int late(Json t) => (t['due'] != null && t['due'] != '' && _due(t).compareTo(today) < 0) ? 0 : 1;
  final list = [...items];
  final idx = {for (var i = 0; i < list.length; i++) list[i]: i};
  list.sort((a, b) {
    final ta = a['task'] as Json, tb = b['task'] as Json;
    var c = late(ta) - late(tb);
    if (c != 0) return c;
    c = priorityRank(_prio(layTasks, ta)) - priorityRank(_prio(layTasks, tb));
    if (c != 0) return c;
    c = _due(ta).compareTo(_due(tb));
    if (c != 0) return c;
    c = ((ta['position'] ?? '') as String).compareTo((tb['position'] ?? '') as String);
    return c != 0 ? c : idx[a]! - idx[b]!;
  });
  return list.isEmpty ? null : list.first;
}

/// Почему енот советует именно её.
String nextReason(Json task, Map<String, dynamic>? layTasks, String today, String Function(String due) humanDue) {
  final due = task['due'] as String?;
  final has = due != null && due.isNotEmpty;
  if (has && due.substring(0, 10).compareTo(today) < 0) {
    return 'просрочено с ${humanDue(due).replaceFirst(RegExp(r'^\S+, '), '')}';
  }
  final p = priorityOf(_prio(layTasks, task));
  if (p != null && (p['id'] as int) < 3) {
    return '${(p['label'] as String).toLowerCase()} приоритет${has ? ', срок ${humanDue(due)}' : ''}';
  }
  return has ? 'срок ${humanDue(due)}' : '';
}
