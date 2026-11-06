import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/calendar.dart' as c;

import '../golden_util.dart';

typedef J = Map<String, dynamic>;

void main() {
  c.calendarClock = () => DateTime(2026, 10, 21, 14);
  List<J> l(Object? x) => (x as List).cast<J>();
  String typeOf(String l, String t) => l == 'L' ? 'work' : (t == 'g' ? 'personal' : 'study');
  final cases = golden('calendar.json');
  for (final (i, x) in cases.indexed) {
    test('calendar ${x['fn']} #$i', () {
      final Object? got = switch (x['fn']) {
        'hourLayout' => () {
          final L = c.hourLayout(l(x['it']), (x['hot'] as List).cast<int>(), x['fit']);
          return {
            ...L.toJson(),
            'ys': [0, 1, 59, 60, 90, 600, 630, 1000, 1439, 1440, 1500, -5].map(L.yAt).toList(),
          };
        }(),
        'periodDays' => c.periodDays(x['d'], x['m']),
        'periodTitle' => c.periodTitle(x['d'], x['m']),
        'shiftPeriod' => c.shiftPeriod(x['d'], x['m'], x['dir']),
        'toMin' => c.toMin(x['s']),
        'fromMin' => c.fromMin(x['n']),
        'typeOfTemplate' => c.typeOfTemplate(x['t']),
        'typeColor' => c.typeColor(x['t']),
        'eventsByDay' => c.eventsByDay(l(x['events']), (x['days'] as List).cast<String>()),
        'tasksByDay' => c.tasksByDay(l(x['lists']), x['tasks'], x['lay'], typeOf, (x['days'] as List).cast<String>()),
        'layoutBlocks' => () {
          final it = l(x['it']);
          final L = c.hourLayout(it.where((e) => e['s'] != null).toList());
          return c.layoutBlocks(it, L.yAt);
        }(),
        'busy' => c.busy(l(x['it'])),
        'busyLo' => c.busy(l(x['it']), 0, 1440),
        'busyMinutes' => c.busyMinutes(l(x['it'])),
        'bestWindow' => c.bestWindow(x['di'], (x['days'] as List).cast<String>()),
        'habitDay' => c.habitDay(_hab(cases, x['id']), _log, x['d'], '2026-10-21'),
        'habitBlocks' => c.habitBlocks(l(x['habits']), x['log'], x['d'], '2026-10-21'),
        'dayLabel' => c.dayLabel(x['d']),
        'whenLabel' => c.whenLabel(x['d']),
        'hoursLabel' => c.hoursLabel(x['n']),
        _ => throw 'нет ${x['fn']}',
      };
      expect(js(got), js(x['out']));
    });
  }
}

J? _cachedLog;
Map get _log => _cachedLog!;
J _hab(List<J> cases, String id) {
  final hb = cases.firstWhere((x) => x['fn'] == 'habitBlocks');
  _cachedLog = hb['log'];
  return (hb['habits'] as List).cast<J>().firstWhere((h) => h['id'] == id);
}
