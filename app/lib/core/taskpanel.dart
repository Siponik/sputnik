// Порт tracker/src/lib/taskpanel.js
// Окно задачи v2: сколько задач в колонках, как показать этап, подписи напоминаний, когда «▸ Ещё» открыто сразу.
import 'reminders.dart' show before, leads, rulesOf;

typedef Json = Map<String, dynamic>;

bool _t(Object? v) => v != null && v != false && v != 0 && v != '';

/// Открытые задачи верхнего уровня по колонкам: { colId: n }. Колонка — из слоя (status), иначе первая.
Map<String, int> colCounts([List<Map> listTasks = const [], List<Map> cols = const [], Map? layTasks]) {
  final n = {for (final c in cols) c['id'] as String: 0};
  if (cols.isEmpty) return n;
  for (final t in listTasks) {
    if (_t(t['parent']) || t['status'] == 'completed') continue;
    final s = (layTasks?[t['id']] as Map?)?['status'];
    final c = _t(s) && s != 'done' && n.containsKey(s) ? s as String : cols[0]['id'] as String;
    n[c] = n[c]! + 1;
  }
  return n;
}

/// track — дорожка (Конвейер), chips — до 4 колонок, menu — выпадающий список.
String stageMode(String? view, [List cols = const []]) =>
    view == 'pipe' ? 'track' : (cols.length <= 4 ? 'chips' : 'menu');

String leadChip(num min) {
  for (final l in leads) {
    if (l['min'] == min) return (l['name'] as String).toLowerCase();
  }
  return 'За $min мин'.toLowerCase();
}

const _monShort = ['янв.', 'февр.', 'мар.', 'апр.', 'мая', 'июн.', 'июл.', 'авг.', 'сент.', 'окт.', 'нояб.', 'дек.'];

/// Подпись чипа «в своё время»: «за 1 день в 10:00», «29 окт. в 18:00».
String customChip(Map? rule) {
  if (rule == null) return '';
  if (rule['kind'] == 'at') {
    final parts = '${rule['at'] ?? ''}'.split('T');
    final d = parts[0], t = parts.length > 1 ? parts[1] : null;
    final ymd = d.split('-').map(int.tryParse).toList();
    int? at(int i) => i < ymd.length ? ymd[i] : null;
    if (!_t(at(0)) || !_t(at(1)) || !_t(at(2))) return 'точное время';
    final date = DateTime(at(0)!, at(1)!, at(2)!);
    final tt = _t(t) ? ' в ${t!.length > 5 ? t.substring(0, 5) : t}' : '';
    return '${date.day} ${_monShort[date.month - 1]}$tt';
  }
  final days = rule['days'] ?? 0;
  String? name;
  for (final b in before) {
    if (b['days'] == days) name = b['name'] as String;
  }
  return '${(name ?? 'За ${rule['days']} дн.').toLowerCase()} в ${rule['time'] ?? '10:00'}';
}

/// Напоминания задачи: минуты «до начала» и одно «в своё время» (или null).
Json splitRemind(Object? remind) {
  final all = rulesOf(remind).cast<Map>();
  final custom = all.where((r) => r['kind'] != 'lead');
  return {
    'leads': [
      for (final r in all)
        if (r['kind'] == 'lead') r['min'],
    ],
    'custom': custom.isEmpty ? null : custom.first,
  };
}

/// Обратно в правило слоя: одно правило, массив или null.
Object? joinRemind([List leads = const [], Map? custom]) {
  final all = [
    for (final m in leads) {'kind': 'lead', 'min': m},
    ?custom,
  ];
  return all.isEmpty ? null : (all.length == 1 ? all[0] : all);
}

/// «▸ Ещё» открыто сразу, если там что-то заполнено: повтор, цвет, картинка.
bool moreFilled([Map? l]) => _t((l?['repeat'] as Map?)?['every']) || _t(l?['type']) || _t(l?['preview']);
