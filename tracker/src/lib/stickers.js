// Вид «Стикеры» для простых дел без этапов (docs/design-v2.md — «Простые дела: вид «Стикеры»»).
// Чистая логика без Svelte: раскладка по темам и по срокам, порядок в колонке, срок при переносе, наклон стикера.
// Даты — строки 'ГГГГ-ММ-ДД' (как api.ymd), today передаётся снаружи, чтобы тесты не зависели от часов.
// Слой: lists[id].topics = [{ id, name, color }] (цвет — id из палитры сфер), lists[id].group = 'topic' | 'when',
// tasks[id].topic, tasks[id].pin.
import { SPHERE_COLORS } from './spheres.js';
import { parseWhen } from './when.js';
import { takeRepeat } from './repeat.js';

/** Темы нового списка со стикерами. */
export const DEFAULT_TOPICS = [
  { id: 'docs', name: 'Документы', color: 'clay' },
  { id: 'buy', name: 'Покупки', color: 'gold' },
  { id: 'call', name: 'Звонки', color: 'work' },
  { id: 'health', name: 'Здоровье', color: 'study' },
  { id: 'home', name: 'Дом', color: 'personal' },
];
/** Дела без темы (или с удалённой темой). */
export const MISC = { id: '', name: 'Разное', c: 'var(--ink-faint)' };

export const topicsOf = (layList) => (Array.isArray(layList?.topics) ? layList.topics : DEFAULT_TOPICS);
export const topicColor = (t) => (t ? (SPHERE_COLORS.find((c) => c.id === t.color) ?? SPHERE_COLORS[0]).v : MISC.c);

// ---------- даты ----------

const parse = (s) => { const [y, m, d] = s.split('-').map(Number); return new Date(y, m - 1, d); };
const fmt = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
export const plusDays = (s, n) => { const d = parse(s); d.setDate(d.getDate() + n); return fmt(d); };
const isSunday = (s) => parse(s).getDay() === 0;
const diff = (a, b) => Math.round((parse(a) - parse(b)) / 864e5);

/** Конец «На неделе»: воскресенье этой недели; в воскресенье — следующее. */
export const weekEnd = (today) => (isSunday(today) ? plusDays(today, 7) : plusDays(today, 7 - parse(today).getDay()));

/** Колонка «по срокам»: today (сегодня и просроченное) | week (завтра … воскресенье) | later (без срока и позже). */
export function bucket(due, today) {
  if (!due) return 'later';
  if (due <= today) return 'today';
  return due <= weekEnd(today) ? 'week' : 'later';
}

export const WHEN = [
  { id: 'today', name: 'Сегодня', c: 'var(--clay)' },
  { id: 'week', name: 'На неделе', c: 'var(--ink-faint)', sub: 'до воскресенья' },
  { id: 'later', name: 'Когда-нибудь', c: 'var(--ink-faint)', sub: 'без срока или позже' },
];

/** Новый срок при переносе в колонку «по срокам» (null — без срока). Срок уже подходит — не трогаем. */
export function whenDue(target, cur, today) {
  if (target === 'today') return today;
  if (target === 'later') return null;
  if (cur && bucket(cur, today) === 'week') return cur;
  return isSunday(today) ? weekEnd(today) : plusDays(today, 1);
}
/** Срок нового стикера в колонке «по срокам»: сегодня / завтра / без срока. */
export const newDue = (target, today) => (target === 'today' ? today : target === 'week' ? plusDays(today, 1) : null);

const WD = ['вс', 'пн', 'вт', 'ср', 'чт', 'пт', 'сб'];
const MON = ['янв.', 'февр.', 'мар.', 'апр.', 'мая', 'июн.', 'июл.', 'авг.', 'сент.', 'окт.', 'нояб.', 'дек.'];
const MON_GEN = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
const short = (s) => { const d = parse(s); return `${d.getDate()} ${MON[d.getMonth()]}`; };

/** Подпись срока внизу стикера: { text, cls: 'late' | 'soon' | '' }. hideToday — в колонке «Сегодня» без времени не пишем. */
export function dueLabel(due, today, slot = null, hideToday = false) {
  if (!due) return { text: '', cls: '' };
  const n = diff(due, today);
  if (n < 0) return { text: `просрочено · ${n === -1 ? 'вчера' : short(due)}`, cls: 'late' };
  const at = slot?.s ? `, ${slot.s}` : '';
  if (n === 0) return { text: hideToday && !at ? '' : `сегодня${at}`, cls: 'soon' };
  if (n === 1) return { text: `завтра${at}`, cls: '' };
  if (due <= weekEnd(today)) return { text: WD[parse(due).getDay()] + at, cls: '' };
  return { text: short(due) + at, cls: '' };
}
/** Подпись колонки «Сегодня»: «ср, 21 октября · и просроченное». */
export function todaySub(today) {
  const d = parse(today);
  return `${WD[d.getDay()]}, ${d.getDate()} ${MON_GEN[d.getMonth()]} · и просроченное`;
}

// ---------- порядок и раскладка ----------

/**
 * Порядок внутри колонки. sort = 'pin' — закреплённые, потом свой порядок ord;
 * sort = 'due' — закреплённые → просроченные → с ближайшим сроком → свой порядок.
 * Без ord — после упорядоченных, по порядку Google (position).
 */
export function order(items, layTasks, today, sort = 'pin') {
  const L = (t) => layTasks?.[t.id] ?? {};
  const due = (t) => (t.due ? t.due.slice(0, 10) : '');
  const ord = (t) => (typeof L(t).ord === 'number' ? L(t).ord : Infinity);
  const byOrd = (a, b) => (ord(a) - ord(b) || 0) || (a.position || '').localeCompare(b.position || '');
  return [...items].sort((a, b) => {
    const p = (L(b).pin ? 1 : 0) - (L(a).pin ? 1 : 0);
    if (p) return p;
    if (sort === 'due') {
      const la = due(a) && due(a) < today ? 0 : 1, lb = due(b) && due(b) < today ? 0 : 1;
      if (la !== lb) return la - lb;
      const da = due(a) || '9999', db = due(b) || '9999';
      if (da !== db) return da < db ? -1 : 1;
    }
    return byOrd(a, b);
  });
}

/**
 * Колонки стены. tasks — открытые задачи верхнего уровня. group — 'topic' | 'when'.
 * Возвращает [{ id, name, c, sub, items }]; «Разное» — только если в нём что-то есть.
 */
export function lanes(tasks, { group = 'topic', topics = DEFAULT_TOPICS, layTasks = {}, today, sort = 'pin', people = [], me = '' }) {
  if (group === 'people') return peopleLanes(tasks, { layTasks, today, sort, people, me });
  if (group === 'when') {
    return WHEN.map((w) => ({
      ...w, sub: w.id === 'today' ? todaySub(today) : w.sub,
      items: order(tasks.filter((t) => bucket(t.due ? t.due.slice(0, 10) : '', today) === w.id), layTasks, today, 'due'),
    }));
  }
  const known = new Set(topics.map((t) => t.id));
  const topicId = (t) => (known.has(layTasks?.[t.id]?.topic) ? layTasks[t.id].topic : '');
  const out = topics.map((tp) => ({ id: tp.id, name: tp.name, c: topicColor(tp), sub: '', items: order(tasks.filter((t) => topicId(t) === tp.id), layTasks, today, sort) }));
  const misc = tasks.filter((t) => topicId(t) === '');
  if (misc.length) out.push({ ...MISC, sub: '', items: order(misc, layTasks, today, sort) });
  return out;
}

/**
 * «По людям» (общая сфера): колонка = человек — «Я» первым, потом принявшие приглашение, «Ничьи» последней.
 * Не принявший получает колонку, только если ему уже что-то отдали. id колонки — почта, у «Ничьих» — ''.
 */
export function peopleLanes(tasks, { layTasks = {}, today, sort = 'pin', people = [], me = '' }) {
  const whoOf = (t) => layTasks?.[t.id]?.who || '';
  const ppl = [...people.filter((p) => p.email === me), ...people.filter((p) => p.email !== me)];
  const out = [];
  for (const p of ppl) {
    const items = tasks.filter((t) => whoOf(t) === p.email);
    if (!p.joined && !items.length) continue;
    out.push({ id: p.email, name: p.email === me ? 'Я' : p.name, c: p.color, m: p, sub: '', items: order(items, layTasks, today, sort) });
  }
  const known = new Set(out.map((l) => l.id));
  // Отдано тому, кого уже нет в сфере, — тоже в «Ничьи»: иначе стикер пропал бы со стены.
  const none = tasks.filter((t) => !whoOf(t) || !known.has(whoOf(t)));
  out.push({ id: '', name: 'Ничьи', c: 'var(--ink-faint)', m: null, sub: '', items: order(none, layTasks, today, sort) });
  return out;
}

/**
 * Какие колонки показать. По темам пустые темы прячутся (кроме keep — туда сейчас пишут новый стикер);
 * если пусто везде — показываем все, чтобы было куда приклеить первый. По срокам — всегда три.
 * Возвращает { shown, hidden } — hidden идут кнопками «＋ в тему».
 */
/** Следующая раскладка: to — нужная (строка), иначе по кругу «темы → сроки (→ люди)».
 *  Кнопка-переключатель зовёт с событием клика — его не принимаем за раскладку. */
export function nextGroup(cur, to, shared = false) {
  const all = shared ? ['topic', 'when', 'people'] : ['topic', 'when'];
  if (typeof to === 'string' && all.includes(to)) return to;
  return all[(all.indexOf(cur) + 1) % all.length];
}

export function visibleLanes(all, { group = 'topic', keep = null } = {}) {
  if (group === 'when' || group === 'people' || all.every((l) => !l.items.length)) return { shown: all, hidden: [] };
  const vis = (l) => l.items.length > 0 || (keep != null && l.id === keep);
  return { shown: all.filter(vis), hidden: all.filter((l) => !vis(l)) };
}

/** Тема задачи из списка тем (или null — «Разное»). */
export const topicOfTask = (task, layTasks, topics) => topics.find((t) => t.id === layTasks?.[task.id]?.topic) ?? null;

// ---------- стикер ----------

/** Наклон стикера −1,5°…+1,5°, постоянный для задачи (хэш id). */
export function tilt(id) {
  let h = 2166136261;
  for (const ch of String(id)) { h ^= ch.codePointAt(0); h = Math.imul(h, 16777619); }
  return Math.round(((h >>> 0) % 31) - 15) / 10;
}

/** Сделано за последние 7 дней — число в «баночке». */
export function jarCount(tasks, now = Date.now()) {
  return tasks.filter((t) => !t.parent && t.status === 'completed' && t.completed && now - new Date(t.completed).getTime() <= 7 * 864e5).length;
}

/**
 * Текст нового стикера: «купить батарейки #покуп в пятницу 17:00 !!!» →
 * { title, topic, day, time, priority, repeat }. #тема — по началу названия темы, без регистра.
 */
export function parseSticker(raw, topics = DEFAULT_TOPICS, today = new Date()) {
  let txt = ` ${raw} `;
  let priority = null;
  const pm = txt.match(/\s(!{1,3})(?=\s)/);
  if (pm) { priority = 4 - pm[1].length; txt = txt.replace(pm[0], ' '); }
  let topic = null;
  const tg = txt.match(/(^|\s)#([^\s#]+)/);
  if (tg) {
    const k = tg[2].toLowerCase().replace(/ё/g, 'е');
    const hit = topics.find((t) => t.name.toLowerCase().replace(/ё/g, 'е').startsWith(k));
    if (hit) { topic = hit.id; txt = txt.replace(tg[0], ' '); }
  }
  const rp = takeRepeat(txt);
  const w = parseWhen(rp.rest, today);
  const t = w.rest.trim();
  return { title: t && t[0].toUpperCase() + t.slice(1), topic, day: w.day, time: w.time, priority, repeat: rp.rule };
}
