// Какие задачи показывать в «Сегодня»: открытые, срок сегодня или раньше (просроченные выше), потом по приоритету слоя.
// Пилот: приоритет берётся из layer['tasks'][id]['priority'] (1 высокий … 3 низкий; нет — 2).
import 'dates.dart';

class TodayTask {
  TodayTask({required this.id, required this.listId, required this.title, required this.day, this.done = false});
  final String id;
  final String listId;
  final String title;
  final String day; // YYYY-MM-DD
  bool done;
}

List<TodayTask> todayTasks(List<TodayTask> all, Map<String, dynamic> layer, DateTime today) {
  final t = ymd(today);
  final tasks = (layer['tasks'] as Map?) ?? const {};
  int prio(TodayTask x) {
    final r = tasks[x.id];
    final p = r is Map ? r['priority'] : null;
    return p is num ? p.toInt() : 2;
  }

  final list = all.where((x) => x.day.isNotEmpty && x.day.compareTo(t) <= 0).toList();
  // List.sort неустойчива — берём индекс как последний ключ.
  final idx = {for (var i = 0; i < list.length; i++) list[i]: i};
  list.sort((a, b) {
    final d = a.day.compareTo(b.day);
    if (d != 0) return d;
    final p = prio(a).compareTo(prio(b));
    return p != 0 ? p : idx[a]!.compareTo(idx[b]!);
  });
  return list;
}
