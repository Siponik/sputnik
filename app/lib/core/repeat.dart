// Порт tracker/src/lib/repeat.js — повторяющиеся задачи.
// Правило в слое: tasks[id].repeat = { every }. Даты — строки ГГГГ-ММ-ДД.

typedef Json = Map<String, dynamic>;

const repeats = [
  (id: 'day', label: 'Каждый день', short: 'каждый день'),
  (id: 'weekdays', label: 'По будням', short: 'по будням'),
  (id: 'week', label: 'Каждую неделю', short: 'каждую неделю'),
  (id: 'month', label: 'Каждый месяц', short: 'каждый месяц'),
  (id: 'year', label: 'Каждый год', short: 'каждый год'),
];

String? _every(Object? rule) => rule is Map ? rule['every'] as String? : null;

String repeatLabel(Object? rule) {
  final e = _every(rule);
  for (final r in repeats) {
    if (r.id == e) return r.short;
  }
  return '';
}

DateTime _parse(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _step(String every, String day, int n, String anchor) {
  var d = _parse(day);
  if (every == 'day') return _fmt(DateTime(d.year, d.month, d.day + 1));
  if (every == 'weekdays') {
    do {
      d = DateTime(d.year, d.month, d.day + 1);
    } while (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday);
    return _fmt(d);
  }
  if (every == 'week') return _fmt(DateTime(d.year, d.month, d.day + 7));
  final a = _parse(anchor);
  final months = every == 'year' ? 12 * n : n;
  final m0 = a.month - 1 + months; // месяц с 0, как в JS
  final y = a.year + m0 ~/ 12, m = m0 % 12;
  final last = DateTime(y, m + 2, 0).day;
  return _fmt(DateTime(y, m + 1, a.day < last ? a.day : last));
}

/// Новый срок: следующий по правилу после старого, но не раньше сегодня. Без срока — от сегодня.
String? nextDue(Object? rule, String? due, String today) {
  final e = _every(rule);
  if (!repeats.any((r) => r.id == e)) return null;
  final base = (due == null || due.isEmpty) ? today : due;
  var day = base;
  for (var n = 1; n < 5000; n++) {
    day = _step(e!, day, n, base);
    if (day.compareTo(today) >= 0 && day.compareTo(base) > 0) return day;
  }
  return null;
}

bool _t(Object? v) => v != null && v != false && v != 0 && v != '';

/// Какие задачи пора продолжить: выполненные, с правилом и без repeatNext.
List<Json> dueRepeats(List<Json> lists, Map<String, dynamic> tasks, Map<String, dynamic>? layTasks) {
  final out = <Json>[];
  for (final l in lists) {
    for (final t in ((tasks[l['id']] ?? const []) as List).cast<Json>()) {
      final L = layTasks?[t['id']];
      final every = L is Map && L['repeat'] is Map ? L['repeat']['every'] : null;
      if (_t(t['parent']) ||
          t['status'] != 'completed' ||
          !_t(every) ||
          _t((L as Map?)?['repeatNext']) ||
          _t(t['deleted'])) {
        continue;
      }
      out.add({'listId': l['id'], 'task': t, 'rule': L!['repeat']});
    }
  }
  return out;
}

/// Следующая копия уже есть: то же название, срок day, тот же список.
Json? existingNext(List<Json>? list, Json task, String day) {
  final name = ((task['title'] ?? '') as String).trim();
  for (final x in list ?? const <Json>[]) {
    final due = (x['due'] ?? '') as String;
    if (x['id'] != task['id'] &&
        !_t(x['parent']) &&
        !_t(x['deleted']) &&
        ((x['title'] ?? '') as String).trim() == name &&
        (due.length > 10 ? due.substring(0, 10) : due) == day) {
      return x;
    }
  }
  return null;
}

/// Поля слоя, которые переходят к следующей задаче.
const carry = ['type', 'priority', 'project', 'slot', 'remind', 'repeat', 'client', 'money', 'tags', 'topic', 'pin'];

final _words = [
  (RegExp(r'(^|\s)(каждый\s+день|ежедневно)(?=\s|$)', caseSensitive: false), 'day'),
  (RegExp(r'(^|\s)(по\s+будням|каждый\s+будний\s+день)(?=\s|$)', caseSensitive: false), 'weekdays'),
  (RegExp(r'(^|\s)(каждую\s+неделю|еженедельно)(?=\s|$)', caseSensitive: false), 'week'),
  (RegExp(r'(^|\s)(каждый\s+месяц|ежемесячно)(?=\s|$)', caseSensitive: false), 'month'),
  (RegExp(r'(^|\s)(каждый\s+год|ежегодно)(?=\s|$)', caseSensitive: false), 'year'),
];

/// Повтор в тексте: rule — { every } или null, rest — текст без этих слов.
({Json? rule, String rest}) takeRepeat(String text) {
  for (final (re, every) in _words) {
    final m = re.firstMatch(text);
    if (m != null) {
      final rest = (text.substring(0, m.start) + m[1]! + text.substring(m.end))
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();
      return (rule: {'every': every}, rest: rest);
    }
  }
  return (rule: null, rest: text);
}
