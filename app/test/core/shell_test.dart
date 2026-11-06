import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/shell.dart' as s;

import '../golden_util.dart';

class _FakeTimers implements s.Timers {
  int now = 0, _id = 0;
  final q = <int, (void Function(), int)>{};
  @override
  Object setTimeout(void Function() f, int ms) {
    q[++_id] = (f, now + ms);
    return _id;
  }

  @override
  void clearTimeout(Object id) => q.remove(id);
  void tick(int ms) {
    final end = now + ms;
    for (;;) {
      final due = q.entries.where((e) => e.value.$2 <= end).toList()
        ..sort((a, b) {
          final c = a.value.$2.compareTo(b.value.$2);
          return c != 0 ? c : a.key.compareTo(b.key);
        });
      if (due.isEmpty) break;
      q.remove(due.first.key);
      now = due.first.value.$2;
      due.first.value.$1();
    }
    now = end;
  }
}

Object _slider(List sc) {
  final t = _FakeTimers();
  final log = <bool>[];
  final sl = s.Slider(set: log.add, timers: t);
  final steps = [];
  for (final step in sc) {
    final op = step[0], a = step.length > 1 ? step[1] : null;
    switch (op) {
      case 'tick':
        t.tick(a);
      case 'enter':
        sl.enter();
      case 'leave':
        sl.leave();
      case 'hold':
        sl.hold(a == true);
      case 'show':
        sl.show();
      case 'peek':
        a == null ? sl.peek() : sl.peek(a);
      case 'hide':
        sl.hide();
      case 'instant':
        sl.instant(a == true);
    }
    steps.add([op, a, sl.open, log.length]);
  }
  return {'steps': steps, 'log': log};
}

void main() {
  final spheres = <Map>[
    {'id': 's1', 'name': 'Работа'},
    {'id': 's2', 'name': 'Ёлки дом'},
    {'id': 's3', 'name': 'Пусто'},
  ];
  final listsBy = <String, List<Map>>{
    's1': [
      {'id': 'a', 'title': 'Иконки'},
      {'id': 'b', 'title': 'Смета клиента'},
    ],
    's2': [
      {'id': 'c', 'title': 'Покупки'},
    ],
    's3': [],
  };
  final noSph = <Map>[
    {'id': 'd', 'title': 'Учёба Blender'},
    {'id': 'e', 'title': 'Иконки 2'},
  ];
  List<Map> l(Object? x) => (x as List).cast<Map>();
  for (final (i, x) in golden('shell.json').indexed) {
    test('shell ${x['fn']} #$i', () {
      final Object got = switch (x['fn']) {
        'hm' => s.hm(x['d']),
        'googleLine' => s.googleLine(x['sync'], x['off']),
        'statusDots' => s.statusDots(sync: x['sync'], offline: x['off'], cloud: x['cloud'], upd: x['upd']),
        'cloudLine' => s.cloudLine(x['c']),
        'versionLine' => s.versionLine(x['u']),
        'remindLine' => s.remindLine(x['r']),
        'ownBot' => s.ownBot(x['s'], x['i']),
        'isBeta' => s.isBeta(x['v']),
        'betaShow' => s.betaShow(x['own'], x['v'], x['pref']),
        'notesOf' => s.notesOf(x['t'], x['n']),
        'showUpdChip' => s.showUpdChip(x['f'], x['p'], x['now']),
        'eveningAt' => s.eveningAt(DateTime.fromMillisecondsSinceEpoch(x['now'])),
        'nightNow' => s.nightNow(x['p'], DateTime.fromMillisecondsSinceEpoch(x['now'])),
        'slider' => _slider(x['sc']),
        'filterSide' => s.filterSide(x['q'], spheres, (id) => listsBy[id]!, noSph),
        'boardTips' => s.boardTips(open: l(x['open']), cols: l(x['cols']), colOf: (t) => t['col'], first: x['first']),
        'SETTINGS_TABS' => s.settingsTabs,
        'SETTINGS_INDEX' => s.settingsIndex,
        'VIEW_TABS' => s.viewTabs,
        'searchSettings' => s.searchSettings(x['q']).map((r) => r['id']).toList(),
        'stepTab' => s.stepTab(x['c'], x['d']),
        'tabOrder' => s.tabOrder(x['s']),
        'moveTab' => s.moveTab((x['o'] as List).cast<String>(), x['id'], x['to']),
        'tabsDefault' => s.tabsDefault((x['o'] as List).cast<String>()),
        'startView' => s.startView(x['p'], x['l']),
        _ => throw 'нет ${x['fn']}',
      };
      expect(js(got), js(x['out']));
    });
  }
}
