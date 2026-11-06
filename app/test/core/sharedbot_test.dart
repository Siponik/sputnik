import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/sharedbot.dart' as b;

import '../golden_util.dart';

typedef J = Map<String, dynamic>;

void main() {
  b.sharedbotClock = () => DateTime(2026, 10, 21, 14);
  // Входы — те же, что в tools/golden/sharedbot.mjs.
  final lists = <J>[
    {'id': 'Lwork', 'title': 'Иконки для клиента'},
    {'id': 'L3d', 'title': '3D-проекты'},
    {'id': 'Lhome', 'title': 'Дела по дому'},
    {'id': 'Lx', 'title': ''},
  ];
  final J layer = {
    'lists': {
      'Lwork': {'template': 'work'},
      'L3d': {'template': 'asset3d', 'view': 'pipe'},
      'Lhome': {'template': 'personal', 'view': 'stickers'},
    },
    'tasks': {
      'a1': {
        'project': 'Башня',
        'slot': {'s': '10:00'},
      },
      'w1': {
        'slot': {'s': '09:30'},
      },
      'w2': {'slot': {}},
    },
    'settings': {
      'route': {
        'смета': {'list': 'Lwork', 'n': 2},
        'башн': {'list': 'L3d'},
        'чужо': {'list': 'nope', 'n': 9},
        'плохо': 'x',
        'купит': {'list': 'Lhome', 'n': 5},
      },
    },
  };
  J t(String id, String title, String? due, [J extra = const {}]) => {
    'id': id,
    'title': title,
    'status': 'needsAction',
    if (due != null) 'due': '${due}T00:00:00.000Z',
    ...extra,
  };
  final tasks = {
    'Lwork': [
      t('w1', 'Смета по набору иконок', '2026-10-21'),
      t('w2', '', '2026-10-28'),
      t('w3', 'Поздно', '2026-10-29'),
      t('w4', 'Сделано', '2026-10-21', {'status': 'completed'}),
      t('w5', 'Подзадача', '2026-10-21', {'parent': 'w1'}),
      t('w6', 'Без срока', null),
      t('w7', 'Просрочено', '2026-10-01'),
      t('w8', 'Удалено', '2026-10-22', {'deleted': true}),
    ],
    'L3d': [t('a1', 'Башня lowpoly', '2026-10-21'), t('a2', 'Пропсы для башни', '2026-10-21')],
    'Lhome': [t('h1', 'Лампочки', '2026-10-25')],
  };
  final lt = layer['tasks'] as Map;
  for (final (i, x) in golden('sharedbot.json').indexed) {
    test('sharedbot ${x['fn']} #$i', () {
      final Object? got = switch (x['fn']) {
        'snapshot' => b.snapshot(lists, tasks, lt, DateTime.fromMillisecondsSinceEpoch(x['now'])),
        'snapshotNoLay' => b.snapshot(lists, tasks, null, DateTime.fromMillisecondsSinceEpoch(x['now'])),
        'guessCtx' => b.guessCtx(lists, layer),
        'guessCtx0' => b.guessCtx([], null),
        'fromText' => b.fromText(x['s'], lists: lists, layer: layer, tasks: tasks),
        'fromTextNoLists' => b.fromText(x['s'], lists: [], layer: layer, tasks: tasks),
        'fromDraft' => b.fromDraft(x['x'], lists: lists, layer: layer, tasks: tasks),
        'fromDraftNoLists' => b.fromDraft(x['x'], lists: [], layer: layer, tasks: tasks),
        'consts' => [b.botUrl, b.botName, b.botLink],
        _ => throw 'нет ${x['fn']}',
      };
      expect(js(got), js(x['out']));
    });
  }
  test('newKey — 64 знака hex', () {
    expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(b.newKey()), isTrue);
    expect(b.newKey() == b.newKey(), isFalse);
  });
}
