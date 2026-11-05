import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/inbox.dart' as ib;

import '../golden_util.dart';

void main() {
  ib.inboxClock = () => DateTime(2026, 10, 21, 14);
  final lists = <Map>[
    {'id': 'L1', 'title': 'Дом'},
    {'id': 'L2', 'title': 'Работа'},
    {'id': 'L3', 'title': 'X'},
  ];
  final tbl = {
    'L1': [
      {'id': 't1'},
      {'id': 't2'},
      {'id': 't5', 'status': 'completed'},
    ],
    'L2': [
      {'id': 't3'},
      {'id': 't6'},
      {'id': 'zz'},
    ],
    'L3': [
      {'id': 't4'},
    ],
  };
  for (final (i, x) in golden('inbox.json').indexed) {
    test('inbox ${x['fn']} #$i', () {
      final Object got = switch (x['fn']) {
        'claudeTasks' => ib.claudeTasks(x['status']),
        'pending' => ib.pending(x['status'], lists, tbl, x['lt']),
        'layerPatches' => ib.layerPatches(x['status'], x['lt']),
        'pullPatches' => ib.pullPatches(x['status'], x['lay']),
        _ => throw 'нет ${x['fn']}',
      };
      expect(js(got), js(x['out']));
    });
  }
}
