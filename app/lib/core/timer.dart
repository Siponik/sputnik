// Порт tracker/src/lib/timer.js — учёт времени (tasks[id].spent — минут, tasks[id].timer = { start } — мс).
typedef Json = Map<String, dynamic>;

const _maxRunMs = 12 * 3600e3;

num? _start(Object? L) {
  final t = L is Map ? L['timer'] : null;
  final s = t is Map ? t['start'] : null;
  return s is num && s != 0 ? s : null;
}

/// Минут набрано вместе с идущим таймером.
double spentMin(Object? L, int now) {
  final st = _start(L);
  final run = st != null ? (now - st).clamp(0, _maxRunMs).toDouble() : 0.0;
  final spent = L is Map && L['spent'] is num ? (L['spent'] as num).toDouble() : 0.0;
  return spent + run / 60e3;
}

/// Id задачи с идущим таймером (самый поздний запуск) или null.
String? runningId(Map<String, dynamic>? layTasks) {
  String? best;
  num? bestStart;
  for (final e in (layTasks ?? const {}).entries) {
    final st = _start(e.value);
    if (st != null && (best == null || st > bestStart!)) {
      best = e.key;
      bestStart = st;
    }
  }
  return best;
}

/// Остановить таймер: набранное — в spent (с точностью 0,1 мин).
Json stopPatch(Object? L, int now) => {'spent': (spentMin(L, now) * 10).round() / 10, 'timer': null};

/// Патчи [[id, patch]]: остановить всё, что идёт; если у id не шёл — запустить.
List<List<Object?>> toggle(Map<String, dynamic>? layTasks, String id, int now) {
  final out = <List<Object?>>[];
  final wasRunning = _start(layTasks?[id]) != null;
  for (final e in (layTasks ?? const {}).entries) {
    if (_start(e.value) != null) out.add([e.key, stopPatch(e.value, now)]);
  }
  if (!wasRunning) {
    out.add([
      id,
      {
        'timer': {'start': now},
      },
    ]);
  }
  return out;
}

/// «1 ч 05 мин», «12 мин», «меньше минуты».
String fmtMin(num min) {
  final m = min.floor();
  if (m < 1) return 'меньше минуты';
  final h = m ~/ 60;
  return h > 0 ? '$h ч ${(m % 60).toString().padLeft(2, '0')} мин' : '$m мин';
}

/// Часы на шапке: «0:12:07».
String clock(num ms) {
  final s = ms < 0 ? 0 : ms ~/ 1000;
  return '${s ~/ 3600}:${(s ~/ 60 % 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}
