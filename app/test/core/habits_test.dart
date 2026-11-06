import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/dates.dart';
import 'package:sputnik_app/core/habits.dart' as h;

import '../golden_util.dart';

typedef J = Map<String, dynamic>;

void main() {
  h.habitsClock = () => DateTime(2026, 10, 21, 14);
  final cases = golden('habits.json');
  final setup = cases.first;
  final habits = (setup['habits'] as List).cast<J>();
  final log = setup['log'] as J;
  J hb(String id) => habits.firstWhere((x) => x['id'] == id);
  for (var i = 1; i < cases.length; i++) {
    final x = cases[i];
    test('habits ${x['fn']} #$i', () {
      final H = x['id'] == null ? <String, dynamic>{} : hb(x['id']);
      final Object? got = switch (x['fn']) {
        'stats' => h.stats(H, log),
        'monthGrid' => h.monthGrid(H, log, x['y'], x['m']),
        'monthRow' => h.monthRow(H, log, x['y'], x['m']),
        'dayState' => h.dayState(H, log, x['d']),
        'scheduledOn' => h.scheduledOn(H, log, x['d']),
        'countOn' => h.countOn(log, H, x['d']),
        'nextMark' => h.nextMark(log, H, x['d']),
        'dayMark' => h.dayMark(H, x['st']),
        'last7' => h.last7(H, log),
        'milestoneDate' => h.milestoneDate(H, log, x['s']),
        'broken' => h.broken(H, log),
        'partOf' => h.partOf(H),
        'partName' => h.partName(H),
        'habitWin' => h.habitWin(H),
        'winLabel' => h.winLabel(H),
        'remindAt' => h.remindAt(H),
        'habitSpan' => h.habitSpan(H),
        'spanLabel' => h.spanLabel(H),
        'unitForms' => h.unitForms(H),
        'scheduleLine' => h.scheduleLine(H),
        'goalN' => h.goalN(H),
        'cardLine' => h.cardLine(H, log),
        'totalDone' => h.totalDone(H, log),
        'moveWin' => h.moveWin(H, x['t']),
        'moveEnd' => h.moveEnd(H, x['t']),
        'monthSummary' => h.monthSummary(habits, log, x['y'], x['m']),
        'habitTip' => (() {
          final t = h.habitTip(habits, log);
          return t == null
              ? null
              : {'habit': t.habit['id'], 'anchor': t.anchor['id'], 'time': t.time, 'misses': t.misses};
        })(),
        'sortHabits' => h.sortHabits(habits).map((e) => e['id']).toList(),
        'milestonePos' => h.milestonePos(x['n']),
        'nextMilestone' => h.nextMilestone(x['n']),
        'plural' => h.plural(x['n'], ['день', 'дня', 'дней']),
        'scheduleLabel' => h.scheduleLabel(x['d']),
        'partWin' => h.partWin(x['p']),
        'cleanWin' => h.cleanWin(x['w']),
        'wholePart' => h.wholePart(x['w']),
        'winFields' => h.winFields(x['w']),
        'normTime' => h.normTime(x['r'], x['e']),
        'normEnd' => h.normEnd(x['t'], x['e']),
        'endAfter' => h.endAfter(x['t'], x['m']),
        'dayOffset' => ymd(h.dayOffset(x['i'])),
        _ => throw StateError('нет ${x['fn']}'),
      };
      expect(js(got), js(x['out']), reason: js(x));
    });
  }
}
