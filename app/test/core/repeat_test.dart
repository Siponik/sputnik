import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/repeat.dart';

void main() {
  final cases = (jsonDecode(File('test/golden/repeat.json').readAsStringSync()) as List).cast<Map<String, dynamic>>();
  for (var i = 0; i < cases.length; i++) {
    final c = cases[i];
    test('${c['fn']} #$i', () {
      final Object? got = switch (c['fn']) {
        'nextDue' => nextDue(c['rule'], c['due'] as String, c['today'] as String),
        'repeatLabel' => repeatLabel(c['rule']),
        'takeRepeat' => (() {
          final r = takeRepeat(c['text'] as String);
          return {'rule': r.rule, 'rest': r.rest};
        })(),
        'dueRepeats' => dueRepeats(
          (c['lists'] as List).cast(),
          c['tasks'] as Map<String, dynamic>,
          c['lay'] as Map<String, dynamic>?,
        ),
        'existingNext' => existingNext(
          (c['list'] as List).cast(),
          c['task'] as Map<String, dynamic>,
          c['day'] as String,
        ),
        'CARRY' => carry,
        _ => throw StateError('нет ${c['fn']}'),
      };
      expect(jsonEncode(got), jsonEncode(c['out']), reason: jsonEncode(c));
    });
  }
}
