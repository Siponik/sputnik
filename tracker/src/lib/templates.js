// Шаблоны списков: какие колонки у доски. Шаблон списка хранится в слое: lists[listId].template.
// Последняя колонка всегда done — задача в ней выполнена в Google Tasks.

export const TEMPLATES = [
  {
    id: 'work',
    name: 'Работа',
    hint: 'Задачи и заказы: входящие → в работе → ревью → готово',
    title: 'Работа',
    cols: [
      { id: 'inbox', name: 'Входящие' },
      { id: 'doing', name: 'В работе' },
      { id: 'review', name: 'На ревью' },
      { id: 'done', name: 'Готово' },
    ],
  },
  {
    id: 'asset3d',
    name: '3D-ассеты',
    hint: 'Каждая карточка — модель, колонки — этапы пайплайна',
    title: '3D-проекты',
    cols: [
      { id: 'refs', name: 'Референсы' },
      { id: 'blockout', name: 'Блокаут' },
      { id: 'sculpt', name: 'Скульпт' },
      { id: 'retopo', name: 'Ретопология' },
      { id: 'uv', name: 'UV' },
      { id: 'textures', name: 'Текстуры' },
      { id: 'render', name: 'Рендер' },
      { id: 'done', name: 'Готово' },
    ],
  },
  {
    id: 'personal',
    name: 'Личное',
    hint: 'Простой список дел: надо → делаю → готово',
    title: 'Личное',
    cols: [
      { id: 'inbox', name: 'Надо сделать' },
      { id: 'doing', name: 'Делаю' },
      { id: 'done', name: 'Готово' },
    ],
  },
  {
    id: 'study',
    name: 'Учёба',
    hint: 'Курсы и уроки: в планах → прохожу → пройдено',
    title: 'Учёба',
    cols: [
      { id: 'inbox', name: 'В планах' },
      { id: 'doing', name: 'Прохожу' },
      { id: 'done', name: 'Пройдено' },
    ],
  },
];

export const templateOf = (id) => TEMPLATES.find((t) => t.id === id) ?? TEMPLATES[0];

// Список привычек — особый: на доске его нет, он живёт на экране «Привычки».
export const HABITS = 'habits';
export const isHabitList = (list, lay) => lay.lists?.[list.id]?.template === HABITS || /(^|\s)привычки$/i.test(list.title ?? '');

// Выполненные задачи старше этого срока уходят с доски в архив.
export const ARCHIVE_AFTER_DAYS = 3;
export function isArchived(task) {
  if (task.status !== 'completed' || !task.completed) return false;
  return Date.now() - new Date(task.completed).getTime() > ARCHIVE_AFTER_DAYS * 864e5;
}
