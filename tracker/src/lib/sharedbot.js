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
/** Напоминания и задачи на неделю — на сервер, если что-то поменялось. Возвращает true, если отправил. */
export async function push(key, items, today) {
  const body = { items, today, tz: tz() };
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
