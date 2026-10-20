// Тип и приоритет задачи — поля слоя Спутника (tasks[id].type, tasks[id].priority), в Google Tasks их нет.

// Тип: цвет и подпись. Подписи — латиницей строчными, как теги в строке «Сегодня» (#work, #asset…).
// Без своего типа задача берёт цвет по шаблону списка.
export const TYPES = [
  { id: 'work', label: 'work' },
  { id: 'creative', label: 'asset' },
  { id: 'study', label: 'study' },
  { id: 'personal', label: 'personal' },
];
export const typeLabel = (id) => TYPES.find((t) => t.id === id)?.label ?? '';

// Приоритет 1–3, как в навыке sputnik-tasks: 1 — высокий, 3 — низкий; нет поля — без приоритета.
export const PRIORITIES = [
  { id: 1, label: 'Высокий', mark: '!!!', cls: 'p1' },
  { id: 2, label: 'Средний', mark: '!!', cls: 'p2' },
  { id: 3, label: 'Низкий', mark: '!', cls: 'p3' },
];
export const priorityOf = (n) => PRIORITIES.find((p) => p.id === n) ?? null;
/** Для сортировки: высокий выше, без приоритета — после среднего, но перед низким. */
export const priorityRank = (n) => (n === 1 ? 0 : n === 2 ? 1 : n === 3 ? 3 : 2);

/** С чего начать (совет енота): сначала просроченное, потом по приоритету, потом по сроку, потом по порядку в списке.
 *  items: [{ task, ... }]; layTasks — слой. Возвращает первый элемент или null. */
export function pickNext(items, layTasks, today) {
  const due = (t) => (t.due ? t.due.slice(0, 10) : '9999');
  const late = (t) => (t.due && due(t) < today ? 0 : 1);
  return items.slice().sort((a, b) => late(a.task) - late(b.task)
    || priorityRank(layTasks?.[a.task.id]?.priority) - priorityRank(layTasks?.[b.task.id]?.priority)
    || due(a.task).localeCompare(due(b.task))
    || (a.task.position || '').localeCompare(b.task.position || ''))[0] ?? null;
}

/** Почему енот советует именно её: «просрочено», «высокий приоритет», «срок завтра»… */
export function nextReason(task, layTasks, today, humanDue) {
  if (task.due && task.due.slice(0, 10) < today) return `просрочено с ${humanDue(task.due).replace(/^\S+, /, '')}`;
  const p = priorityOf(layTasks?.[task.id]?.priority);
  if (p && p.id < 3) return `${p.label.toLowerCase()} приоритет${task.due ? `, срок ${humanDue(task.due)}` : ''}`;
  return task.due ? `срок ${humanDue(task.due)}` : '';
}

/** Поле заметки растёт вместе с текстом (до 60% высоты окна), потом прокручивается. */
export function autosize(el) {
  const fit = () => { el.style.height = 'auto'; el.style.height = `${Math.min(el.scrollHeight + 2, window.innerHeight * 0.6)}px`; };
  fit();
  el.addEventListener('input', fit);
  window.addEventListener('resize', fit);
  return { update: fit, destroy() { el.removeEventListener('input', fit); window.removeEventListener('resize', fit); } };
}
