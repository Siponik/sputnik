// Порт tracker/src/lib/spheres.js — сферы (группы списков). Цвета — имена CSS-переменных старого трекера;
// во Flutter их переводит тема (ui/theme). iconStyle из JS — это CSS, его нет.
import 'search.dart' show ruCompare;

typedef Json = Map<String, dynamic>;

const sphereColors = <Json>[
  {'id': 'clay', 'name': 'Глина', 'v': 'var(--clay)'},
  {'id': 'gold', 'name': 'Золото', 'v': 'var(--gold)'},
  {'id': 'work', 'name': 'Синий', 'v': 'var(--type-work)'},
  {'id': 'study', 'name': 'Фиолетовый', 'v': 'var(--type-study)'},
  {'id': 'personal', 'name': 'Зелёный', 'v': 'var(--type-personal)'},
  {'id': 'done', 'name': 'Бирюзовый', 'v': 'var(--signal-done)'},
];

const sphereIcons = <String, Json>{
  'cube': {'name': 'Куб', 'd': 'M12 3l8 4.5v9L12 21l-8-4.5v-9zM12 12l8-4.5M12 12v9M12 12L4 7.5'},
  'case': {'name': 'Портфель', 'd': 'M4 8h16v11H4zM9 8V5h6v3M4 13h16'},
  'book': {'name': 'Книга', 'd': 'M5 4h10a3 3 0 0 1 3 3v13H8a3 3 0 0 1-3-3zM5 17a3 3 0 0 1 3-3h10'},
  'home': {'name': 'Дом', 'd': 'M4 11l8-7 8 7M6 10v10h12V10M10 20v-6h4v6'},
  'users': {
    'name': 'Люди',
    'd': 'M9 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7zM3 20c0-3.3 2.7-6 6-6s6 2.7 6 6M16 4.5a3.5 3.5 0 0 1 0 6.5M18 14c2 .8 3 3 3 6',
  },
  'heart': {'name': 'Сердце', 'd': 'M12 20s-7-4.5-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.5-7 10-7 10z'},
  'brush': {'name': 'Кисть', 'd': 'M18 3l3 3-9.5 9.5-3-3zM8.5 12.5C6 12.5 4 14.5 4 17c0 1.5-1 2.5-2 3 4 1 8-1 8-4.5'},
  'star': {'name': 'Звезда', 'd': 'M12 3l2.7 5.6 6.1.8-4.4 4.3 1 6.1L12 17l-5.4 2.8 1-6.1-4.4-4.3 6.1-.8z'},
};

String sphereColor(Object? s) {
  final c = s is Map ? s['color'] : null;
  return (sphereColors.firstWhere((x) => x['id'] == c, orElse: () => sphereColors[0])['v']) as String;
}

String iconPath(Object? s) => ((sphereIcons[s is Map ? s['icon'] : null] ?? sphereIcons['star']!)['d']) as String;

bool _removed(Object? s) => s is Map && s['removed'] != null && s['removed'] != false;

/// Сферы по порядку, без удалённых.
List<Json> spheresFrom(Json? lay) {
  final out = <Json>[];
  for (final e in ((lay?['spheres'] ?? const {}) as Map).entries) {
    if (e.value is Map && !_removed(e.value)) out.add({'id': e.key, ...(e.value as Map).cast<String, dynamic>()});
  }
  final idx = {for (var i = 0; i < out.length; i++) out[i]: i};
  out.sort((a, b) {
    final d = ((a['order'] ?? 0) as num) - ((b['order'] ?? 0) as num);
    if (d != 0) return d.sign.toInt();
    final c = ruCompare((a['name'] ?? '') as String, (b['name'] ?? '') as String);
    return c != 0 ? c : idx[a]! - idx[b]!;
  });
  return out;
}

String? sphereOf(String listId, Json? lay) {
  final l = (lay?['lists'] as Map?)?[listId];
  final id = l is Map ? l['sphere'] : null;
  if (id == null || id == '') return null;
  final s = (lay?['spheres'] as Map?)?[id];
  return s != null && !_removed(s) ? id as String : null;
}

/// Списки для выпадающего списка с группами по сферам.
Json listChoices(List<Json> lists, Json? lay) {
  final spheres = spheresFrom(lay);
  final color = {for (final s in spheres) s['id']: sphereColor(s)};
  final options = [
    for (final l in lists)
      (() {
        final sp = sphereOf(l['id'] as String, lay);
        return {
          'id': l['id'],
          'label': l['title'],
          'group': sp ?? '',
          'color': sp != null ? color[sp] : 'var(--ink-faint)',
        };
      })(),
  ];
  final used = {for (final o in options) o['group']};
  final groups = [
    for (final s in spheres)
      if (used.contains(s['id'])) {'id': s['id'], 'name': s['name'], 'color': color[s['id']]},
    if (used.contains('') && used.length > 1) {'id': '', 'name': 'Без сферы', 'color': 'var(--ink-faint)'},
  ];
  return {'options': options, 'groups': groups.isEmpty ? null : groups};
}
