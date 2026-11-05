import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/create.dart' as c;

import '../golden_util.dart';

void main() {
  const today = '2026-10-21';
  for (final (i, x) in golden('create.json').indexed) {
    test('create ${x['fn']} #$i', () {
      final Object? got = switch (x['fn']) {
        'plus' => c.plus(x['d'], x['n']),
        'shortDay' => c.shortDay(x['d']),
        'longDay' => c.longDay(x['d']),
        'eventDay' => c.eventDay(x['d'], today),
        'dayMonth' => c.dayMonth(x['d']),
        'weekday' => c.weekday(x['d']),
        'whenChip' => c.whenChip(x['d'], today),
        'nextBirthday' => c.nextBirthday(x['d'], today),
        'daysTill' => c.daysTill(x['d'], today),
        'dueShort' => c.dueShort(x['d'], today, x['sl']),
        'ageAt' => c.ageAt(x['y'], x['d'], today),
        'toMin' => c.toMin(x['s']),
        'fromMin' => c.fromMin(x['n']),
        'addMin' => c.addMin(x['s'], x['n']),
        'dative' => c.dative(x['n']),
        'years' => c.years(x['n']),
        'dayChunk' => c.dayChunk(x['events'], x['day'], x['sl'], 'Моё'),
        'dayChunk3' => c.dayChunk(x['events'], x['day'], x['sl'], '', 3),
        'freeCheck' => c.freeCheck(x['events'], x['day'], x['sl']),
        'colCount' => c.colCount(x['lt'], x['lay'], x['col'], x['first']),
        'topOrd' => c.topOrd(x['lt'], x['lay'], x['col'], x['first']),
        'stageChecklist' => c.stageChecklist(x['lt'], x['lay']),
        'initials' => c.initials(x['t']),
        'suggestKind' => c.suggestKind(x['s'], x['p']),
        'kindHint' => c.kindHint(x['s'], x['p'], x['k']),
        'recurrenceOf' => c.recurrenceOf(x['r']),
        'parseHabit' => c.parseHabit(x['s'], x['off']),
        'GIFT_DAYS' => c.giftDays,
        'giftDate' => c.giftDate(x['b'], x['d']),
        'bdayName' => c.bdayName(x['s']),
        'giftsDue' => c.giftsDue(x['ev'], x['t']),
        _ => throw 'нет ${x['fn']}',
      };
      expect(js(got), js(x['out']));
    });
  }
}
