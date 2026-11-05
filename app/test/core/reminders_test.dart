import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/reminders.dart' as r;

import '../golden_util.dart';

typedef J = Map<String, dynamic>;

void main() {
  r.remindersClock = () => DateTime(2026, 10, 21, 14);
  List<Map> l(Object? x) => (x as List).cast<Map>();
  DateTime at(Object? ms) => DateTime.fromMillisecondsSinceEpoch(ms as int);
  final cases = golden('reminders.json');
  for (final (i, x) in cases.indexed) {
    test('reminders ${x['fn']} #$i', () {
      r.setDefaultTime(x['fn'] == 'collectOff' ? 'off' : (x['dt'] ?? '10:00'));
      final Object? got = switch (x['fn']) {
        'defaultMins' => r.defaultMins(x['s'], x['k']),
        'defaultRule' => r.defaultRule(x['s']),
        'minsToRule' => r.minsToRule(x['m']),
        'rulesOf' => r.rulesOf(x['r']),
        'leadName' => r.leadName(x['m'], x['k']),
        'leadsText' => r.leadsText(x['m'], x['k']),
        'fireAt' => r.fireAt(x['r'], x['t'], x['sl'])?.toUtc().toIso8601String(),
        'remindLabel' => r.remindLabel(x['r'], x['t'], x['sl']),
        'collect' ||
        'collectOff' => r.collect(l(x['lists']), x['tasks'], x['lay'], x['hl'], l(x['cheers']), l(x['events'])),
        'assignedItems' => r.assignedItems(l(x['lists']), x['tasks'], x['lay'], x['now']),
        'habitItems' => r.habitItems((x['habits'] as List).cast<J>(), x['log'], at(x['now'])),
        'habitWinDue' =>
          r
              .habitWinDue((x['habits'] as List).cast<J>(), x['log'], x['sent'], at(x['now']))
              .map((h) => h['id'])
              .toList(),
        _ => throw 'нет ${x['fn']}',
      };
      expect(js(got), js(x['out']));
    });
  }
}
