// Действия состояния без Google: повтор, перенос, отметка привычки.
import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/dates.dart';
import 'package:sputnik_app/state/app_state.dart';

void main() {
  test('выполненная задача с повтором рождает следующую, отмена её убирает', () {
    final s = AppState();
    final today = ymd(DateTime.now());
    s.lists = [
      {'id': 'L', 'title': 'Дом'},
    ];
    s.tasks = {
      'L': [
        {'id': 'a', 'title': 'Полить цветы', 'status': 'needsAction', 'due': ymdToDue(today)},
      ],
    };
    s.setTask('a', {
      'repeat': {'every': 'day'},
      'priority': 1,
    });
    s.toggleDone('L', s.tasks['L']!.first);
    final copies = s.tasks['L']!.where((t) => t['title'] == 'Полить цветы' && t['id'] != 'a').toList();
    expect(copies.length, 1);
    expect(s.layTask(copies.first['id'] as String)['priority'], 1);
    s.toggleDone('L', s.task('L', 'a')!);
    expect(s.tasks['L']!.where((t) => t['id'] != 'a').length, 0);
  });

  test('перенос в другой список забирает поля слоя', () {
    final s = AppState();
    s.lists = [
      {'id': 'A', 'title': 'А'},
      {'id': 'B', 'title': 'Б'},
    ];
    s.tasks = {
      'A': [
        {'id': 'x', 'title': 'Задача', 'status': 'needsAction'},
      ],
      'B': [],
    };
    s.setTask('x', {'priority': 2});
    s.moveToList('A', s.tasks['A']!.first, 'B');
    expect(s.tasks['A'], isEmpty);
    expect(s.layTask(s.tasks['B']!.first['id'] as String)['priority'], 2);
  });
}
