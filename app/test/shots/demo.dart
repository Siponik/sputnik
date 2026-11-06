// Демо-данные, похожие на макеты G (списки «3D-ассеты», «Работа · клиенты», «Учёба», «Дела по дому», привычки).
import 'package:sputnik_app/core/dates.dart';
import 'package:sputnik_app/state/app_state.dart';

AppState gDemo() {
  final s = AppState();
  final now = DateTime.now();
  final today = ymdToDue(ymd(now))!;
  String day(int n) => ymdToDue(ymd(now.add(Duration(days: n))))!;
  String ago(int n) => ymd(now.subtract(Duration(days: n)));
  s.started = true;
  s.activeList = 'W';
  s.lists = [
    {'id': 'A', 'title': '3D-ассеты'},
    {'id': 'W', 'title': 'Работа · клиенты'},
    {'id': 'U', 'title': 'Учёба'},
    {'id': 'D', 'title': 'Дела по дому'},
    {'id': 'H', 'title': 'Привычки'},
  ];
  Map<String, dynamic> t(String id, String title, {String? due, bool done = false, String? parent}) => {
    'id': id,
    'title': title,
    'status': done ? 'completed' : 'needsAction',
    'due': ?due,
    if (done) 'completed': now.toUtc().toIso8601String(),
    'parent': ?parent,
  };
  s.tasks = {
    'A': [
      t('a1', 'Текстуры для щита, 2K', due: today),
      t('a2', 'Ретопология меча', due: today, done: true),
      t('a3', 'Скульпт шлема', due: day(2)),
      t('a4', 'UV щита', due: day(-1)),
    ],
    'W': [
      t('w1', 'Созвон с клиентом «Таверна»', due: today),
      t('w2', 'Счёт за октябрь', due: day(1)),
      t('w3', 'Бриф: броня для «Кузни»', due: day(4)),
      t('w4', 'Смета на логотип', due: day(-2)),
      t('w5', 'Презентация концептов'),
      t('w6', 'Иконки v1', done: true),
    ],
    'U': [t('u1', 'Глава 4 курса по Substance', due: today)],
    'D': [t('d1', 'Купить корм коту', due: today), t('d2', 'Позвонить в управляющую')],
    'H': [t('h1', 'Зарядка'), t('h2', 'Вода'), t('h3', 'Скетч 15 минут')],
  };
  final ms = now.millisecondsSinceEpoch;
  s.layer['spheres'] = {
    'sp1': {'name': '3D и заказы', 'color': 'clay', 'icon': 'cube', 'order': 1, 't': ms},
    'sp2': {'name': 'Работа', 'color': 'work', 'icon': 'case', 'order': 2, 't': ms},
    'sp3': {'name': 'Учёба', 'color': 'study', 'icon': 'book', 'order': 3, 't': ms},
    'sp4': {'name': 'Дом', 'color': 'personal', 'icon': 'home', 'order': 4, 't': ms},
  };
  s.layer['lists'] = {
    'A': {'sphere': 'sp1', 'template': 'asset3d', 'view': 'pipe', 't': ms},
    'W': {'sphere': 'sp2', 'template': 'work', 't': ms},
    'U': {'sphere': 'sp3', 'template': 'study', 'view': 'list', 't': ms},
    'D': {'sphere': 'sp4', 'template': 'personal', 'view': 'stickers', 't': ms},
  };
  s.layer['tasks'] = {
    'a1': {
      'slot': {'s': '15:00', 'e': '17:00'},
      'priority': 1,
      'status': 'texture',
      't': ms,
    },
    'a2': {
      'slot': {'s': '10:00', 'e': '11:00'},
      't': ms,
    },
    'w1': {
      'slot': {'s': '12:30', 'e': '13:30'},
      'status': 'doing',
      't': ms,
    },
    'u1': {
      'slot': {'s': '19:00', 'e': '20:00'},
      't': ms,
    },
    'w2': {'priority': 1, 't': ms},
    'w3': {'priority': 2, 't': ms},
    'w4': {'priority': 3, 'status': 'doing', 't': ms},
    'w5': {'status': 'review', 't': ms},
  };
  s.layer['habits'] = {
    'h1': {'createdAt': ago(60), 'part': 'morning', 'icon': 'run', 'color': 'gold', 't': ms},
    'h2': {
      'createdAt': ago(60),
      'goal': {'n': 8, 'unit': 'стаканов'},
      'color': 'blue',
      't': ms,
    },
    'h3': {'createdAt': ago(60), 'perWeek': 3, 'part': 'evening', 'color': 'clay', 't': ms},
  };
  s.layer['log'] = {
    for (var i = 0; i < 21; i++) 'h1|${ago(i)}': {'done': true, 'n': 1, 't': ms},
    for (var i = 1; i < 13; i++) 'h2|${ago(i)}': {'done': true, 'n': 8, 't': ms},
    'h2|${ago(0)}': {'n': 5, 't': ms},
    for (var i = 1; i < 20; i += 2) 'h3|${ago(i)}': {'done': true, 'n': 1, 't': ms},
  };
  DateTime at(int h, [int m = 0]) => DateTime(now.year, now.month, now.day, h, m);
  s.events = [
    {
      'summary': 'Обед с Олей',
      'calId': 'primary',
      'start': {'dateTime': at(13).toUtc().toIso8601String()},
      'end': {'dateTime': at(14).toUtc().toIso8601String()},
    },
  ];
  s.calendars = [
    {'id': 'primary', 'summary': 'Основной', 'primary': true, 'accessRole': 'owner'},
  ];
  return s;
}
