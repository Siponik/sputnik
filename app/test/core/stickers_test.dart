import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/stickers.dart' as s;
import 'package:sputnik_app/core/today.dart' as td;

import '../golden_util.dart';

typedef J = Map<String, dynamic>;

void run(String file, Object? Function(J c) f) {
  final cases = golden(file);
  for (var i = 0; i < cases.length; i++) {
    test('$file ${cases[i]['fn']} #$i', () => expect(js(f(cases[i])), js(cases[i]['out']), reason: js(cases[i])));
  }
}

List<J> l(Object? x) => (x as List).cast<J>();

List<J> lanesOf(J x) {
  final o = x['o'] as J;
  return s.lanes(
    l(x['tasks']),
    group: o['group'],
    topics: (o['topics'] ?? s.defaultTopics) as List,
    layTasks: o['layTasks'],
    today: o['today'],
    sort: o['sort'] ?? 'pin',
    people: (o['people'] ?? const []) as List,
    me: o['me'] ?? '',
  );
}

void main() {
  run(
    'today.json',
    (x) => switch (x['fn']) {
      'understood' => td.understood(x['p'], x['today']),
      'taskFrom' => td.taskFrom(x['p'], x['today'], x['dest'], x['r']),
      _ => throw StateError('?'),
    },
  );
  final all = golden('stickers.json');
  final tasks = l(all.firstWhere((x) => x['fn'] == 'lanes')['tasks']);
  run('stickers.json', (x) {
    switch (x['fn']) {
      case 'weekEnd':
        return s.weekEnd(x['today']);
      case 'todaySub':
        return s.todaySub(x['today']);
      case 'plusDays':
        return s.plusDays(x['d'], x['n']);
      case 'bucket':
        return s.bucket(x['due'], x['today']);
      case 'whenDue':
        return s.whenDue(x['target'], x['cur'], x['today']);
      case 'dueLabel':
        return s.dueLabel(x['due'], x['today'], x['slot'], x['hide']);
      case 'newDue':
        return s.newDue(x['target'], x['today']);
      case 'topicsOf':
        return s.topicsOf(x['L']);
      case 'topicColor':
        return s.topicColor(x['t']);
      case 'order':
        return s.order(l(x['items']), x['lay'], x['today'], x['sort']).map((t) => t['id']).toList();
      case 'lanes':
        return lanesOf(x).map((e) => {...e, 'items': (e['items'] as List).map((t) => t['id']).toList()}).toList();
      case 'visibleLanes':
        final v = s.visibleLanes(
          lanesOf({'tasks': tasks, 'o': x['o']}),
          group: (x['o'] as J)['group'],
          keep: x['keep'],
        );
        return {'shown': v.shown.map((e) => e['id']).toList(), 'hidden': v.hidden.map((e) => e['id']).toList()};
      case 'nextGroup':
        return s.nextGroup(x['cur'], x['to'] == 'obj' ? const {} : x['to'], x['sh']);
      case 'topicOfTask':
        return s.topicOfTask(x['task'], x['lay'], s.defaultTopics);
      case 'tilt':
        return s.tilt(x['id']);
      case 'jarCount':
        return s.jarCount(l(x['tasks']), x['now']);
      case 'parseSticker':
        final d = x['today'] as List;
        return s.parseSticker(x['raw'], s.defaultTopics, DateTime(d[0], d[1], d[2], 9));
      case 'consts':
        return {'DEFAULT_TOPICS': s.defaultTopics, 'MISC': s.misc, 'WHEN': s.whenLanes};
    }
    throw StateError('?');
  });
}
