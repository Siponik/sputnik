import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/today_tasks.dart';

TodayTask t(String id, String day) => TodayTask(id: id, listId: 'l', title: id, day: day);

void main() {
  test('просроченные выше, будущие и без срока скрыты, приоритет внутри дня', () {
    final all = [t('a', '2026-11-05'), t('b', '2026-11-04'), t('c', '2026-11-06'), t('d', ''), t('e', '2026-11-05')];
    final layer = {
      'tasks': {
        'e': {'priority': 1},
      },
    };
    final r = todayTasks(all, layer, DateTime(2026, 11, 5)).map((x) => x.id).toList();
    expect(r, ['b', 'e', 'a']);
  });
}
