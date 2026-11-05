import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/dupes.dart';
import 'package:sputnik_app/core/fresh.dart';
import 'package:sputnik_app/core/search.dart';
import 'package:sputnik_app/core/timer.dart';

import '../golden_util.dart';

typedef J = Map<String, dynamic>;

void run(String file, Object? Function(J c) f) {
  final cases = golden(file);
  for (var i = 0; i < cases.length; i++) {
    test('$file ${cases[i]['fn']} #$i', () => expect(js(f(cases[i])), js(cases[i]['out']), reason: js(cases[i])));
  }
}

void main() {
  run('dupes.json', (c) => findDupes(c['tasks'] as J, (c['lists'] as List).cast(), c['lay'] as J?));
  run(
    'search.json',
    (c) => switch (c['fn']) {
      'norm' => norm(c['s']),
      'score' => score(c['q'] as String, c['title'], c['notes']),
      'findTasks' => findTasks(
        c['q'] as String,
        (c['lists'] as List).cast(),
        c['tasks'] as J,
        c['limit'] as int,
      ).map((r) => {'task': r.task['id'], 'list': r.list['id'], 'parent': r.parent?['id'], 's': r.s}).toList(),
      'findPlaces' => findPlaces(c['q'] as String, (c['places'] as List).cast()).map((p) => p['id']).toList(),
      _ => throw StateError('?'),
    },
  );
  run(
    'timer.json',
    (c) => switch (c['fn']) {
      'spentMin' => spentMin(c['L'], c['now'] as int),
      'stopPatch' => stopPatch(c['L'], c['now'] as int),
      'runningId' => runningId(c['lay'] as J?),
      'toggle' => toggle(c['lay'] as J?, c['id'] as String, c['now'] as int),
      'fmtMin' => fmtMin(c['m'] as num),
      'clock' => clock(c['ms'] as num),
      _ => throw StateError('?'),
    },
  );
  run(
    'fresh.json',
    (c) => keepLocal(
      (c['fetched'] as List).cast(),
      (c['local'] as List).cast(),
      (c['before'] as List).cast<String>().toSet(),
      {for (final p in c['touched'] as List) p[0] as String: p[1] as num},
      c['t0'] as num,
    ),
  );
}
