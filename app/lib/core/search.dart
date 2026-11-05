// Порт tracker/src/lib/search.js — поиск по задачам и переходам (окно Ctrl+K).
typedef Json = Map<String, dynamic>;

/// Строчные, ё = е, пробелы схлопнуты.
String norm(Object? s) =>
    (s ?? '').toString().toLowerCase().replaceAll('ё', 'е').replaceAll(RegExp(r'\s+'), ' ').trim();

/// Насколько задача подходит (0 — нет): все слова запроса — в названии или заметке.
int score(String q, Object? title, [Object? notes = '']) {
  final words = norm(q).split(' ').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return 0;
  final t = norm(title), n = norm(notes);
  var s = 0;
  for (final w in words) {
    if (t.startsWith(w)) {
      s += 6;
    } else if (RegExp('(^|[\\s«"(\\-])${RegExp.escape(w)}').hasMatch(t)) {
      s += 4;
    } else if (t.contains(w)) {
      s += 2;
    } else if (n.contains(w)) {
      s += 1;
    } else {
      return 0;
    }
  }
  return s;
}

/// Приближение localeCompare(…, 'ru'): сначала без регистра и с ё = е, потом ё после е, потом строчные раньше.
int ruCompare(String a, String b) {
  int cmp(String x, String y) => x.compareTo(y).sign;
  final p = cmp(a.toLowerCase().replaceAll('ё', 'е'), b.toLowerCase().replaceAll('ё', 'е'));
  if (p != 0) return p;
  final s = cmp(a.toLowerCase(), b.toLowerCase());
  if (s != 0) return s;
  return -cmp(a, b);
}

/// Задачи всех списков под запрос: открытые выше, лучшие совпадения выше.
List<({Json task, Json list, Json? parent, int s})> findTasks(
  String q,
  List<Json> lists,
  Map<String, dynamic> tasksByList, [
  int limit = 30,
]) {
  final out = <({Json task, Json list, Json? parent, int s})>[];
  for (final l in lists) {
    final all = ((tasksByList[l['id']] ?? const []) as List).cast<Json>();
    for (final t in all) {
      final sc = score(q, t['title'], t['notes'] ?? '');
      if (sc == 0) continue;
      final hasParent = t['parent'] != null && t['parent'] != '';
      Json? parent;
      if (hasParent) {
        for (final p in all) {
          if (p['id'] == t['parent']) {
            parent = p;
            break;
          }
        }
      }
      out.add((task: t, list: l, parent: parent, s: sc + (t['status'] == 'completed' ? 0 : 100) + (hasParent ? 0 : 1)));
    }
  }
  final idx = {for (var i = 0; i < out.length; i++) out[i]: i};
  out.sort((a, b) {
    final d = b.s - a.s;
    if (d != 0) return d;
    final c = ruCompare((a.task['title'] ?? '') as String, (b.task['title'] ?? '') as String);
    return c != 0 ? c : idx[a]! - idx[b]!;
  });
  return out.length > limit ? out.sublist(0, limit) : out;
}

/// Переходы (разделы, списки), чьё имя подходит под запрос.
List<Json> findPlaces(String q, List<Json> places) {
  final qq = norm(q);
  if (qq.isEmpty) return places;
  return places
      .where(
        (p) => norm(p['name']).contains(qq) || ((p['alias'] ?? const []) as List).any((a) => norm(a).startsWith(qq)),
      )
      .toList();
}
