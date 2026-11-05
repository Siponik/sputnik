// Порт tracker/src/lib/fresh.js — ответ Google не затирает правки, сделанные пока он шёл.
typedef Json = Map<String, dynamic>;

/// fetched — ответ; local — задачи сейчас; before — id на момент запроса; touched — id → когда меняли (мс); t0 — запрос.
List<Json> keepLocal(
  List<Json> fetched, [
  List<Json> local = const [],
  Set<String> before = const {},
  Map<String, num> touched = const {},
  num t0 = 0,
]) {
  final now = {for (final t in local) t['id'] as String: t};
  final got = {for (final t in fetched) t['id'] as String};
  final out = <Json>[];
  for (final t in fetched) {
    final id = t['id'] as String;
    if (before.contains(id) && !now.containsKey(id)) continue;
    out.add((touched[id] ?? 0) > t0 && now.containsKey(id) ? now[id]! : t);
  }
  for (final t in local) {
    final id = t['id'] as String;
    if (!got.contains(id) && !before.contains(id)) out.add(t);
  }
  return out;
}
