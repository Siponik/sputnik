import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/accent.dart' as a;
import 'package:sputnik_app/core/authcheck.dart' as c;
import 'package:sputnik_app/core/dropdown.dart' as d;
import 'package:sputnik_app/core/meta.dart' as m;
import 'package:sputnik_app/core/spheres.dart' as s;

import '../golden_util.dart';

typedef J = Map<String, dynamic>;

void run(String file, Object? Function(J c) f) {
  final cases = golden(file);
  for (var i = 0; i < cases.length; i++) {
    test('$file ${cases[i]['fn']} #$i', () => expect(js(f(cases[i])), js(cases[i]['out']), reason: js(cases[i])));
  }
}

List<J> l(Object? x) => (x as List).cast<J>();

void main() {
  run(
    'accent.json',
    (x) => switch (x['fn']) {
      'luminance' => a.luminance(x['x']),
      'contrast' => a.contrast(x['x'], x['y']),
      'mix' => a.mix(x['x'], x['y'], x['t']),
      'fit' => a.fit(x['x'], x['bg'], x['min']),
      'accentOf' => a.accentOf(x['v']),
      'accentCss' => a.accentCss(x['v']),
      'vars' => a.vars(x['x'], x['th']),
      'ACCENTS' => a.accents,
      _ => throw StateError('?'),
    },
  );
  run(
    'authcheck.json',
    (x) => switch (x['fn']) {
      'checkSecretText' => c.checkSecretText(x['t'], x['size']),
      'loginHint' => c.loginHint(x['e']),
      'isStopped' => c.isStopped(x['e']),
      'isScopeLack' => c.isScopeLack(x['e']),
      'calDefaultOn' => c.calDefaultOn(x['cal']),
      _ => throw StateError('?'),
    },
  );
  final opts = l(golden('dropdown.json').firstWhere((x) => x['fn'] == 'moveActive')['opts']);
  run('dropdown.json', (x) {
    final o = x['opts'] == null ? opts : l(x['opts']);
    return switch (x['fn']) {
      'filterOpts' => d.filterOpts(opts, x['q']).map((e) => e['id']).toList(),
      'marks' => d.marks(x['label'], x['q']),
      'moveActive' => d.moveActive(o, x['cur'], x['key']),
      'jumpTo' => d.jumpTo(o, x['cur'], x['ch']),
      'toggleIn' => d.toggleIn(x['values'] as List?, x['id'], o),
      'buttonText' => d.buttonText(opts, x['value'], x['multi']),
      'placeMenu' =>
        x['opt'] == null
            ? d.placeMenu(x['btn'], x['h'], x['w'], x['view'])
            : d.placeMenu(
                x['btn'],
                x['h'],
                x['w'],
                x['view'],
                gap: x['opt']['gap'],
                max: x['opt']['max'],
                pad: x['opt']['pad'],
              ),
      _ => throw StateError('?'),
    };
  });
  String human(String due) => 'пт, ${due.substring(8, 10)}.${due.substring(5, 7)}';
  run(
    'meta.json',
    (x) => switch (x['fn']) {
      'typeLabel' => m.typeLabel(x['id']),
      'priorityOf' => m.priorityOf(x['n']),
      'priorityRank' => m.priorityRank(x['n']),
      'pickNext' => (m.pickNext(l(x['items']), x['lay'], x['today'])?['task'] as J?)?['id'],
      'nextReason' => m.nextReason(x['task'], x['lay'], x['today'], human),
      'TYPES' => m.types,
      'PRIORITIES' => m.priorities,
      _ => throw StateError('?'),
    },
  );
  run(
    'spheres.json',
    (x) => switch (x['fn']) {
      'spheresFrom' => s.spheresFrom(x['lay']),
      'sphereOf' => s.sphereOf(x['id'], x['lay']),
      'sphereColor' => s.sphereColor(x['sp']),
      'iconPath' => s.iconPath(x['sp']),
      'listChoices' => s.listChoices(l(x['lists']), x['lay']),
      _ => throw StateError('?'),
    },
  );
}
