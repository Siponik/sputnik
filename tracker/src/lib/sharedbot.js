// Общий Telegram-бот Спутника (сервер — bot/ в этом репозитории, Cloudflare Workers).
// Привязка: человек пишет боту /start, вводит код в «Настройках» → link(). Ключ — в слое settings.tgbot.key,
// поэтому второй компьютер подхватывает привязку сам. Ключей Google сервер не получает:
//   push()  — напоминания (те же пункты, что в файле для личного бота) и задачи на неделю для /today и /week;
//   inbox() — что человек написал боту (новые задачи, «✓ Готово»), трекер сам делает это в Google и шлёт ack().

import { parseLine, route } from './route.js';
import { taskFrom } from './today.js';

export const BOT_URL = 'https://sputnik-bot.siponikdev.workers.dev';
export const BOT_NAME = 'SputnikTasksBot';
export const BOT_LINK = `https://t.me/${BOT_NAME}`;

export function newKey() {
  const b = new Uint8Array(32);
  crypto.getRandomValues(b);
  return [...b].map((x) => x.toString(16).padStart(2, '0')).join('');
}

async function call(path, { method = 'GET', key = '', body } = {}) {
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), 15000);
  try {
    const r = await fetch(BOT_URL + path, {
      method,
      signal: ctl.signal,
      headers: { ...(key ? { Authorization: `Bearer ${key}` } : {}), ...(body ? { 'Content-Type': 'application/json' } : {}) },
      ...(body ? { body: JSON.stringify(body) } : {}),
    });
    const data = await r.json().catch(() => ({}));
    if (!r.ok) { const e = new Error(data.error || `Бот ответил ${r.status}`); e.unlinked = !!data.unlinked; throw e; }
    return data;
  } catch (e) {
    if (e.name === 'AbortError') throw new Error('Бот не отвечает — проверь интернет');
    throw e;
  } finally { clearTimeout(timer); }
}

const tz = () => Intl.DateTimeFormat().resolvedOptions().timeZone || 'Europe/Moscow';

export const link = (code, key) => call('/link', { method: 'POST', body: { code: String(code).replace(/\D/g, ''), key, tz: tz() } });
export const test = (key) => call('/test', { method: 'POST', key });
export const unlink = (key) => call('/unlink', { method: 'POST', key });
export const inbox = (key) => call('/inbox', { key });
export const ack = (key, ids) => call('/ack', { method: 'POST', key, body: { ids } });

let lastBody = '';
/** Напоминания и задачи на неделю — на сервер, если что-то поменялось. Возвращает true, если отправил.
 *  guess — списки, основной и выученные слова для черновиков в боте (guessCtx). */
export async function push(key, items, today, guess = {}) {
  const body = { items, today, tz: tz(), ...guess };
  const text = JSON.stringify(body);
  if (text === lastBody) return false;
  await call('/state', { method: 'PUT', key, body });
  lastBody = text;
  return true;
}
export const forget = () => { lastBody = ''; };

const ymd = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

/** Открытые задачи со сроком до +7 дней (и просроченные) — для /today и /week в боте. */
export function snapshot(lists, tasksByList, layTasks = {}, now = new Date()) {
  const end = ymd(new Date(now.getFullYear(), now.getMonth(), now.getDate() + 7));
  const out = [];
  for (const l of lists) {
    for (const t of tasksByList[l.id] ?? []) {
      if (t.status === 'completed' || t.deleted || t.parent || !t.due) continue;
      const due = t.due.slice(0, 10);
      if (due > end) continue;
      out.push({ title: t.title || 'Без названия', due, ...(layTasks[t.id]?.slot?.s ? { time: layTasks[t.id].slot.s } : {}), list: l.title });
    }
  }
  return out.sort((a, b) => a.due.localeCompare(b.due) || (a.time ?? '99').localeCompare(b.time ?? '99')).slice(0, 300);
}

/** Для догадки в боте: списки, основной (первый) и выученные слова settings.route → { основа: listId }. */
export function guessCtx(lists, layer) {
  const ids = new Set(lists.map((l) => l.id));
  const words = Object.entries(layer?.settings?.route ?? {})
    .filter(([, e]) => e && typeof e === 'object' && ids.has(e.list))
    .sort((a, b) => (b[1].n ?? 1) - (a[1].n ?? 1)).slice(0, 300)
    .map(([w, e]) => [w, e.list]);
  return { lists: lists.slice(0, 100).map((l) => ({ id: l.id, title: l.title || 'Без названия' })), def: lists[0]?.id ?? null, words: Object.fromEntries(words) };
}

/** Карточка из бота (поля уже выбраны человеком) → задача для quickCreate. Тип и повтор — из исходного текста.
 *  rem: null — напоминание по умолчанию, 'off' — без него, число — за N минут до начала. */
export function fromDraft(x, { lists, layer, tasks, today = new Date() }) {
  const base = x.src ? fromText(x.src, { lists, layer, tasks, today }) : null;
  const listId = lists.some((l) => l.id === x.listId) ? x.listId : base?.listId ?? fromText(x.title ?? '', { lists, layer, tasks, today })?.listId;
  if (!listId || !x.title) return null;
  const hm = /^([01]\d|2[0-3]):[0-5]\d$/;
  const plus = (t) => { const m = Math.min(1439, +t.slice(0, 2) * 60 + +t.slice(3) + 60); return `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`; };
  const layer2 = { ...(base?.layer ?? {}) };
  delete layer2.topic; delete layer2.project; // они — для списка, который угадал трекер
  if ([1, 2, 3].includes(x.prio)) layer2.priority = x.prio; else delete layer2.priority;
  if (x.rem === 'off') layer2.remind = null;
  else if (Number.isInteger(x.rem) && x.rem >= 0) layer2.remind = { kind: 'lead', min: x.rem };
  const due = /^\d{4}-\d{2}-\d{2}$/.test(x.due ?? '') ? x.due : null;
  return { title: String(x.title).slice(0, 250), listId, due, slot: due && hm.test(x.time ?? '') ? { s: x.time, e: plus(x.time) } : null, layer: layer2, notes: String(x.notes ?? '').slice(0, 4000) };
}

/** Сообщение боту → задача для quickCreate: дата/время/!!!/#тип/@список словами, список — как в строке «Сегодня».
 *  Без даты — без срока (в отличие от строки «Сегодня», где без даты значит «сегодня»). */
export function fromText(text, { lists, layer, tasks, today = new Date() }) {
  const [first, ...rest] = String(text).split('\n');
  const p = parseLine(first, { today });
  if (!p.title || !lists.length) return null;
  const src = [p.at ? `@${p.at}` : '', p.tag ? `#${p.tag}` : '', p.rest].join(' ').trim();
  const ranked = route(src, { lists, layer, tasks });
  const t = taskFrom(p, ymd(today), ranked[0]?.listId ?? lists[0].id, ranked[0]);
  return { ...t, due: p.day ?? null, notes: rest.join('\n').trim() };
}
