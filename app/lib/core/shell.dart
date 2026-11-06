// Порт tracker/src/lib/shell.js
// Шапка, «Состояние», обновления, левая колонка и настройки — чистая логика.
import 'dart:async';

typedef Json = Map<String, dynamic>;

bool _t(Object? v) => v != null && v != false && v != 0 && v != '';
String _p2(int n) => n.toString().padLeft(2, '0');

/// «09:05» по местному времени; d — мс или строка ISO.
String hm(Object? d) {
  if (!_t(d)) return '';
  final x = d is num ? DateTime.fromMillisecondsSinceEpoch(d.toInt()) : DateTime.parse(d.toString()).toLocal();
  return '${_p2(x.hour)}:${_p2(x.minute)}';
}

Json _line(String text, String cls) => {'text': text, 'cls': cls};

Json statusDots({required Map sync, bool offline = false, required Map cloud, required Map upd}) {
  final g = {'c': _t(sync['err']) ? 'e' : '', 'busy': _t(sync['busy'])};
  final st = cloud['state'];
  final l = {'c': st == 'login' ? 'w' : (st == 'err' ? 'e' : ''), 'busy': st == 'busy'};
  final v = {'c': _t(upd['found']) ? 'w' : (_t(upd['err']) ? 'e' : ''), 'busy': _t(upd['busy'])};
  var label = hm(sync['at']);
  if (offline) {
    label = 'Нет связи';
  } else if (st == 'login') {
    label = 'Нужен вход';
  } else if (_t(sync['err'])) {
    label = 'Ошибка';
  }
  return {
    'dots': [g, l, v],
    'label': label,
  };
}

Json googleLine(Map sync, [bool offline = false]) {
  if (_t(sync['busy'])) return _line('обновляю…', '');
  if (offline) return _line('нет связи — повторю через минуту', 'e');
  if (_t(sync['err'])) return _line(sync['err'], 'e');
  if (!_t(sync['at'])) return _line('ещё не обновлялось', '');
  return _line('обновлено в ${hm(sync['at'])} · раз в 2 минуты', 'ok');
}

Json cloudLine(Map cloud) {
  final st = cloud['state'];
  if (st == 'login') return _line('нужно разрешить скрытую папку на Drive', 'w');
  if (st == 'err') return _line(_t(cloud['err']) ? cloud['err'] : 'не удалось синхронизировать', 'e');
  if (st == 'busy') return _line('синхронизирую…', '');
  if (st == 'ok' && _t(cloud['at'])) return _line('синхронизировано в ${hm(cloud['at'])}', 'ok');
  return _line('ещё не синхронизировано', '');
}

Json versionLine(Map upd) {
  final f = upd['found'] as Map?;
  if (_t(upd['busy'])) {
    final p = (((upd['progress'] ?? 0) as num) * 100 + 0.5).floor();
    return _line('ставлю ${f?['version'] ?? ''} · $p%', 'w');
  }
  if (f != null) return _line('вышла ${f['version']} · меньше минуты', 'c');
  if (_t(upd['err'])) return _line(upd['err'], 'e');
  if (_t(upd['checkedAt'])) return _line('последняя версия · проверено в ${hm(upd['checkedAt'])}', 'ok');
  return _line('обновления проверяются сами', '');
}

Json remindLine(Map? rem) {
  if (_t(rem?['shared'])) {
    if (_t(rem!['err'])) return _line(rem['err'], 'e');
    return _t(rem['linked'])
        ? _line('через общий бот', 'ok')
        : _line('бот не подключён — Настройки → Напоминания', 'w');
  }
  if (_t(rem?['err'])) return _line(rem!['err'], 'e');
  if (!_t(rem?['at'])) return _line('файл ещё не обновлялся', '');
  return _line('файл обновлён ${hm(rem!['at'])} · ${rem['n']} впереди', 'ok');
}

/// Свой бот на Apps Script — только у владельца. show — строка в настройках, on — писать файл напоминаний.
Json ownBot(Map? settings, Object? inbox) {
  final v = (settings?['ownBot'] as Map?)?['v'];
  final found = _t(inbox);
  return {'show': found || v == true, 'on': v is bool ? v : found};
}

bool isBeta(Object? v) => RegExp(r'-beta\.\d+$').hasMatch('${v ?? ''}');

bool betaShow(Map? own, Object? version, [Map pref = const {}]) =>
    _t(own?['show']) || pref['beta'] == true || isBeta(version);

/// «Что нового»: первые n пунктов списка из заметки релиза.
List<String> notesOf(Object? text, [int n = 3]) {
  final lines = '${text ?? ''}'.split(RegExp(r'\r?\n')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  final bullet = RegExp(r'^[-*•✦]\s+');
  final items = [
    for (final s in lines)
      if (bullet.hasMatch(s)) s.replaceFirst(bullet, ''),
  ];
  return (items.isNotEmpty ? items : lines).take(n).toList();
}

bool showUpdChip(Map? found, [Map pref = const {}, int? now]) {
  if (found == null) return false;
  if (_t(pref['skip']) && pref['skip'] == found['version']) return false;
  now ??= DateTime.now().millisecondsSinceEpoch;
  if (_t(pref['remindAt']) && now < (pref['remindAt'] as num)) return false;
  return true;
}

/// «Вечером» — сегодня в 20:00, а если уже позже — завтра в 20:00.
int eveningAt([DateTime? now]) {
  now ??= DateTime.now();
  var d = DateTime(now.year, now.month, now.day, 20);
  if (!d.isAfter(now)) d = DateTime(now.year, now.month, now.day + 1, 20);
  return d.millisecondsSinceEpoch;
}

bool nightNow([Map pref = const {}, DateTime? now]) => _t(pref['night']) && (now ?? DateTime.now()).hour == 3;

// ---------- левая колонка доски ----------

/// Таймеры для Slider (в тестах — подставные).
abstract class Timers {
  Object setTimeout(void Function() f, int ms);
  void clearTimeout(Object id);
}

class _RealTimers implements Timers {
  @override
  Object setTimeout(void Function() f, int ms) => Timer(Duration(milliseconds: ms), f);
  @override
  void clearTimeout(Object id) => (id as Timer).cancel();
}

/// Выезд откреплённой колонки: наведение — через inMs выезжает, уход — через outMs уезжает.
class Slider {
  Slider({this.inMs = 150, this.outMs = 300, this.set, Timers? timers}) : _timers = timers ?? _RealTimers();
  int inMs, outMs;
  final void Function(bool open)? set;
  final Timers _timers;
  bool _open = false, _inside = false, _held = false;
  Object? _tm;

  bool get open => _open;
  void _clear() {
    if (_tm != null) _timers.clearTimeout(_tm!);
    _tm = null;
  }

  void _go(bool v) {
    _clear();
    if (_open != v) {
      _open = v;
      set?.call(v);
    }
  }

  void _later(bool v, int ms) {
    _clear();
    if (ms == 0) {
      _go(v);
    } else {
      _tm = _timers.setTimeout(() => _go(v), ms);
    }
  }

  void enter() {
    _inside = true;
    if (_open) {
      _clear();
    } else {
      _later(true, inMs);
    }
  }

  void leave() {
    _inside = false;
    if (!_open) {
      _clear();
    } else if (!_held) {
      _later(false, outMs);
    }
  }

  void hold(bool v) {
    _held = v;
    if (_held) {
      _clear();
    } else if (_open && !_inside) {
      _later(false, outMs);
    }
  }

  void show() => _go(true);

  /// Выдвинуть на время (клавиши [ ]): мышь не на колонке — уедет через ms.
  void peek([int ms = 1500]) {
    _go(true);
    if (!_inside && !_held) _later(false, ms);
  }

  void hide() {
    _held = false;
    _go(false);
  }

  /// Анимации выключены — выезд мгновенный.
  void instant(bool v) {
    if (v) {
      inMs = 0;
      outMs = 0;
    }
  }
}

String _norm(Object? s) => (s ?? '').toString().toLowerCase().replaceAll('ё', 'е');
List<String> _words(Object? q) => _norm(q).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

/// Фильтр «Список…»: сферы и списки, где есть все слова запроса.
Json filterSide(String query, List<Map> spheres, List<Map> Function(Object? id) listsOf, List<Map> noSphere) {
  final words = _words(query);
  bool hit(Object? s) => words.every((w) => _norm(s).contains(w));
  if (words.isEmpty) {
    return {
      'spheres': [
        for (final sp in spheres) {'sp': sp, 'lists': listsOf(sp['id'])},
      ],
      'noSphere': noSphere,
      'first': null,
    };
  }
  final out = <Json>[];
  for (final sp in spheres) {
    final all = listsOf(sp['id']);
    final lists = hit(sp['name']) ? all : all.where((l) => hit(l['title'])).toList();
    if (lists.isNotEmpty || hit(sp['name'])) out.add({'sp': sp, 'lists': lists});
  }
  final rest = noSphere.where((l) => hit(l['title'])).toList();
  final flat = [for (final x in out) ...x['lists'] as List];
  final first = flat.isNotEmpty ? flat.first : (rest.isNotEmpty ? rest.first : null);
  return {
    'spheres': out,
    'noSphere': rest,
    'first': first,
    'firstSphere': first == null ? (out.isNotEmpty ? out.first['sp'] : null) : null,
  };
}

/// Советы енота для доски: 2–3 штуки { id, text, act, kind, ref }.
List<Json> boardTips({
  required List<Map> open,
  required List<Map> cols,
  required Object? Function(Map) colOf,
  Map? first,
}) {
  final tips = <Json>[];
  if (open.isEmpty) {
    return [
      {
        'id': 'empty',
        'text': 'Всё разобрано. Новые задачи — кнопкой «+ Добавить задачу» в колонке или «Создать».',
        'act': 'Новая задача',
        'kind': 'new',
      },
    ];
  }
  if (first != null) {
    final task = first['task'] as Map;
    final title = _t(task['title']) ? task['title'] : 'Без названия';
    final head = 'Начни с «$title»${_t(first['why']) ? ' — ${first['why']}' : ''}';
    tips.add({
      'id': 'first',
      'text': '$head${head.endsWith('.') ? '' : '.'} Остальное подождёт.',
      'act': 'Открыть',
      'kind': 'task',
      'ref': task['id'],
    });
  }
  int n(Map c) => open.where((t) => colOf(t) == c['id']).length;
  Map? lim;
  for (final c in cols) {
    if (_t(c['limit']) && n(c) >= (c['limit'] as num) - 1) {
      lim = c;
      break;
    }
  }
  if (lim != null) {
    final k = n(lim);
    tips.add({
      'id': 'limit',
      'kind': 'col',
      'ref': lim['id'],
      'act': 'К «${lim['name']}»',
      'text': k > lim['limit']
          ? 'В «${lim['name']}» $k из ${lim['limit']} — больше лимита. Закончи что-нибудь, прежде чем брать новое.'
          : '«${lim['name']}» уже $k из ${lim['limit']} — закончи одну, прежде чем брать новую.',
    });
  }
  final inbox = cols.isNotEmpty ? cols[0] : null;
  final ni = inbox != null ? n(inbox) : 0;
  if (inbox != null && ni >= 3 && cols.length > 2) {
    tips.add({
      'id': 'inbox',
      'kind': 'col',
      'ref': inbox['id'],
      'act': 'К «${inbox['name']}»',
      'text': 'Во «${inbox['name']}» $ni — разбери: что в работу, что на потом.',
    });
  }
  return tips.take(3).toList();
}

// ---------- Настройки ----------

const settingsTabs = <Json>[
  {'id': 'look', 'name': 'Вид'},
  {'id': 'show', 'name': 'Что показывать'},
  {'id': 'rem', 'name': 'Напоминания'},
  {'id': 'sync', 'name': 'Синхронизация'},
  {'id': 'upd', 'name': 'Обновления'},
  {'id': 'keys', 'name': 'Клавиши'},
];

const settingsIndex = <Json>[
  {
    'tab': 'look',
    'id': 'theme',
    'title': 'Тема',
    'hint': 'Тёмная — основная. «Как в Windows» переключается вместе с системой.',
    'also': 'светлая цвет оформление',
  },
  {
    'tab': 'look',
    'id': 'accent',
    'title': 'Акцент',
    'hint': 'Цвет кнопок, выделения и подсветки',
    'also': 'акцентный цвет оформление глина палитра',
  },
  {
    'tab': 'look',
    'id': 'motion',
    'title': 'Анимации',
    'hint': '«Минимум» — только мягкое появление. «Выкл» — всё сразу.',
    'also': 'движение',
  },
  {
    'tab': 'look',
    'id': 'tabs',
    'title': 'Порядок вкладок',
    'hint': 'Сегодня, Календарь, Доска, Привычки — в каком порядке стоят в шапке. Клавиши 1–4 идут так же.',
    'also': 'меню шапка разделы переставить порядок верхнее',
  },
  {
    'tab': 'look',
    'id': 'start',
    'title': 'Открывать при запуске',
    'hint': 'Какой раздел показывать первым',
    'also': 'старт',
  },
  {
    'tab': 'look',
    'id': 'tips',
    'title': 'Енот-советчик',
    'hint': 'Советы внизу колонки доски',
    'also': 'совет подсказки',
  },
  {
    'tab': 'show',
    'id': 'lists',
    'title': 'Списки задач',
    'hint': 'Какие списки видны на доске, в «Сегодня» и в календаре',
    'also': 'скрыть показывать',
  },
  {
    'tab': 'show',
    'id': 'cals',
    'title': 'Календари',
    'hint': 'Какие календари Google показывать',
    'also': 'скрыть показывать дни рождения праздники',
  },
  {
    'tab': 'rem',
    'id': 'tgbot',
    'title': 'Telegram',
    'hint': 'Общий бот: напоминания и задачи текстом',
    'also': 'телеграм бот подключить код',
  },
  {
    'tab': 'rem',
    'id': 'bot',
    'title': 'Свой бот (Apps Script)',
    'hint': 'Только у владельца: файл напоминаний, проверка связи, выключить',
    'also': 'телеграм бот проверить apps script выключить',
  },
  {
    'tab': 'rem',
    'id': 'rtask',
    'title': 'Задачи — по умолчанию',
    'hint': 'Напоминание, которое ставится новой задаче со сроком',
  },
  {'tab': 'rem', 'id': 'revent', 'title': 'События', 'hint': 'Напоминание о событии по умолчанию'},
  {'tab': 'rem', 'id': 'rbday', 'title': 'Дни рождения', 'hint': 'Напоминание о дне рождения по умолчанию'},
  {
    'tab': 'rem',
    'id': 'rhour',
    'title': 'Задачи без времени',
    'hint': 'Во сколько напоминать, если у задачи только дата, или не напоминать',
    'also': 'выключить отключить уведомление',
  },
  {'tab': 'rem', 'id': 'notify', 'title': 'Уведомления Windows', 'hint': 'Вехи привычек; основное — в боте'},
  {
    'tab': 'sync',
    'id': 'acct',
    'title': 'Google-аккаунт',
    'hint': 'Задачи, календарь, скрытая папка',
    'also': 'выйти войти почта',
  },
  {
    'tab': 'sync',
    'id': 'google',
    'title': 'Google Задачи и Календарь',
    'hint': 'Обновляется само раз в 2 минуты',
    'also': 'обновить синхронизация',
  },
  {
    'tab': 'sync',
    'id': 'cloud',
    'title': 'Между компьютерами',
    'hint': 'Слой Спутника в скрытой папке на Drive',
    'also': 'синхронизация второй компьютер',
  },
  {
    'tab': 'sync',
    'id': 'dupes',
    'title': 'Дубли задач',
    'hint': 'Одинаковые задачи в одном списке',
    'also': 'дубли копии повторы двойные',
  },
  {
    'tab': 'sync',
    'id': 'backup',
    'title': 'Резервные копии',
    'hint': 'Каждый день, хранятся 14',
    'also': 'бэкап копия папка',
  },
  {
    'tab': 'upd',
    'id': 'ver',
    'title': 'Версия Спутника',
    'hint': 'Обновить или проверить обновления',
    'also': 'обновление',
  },
  {
    'tab': 'upd',
    'id': 'auto',
    'title': 'Проверять самому',
    'hint': 'Через 30 секунд после запуска и раз в 6 часов',
    'also': 'обновления автоматически',
  },
  {
    'tab': 'upd',
    'id': 'night',
    'title': 'Ставить ночью',
    'hint': 'Если компьютер включён — обновится в 3:00 без вопросов',
    'also': 'обновления',
  },
  {'tab': 'upd', 'id': 'all', 'title': 'Все версии', 'hint': 'Список изменений на GitHub', 'also': 'релизы'},
  {
    'tab': 'keys',
    'id': 'keys',
    'title': 'Клавиши',
    'hint': 'Горячие клавиши — работают и в русской раскладке',
    'also': 'сочетания хоткеи',
  },
];

/// Найти настройку: все слова запроса — в заголовке, пояснении или словах для поиска. Порядок — как на экране.
List<Json> searchSettings(String? query, [List<Json> index = settingsIndex]) {
  final words = _words(query);
  if (words.isEmpty) return [];
  return index.where((r) {
    final t = _norm('${r['title']} ${r['hint'] ?? ''} ${r['also'] ?? ''}');
    return words.every((w) => t.contains(w));
  }).toList();
}

/// ↑ ↓ по вкладкам настроек.
String stepTab(String cur, int dir, [List<Json> tabs = settingsTabs]) {
  final i = tabs.indexWhere((t) => t['id'] == cur);
  return tabs[(i + dir + tabs.length) % tabs.length]['id'];
}

// ---------- Порядок вкладок в шапке ----------

const viewTabs = <Json>[
  {'id': 'today', 'name': 'Сегодня'},
  {'id': 'calendar', 'name': 'Календарь'},
  {'id': 'board', 'name': 'Доска'},
  {'id': 'habits', 'name': 'Привычки'},
];

/// Порядок вкладок из настройки: неизвестные и повторы отбрасываются, забытые — в конец.
List<String> tabOrder(Object? saved, [List<Json> tabs = viewTabs]) {
  final ids = [for (final t in tabs) t['id'] as String];
  final out = <String>[];
  for (final id in saved is List ? saved : const []) {
    if (ids.contains(id) && !out.contains(id)) out.add(id);
  }
  return [...out, ...ids.where((id) => !out.contains(id))];
}

/// Переставить вкладку id на место to.
List<String> moveTab(List<String> order, String id, int to) {
  final rest = order.where((x) => x != id).toList();
  if (rest.length == order.length) return [...order];
  final i = to < 0 ? 0 : (to > rest.length ? rest.length : to);
  return [...rest.sublist(0, i), id, ...rest.sublist(i)];
}

bool tabsDefault(List<String> order, [List<Json> tabs = viewTabs]) =>
    order.join(',') == tabs.map((t) => t['id']).join(',');

/// С какого раздела открыться: today | board | last.
String startView(Object? pref, Object? last, [List<String> views = const ['today', 'calendar', 'board', 'habits']]) {
  if (pref == 'board') return 'board';
  if (pref == 'last' && views.contains(last)) return last as String;
  return 'today';
}
