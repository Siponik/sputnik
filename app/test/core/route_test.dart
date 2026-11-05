import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/route.dart' as r;

import '../golden_util.dart';

typedef J = Map<String, dynamic>;

void main() {
  final cases = golden('route.json');
  final today = DateTime(2026, 10, 21);
  final now = today.millisecondsSinceEpoch;
  // Входы route — те же, что в tools/golden/route.mjs.
  T(String id, String title, [J extra = const {}]) => {'id': id, 'title': title, 'status': 'needsAction', ...extra};
  final lists = <J>[
    {'id': 'Lwork', 'title': 'Иконки для клиента'},
    {'id': 'L3d', 'title': '3D-проекты'},
    {'id': 'Lhome', 'title': 'Дела по дому'},
    {'id': 'Lstudy', 'title': 'Курс Blender'},
  ];
  final J layer = {
    'lists': {
      'Lwork': {'template': 'work'},
      'L3d': {'template': 'asset3d', 'view': 'pipe'},
      'Lhome': {'template': 'personal', 'view': 'stickers'},
      'Lstudy': {'template': 'study'},
    },
    'tasks': {
      'a1': {'project': 'Башня'},
      'a2': {'project': 'Башня'},
      'a3': {'project': 'Таверна'},
      'a4': {'project': 'Таверна'},
    },
    'settings': {},
  };
  final tasks = {
    'Lwork': [
      T('w1', 'Смета по набору иконок'),
      T('w2', 'Референсы для набора «Зимние»'),
      T('w3', 'Ревью набора «Погода»'),
      T('w4', 'Старое сделанное письмо', {'status': 'completed', 'completed': '2026-08-01T00:00:00Z'}),
      T('w5', 'Свежий отчёт', {'status': 'completed', 'completed': '2026-10-20T00:00:00Z'}),
      T('w6', 'Подзадача иконок', {'parent': 'w1'}),
    ],
    'L3d': [
      T('a1', 'Башня lowpoly'),
      T('a2', 'Пропсы для башни'),
      T('a3', 'Сундук с золотом'),
      T('a4', 'Таверна'),
      T('a5', 'Без проекта', {'parent': 'a1'}),
    ],
    'Lhome': [T('h1', 'Лампочки в коридор'), T('h2', 'Позвонить бабушке')],
    'Lstudy': [T('s1', 'Урок 3: материалы')],
  };
  final J learned = {
    ...layer,
    'settings': {
      'route': {
        'разоб': {'list': 'Lstudy', 'n': 3},
        'батар': {'list': 'Lhome', 'topic': 'buy', 'n': 1},
        'плохо': 'x',
        'смета': {'list': 'L3d', 'n': 9},
      },
    },
  };
  for (final (i, x) in cases.indexed) {
    test('route ${x['fn']} #$i', () {
      final Object? got = switch (x['fn']) {
        'words' => r.words(x['s']),
        'stem' => r.stem(x['s']),
        'sameWord' => r.sameWord(x['a'], x['b']),
        'parseLine' => r.parseLine(x['s'], today: today, off: x['off']),
        'projectsOf' => r.projectsOf(x['t'], x['lay']),
        'findList' => r.findList(lists, x['w']),
        'viewOf' => r.viewOf(x['id'], layer),
        'route' => r.route(
          x['text'],
          lists: x['empty'] == true ? const [] : lists,
          layer: x['learned'] == true ? learned : layer,
          tasks: tasks,
          current: x['current'],
          now: now,
        ),
        'learn' => r.learn(x['cur'], x['title'], x['list'], x['topic']),
        _ => throw 'нет ${x['fn']}',
      };
      expect(js(got), js(x['out']));
    });
  }
}
