import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/boardedit.dart' as b;
import 'package:sputnik_app/core/templates.dart' as t;

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
    'templates.json',
    (x) => switch (x['fn']) {
      'templatesFrom' => t.templatesFrom(x['lay']),
      'templateOf' => t.templateOf(x['id'], x['lay']),
      'boardOf' => t.boardOf(x['id'], x['lay']),
      'follows' => t.follows(x['id'], x['lay'], x['tid']),
      'shortName' => t.shortName(x['t']),
      'colColor' => t.colColor(x['c']),
      'isBuiltin' => t.isBuiltin(x['id']),
      'isHabitList' => t.isHabitList(x['list'], x['lay']),
      'isOwn' => t.isOwn(x['L']),
      'ownPatch' => t.ownPatch(x['d']),
      'resetPatch' => t.resetPatch(),
      'sameShape' => t.sameShape(x['a'], x['b']),
      'matchCols' => t.matchCols(x['o'], x['n']),
      'lostMoves' => t.lostMoves(x['o'], x['n']),
      'relocate' => t.relocate(x['tl'], x['lt'], x['mv']),
      'saveListPlan' => t.saveListPlan(x['lay'], x['id'], x['draft'], x['tl'], x['removed']),
      'resetListPlan' => t.resetListPlan(x['lay'], x['id'], x['tl']),
      'switchPlan' => t.switchPlan(x['lay'], x['id'], x['tid'], x['tl'], x['mp']),
      'sortOf' => t.sortOf(x['L']),
      'orderTasks' => t.orderTasks(l(x['items']), x['lay'], x['sort']).map((e) => e['id']).toList(),
      'archiveDays' => t.archiveDays(x['L']),
      'isArchived' => t.isArchived(x['task'], x['days'], x['now']),
      'blankTemplate' => t.blankTemplate(x['name'], x['now']),
      'BUILTIN' => t.builtin,
      'VIEWS' => t.views,
      'FIELDS' => t.fieldsList,
      'SORTS' => t.sorts,
      _ => throw StateError('?'),
    },
  );
  run(
    'boardedit.json',
    (x) => switch (x['fn']) {
      'draftOf' => b.draftOf(x['b']),
      'moveCol' => b.moveCol(x['cols'], x['from'], x['to']),
      'recolor' => b.recolor(x['c']),
      'relimit' => b.relimit(x['c'], x['d']),
      'newCol' => b.newCol(x['now']),
      'dropCol' => b.dropCol(x['cols'], x['i'], x['removed'], x['n']),
      'toggleField' => b.toggleField(x['fields'], x['f']),
      'tasksWord' => b.tasksWord(x['n']),
      'listsWord' => b.listsWord(x['n']),
      'colIsOwn' => b.colIsOwn(x['c'], x['base']),
      'changes' => b.changes(x['from'], x['draft']),
      'sampleTask' => b.sampleTask(l(x['tasks']), x['lay'], (id) => (x['subs'] as Map)[id] ?? const [])?['id'],
      'previewCount' => b.previewCount(x['n'], x['i'], x['total']),
      'fieldInfo' => (() {
        final f = b.fieldInfo(x['id']);
        if (f == null) return null;
        final o = Map<String, dynamic>.from(x['out'] as Map)..remove('icon');
        return js(f) == js(o) ? x['out'] : f; // значки (SVG) не переносим
      })(),
      _ => throw StateError('?'),
    },
  );
}
