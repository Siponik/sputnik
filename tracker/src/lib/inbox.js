// «Входящие от Claude»: задачи, которые Apps Script (reminders/Inbox.gs) создал по запросам из чатов.
// Трекер узнаёт их по статусу (api.inboxStatus) и показывает на «Сегодня», пока их не примут или не отклонят.
// Решение хранится в слое: tasks[id].inbox = 'accepted' | 'rejected'.
import { templatesFrom, VIEWS } from './templates.js';
import { topicsOf } from './stickers.js';
import { spheresFrom, SPHERE_COLORS, SPHERE_ICONS } from './spheres.js';

/** taskId → { from, at } для задач, созданных из чатов (без дублей и отметок «выполнено»). */
export function claudeTasks(status) {
  const out = {};
  for (const p of Object.values(status?.processed ?? {})) {
    if (!p?.ok) continue;
    for (const c of p.created ?? []) {
      if (c?.op === 'task.create' && c.taskId && !c.existed) out[c.taskId] = { from: p.from || '', at: p.at };
    }
  }
  return out;
}

/** Ещё не разобранные: задача есть, открыта и решения по ней нет. */
export function pending(status, lists, tasksByList, layTasks) {
  const ids = claudeTasks(status);
  const items = [];
  for (const l of lists) {
    for (const t of tasksByList[l.id] ?? []) {
      if (!ids[t.id] || t.status === 'completed' || layTasks?.[t.id]?.inbox) continue;
      items.push({ task: t, listId: l.id, list: l.title, ...ids[t.id] });
    }
  }
  return items.sort((a, b) => (b.at || '').localeCompare(a.at || ''));
}

// Типы из навыка sputnik-tasks → наши цвета. plain — без своего типа (цвет от шаблона списка).
const TYPE = { work: 'work', meeting: 'work', creative: 'creative', study: 'study', personal: 'personal' };

const str = (v, max) => (typeof v === 'string' && v.trim() && v.length <= max ? v.trim() : null);
const MAX_LEAD = 60 * 24 * 62; // напоминание — не раньше чем за два месяца
const lead = (m) => (Number.isInteger(m) && m >= 0 && m <= MAX_LEAD ? { kind: 'lead', min: m } : null);
const plusHour = (hm) => { const m = Math.min(23 * 60 + 59, Number(hm.slice(0, 2)) * 60 + Number(hm.slice(3)) + 60); return `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`; };
const norm = (x) => String(x ?? '').trim().toLowerCase().replace(/ё/g, 'е');

/** Поля слоя из pendingLayer, которые ещё не перенесены в наш слой: [[taskId, patch], …].
 *  topicOf(listId, тема) → id темы стикеров (по id или названию); без него тема берётся как есть. */
export function layerPatches(status, layTasks, topicOf = null) {
  const out = [];
  for (const [id, f] of Object.entries(status?.pendingLayer ?? {})) {
    if (layTasks?.[id]?.pulled) continue;
    const patch = { pulled: true };
    if (TYPE[f.type]) patch.type = TYPE[f.type];
    if (typeof f.project === 'string') patch.project = f.project;
    if (Array.isArray(f.tags)) patch.tags = f.tags.filter((x) => typeof x === 'string');
    if ([1, 2, 3].includes(f.priority)) patch.priority = f.priority;
    if (typeof f.stage === 'string') patch.stage = f.stage;
    if (['day', 'weekdays', 'week', 'month', 'year'].includes(f.repeat?.every)) patch.repeat = { every: f.repeat.every };
    // Время из Telegram-бота или чата: «завтра 17:00» → slot { s, e }.
    const hm = /^([01]\d|2[0-3]):[0-5]\d$/;
    if (f.slot && hm.test(f.slot.s) && hm.test(f.slot.e) && f.slot.s < f.slot.e) patch.slot = { s: f.slot.s, e: f.slot.e };
    else if (f.slot && hm.test(f.slot.s) && f.slot.e == null) patch.slot = { s: f.slot.s, e: plusHour(f.slot.s) }; // без конца — час
    // Колонка канбана / этап конвейера (id колонки шаблона); дата входа в этап — время запроса.
    const col = str(f.status, 40);
    if (col && /^[\w-]+$/.test(col)) {
      patch.status = col;
      const at = Date.parse(f.at);
      patch.stageAt = { [col]: Number.isFinite(at) ? at : Date.now() };
    }
    const topic = str(f.topic, 40);
    if (topic) { const tid = topicOf ? topicOf(f.listId, topic) : topic; if (tid) patch.topic = tid; }
    if (f.pin === true) patch.pin = true;
    const client = str(f.client, 100), money = typeof f.money === 'number' ? String(f.money) : str(f.money, 40);
    if (client) patch.client = client;
    if (money) patch.money = money;
    // Напоминание: минуты до начала (срок + время задачи) — число или несколько чисел.
    const rems = (Array.isArray(f.remind) ? f.remind : [f.remind]).map(lead).filter(Boolean);
    if (rems.length) patch.remind = rems.length > 1 ? rems : rems[0];
    if (Number.isFinite(f.spent) && f.spent > 0 && f.spent < 1e5) patch.spent = Math.round(f.spent);
    if (f.accept === true) patch.inbox = 'accepted'; // пользователь сам попросил — без «Принять / Отклонить»
    out.push([id, patch]);
  }
  return out;
}

const slug = (name, taken) => {
  const base = norm(name).replace(/[^a-zа-я0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 24) || 'x';
  let id = base, i = 2;
  while (taken.has(id)) id = `${base}-${i++}`;
  taken.add(id);
  return id;
};

/** Всё, что прислали чаты, одним набором правок слоя: { spheres, lists, tasks } — каждое [[id, patch], …].
 *  Списки — из pendingLists (шаблон, вид, сфера по названию, темы стикеров, группировка), переносятся один раз
 *  (lists[id].pulled = время запроса). Неизвестная тема у задачи-стикера добавляется в темы списка. */
export function pullPatches(status, lay) {
  const spheres = new Map(), lists = new Map();
  const known = spheresFrom(lay);
  const tpls = templatesFrom(lay);
  const colorIds = SPHERE_COLORS.map((c) => c.id);
  const sphereIds = new Set(Object.keys(lay?.spheres ?? {}));
  let order = Math.max(0, ...known.map((s) => s.order ?? 0));

  const sphereId = (name, color, icon) => {
    const hit = known.find((s) => norm(s.name) === norm(name)) ?? [...spheres.entries()].map(([id, s]) => ({ id, ...s })).find((s) => norm(s.name) === norm(name));
    if (hit) return hit.id;
    const id = 'sp-' + slug(name, sphereIds);
    spheres.set(id, { name: name.trim(), color: colorIds.includes(color) ? color : colorIds[(known.length + spheres.size) % colorIds.length], icon: SPHERE_ICONS[icon] ? icon : 'star', order: ++order, removed: false });
    return id;
  };
  const topicList = (raw) => {
    const taken = new Set(), out = [];
    for (const [i, x] of raw.entries()) {
      const name = str(typeof x === 'string' ? x : x?.name, 40);
      if (!name || out.some((t) => norm(t.name) === norm(name))) continue;
      const def = topicsOf(null).find((t) => norm(t.name) === norm(name));
      const color = colorIds.includes(x?.color) ? x.color : def?.color ?? colorIds[i % colorIds.length];
      out.push({ id: def && !taken.has(def.id) ? (taken.add(def.id), def.id) : slug(name, taken), name, color });
    }
    return out.slice(0, 12);
  };

  for (const [id, f] of Object.entries(status?.pendingLists ?? {})) {
    if (!f || typeof f !== 'object' || (f.at && lay?.lists?.[id]?.pulled === f.at)) continue;
    const patch = { pulled: f.at || true };
    const tpl = str(f.template, 60) && tpls.find((t) => t.id === f.template || norm(t.name) === norm(f.template));
    if (tpl) patch.template = tpl.id;
    if (VIEWS.some((v) => v.id === f.view)) patch.view = f.view;
    const sp = str(f.sphere, 40);
    if (sp) patch.sphere = sphereId(sp, f.sphereColor, f.sphereIcon);
    if (Array.isArray(f.topics)) { const t = topicList(f.topics); if (t.length) patch.topics = t; }
    if (['topic', 'when'].includes(f.group)) patch.group = f.group;
    lists.set(id, patch);
  }

  // Тема по id или названию в темах списка (с учётом только что пришедших); новой — добавляем.
  const topicOf = (listId, name) => {
    if (!listId) return null;
    const cur = lists.get(listId)?.topics ?? topicsOf(lay?.lists?.[listId]);
    const hit = cur.find((t) => t.id === name || norm(t.name) === norm(name));
    if (hit) return hit.id;
    const taken = new Set(cur.map((t) => t.id));
    const t = { id: slug(name, taken), name, color: colorIds[cur.length % colorIds.length] };
    lists.set(listId, { ...(lists.get(listId) ?? {}), topics: [...cur, t] });
    return t.id;
  };
  const tasks = layerPatches(status, lay?.tasks, topicOf);
  return { spheres: [...spheres], lists: [...lists], tasks };
}
