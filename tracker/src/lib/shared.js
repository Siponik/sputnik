// Общая сфера — обмен с Google Календарём (чистая логика — lib/sharedcore.js).
// У каждой общей сферы свой календарь «Спутник · сфера …» с меткой в описании. Владелец делится им по почте,
// у остальных участников Спутник находит его в их списке календарей. Записи календаря кэшируются (localStorage),
// изменения забираем «токеном изменений» Google — это дёшево, поэтому опрашиваем часто (App — раз в 30 с).
import { gapi } from './api.js';
import * as core from './sharedcore.js';

const CAL = 'https://www.googleapis.com/calendar/v3';
const KEY = 'sp.shared';
const enc = encodeURIComponent;

/** stores[cal] = { cal, title, role, sync, recs: { ключ: запись } }; me — почта входа. */
let stores = {};
let me = '';
try { const j = JSON.parse(localStorage.getItem(KEY) ?? 'null'); if (j?.stores) { stores = j.stores; me = j.me ?? ''; } } catch {}
function persist() { try { localStorage.setItem(KEY, JSON.stringify({ stores, me })); } catch {} }

/** Забыть всё (выход из Google, другой аккаунт). */
export function reset() { stores = {}; me = ''; persist(); }
export const myEmail = () => me;
export const calendars = () => Object.keys(stores);
export const storeOf = (cal) => stores[cal] ?? null;
export const isOwner = (cal) => stores[cal]?.role === 'owner';

// ключ списка → календарь
function calOfList(lk) {
  for (const s of Object.values(stores)) if (s.recs[lk]) return s.cal;
  return null;
}
export const calOfListId = (id) => calOfList(core.listKey(id));

// ---------- что есть ----------

/** Все списки общих сфер в виде списков Google Tasks. */
export function lists() {
  return Object.values(stores).flatMap((s) => core.listsOf(s.recs, s.cal));
}

/** Задачи общего списка (id — sh:…). */
export function tasks(id) {
  const lk = core.listKey(id), cal = calOfList(lk);
  return cal ? core.tasksOf(stores[cal].recs, lk) : [];
}

/** Запись сферы календаря. */
export const sphereRec = (cal) => stores[cal]?.recs?.[core.SPHERE_KEY] ?? null;

// ---------- обмен ----------

/**
 * Найти календари общих сфер и забрать их изменения.
 * Возвращает { changes: [{ cal, k, base, rec }] (rec = null — запись удалена), gone: [cal] — к календарю больше нет доступа }.
 */
export async function pullAll() {
  const r = await gapi('GET', `${CAL}/users/me/calendarList?minAccessRole=reader&showHidden=true`);
  const items = r?.items ?? [];
  me = items.find((c) => c.primary)?.id ?? me;
  const found = items.filter(core.isSphereCal);
  const gone = Object.keys(stores).filter((cal) => !found.some((c) => c.id === cal));
  for (const cal of gone) delete stores[cal];
  const changes = [];
  for (const c of found) {
    const s = (stores[c.id] ??= { cal: c.id, title: c.summary, role: c.accessRole, sync: '', recs: {} });
    s.role = c.accessRole;
    s.title = c.summary;
    try { changes.push(...(await pull(s))); }
    catch (e) { if (!/404|403/.test(String(e))) throw e; }
  }
  persist();
  return { changes, gone };
}

async function pull(s) {
  const out = [];
  const full = !s.sync;
  const seen = full ? new Set() : null;
  let page = '';
  for (;;) {
    const q = new URLSearchParams({ maxResults: '2500', showDeleted: full ? 'false' : 'true' });
    if (!full) q.set('syncToken', s.sync);
    if (page) q.set('pageToken', page);
    let r;
    try { r = await gapi('GET', `${CAL}/calendars/${enc(s.cal)}/events?${q}`); }
    catch (e) {
      // Токен устарел — Google просит забрать всё заново.
      if (/410/.test(String(e)) && !full) { s.sync = ''; return pull(s); }
      throw e;
    }
    for (const ev of r?.items ?? []) {
      const rec = core.fromEvent(ev);
      const k = rec?.k ?? ev.id;
      if (seen) seen.add(k);
      const base = s.recs[k] ?? null;
      if (!rec) { if (base && ev.status === 'cancelled') { delete s.recs[k]; out.push({ cal: s.cal, k, base, rec: null }); } continue; }
      const m = core.mergeRec(base, rec);
      if (base && core.same(base, m)) continue;
      s.recs[k] = m;
      out.push({ cal: s.cal, k, base, rec: m });
    }
    page = r?.nextPageToken ?? '';
    if (!page) { s.sync = r?.nextSyncToken ?? ''; break; }
  }
  if (seen) for (const k of Object.keys(s.recs)) if (!seen.has(k)) { out.push({ cal: s.cal, k, base: s.recs[k], rec: null }); delete s.recs[k]; }
  return out;
}

/** Записать запись: сначала свежая версия из календаря (её поля могли поменять другие), потом слитая. */
async function write(cal, rec) {
  let cur = null;
  try { cur = core.fromEvent(await gapi('GET', `${CAL}/calendars/${enc(cal)}/events/${enc(rec.k)}`)); }
  catch (e) { if (!/404|410/.test(String(e))) throw e; }
  const m = core.mergeRec(cur, rec);
  const body = core.toEvent(m);
  if (cur) await gapi('PUT', `${CAL}/calendars/${enc(cal)}/events/${enc(rec.k)}`, body);
  else {
    try { await gapi('POST', `${CAL}/calendars/${enc(cal)}/events`, body); }
    // Событие с этим id уже было и удалено — Google не даёт создать заново, но даёт перезаписать.
    catch (e) { if (/409/.test(String(e))) await gapi('PUT', `${CAL}/calendars/${enc(cal)}/events/${enc(rec.k)}`, { ...body, status: 'confirmed' }); else throw e; }
  }
  if (stores[cal]) { stores[cal].recs[rec.k] = m; persist(); }
  return m;
}

async function drop(cal, k) {
  try { await gapi('DELETE', `${CAL}/calendars/${enc(cal)}/events/${enc(k)}`); }
  catch (e) { if (!/404|410/.test(String(e))) throw e; }
  if (stores[cal]) { delete stores[cal].recs[k]; persist(); }
}

/** Дописать поля в запись (поля слоя — с '$'). */
export async function patchRec(cal, k, patch) {
  const cur = stores[cal]?.recs?.[k];
  if (!cur) return null;
  const next = core.edit(cur, patch);
  return next === cur ? cur : write(cal, next);
}

// ---------- задачи и списки — как Google Tasks ----------

function need(id) {
  const lk = core.listKey(id), cal = calOfList(lk);
  if (!cal) throw new Error('404 общий список не найден (обнови Спутник)');
  return { lk, cal };
}

export async function createTask(id, body, parent = null, layer = {}) {
  const { lk, cal } = need(id);
  const f = { list: lk, pos: core.newPos(), ...core.taskPatch({ title: '', notes: '', status: 'needsAction', ...body }), ...(parent ? { parent } : {}) };
  for (const [n, v] of Object.entries(layer)) f['$' + n] = v;
  if (!f.completed) delete f.completed;
  return core.taskView(await write(cal, core.make(core.newKey('t'), f)));
}

export async function patchTask(id, taskId, body) {
  const { cal } = need(id);
  const cur = stores[cal].recs[taskId];
  if (!cur) throw new Error('404 задача не найдена');
  const next = core.edit(cur, core.taskPatch(body));
  return core.taskView(next === cur ? cur : await write(cal, next));
}

export async function deleteTask(id, taskId) {
  const { cal } = need(id);
  for (const k of core.withChildren(stores[cal].recs, taskId).reverse()) await drop(cal, k);
}

export async function createList(cal, title, layer = {}) {
  const f = { title, created: Date.now() };
  for (const [n, v] of Object.entries(layer)) f['$' + n] = v;
  return core.listView(await write(cal, core.make(core.newKey('l'), f)), cal);
}

export async function deleteList(id) {
  const { lk, cal } = need(id);
  const recs = stores[cal].recs;
  for (const r of Object.values(recs)) if (r.f?.list === lk && r.f?.parent) await drop(cal, r.k);
  for (const r of Object.values(recs)) if (r.f?.list === lk) await drop(cal, r.k);
  await drop(cal, lk);
}

// ---------- сфера ----------

/** Завести календарь общей сферы. Возвращает id календаря. */
export async function createSphere({ name, color, icon }) {
  const c = await gapi('POST', `${CAL}/calendars`, {
    summary: `Спутник · сфера ${name}`,
    description: `${core.MARK} v1 — служебный календарь общей сферы Спутника. Не удаляй и не меняй его события вручную.`,
    timeZone: 'Europe/Moscow',
  });
  // В самом Google Календаре его не видно: служебные события на 2000 год там только мешали бы.
  await gapi('PATCH', `${CAL}/users/me/calendarList/${enc(c.id)}`, { selected: false, hidden: true }).catch(() => {});
  stores[c.id] = { cal: c.id, title: c.summary, role: 'owner', sync: '', recs: {} };
  await write(c.id, core.make(core.SPHERE_KEY, { name, color, icon, owner: me || null }));
  return c.id;
}

/** Удалить сферу у всех (владелец) или выйти из неё (участник). */
export async function removeSphere(cal) {
  if (isOwner(cal)) await gapi('DELETE', `${CAL}/calendars/${enc(cal)}`);
  else await gapi('DELETE', `${CAL}/users/me/calendarList/${enc(cal)}`);
  delete stores[cal];
  persist();
}

/** Присоединиться к сфере по коду (id календаря), которым поделился владелец. */
export async function join(code) {
  const id = code.trim();
  const c = await gapi('POST', `${CAL}/users/me/calendarList`, { id, selected: false, hidden: true });
  if (!core.isSphereCal(c)) {
    // Описание календаря у участника может не прийти сразу — проверим по записи сферы.
    const ev = await gapi('GET', `${CAL}/calendars/${enc(id)}/events/${core.SPHERE_KEY}`).catch(() => null);
    if (!core.fromEvent(ev)) throw new Error('Это не общая сфера Спутника');
  }
  return id;
}

// ---------- участники (только владелец) ----------

/** Участники: [{ id, email, role }] — без самого владельца. */
export async function members(cal) {
  const r = await gapi('GET', `${CAL}/calendars/${enc(cal)}/acl`);
  return (r?.items ?? [])
    .filter((a) => a.scope?.type === 'user' && a.role !== 'owner')
    .map((a) => ({ id: a.id, email: a.scope.value, role: a.role }));
}

/** Позвать по почте: право «вносить изменения», Google сам пришлёт письмо. */
export const invite = (cal, email) =>
  gapi('POST', `${CAL}/calendars/${enc(cal)}/acl?sendNotifications=true`, { role: 'writer', scope: { type: 'user', value: email.trim() } });

export const removeMember = (cal, ruleId) => gapi('DELETE', `${CAL}/calendars/${enc(cal)}/acl/${enc(ruleId)}`);
