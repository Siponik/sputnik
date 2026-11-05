// Порт tracker/src/lib/dupes.js — дубли задач (открытые задачи одного списка с тем же названием и сроком).
typedef Json = Map<String, dynamic>;

String _s(Object? v) => (v ?? '') as String;
String _day(Object? due) => _s(due).length > 10 ? _s(due).substring(0, 10) : _s(due);
bool _t(Object? v) => v != null && v != false && v != 0 && v != '';

/// Группы дублей: [{ listId, listName, title, due, keep, extra }]. Оставляем копию с бо́льшим числом полей слоя.
List<Json> findDupes(Map<String, dynamic> tasks, List<Json> lists, [Map<String, dynamic>? layTasks]) {
  int weight(Json t) {
    final r = layTasks?[t['id']];
    return r is Map ? r.keys.where((k) => k != 't').length : 0;
  }

  final out = <Json>[];
  for (final l in lists) {
    final groups = <String, List<Json>>{};
    for (final t in ((tasks[l['id']] ?? const []) as List).cast<Json>()) {
      if (_t(t['parent']) || _t(t['deleted']) || t['status'] == 'completed' || _s(t['title']).trim().isEmpty) continue;
      groups.putIfAbsent('${_s(t['title']).trim().toLowerCase()}|${_day(t['due'])}', () => []).add(t);
    }
    for (final g in groups.values) {
      if (g.length < 2) continue;
      final sorted = [...g]
        ..sort((a, b) {
          final w = weight(b) - weight(a);
          if (w != 0) return w;
          return (a['id'] as String).compareTo(b['id'] as String) < 0 ? -1 : 1;
        });
      out.add({
        'listId': l['id'],
        'listName': l['title'],
        'title': sorted[0]['title'],
        'due': _day(sorted[0]['due']),
        'keep': sorted[0],
        'extra': sorted.sublist(1),
      });
    }
  }
  return out;
}
