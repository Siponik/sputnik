// Тип и приоритет задачи — поля слоя Спутника (tasks[id].type, tasks[id].priority), в Google Tasks их нет.

// Тип: цвет и подпись. Без своего типа задача берёт цвет по шаблону списка.
export const TYPES = [
  { id: 'work', label: 'Работа' },
  { id: 'creative', label: 'Ассет' },
  { id: 'study', label: 'Учёба' },
  { id: 'personal', label: 'Личное' },
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

/** Поле заметки растёт вместе с текстом (до 60% высоты окна), потом прокручивается. */
export function autosize(el) {
  const fit = () => { el.style.height = 'auto'; el.style.height = `${Math.min(el.scrollHeight + 2, window.innerHeight * 0.6)}px`; };
  fit();
  el.addEventListener('input', fit);
  window.addEventListener('resize', fit);
  return { update: fit, destroy() { el.removeEventListener('input', fit); window.removeEventListener('resize', fit); } };
}
