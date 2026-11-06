// Слой Спутника и его слияние между компьютерами. Порт tracker/src/lib/layer.js (только чистая часть: слияние;
// обмен с Drive — в слое data/, не здесь). Результаты должны совпадать со старым кодом — это проверяют золотые
// тесты test/golden/layer_merge.json.
//
// Слой — JSON: { version, tasks: {id: запись}, lists, habits, log, cals, settings, templates, templatesEdit, spheres }.
// Каждая запись несёт t — время изменения. При слиянии по каждой записи побеждают поля более свежей.
// Удалённая запись — «надгробие» { gone: true, t }, чтобы другой компьютер не вернул её.
import 'dart:convert';

typedef Json = Map<String, dynamic>;

const sections = ['tasks', 'lists', 'habits', 'log', 'cals', 'settings', 'templates', 'templatesEdit', 'spheres'];

/// Список удалён: надгробия списка и его задач (как forgetList в layer.js).
Json forgetList(Json lay, String listId, [List<String> taskIds = const [], int? t]) {
  final now = t ?? DateTime.now().millisecondsSinceEpoch;
  final lists = (lay['lists'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
  final tasks = (lay['tasks'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
  lay['lists'] = lists;
  lay['tasks'] = tasks;
  lists[listId] = {'gone': true, 't': now};
  for (final id in taskIds) {
    if (tasks[id] != null) tasks[id] = {'gone': true, 't': now};
  }
  return lay;
}

Json emptyLayer() => {'version': 1, for (final s in sections) s: <String, dynamic>{}};

class MergeResult {
  const MergeResult(this.merged, {required this.localChanged, required this.remoteChanged});

  final Json merged;

  /// В локальный слой пришло что-то новое.
  final bool localChanged;

  /// Облачную копию надо перезаписать.
  final bool remoteChanged;
}

bool _isObj(Object? v) => v is Map;
Json _asJson(Object? v) => Json.from(v as Map);

double _tOf(Object? rec) {
  if (rec is Map) {
    final t = rec['t'];
    if (t is num && t.isFinite) return t.toDouble();
  }
  return 0;
}

// В JS «истина» у слова gone: true, ненулевое число, непустая строка.
bool _truthy(Object? v) => v != null && v != false && v != 0 && v != '';

/// Разделы — известные и любые новые от более свежей версии трекера на другом компьютере.
List<String> _sectionsOf(Object? a, Object? b) {
  final names = <String>{...sections, if (a is Map) ...a.keys.cast<String>(), if (b is Map) ...b.keys.cast<String>()};
  return [
    for (final s in names)
      if (_isObj(a is Map ? a[s] : null) || _isObj(b is Map ? b[s] : null)) s,
  ];
}

/// Сливает локальный слой с копией из облака ([remote] может быть null).
MergeResult merge(Object? local, Object? remote) {
  final merged = <String, dynamic>{
    ...emptyLayer(),
    if (_isObj(remote)) ..._asJson(remote),
    if (_isObj(local)) ..._asJson(local),
  };
  var localChanged = false;
  var remoteChanged = !_isObj(remote);
  for (final s in _sectionsOf(local, remote)) {
    final l0 = local is Map ? local[s] : null;
    final r0 = remote is Map ? remote[s] : null;
    final L = _isObj(l0) ? _asJson(l0) : <String, dynamic>{};
    final R = _isObj(r0) ? _asJson(r0) : <String, dynamic>{};
    final out = <String, dynamic>{};
    for (final k in {...L.keys, ...R.keys}) {
      final hasL = L.containsKey(k), hasR = R.containsKey(k);
      final l = L[k], r = R[k];
      final Object? m = !hasR
          ? l
          : !hasL
          ? r
          : sameJson(l, r)
          ? l
          : _combine(l, r);
      if (!hasL || !sameJson(m, l)) localChanged = true;
      if (!hasR || !sameJson(m, r)) remoteChanged = true;
      out[k] = m;
    }
    merged[s] = out;
  }
  return MergeResult(merged, localChanged: localChanged, remoteChanged: remoteChanged);
}

// Две версии одной записи: поля более свежей главнее, а поля, которых в ней нет, берём из старой.
// Трекер пишет записи только через touch (новое поверх старого), поэтому «поля нет» значит «этот компьютер
// о нём не знал», а не «удалили»: так второй компьютер, дописавший к задаче одно поле, не сотрёт остальные.
// Надгробие { gone } заменяет запись целиком.
Object? _combine(Object? l, Object? r) {
  final rNewer = _newer(r, l);
  final n = rNewer ? r : l;
  final o = rNewer ? l : r;
  if (n is Map && o is Map && !_truthy(n['gone'])) {
    return <String, dynamic>{...o.cast<String, dynamic>(), ...n.cast<String, dynamic>()};
  }
  return n;
}

// Свежее по t; при равном t (старые записи без t) — одинаково на всех компьютерах, иначе они перетягивали бы
// запись друг у друга.
bool _newer(Object? a, Object? b) {
  final ta = _tOf(a), tb = _tOf(b);
  if (ta != tb) return ta > tb;
  return jsonEncode(a).compareTo(jsonEncode(b)) > 0;
}

/// Одинаковы ли записи (порядок ключей не важен).
bool sameJson(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    return a.length == b.length && a.keys.every((k) => b.containsKey(k) && sameJson(a[k], b[k]));
  }
  if (a is List && b is List) {
    return a.length == b.length && List.generate(a.length, (i) => i).every((i) => sameJson(a[i], b[i]));
  }
  if (a is Map || b is Map || a is List || b is List) return false;
  return a == b;
}
