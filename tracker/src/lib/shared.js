// Общая сфера — обмен с Google Календарём (чистая логика — lib/sharedcore.js).
// У каждой общей сферы свой календарь «Спутник · сфера …» с меткой в описании. Владелец делится им по почте,
// у остальных участников Спутник находит его в их списке календарей. Записи календаря кэшируются (localStorage),
// изменения забираем «токеном изменений» Google — это дёшево, поэтому опрашиваем часто (App — раз в 30 с).
import { gapi, isOffline } from './api.js';
import * as core from './sharedcore.js';

const CAL = 'https://www.googleapis.com/calendar/v3';
const KEY = 'sp.shared';
const enc = encodeURIComponent;

/** stores[cal] = { cal, title, role, sync, recs: { ключ: запись }, pending: { ключ: 'w' | 'd' }, accepted, lost }; me — почта входа.
 *  pending — правки, сделанные без связи: уходят первыми при следующем обмене.
 *  accepted — сам вошёл (по коду или «Принять»), иначе это приглашение (core.isInvite); lost — доступа больше нет. */
let stores = {};
let me = '';
try { const j = JSON.parse(localStorage.getItem(KEY) ?? 'null'); if (j?.stores) { stores = j.stores; me = j.me ?? ''; } } catch {}
function persist() { try { localStorage.setItem(KEY, JSON.stringify({ stores, me })); } catch {} }

/** Забыть всё (выход из Google, другой аккаунт). */
export function reset() { stores = {}; me = ''; persist(); }
export const myEmail = () => me;
export const calendars = () => Object.keys(stores);
/** Календари сфер, в которых я участвую (без приглашений и без потерянных). */
export const activeCalendars = () => Object.values(stores).filter((s) => !s.lost && !core.isInvite(s, me)).map((s) => s.cal);
/** Приглашения: позвали, но я ещё не принял (плашка «X зовёт тебя в сферу»). */
export const invites = () => Object.values(stores).filter((s) => !s.lost && core.isInvite(s, me)).map((s) => core.inviteInfo(s, me));
export const isLost = (cal) => !!stores[cal]?.lost;
export const storeOf = (cal) => stores[cal] ?? null;
export const isOwner = (cal) => stores[cal]?.role === 'owner';
/** Участники сферы по порядку, с цветами (sharedcore.membersOf). */
export const people = (cal) => core.membersOf(stores[cal]?.recs);
/** Ключи записей, которые ещё не ушли в календарь (нет связи). */
export const pendingOf = (cal) => Object.keys(stores[cal]?.pending ?? {});

// ключ списка → календарь
function calOfList(lk) {
  for (const s of Object.values(stores)) if (s.recs[lk]) return s.cal;
  return null;
}
export const calOfListId = (id) => calOfList(core.listKey(id));

// ---------- что есть ----------

/** Все списки общих сфер в виде списков Google Tasks. */
export function lists() {
  return Object.values(stores).filter((s) => !core.isInvite(s, me))
    .flatMap((s) => core.listsOf(s.recs, s.cal).map((l) => (s.lost ? { ...l, lost: true } : l)));
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
export async function pullAll({ discover = true } = {}) {
  const items = discover
    ? (await gapi('GET', `${CAL}/users/me/calendarList?minAccessRole=reader&showHidden=true`))?.items ?? []
    : Object.values(stores).map((x) => ({ id: x.cal, summary: x.title, accessRole: x.role, description: core.MARK }));
  me = items.find((c) => c.primary)?.id ?? me;
  const found = items.filter(core.isSphereCal);
  // Календаря больше нет в списке (владелец удалил сферу, нас убрали) — не забываем молча: сфера остаётся в колонке
  // бледной с «нет доступа», пока человек сам её не уберёт. gone — те, что потеряны только что.
  const gone = [];
  const lose = (s) => { if (!s.lost) { s.lost = true; gone.push(s.cal); } };
  if (discover) for (const s of Object.values(stores)) if (!found.some((c) => c.id === s.cal)) lose(s);
  const changes = [];
  for (const c of found) {
    const s = (stores[c.id] ??= { cal: c.id, title: c.summary, role: c.accessRole, sync: '', recs: {} });
    if (s.lost && !discover) continue; // потерянные проверяем только при полном обходе
    s.role = c.accessRole;
    s.title = c.summary;
    s.pending ??= {};
    try {
      await flush(s);
      const got = await pull(s);
      changes.push(...got);
      s.lost = false;
      if (!core.isInvite(s, me)) await markJoined(s, got);
    } catch (e) { if (/404|403/.test(String(e))) lose(s); else throw e; }
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

/** Записать запись: сначала свежая версия из календаря (её поля могли поменять другие), потом слитая.
 *  Нет связи — запись остаётся в кэше и в pending, уйдёт при следующем обмене (flush). */
async function write(cal, rec) {
  if (me && rec.f.by !== me) rec = core.edit(rec, { by: me });
  try { return await put(cal, rec); }
  catch (e) {
    if (!isOffline(e) || !stores[cal]) throw e;
    stores[cal].recs[rec.k] = rec;
    (stores[cal].pending ??= {})[rec.k] = 'w';
    persist();
    return rec;
  }
}

async function put(cal, rec) {
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
  if (stores[cal]) { stores[cal].recs[rec.k] = m; if (stores[cal].pending) delete stores[cal].pending[rec.k]; persist(); }
  return m;
}

async function drop(cal, k) {
  try { await gapi('DELETE', `${CAL}/calendars/${enc(cal)}/events/${enc(k)}`); }
  catch (e) {
    if (isOffline(e) && stores[cal]) { (stores[cal].pending ??= {})[k] = 'd'; }
    else if (!/404|410/.test(String(e))) throw e;
  }
  if (stores[cal]) { delete stores[cal].recs[k]; if (stores[cal].pending?.[k] !== 'd') delete stores[cal].pending?.[k]; persist(); }
}

/** Отправить правки, сделанные без связи. Нет связи и сейчас — бросает (обмен не идёт). */
async function flush(s) {
  for (const [k, op] of Object.entries(s.pending ?? {})) {
    if (op === 'd') {
      try { await gapi('DELETE', `${CAL}/calendars/${enc(s.cal)}/events/${enc(k)}`); }
      catch (e) { if (!/404|410/.test(String(e))) throw e; }
      delete s.pending[k];
    } else if (s.recs[k]) await put(s.cal, s.recs[k]);
    else delete s.pending[k];
  }
  persist();
}

/** Участник впервые видит сферу — отмечаем «принял приглашение» (владелец увидит, что он с нами); «был тогда-то» — раз в час,
 *  а если пришли чужие правки — через 2 минуты (по нему другие видят, дошло ли до нас, — «ждёт Аню»). */
async function markJoined(s, got = []) {
  if (!me || !s.recs[core.SPHERE_KEY]) return;
  const k = core.memberKey(me), cur = s.recs[k];
  const foreign = got.some((c) => c.rec && c.rec.f.by && c.rec.f.by !== me && core.lastTime(c.rec) > (cur?.f?.seen ?? 0));
  const stale = core.seenDue(cur?.f?.seen, foreign);
  if (cur?.f?.joined && !cur.f.removed && !stale) return;
  const next = cur ? core.edit(cur, { joined: true, removed: false, seen: Date.now() }) : core.make(k, { email: me, order: core.nextOrder(s.recs), joined: true, seen: Date.now() });
  await write(s.cal, next);
}

/** «Как меня видят»: имя, цвет и фото из настроек — в мою запись участника каждой сферы, где я есть. Возвращает, сколько сфер поменялось. */
export async function applyProfile(profile) {
  if (!me) return 0;
  let n = 0;
  for (const cal of activeCalendars()) {
    const cur = stores[cal].recs[core.memberKey(me)];
    if (!cur || cur.f.removed) continue;
    const patch = core.profilePatch(cur, profile);
    if (!Object.keys(patch).length) continue;
    await write(cal, core.edit(cur, patch));
    n++;
  }
  return n;
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
  if (me) await write(c.id, core.make(core.memberKey(me), { email: me, order: 0, joined: true }));
  return c.id;
}

/** Удалить сферу у всех (владелец) или выйти из неё (участник). */
export async function removeSphere(cal) {
  if (stores[cal]?.lost) return forget(cal);
  if (isOwner(cal)) await gapi('DELETE', `${CAL}/calendars/${enc(cal)}`);
  else {
    const k = core.memberKey(me);
    if (me && stores[cal]?.recs?.[k]) await patchRec(cal, k, { removed: true }).catch(() => {});
    await gapi('DELETE', `${CAL}/users/me/calendarList/${enc(cal)}`);
  }
  delete stores[cal];
  persist();
}

/** Присоединиться к сфере по коду (id календаря), которым поделился владелец. Вошёл сам — это уже не приглашение. */
export async function join(code) {
  const id = code.trim();
  const c = await gapi('POST', `${CAL}/users/me/calendarList`, { id, selected: false, hidden: true });
  if (!core.isSphereCal(c)) {
    // Описание календаря у участника может не прийти сразу — проверим по записи сферы.
    const ev = await gapi('GET', `${CAL}/calendars/${enc(id)}/events/${core.SPHERE_KEY}`).catch(() => null);
    if (!core.fromEvent(ev)) throw new Error('Это не общая сфера Спутника');
  }
  stores[id] = { ...(stores[id] ?? { cal: id, title: c.summary ?? '', role: c.accessRole ?? 'writer', sync: '', recs: {} }), accepted: true, lost: false };
  persist();
  return id;
}

/** «Принять» приглашение: сфера появляется в колонке, владелец видит, что я с ними. */
export async function accept(cal) {
  const s = stores[cal];
  if (!s) return;
  s.accepted = true;
  persist();
  await gapi('PATCH', `${CAL}/users/me/calendarList/${enc(cal)}`, { selected: false, hidden: true }).catch(() => {});
  await markJoined(s);
  persist();
}

/** «Отказаться» от приглашения — как выйти из сферы. */
export const decline = (cal) => removeSphere(cal);

/** Сфера без доступа — «Убрать из колонки»: забыть её здесь (календаря у нас уже нет). */
export async function forget(cal) {
  await gapi('DELETE', `${CAL}/users/me/calendarList/${enc(cal)}`).catch(() => {});
  delete stores[cal];
  persist();
}

// ---------- участники (только владелец) ----------

/** Позвать по почте: право «вносить изменения», Google сам пришлёт письмо; в сфере — запись «ещё не принял». */
export async function invite(cal, email) {
  const e = email.trim().toLowerCase();
  await gapi('POST', `${CAL}/calendars/${enc(cal)}/acl?sendNotifications=true`, { role: 'writer', scope: { type: 'user', value: e } });
  const recs = stores[cal]?.recs ?? {}, k = core.memberKey(e);
  const next = recs[k] ? core.edit(recs[k], { removed: false }) : core.make(k, { email: e, order: core.nextOrder(recs), joined: false });
  if (next !== recs[k]) await write(cal, next);
}

/** Убрать участника (или отозвать приглашение): доступ к календарю и его запись. */
export async function removeMember(cal, email) {
  const e = email.trim().toLowerCase();
  try { await gapi('DELETE', `${CAL}/calendars/${enc(cal)}/acl/${enc('user:' + e)}`); }
  catch (err) { if (!/404|410/.test(String(err))) throw err; }
  const k = core.memberKey(e);
  if (stores[cal]?.recs?.[k]) await patchRec(cal, k, { removed: true });
}

/** Перестать делиться: убрать всех, кроме владельца. Сфера остаётся у владельца, как была. */
export async function stopSharing(cal) {
  for (const p of people(cal)) if (!p.owner) await removeMember(cal, p.email);
}

/** Текст приглашения для «Скопировать ссылку-приглашение»: ссылка Google Календаря и код для Спутника. */
export function inviteText(cal, sphereName) {
  const link = `https://calendar.google.com/calendar/r?cid=${encodeURIComponent(cal)}`;
  return `Зову тебя в общую сферу «${sphereName}» в Спутнике.\n1) Открой ссылку и добавь календарь: ${link}\n2) Или в Спутнике: ＋ в левой колонке → «Войти в общую сферу…» и код: ${cal}`;
}
