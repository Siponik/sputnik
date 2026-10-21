// Шаблоны досок: колонки, вид по умолчанию и что показывать на карточке (docs/design-v2.md — «Шаблоны досок: редактор»).
// Встроенные — здесь, в коде. Правки встроенных — слой templatesEdit[id], свои шаблоны — слой templates[id]:
//   { name, view, fields, cols: [{ id, name, color, limit }] }.
// У колонки стабильный id — задача ссылается на него (слой tasks[id].status), переименование ничего не ломает.
// Последняя колонка всегда «готово»: задача в ней выполнена в Google Tasks. Её id — 'done'.
// Шаблон списка — слой lists[listId].template, вид списка (если поменяли) — lists[listId].view.

/** 7 цветов колонок (клик по точке в редакторе перебирает их). В шаблоне хранится номер. */
export const PALETTE = [
  { v: 'var(--ink-faint)', name: 'серый' },
  { v: 'var(--type-work)', name: 'синий' },
  { v: 'var(--clay)', name: 'глина' },
  { v: 'var(--gold)', name: 'золото' },
  { v: 'var(--type-study)', name: 'фиолетовый' },
  { v: 'var(--type-personal)', name: 'зелёный' },
  { v: 'var(--signal-done)', name: 'бирюзовый' },
];
export const colColor = (c) => PALETTE[c?.color ?? 0]?.v ?? PALETTE[0].v;

export const VIEWS = [
  { id: 'kanban', name: 'Канбан', hint: 'Колонки рядом, карточки перетаскиваются. Подходит, когда задач много и они быстро двигаются.' },
  { id: 'pipe', name: 'Конвейер', hint: 'Строка = задача, колонки — этапы по порядку. Для долгих задач с этапами: ассеты, большие заказы.' },
  { id: 'stickers', name: 'Стикеры', hint: 'Дела-стикеры по темам или по срокам, кружок — сделано. Для простых дел без этапов: покупки, звонки, дом.' },
  { id: 'list', name: 'Список', hint: 'Простой список с этапом в виде метки. Для курсов и дел, где этапов мало.' },
];

/** Что можно показать на карточке. */
export const FIELDS = [
  { id: 'due', name: 'Срок' }, { id: 'prio', name: 'Приоритет' }, { id: 'type', name: 'Тип' },
  { id: 'stage', name: 'Дорожка этапов' }, { id: 'subtasks', name: 'Подзадачи' }, { id: 'time', name: 'Учёт времени' },
  { id: 'progress', name: 'Прогресс (3 из 10)' }, { id: 'client', name: 'Клиент' }, { id: 'money', name: 'Сумма' },
];

const col = (id, name, color = 0, limit = 0) => ({ id, name, color, limit });

export const BUILTIN = [
  {
    id: 'work', name: 'Работа', title: 'Работа', hint: 'Задачи: входящие → в работе → ревью → готово',
    view: 'kanban', fields: ['due', 'prio', 'type'],
    cols: [col('inbox', 'Входящие', 0), col('doing', 'В работе', 2, 3), col('review', 'На ревью', 3), col('done', 'Готово', 6)],
  },
  {
    id: 'client', name: 'Заказы клиентов', title: 'Заказы', hint: 'Заявка → смета → работа → правки → сдано → оплачено',
    view: 'kanban', fields: ['due', 'prio', 'client', 'money'],
    cols: [col('request', 'Заявка', 0), col('estimate', 'Смета', 3), col('doing', 'В работе', 2, 2), col('revise', 'Правки', 4),
      col('delivered', 'Сдано', 1), col('done', 'Оплачено', 6)],
  },
  {
    id: 'asset3d', name: '3D-ассеты', title: '3D-проекты', hint: 'Каждая строка — модель, этапы пайплайна по порядку',
    view: 'pipe', fields: ['due', 'stage', 'subtasks', 'time'],
    cols: [col('refs', 'Референсы', 0), col('blockout', 'Блокаут', 1), col('sculpt', 'Скульпт', 4), col('retopo', 'Ретопология', 2),
      col('uv', 'UV', 3), col('textures', 'Текстуры', 5), col('render', 'Рендер', 3), col('done', 'Готово', 6)],
  },
  {
    id: 'personal', name: 'Личное', title: 'Личное', hint: 'Простые дела стикерами: по темам или по срокам',
    view: 'stickers', fields: ['due'],
    cols: [col('inbox', 'Надо сделать', 0), col('doing', 'Делаю', 2, 3), col('done', 'Готово', 6)],
  },
  {
    id: 'study', name: 'Учёба', title: 'Учёба', hint: 'Курсы и уроки: в планах → прохожу → пройдено',
    view: 'list', fields: ['due', 'progress'],
    cols: [col('inbox', 'В планах', 0), col('doing', 'Прохожу', 4, 2), col('done', 'Пройдено', 6)],
  },
];
export const isBuiltin = (id) => BUILTIN.some((t) => t.id === id);

/** Новый свой шаблон: «Надо → Делаю → Готово». */
export function blankTemplate(name = 'Свой шаблон') {
  return { name, view: 'kanban', fields: ['due', 'prio'], cols: [col('c' + Date.now().toString(36), 'Надо', 0), col('c' + (Date.now() + 1).toString(36), 'Делаю', 2), col('done', 'Готово', 6)] };
}

const clone = (t) => JSON.parse(JSON.stringify(t));
const pick = (t) => ({ name: t.name, view: t.view, fields: [...t.fields], cols: t.cols.map((c) => ({ ...c })) });

/** Все шаблоны с учётом слоя: встроенные (с правками) и свои. */
export function templatesFrom(lay) {
  const out = BUILTIN.map((b) => {
    const e = lay?.templatesEdit?.[b.id];
    return e && !e.removed ? { ...clone(b), ...pick({ ...b, ...e }), changed: true } : { ...clone(b), changed: false };
  });
  for (const [id, t] of Object.entries(lay?.templates ?? {})) {
    if (!t || t.removed || !t.cols?.length) continue;
    out.push({ id, title: t.name, hint: t.cols.map((c) => c.name).join(' → '), ...pick({ view: 'kanban', fields: [], ...t }), mine: true });
  }
  return out;
}

/** Шаблон по id (без слоя — только встроенные). Неизвестный — «Работа». */
export function templateOf(id, lay = null) {
  const all = templatesFrom(lay);
  return all.find((t) => t.id === id) ?? all[0];
}

/** Короткая метка шаблона для левой колонки. */
export const shortName = (t) => ({ work: 'работа', client: 'заказы', asset3d: '3D', personal: 'дела', study: 'учёба' }[t.id] ?? 'свой');

// Список привычек — особый: на доске его нет, он живёт на экране «Привычки».
export const HABITS = 'habits';
export const isHabitList = (list, lay) => lay.lists?.[list.id]?.template === HABITS || /(^|\s)привычки$/i.test(list.title ?? '');

// Выполненные задачи старше этого срока уходят с доски в архив.
export const ARCHIVE_AFTER_DAYS = 3;
export function isArchived(task) {
  if (task.status !== 'completed' || !task.completed) return false;
  return Date.now() - new Date(task.completed).getTime() > ARCHIVE_AFTER_DAYS * 864e5;
}

// Старое имя: список встроенных (для мест, где слой не нужен).
export const TEMPLATES = BUILTIN;
