// Шаблоны досок: колонки, вид по умолчанию и что показывать на карточке (docs/design-v2.md — «Шаблоны досок: редактор»).
// Встроенные — здесь, в коде. Правки встроенных — слой templatesEdit[id], свои шаблоны — слой templates[id]:
//   { name, view, fields, cols: [{ id, name, color, limit }] }.
// У колонки стабильный id — задача ссылается на него (слой tasks[id].status), переименование ничего не ломает.
// Последняя колонка всегда «готово»: задача в ней выполнена в Google Tasks. Её id — 'done'.
// Шаблон списка — слой lists[listId].template, вид списка (если поменяли) — lists[listId].view.
// Шаблон и список — раздельно (docs/design-v2.md, 28.10): у списка может быть своя копия колонок и полей —
// lists[listId].cols / lists[listId].fields. Есть копия — список «своё», правки шаблона до него не доходят.
// Нет — список идёт за шаблоном. Доску списка собирает boardOf, а не templateOf.

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

// ---------- доска списка: шаблон + своя копия ----------

const okCols = (c) => Array.isArray(c) && c.length >= 2 && c[c.length - 1]?.id === 'done';

/** Своё ли у списка (колонки или поля отвязаны от шаблона). */
export const isOwn = (L) => okCols(L?.cols) || Array.isArray(L?.fields);

/** Доска списка: шаблон с наложенной копией списка (cols / fields / view).
 *  id и name — шаблона (по ним считают «Используется»), own — список отвязан от шаблона, base — сам шаблон. */
export function boardOf(listId, lay) {
  const L = lay?.lists?.[listId] ?? {};
  const base = templateOf(L.template, lay);
  const cols = okCols(L.cols) ? L.cols.map((c) => ({ ...c })) : base.cols;
  const fields = Array.isArray(L.fields) ? [...L.fields] : base.fields;
  return { ...base, view: L.view ?? base.view ?? 'kanban', cols, fields, own: isOwn(L), base };
}

/** Идёт ли список за шаблоном tid (без своей копии) — его меняет правка шаблона. */
export const follows = (listId, lay, tid) => boardOf(listId, lay).id === tid && !isOwn(lay?.lists?.[listId]);

/** Что записать в lists[id], чтобы сохранить доску «только для этого списка». */
export const ownPatch = (draft) => ({
  view: draft.view,
  fields: [...draft.fields],
  cols: draft.cols.map(({ id, name, color, limit }) => ({ id, name: String(name ?? '').trim() || 'Без названия', color: color ?? 0, limit: limit ?? 0 })),
});

/** «Вернуть как в шаблоне»: убрать свою копию. null, а не undefined — иначе другой компьютер не узнает, что поле стёрли. */
export const resetPatch = () => ({ cols: null, fields: null, view: null });

const norm = (s) => String(s ?? '').trim().toLowerCase().replace(/ё/g, 'е');

/** Куда переедут задачи при смене колонок: { старый id: новый id } для каждой старой колонки.
 *  Сначала по названию, потом тот же id, иначе по порядку; «готово» — всегда в последнюю. */
export function matchCols(oldCols, newCols) {
  const last = newCols.length - 1, out = {};
  const byName = new Map(newCols.map((c) => [norm(c.name), c.id]));
  oldCols.forEach((c, i) => {
    if (c.id === 'done') { out[c.id] = newCols[last].id; return; }
    const n = byName.get(norm(c.name));
    if (n && n !== 'done') out[c.id] = n;
    else if (newCols.some((x) => x.id === c.id && x.id !== 'done')) out[c.id] = c.id;
    else out[c.id] = newCols[Math.min(i, Math.max(0, last - 1))].id;
  });
  return out;
}

/** Перенос задач из исчезающих колонок: moves { старый id: новый id } (цепочки тоже — a → b → c).
 *  Возвращает правки [{ id, status }] для слоя; задачи без своей колонки (в первой) и уже на месте не трогает. */
export function relocate(taskList, layTasks, moves) {
  const out = [];
  for (const t of taskList ?? []) {
    const from = layTasks?.[t.id]?.status;
    if (!from || moves[from] === undefined || moves[from] === from) continue;
    let s = from, guard = 0;
    while (moves[s] !== undefined && moves[s] !== s && guard++ < 20) s = moves[s];
    if (s !== from) out.push({ id: t.id, status: s });
  }
  return out;
}

/** Колонки, которые пропадут при переходе oldCols → newCols, — с их задачами (для relocate). */
export function lostMoves(oldCols, newCols) {
  const keep = new Set(newCols.map((c) => c.id)), m = matchCols(oldCols, newCols), out = {};
  for (const c of oldCols) if (!keep.has(c.id)) out[c.id] = m[c.id];
  return out;
}

/** Сохранить доску «только для этого списка»: правка слоя списка и переезды задач из пропавших колонок.
 *  removed — [{ id, to }] из редактора (куда человек сам отправил задачи удалённой колонки), главнее авто-сопоставления. */
export function saveListPlan(lay, listId, draft, taskList, removed = []) {
  const cur = boardOf(listId, lay);
  const moves = { ...lostMoves(cur.cols, draft.cols), ...Object.fromEntries(removed.map((r) => [r.id, r.to])) };
  return { patch: ownPatch(draft), moves: relocate(taskList, lay?.tasks, moves) };
}

/** «Вернуть как в шаблоне»: убрать свою копию, задачи из своих колонок — в колонки шаблона. */
export function resetListPlan(lay, listId, taskList) {
  const cur = boardOf(listId, lay);
  return { patch: resetPatch(), moves: relocate(taskList, lay?.tasks, lostMoves(cur.cols, cur.base.cols)) };
}

// Выполненные задачи старше этого срока уходят с доски в архив. У списка можно поменять: lists[id].archive — 0 | 3 | 7.
export const ARCHIVE_AFTER_DAYS = 3;
export const ARCHIVE_CHOICES = [0, 3, 7];
export const archiveDays = (L) => (ARCHIVE_CHOICES.includes(L?.archive) ? L.archive : ARCHIVE_AFTER_DAYS);
export function isArchived(task, days = ARCHIVE_AFTER_DAYS, now = Date.now()) {
  if (task.status !== 'completed' || !task.completed) return false;
  return now - new Date(task.completed).getTime() > days * 864e5;
}

// Старое имя: список встроенных (для мест, где слой не нужен).
export const TEMPLATES = BUILTIN;
