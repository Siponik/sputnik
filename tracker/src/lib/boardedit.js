// Редактор доски — общий для шаблона и для списка (lib/BoardEditor.svelte, docs/design-v2.md — «Шаблон и список — раздельно»).
// Здесь — чистые правки черновика { view, fields, cols } и подписи; компонент только показывает и зовёт их.
import { PALETTE } from './templates.js';

/** Значки видов (линии 24×24, как в левой колонке). */
export const VIEW_ICONS = {
  kanban: '<rect x="4" y="4" width="5" height="16" rx="1"/><rect x="11" y="4" width="5" height="10" rx="1"/>',
  pipe: '<path d="M4 7h16M4 12h16M4 17h16"/>',
  stickers: '<rect x="4" y="4" width="7" height="7" rx="1"/><rect x="13" y="4" width="7" height="7" rx="1"/><rect x="4" y="13" width="7" height="7" rx="1"/>',
  list: '<path d="M5 6h14M5 12h14M5 18h9"/>',
};

/** Поля: где видно (card — на карточке, drawer — своё поле в окне задачи), что именно появится, значок. */
export const FIELD_INFO = [
  { id: 'due', name: 'Срок', group: 'card', what: 'чип «пт» / «сегодня»', icon: '<rect x="4" y="5" width="16" height="15" rx="2"/><path d="M4 10h16M9 3v4M15 3v4"/>' },
  { id: 'prio', name: 'Приоритет', group: 'card', what: '!!! слева от названия и полоска', icon: '<path d="M6 21V4h11l-2 4 2 4H6"/>' },
  { id: 'type', name: 'Тип', group: 'card', what: 'цвет полоски и чип «#работа»', icon: '<path d="M3 12V4h8l10 10-8 8z"/><circle cx="7.5" cy="8" r="1.3"/>' },
  { id: 'subtasks', name: 'Подзадачи', group: 'card', what: '«☑ 2 из 4» на карточке', icon: '<rect x="4" y="4" width="16" height="16" rx="3"/><path d="M8.5 12l2.5 2.5 4.5-5"/>' },
  { id: 'time', name: 'Учёт времени', group: 'card', what: '«⏱ 1 ч 15 мин», кнопка таймера', icon: '<circle cx="12" cy="13" r="7.5"/><path d="M12 9.5V13l2.5 1.5M10 3h4"/>' },
  { id: 'stage', name: 'Дорожка этапов', group: 'card', what: 'полоска этапов под названием', icon: '<path d="M3 12h4l2-5 4 10 2-5h6"/>' },
  { id: 'progress', name: 'Прогресс', group: 'card', what: '«3 из 10 уроков» — для учёбы', icon: '<path d="M5 19V14M10 19V10M15 19V12M20 19V6"/>' },
  { id: 'client', name: 'Клиент', group: 'drawer', what: 'поле в окне задачи + на карточке', icon: '<circle cx="12" cy="8" r="3.5"/><path d="M5 20c1-4 4-6 7-6s6 2 7 6"/>' },
  { id: 'money', name: 'Сумма', group: 'drawer', what: 'поле в окне задачи, итог колонки', icon: '<path d="M8 20V4h6a4 4 0 0 1 0 8H6M6 16h8"/>' },
];
export const fieldInfo = (id) => FIELD_INFO.find((f) => f.id === id);

/** Копия для редактирования. */
export const draftOf = (b) => ({ view: b.view, fields: [...(b.fields ?? [])], cols: b.cols.map((c) => ({ id: c.id, name: c.name, color: c.color ?? 0, limit: c.limit ?? 0 })) });

/** Переставить колонку from на место to. «Готово» (последняя) не двигается, и ничего не встаёт после неё. */
export function moveCol(cols, from, to) {
  const end = cols.length - 1;
  if (from === end || from < 0 || from > end) return cols;
  const t = Math.max(0, Math.min(end - 1, to));
  if (t === from) return cols;
  const out = [...cols];
  const [c] = out.splice(from, 1);
  out.splice(t, 0, c);
  return out;
}

export const recolor = (c) => ({ ...c, color: ((c.color ?? 0) + 1) % PALETTE.length });
export const relimit = (c, d) => ({ ...c, limit: Math.max(0, Math.min(20, (c.limit ?? 0) + d)) });
export const newCol = (now = Date.now()) => ({ id: 'c' + now.toString(36), name: 'Новая колонка', color: 0, limit: 0 });

/** Удалить колонку i: задачи уедут в соседнюю (левую, у первой — правую). removed — уже удалённые [{ id, name, to, toName, n }]:
 *  если туда уже ехали задачи, теперь они едут дальше. null — удалять нельзя («Готово» или останется меньше двух). */
export function dropCol(cols, i, removed = [], n = 0) {
  const end = cols.length - 1;
  if (cols.length <= 2 || i === end || i < 0) return null;
  const c = cols[i], to = cols[i > 0 ? i - 1 : i + 1];
  return {
    cols: cols.filter((_, k) => k !== i),
    removed: removed.map((r) => (r.to === c.id ? { ...r, to: to.id, toName: to.name } : r)).concat([{ id: c.id, name: c.name, to: to.id, toName: to.name, n }]),
  };
}

export const toggleField = (fields, f) => (fields.includes(f) ? fields.filter((x) => x !== f) : [...fields, f]);

/** «4 задачи», «1 задача», «0 задач». */
export function tasksWord(n) {
  const a = n % 10, b = n % 100;
  return `${n} ${a === 1 && b !== 11 ? 'задача' : a >= 2 && a <= 4 && (b < 12 || b > 14) ? 'задачи' : 'задач'}`;
}
/** «3 списка», «1 список», «5 списков». */
export function listsWord(n) {
  const a = n % 10, b = n % 100;
  return `${n} ${a === 1 && b !== 11 ? 'список' : a >= 2 && a <= 4 && (b < 12 || b > 14) ? 'списка' : 'списков'}`;
}

/** Своя ли колонка у списка: новая или переименованная по сравнению с шаблоном. */
export function colIsOwn(c, baseCols = []) {
  const b = baseCols.find((x) => x.id === c.id);
  return !b || String(b.name).trim() !== String(c.name).trim();
}

/** Что поменялось в черновике против исходного — короткими словами, для строки «изменения: …». */
export function changes(from, draft) {
  const out = [];
  const ids = new Set(from.cols.map((c) => c.id));
  const added = draft.cols.filter((c) => !ids.has(c.id));
  const gone = from.cols.filter((c) => !draft.cols.some((x) => x.id === c.id));
  for (const c of added) out.push(`колонка «${c.name}»`);
  for (const c of gone) out.push(`убрана «${c.name}»`);
  const renamed = draft.cols.filter((c) => ids.has(c.id) && from.cols.find((x) => x.id === c.id).name !== c.name);
  for (const c of renamed) out.push(`«${c.name}»`);
  const kept = draft.cols.filter((c) => ids.has(c.id)).map((c) => c.id), was = from.cols.filter((c) => kept.includes(c.id)).map((c) => c.id);
  if (kept.join() !== was.join()) out.push('порядок колонок');
  if (draft.cols.some((c) => { const o = from.cols.find((x) => x.id === c.id); return o && ((o.color ?? 0) !== (c.color ?? 0) || (o.limit ?? 0) !== (c.limit ?? 0)); })) out.push('цвет или лимит');
  if ([...from.fields].sort().join() !== [...draft.fields].sort().join()) out.push('поля');
  if (from.view !== draft.view) out.push('вид');
  return out;
}

/** Задача для превью карточки: открытая, и у которой видно побольше полей; нет задач — null (тогда пример). */
export function sampleTask(tasks = [], layTasks = {}, subsOf = () => []) {
  const open = tasks.filter((t) => !t.parent && t.status !== 'completed');
  const score = (t) => { const L = layTasks?.[t.id] ?? {}; return (t.due ? 2 : 0) + (L.priority ? 2 : 0) + (L.type ? 1 : 0) + (subsOf(t.id).length ? 2 : 0) + (L.spent ? 1 : 0) + (L.client ? 1 : 0); };
  return open.reduce((best, t) => (!best || score(t) > score(best) ? t : best), null);
}

/** Сколько задач в мини-колонке превью: настоящие, а у пустого шаблона — немного для вида. */
export const previewCount = (n, i, total) => Math.min(3, n ?? (i === 0 ? 3 : i === total - 1 ? 2 : 1));
