// Общие сферы: сфера в своём Google Календаре, которым владелец делится по почте (lib/shared.js — обмен,
// lib/sharedcore.js — чистая логика). Её списки и задачи api.js отдаёт как обычные, а поля слоя (колонка, этап, тема,
// приоритет…) сводим с записями календаря здесь: забрали — в слой, поменяли слой — в календарь.
// Окна и вопросы (сделать общей, выйти, перестать делиться) остаются в App — стор только меняет данные.
import * as api from '../lib/api.js';
import * as shared from '../lib/shared.js';
import * as sh from '../lib/sharedcore.js';
import * as fresh from '../lib/fresh.js';
import * as layerSync from '../lib/layer.js';
import * as notify from '@tauri-apps/plugin-notification';
import { plural } from '../lib/habits.js';
import { spheresFrom, sphereOf } from '../lib/spheres.js';
import { layer, touch, save } from './layer.svelte.js';
import { board, find, toggle, touchedAt } from './tasks.svelte.js';
import { sync } from './sync.svelte.js';
import { say } from './toast.svelte.js';

/** ver — растёт после обмена и правок: экран перечитывает участников из кэша shared.js; err — последняя ошибка обмена;
 *  hidden — «sid|почта» убранных участников, пока идут 6 с на «Отменить». */
export const share = $state({ ver: 0, err: '', hidden: [] });

// Что App подставляет: можно ли сейчас обмениваться, открыть задачу, список переехал (новый id).
let hooks = { ready: () => false, open: () => {}, onListMoved: () => {} };
export function configure(h) { hooks = { ...hooks, ...h }; }

/** Моя почта (перечитывается вместе с share.ver). */
export const me = () => (share.ver, shared.myEmail());
export const isSharedSphere = (sid) => !!sid && sh.isSharedId(sid);
/** Сфера по-настоящему общая (есть кто-то кроме владельца) — для метки «общая» и кружков. */
export const together = (sid) => isSharedSphere(sid) && sh.isTogether(peopleOf(sid));

let sharePushing = null;
const leaving = new Map(); // «sid|почта» → таймер «Убрать» (6 с на «Отменить»)

/** Участники общей сферы по порядку, с цветами; у личной — пусто. */
export function peopleOf(sid) {
  void share.ver;
  const cal = sh.calOfSphere(sid);
  return cal ? shared.people(cal).filter((p) => !share.hidden.includes(`${sid}|${p.email}`)) : [];
}

/** Записи календарей, которые пришли или поменялись, — в слой; что поменяли здесь, пока их не было, — обратно. */
export function applyShared({ changes, gone }) {
  let changed = false;
  const back = [];
  const put = (sec, key, patch, t) => {
    layer.data[sec] ??= {};
    const cur = layer.data[sec][key] ?? {};
    layer.data[sec][key] = { ...cur, ...patch, t: Math.max(cur.t ?? 0, t || Date.now()) };
    changed = true;
  };
  const given = [], closed = [];
  const me = shared.myEmail();
  const active = new Set(shared.activeCalendars()); // приглашение до «Принять» в слой не попадает
  for (const { cal, k, base, rec } of changes) {
    if (!rec || !active.has(cal)) continue;
    const kind = sh.kindOf(k), t = sh.lastTime(rec);
    // Новую запись (base нет) считаем «отданной мне», только если её завели недавно — иначе при первом входе в сферу
    // посыпались бы уведомления обо всех старых задачах.
    if (sh.assignedToMe(base, rec, me) && (base || Date.now() - t < 15 * 60e3)) given.push({ cal, k, rec });
    if (kind === 'task' && base && base.f.status !== 'completed' && rec.f.status === 'completed' && rec.f.by && rec.f.by !== me && !rec.f.parent) closed.push({ cal, k, rec });
    if (kind === 'task') {
      const { toLayer, toRec } = sh.reconcile(layer.data.tasks?.[k], base, rec, 'task');
      if (Object.keys(toLayer).length) put('tasks', k, toLayer, t);
      if (Object.keys(toRec).length) back.push([cal, k, toRec]);
    } else if (kind === 'list') {
      const id = sh.listId(k);
      const { toLayer, toRec } = sh.reconcile(layer.data.lists?.[id], base, rec, 'list');
      if (Object.keys(toLayer).length) put('lists', id, toLayer, t);
      if (Object.keys(toRec).length) back.push([cal, k, toRec]);
    } else if (kind === 'sphere') {
      const { toLayer, toRec } = sh.reconcileSphere(layer.data.spheres?.[sh.sphereId(cal)], base, rec);
      if (Object.keys(toLayer).length) put('spheres', sh.sphereId(cal), toLayer, t);
      if (Object.keys(toRec).length) back.push([cal, k, toRec]);
    }
  }
  // У каждой сферы, где я участник, — запись в слое, у её списков — эта сфера. Приглашения ждут «Принять».
  for (const cal of shared.activeCalendars()) {
    const sid = sh.sphereId(cal);
    const S = layer.data.spheres?.[sid];
    if (S?.noAccess) put('spheres', sid, { noAccess: false });
    if (!S || S.removed || S.gone || !S.shared) {
      const rec = shared.sphereRec(cal);
      put('spheres', sid, { name: rec?.f?.name ?? 'Общая сфера', color: rec?.f?.color ?? 'gold', icon: rec?.f?.icon ?? 'users',
        order: S?.order ?? Math.max(0, ...spheresFrom(layer.data).map((x) => x.order ?? 0)) + 1, removed: false, gone: undefined, shared: { cal } });
    }
    for (const l of shared.lists().filter((x) => x.shared === cal)) if (layer.data.lists?.[l.id]?.sphere !== sid) put('lists', l.id, { sphere: sid });
  }
  // Доступа к календарю больше нет: сферу удалил владелец или нас убрали. Сфера остаётся бледной с «нет доступа».
  for (const cal of gone) {
    const sid = sh.sphereId(cal);
    if (layer.data.spheres?.[sid] && !layer.data.spheres[sid].removed) { put('spheres', sid, { noAccess: true }); say(`Нет доступа к сфере «${layer.data.spheres[sid].name}»: её удалили или тебя убрали из участников`); }
  }
  for (const g of given) {
    const name = shared.people(g.cal).find((p) => p.email === g.rec.f.by)?.name ?? sh.nameOf(g.rec.f.by);
    put('tasks', g.k, { given: { by: g.rec.f.by, name, at: new Date().toISOString() } });
  }
  if (changed) save();
  share.ver++;
  if (given.length) tellGiven(given);
  else if (closed.length) {
    // «Оля закрыла «…» · Вернуть» (docs/design-v2.md, «Общие сферы» 7).
    const c = closed[0], lid = sh.listId(c.rec.f.list ?? '');
    const name = shared.people(c.cal).find((p) => p.email === c.rec.f.by)?.name ?? sh.nameOf(c.rec.f.by);
    say(closed.length === 1 ? `${name} · сделано «${c.rec.f.title || 'Без названия'}»` : `Участники закрыли задач: ${closed.length}`,
      closed.length === 1 ? () => { const cur = find(lid, c.k); if (cur) toggle(cur, false, lid, true); } : null, 'Вернуть');
  }
  for (const [cal, k, p] of back) shared.patchRec(cal, k, p).catch(() => {});
}

/** Тебе отдали задачи: плашка в приложении и уведомление Windows (бот — через файл напоминаний, kind 'assigned'). */
async function tellGiven(given) {
  const g = given[0], name = layer.data.tasks?.[g.k]?.given?.name ?? 'Участник';
  const title = g.rec.f.title || 'Без названия';
  const text = given.length === 1 ? `${name} отдаёт тебе «${title}»` : `Тебе отдали задач: ${given.length}`;
  const lid = sh.listId(g.rec.f.list ?? '');
  say(text, given.length === 1 && g.rec.f.list ? () => hooks.open(lid, g.k) : null, 'Открыть');
  if (layer.data.settings?.notify?.v === false) return;
  try {
    let ok = await notify.isPermissionGranted();
    if (!ok) ok = (await notify.requestPermission()) === 'granted';
    if (ok) notify.sendNotification({ title: 'Спутник · тебе отдали задачу', body: given.length === 1 ? `${name}: ${title}` : text });
  } catch { /* уведомления недоступны — плашка и бот всё равно скажут */ }
}

export function askAccess(sid) {
  const cal = sh.calOfSphere(sid), owner = shared.people(cal).find((p) => p.owner);
  navigator.clipboard?.writeText(sh.askAccessText(layer.data.spheres?.[sid]?.name ?? '', owner?.email ?? '')).then(() => say('Письмо владельцу скопировано — вставь его в почту'), () => say('Не удалось скопировать'));
}
/** Сколько моих правок ещё не видел самый «отставший» участник сферы (плашка над доской). */
export function unseenOf(sid) {
  void share.ver;
  const cal = sh.calOfSphere(sid);
  if (!cal || !together(sid)) return null;
  const u = sh.unseenBy(shared.storeOf(cal)?.recs, peopleOf(sid), me())[0];
  return u && u.n >= 2 ? u : null;
}
/** Задача отдана, а Спутник исполнителя её ещё не забрал — «ждёт Аню». */
export function waitOf(listId, taskId) {
  void share.ver;
  const cal = shared.calOfListId(listId);
  return cal ? sh.waitingFor(shared.storeOf(cal)?.recs?.[taskId], shared.people(cal), me()) : null;
}

/** Задача из строки «Сегодня» в общую сферу — сразу моя (в «Создать» по умолчанию «Никто»). */
export function mineByDefault(p) {
  if (!p?.listId || !sh.isSharedId(p.listId) || !together(sphereOf(p.listId, layer.data)) || p.layer?.who !== undefined) return p;
  return { ...p, layer: { ...(p.layer ?? {}), who: me() } };
}

/** Исполнитель задачи общей сферы (w — почта или null). «Отдано мне» снимается: сам выбрал. */
export function setWho(id, w) {
  touch('tasks', id, { who: w ?? null, ...(layer.data.tasks?.[id]?.given ? { given: null } : {}) });
  save();
}

/** Правки слоя общих задач, списков и сфер — в их календари. */
export async function pushShared() {
  if (sharePushing) { await sharePushing; }
  sharePushing = (async () => {
    for (const cal of shared.activeCalendars()) {
      const recs = shared.storeOf(cal)?.recs ?? {};
      for (const rec of Object.values(recs)) {
        const kind = sh.kindOf(rec.k);
        const L = kind === 'task' ? layer.data.tasks?.[rec.k] : kind === 'list' ? layer.data.lists?.[sh.listId(rec.k)] : layer.data.spheres?.[sh.sphereId(cal)];
        if (!L) continue;
        const { toRec } = kind === 'sphere' ? sh.reconcileSphere(L, rec, rec) : sh.reconcile(L, rec, rec, kind);
        if (!Object.keys(toRec).length) continue;
        try { await shared.patchRec(cal, rec.k, toRec); share.err = ''; }
        catch (e) { share.err = String(e); if (!api.isOffline(e)) say('Не удалось передать правку в общую сферу: ' + e); return; }
      }
    }
  })();
  try { await sharePushing; } finally { sharePushing = null; share.ver++; }
}

/** Раз в 30 с — изменения общих сфер (дёшево: Google отдаёт только новое). */
export async function shareTick() {
  if (!hooks.ready() || sync.busy || !shared.calendars().length || document.hidden) return;
  const t0 = Date.now();
  const before = Object.fromEntries(Object.entries(board.tasks).map(([id, ts]) => [id, new Set(ts.map((t) => t.id))]));
  let r;
  try { r = await shared.pullAll({ discover: false }); share.err = ''; } catch (e) { share.err = String(e); return; }
  if (!r.changes.length && !r.gone.length) return;
  applyShared(r);
  const shl = shared.lists();
  board.lists = [...board.lists.filter((l) => !sh.isSharedId(l.id)), ...shl];
  for (const l of shl) board.tasks[l.id] = fresh.keepLocal(shared.tasks(l.id), board.tasks[l.id], before[l.id], touchedAt, t0);
  for (const id of Object.keys(board.tasks)) if (sh.isSharedId(id) && !shl.some((l) => l.id === id)) delete board.tasks[id];
}

/** Перенести списки обычной сферы в общий календарь: задачи с подзадачами и полями слоя, потом удалить их из Google Tasks. */
export async function moveListsToShared(cal, sid, ls) {
  const def = await api.defaultListId().catch(() => null);
  for (const l of ls) {
    if (l.id === def) { say(`«${l.title}» — основной список Google Tasks, его перенести нельзя. Убери его из сферы и попробуй снова.`); return false; }
  }
  for (const l of ls) {
    say(`Переношу «${l.title}» в общую сферу…`);
    const L = layer.data.lists?.[l.id] ?? {};
    const { t: _t, gone: _g, hidden: _h, sphere: _s, ...listLayer } = L;
    const nl = await shared.createList(cal, l.title, listLayer);
    const all = board.tasks[l.id] ?? (await api.listTasks(l.id));
    const own = (id) => { const T = layer.data.tasks?.[id] ?? {}; return Object.fromEntries(['remind', 'spent', 'timer', 'inbox', 'pulled'].filter((k) => T[k] != null).map((k) => [k, T[k]])); };
    const shareable = (id) => Object.fromEntries(Object.entries(sh.sharedOf(layer.data.tasks?.[id], 'task')).map(([k, v]) => [k.slice(1), v]));
    const ids = new Map();
    const body = (x) => ({ title: x.title, notes: x.notes ?? '', ...(x.due ? { due: x.due } : {}), status: x.status, ...(x.completed ? { completed: x.completed } : {}) });
    // По порядку Google: первые сверху остаются сверху.
    const byPos = (a, b) => (b.position || '').localeCompare(a.position || '');
    for (const x of all.filter((x) => !x.parent).sort(byPos)) {
      const r = await shared.createTask(nl.id, body(x), null, shareable(x.id));
      ids.set(x.id, r.id);
      layer.data.tasks ??= {};
      layer.data.tasks[r.id] = { ...sh.layerOf(shared.storeOf(cal).recs[r.id]), ...own(x.id), t: Date.now() };
    }
    for (const x of all.filter((x) => x.parent && ids.has(x.parent)).sort(byPos)) {
      const r = await shared.createTask(nl.id, body(x), ids.get(x.parent), shareable(x.id));
      layer.data.tasks[r.id] = { ...sh.layerOf(shared.storeOf(cal).recs[r.id]), ...own(x.id), t: Date.now() };
    }
    layer.data.lists[nl.id] = { ...listLayer, sphere: sid, t: Date.now() };
    await api.deleteList(l.id);
    layerSync.forgetList(layer.data, l.id, all.map((x) => x.id));
    board.lists = [...board.lists.filter((x) => x.id !== l.id), nl];
    delete board.tasks[l.id];
    board.tasks[nl.id] = shared.tasks(nl.id);
    hooks.onListMoved(l.id, nl.id);
  }
  return true;
}

/** «Как меня видят» (окно «Участники»): имя, цвет, фото — одно на все общие сферы, хранится в настройках слоя. */
export async function saveProfile(p) {
  const f = sh.profileFields(p);
  touch('settings', 'profile', f);
  save();
  try { await shared.applyProfile(f); share.ver++; say('Готово: так тебя видят во всех общих сферах'); }
  catch (e) { say('Не удалось обновить профиль в сферах: ' + e); }
}

export async function inviteTo(sid, emails) {
  const cal = sh.calOfSphere(sid);
  let n = 0;
  for (const e of emails) {
    try { await shared.invite(cal, e); n++; } catch (err) { say(`Не удалось позвать ${e}: ${err}`); }
    share.ver++;
  }
  if (n) say(n === 1 ? `Позвали ${emails[0]} — Google пришлёт письмо` : `Позвали ${n} ${plural(n, ['человека', 'человек', 'человек'])} — Google пришлёт письма`);
}

/** «Убрать» / «Отозвать» — без вопроса, но 6 с на «Отменить» (docs/design-v2.md, «Общие сферы» 1). */
export function removePerson(sid, p) {
  const key = `${sid}|${p.email}`;
  share.hidden = [...share.hidden, key];
  const timer = setTimeout(async () => {
    leaving.delete(key);
    try { await shared.removeMember(sh.calOfSphere(sid), p.email); }
    catch (e) { say('Не удалось убрать: ' + e); }
    share.hidden = share.hidden.filter((x) => x !== key);
    share.ver++;
  }, 6000);
  leaving.set(key, timer);
  say(p.joined ? `${p.name} больше не в сфере` : `Приглашение ${p.email} отозвано`, () => {
    clearTimeout(leaving.get(key));
    leaving.delete(key);
    share.hidden = share.hidden.filter((x) => x !== key);
  });
}

export async function copyInvite(sid) {
  const sp = spheresFrom(layer.data).find((s) => s.id === sid);
  try { await navigator.clipboard.writeText(shared.inviteText(sh.calOfSphere(sid), sp?.name ?? '')); say('Приглашение скопировано — отправь его в любой мессенджер'); }
  catch { say('Не удалось скопировать'); }
}
