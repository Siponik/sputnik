// Дубли задач — открытые задачи одного списка с тем же названием и сроком. Появлялись, когда два компьютера
// оба продолжали выполненную повторяющуюся задачу (до 0.6.65). Найти — здесь, удалить — только после подтверждения
// (Настройки → Синхронизация → «Дубли задач»).

const key = (t) => `${(t.title ?? '').trim().toLowerCase()}|${(t.due ?? '').slice(0, 10)}`;
// Какую копию оставить: ту, у которой больше полей в слое (тема, приоритет…), при равенстве — первую по id.
const weight = (t, layTasks) => Object.keys(layTasks?.[t.id] ?? {}).filter((k) => k !== 't').length;

/**
 * Группы дублей: [{ listId, listName, title, due, keep, extra: [task] }].
 * tasks — { listId: [задачи] }, lists — [{ id, title }]. Подзадачи, выполненные и без названия не трогаем.
 */
export function findDupes(tasks, lists, layTasks = {}) {
  const out = [];
  for (const l of lists) {
    const groups = new Map();
    for (const t of tasks[l.id] ?? []) {
      if (t.parent || t.deleted || t.status === 'completed' || !(t.title ?? '').trim()) continue;
      const k = key(t);
      groups.set(k, [...(groups.get(k) ?? []), t]);
    }
    for (const g of groups.values()) {
      if (g.length < 2) continue;
      const sorted = [...g].sort((a, b) => weight(b, layTasks) - weight(a, layTasks) || (a.id < b.id ? -1 : 1));
      out.push({ listId: l.id, listName: l.title, title: sorted[0].title, due: (sorted[0].due ?? '').slice(0, 10), keep: sorted[0], extra: sorted.slice(1) });
    }
  }
  return out;
}
