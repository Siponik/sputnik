import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/taskpanel.dart' as p;

import '../golden_util.dart';

void main() {
  List<Map> l(Object? x) => (x as List).cast<Map>();
  for (final (i, x) in golden('taskpanel.json').indexed) {
    test('taskpanel ${x['fn']} #$i', () {
      final Object? got = switch (x['fn']) {
        'colCounts' => p.colCounts(l(x['tasks']), l(x['cols']), x['lay']),
        'stageMode' => p.stageMode(x['v'], x['cols']),
        'leadChip' => p.leadChip(x['m']),
        'customChip' => p.customChip(x['r']),
        'splitRemind' => p.splitRemind(x['r']),
        'joinRemind' => p.joinRemind(x['l'], x['c']),
        'moreFilled' => p.moreFilled(x['L']),
        _ => throw 'нет ${x['fn']}',
      };
      expect(js(got), js(x['out']));
    });
  }
}
