// Демо-режим (npm run demo): трекер открывается в обычном браузере, без Tauri и без Google.
// Подменяет invoke(): Google Tasks и Calendar — выдуманные данные в памяти, слой — в памяти (?fresh — сначала).
// Нужен, чтобы видеть экран и сравнивать с макетами (design/screens/ref/*.png). Ничего не уходит в сеть.
import { seedLists, seedTasks, seedLayer, seedInbox, seedShared, DEMO_ME } from './data.js';

const lists = seedLists();
const tasks = seedTasks(); // { listId: [task] }
let layer = seedLayer();
let n = 1000;
const now = () => new Date().toISOString();

function tasksApi(method, path, q, body) {
  let m;
  if ((m = /^users\/@me\/lists$/.exec(path))) {
    if (method === 'GET') return { items: lists };
    const l = { id: 'L' + n++, title: body.title, updated: now() };
    lists.push(l); tasks[l.id] = [];
    return l;
  }
  if ((m = /^users\/@me\/lists\/([^/]+)$/.exec(path))) {
    const id = decodeURIComponent(m[1]);
    if (method === 'GET') return id === '@default' ? lists[0] : lists.find((l) => l.id === id);
    if (method === 'DELETE') {
      if (id === lists[0]?.id) throw new Error('400 Invalid Value'); // основной список Google не удаляет
      lists.splice(lists.findIndex((l) => l.id === id), 1); delete tasks[id]; return null;
    }
  }
  if ((m = /^lists\/([^/]+)\/tasks$/.exec(path))) {
    const id = decodeURIComponent(m[1]);
    tasks[id] ??= [];
    if (method === 'GET') return { items: tasks[id] };
    const t = { id: 'T' + n++, status: 'needsAction', updated: now(), ...body };
    if (q.get('parent')) t.parent = q.get('parent');
    tasks[id].unshift(t);
    return t;
  }
  if ((m = /^lists\/([^/]+)\/tasks\/([^/]+)(\/move)?$/.exec(path))) {
    const id = decodeURIComponent(m[1]), tid = decodeURIComponent(m[2]);
    const arr = tasks[id] ?? [];
    const i = arr.findIndex((t) => t.id === tid);
    if (m[3]) {
      const dest = q.get('destinationTasklist');
      const [t] = arr.splice(i, 1);
      (tasks[dest] ??= []).unshift(t);
      return t;
    }
    if (method === 'DELETE') { arr.splice(i, 1); return null; }
    if (method === 'PATCH') {
      Object.assign(arr[i], body, { updated: now() });
      if (body.status === 'completed' && !arr[i].completed) arr[i].completed = now();
      if (body.status === 'needsAction') delete arr[i].completed;
      return arr[i];
    }
    return arr[i];
  }
  return {};
}

// Календари общих сфер (lib/shared.js) в памяти: календари, события с «токеном изменений», доступы.
const cals = {}; // id → { summary, description, role, events: { id: { ev, at } }, acl: [] }
let calTick = 1;
for (const c of seedShared()) cals[c.id] = { summary: c.summary, description: c.description, role: c.role, acl: [], events: Object.fromEntries(c.recs.map((ev) => [ev.id, { ev: { ...ev, status: 'confirmed' }, at: calTick++ }])) };
if (typeof window !== 'undefined') window.__demoCals = cals;
const httpErr = (code, msg) => { throw new Error(`${code} ${msg} (демо)`); };

function sphereCalApi(method, path, q, body) {
  let m;
  if (path === 'calendars' && method === 'POST') {
    const id = 'c' + n++ + '@group.calendar.google.com';
    cals[id] = { summary: body.summary, description: body.description, role: 'owner', events: {}, acl: [] };
    return { id, summary: body.summary, description: body.description };
  }
  if ((m = /^users\/me\/calendarList\/(.+)$/.exec(path))) {
    const id = decodeURIComponent(m[1]);
    if (method === 'DELETE') { delete cals[id]; return null; }
    return { id };
  }
  if (path === 'users/me/calendarList' && method === 'POST') {
    const c = cals[body.id] ?? httpErr(404, 'Not Found');
    return { id: body.id, summary: c.summary, description: c.description };
  }
  if (!(m = /^calendars\/([^/]+)(?:\/(events|acl)(?:\/([^/]+))?)?$/.exec(path))) return undefined;
  const id = decodeURIComponent(m[1]), c = cals[id];
  if (!c) return undefined;
  if (!m[2]) { if (method === 'DELETE') { delete cals[id]; return null; } return { id, summary: c.summary }; }
  if (m[2] === 'acl') {
    if (method === 'GET') return { items: [{ id: 'user:' + DEMO_ME, role: 'owner', scope: { type: 'user', value: DEMO_ME } }, ...c.acl] };
    if (method === 'POST') { const a = { id: 'user:' + body.scope.value, role: body.role, scope: body.scope }; c.acl = [...c.acl.filter((x) => x.id !== a.id), a]; return a; }
    if (method === 'DELETE') { c.acl = c.acl.filter((x) => x.id !== decodeURIComponent(m[3])); return null; }
  }
  const eid = m[3] && decodeURIComponent(m[3]);
  if (!eid && method === 'GET') {
    const since = Number(q.get('syncToken') || 0);
    const items = Object.values(c.events).filter((x) => x.at > since && (since || x.ev.status !== 'cancelled')).map((x) => structuredClone(x.ev));
    return { items, nextSyncToken: String(calTick) };
  }
  if (!eid && method === 'POST') {
    if (c.events[body.id] && c.events[body.id].ev.status !== 'cancelled') httpErr(409, 'duplicate');
    if (c.events[body.id]) httpErr(409, 'duplicate');
    c.events[body.id] = { ev: { ...structuredClone(body), status: 'confirmed' }, at: ++calTick };
    return structuredClone(c.events[body.id].ev);
  }
  const x = c.events[eid];
  if (method === 'GET') { if (!x || x.ev.status === 'cancelled') httpErr(404, 'Not Found'); return structuredClone(x.ev); }
  if (method === 'PUT') { c.events[eid] = { ev: { ...structuredClone(body), id: eid, status: 'confirmed' }, at: ++calTick }; return structuredClone(c.events[eid].ev); }
  if (method === 'DELETE') { if (!x) httpErr(404, 'Not Found'); c.events[eid] = { ev: { id: eid, status: 'cancelled' }, at: ++calTick }; return null; }
  return undefined;
}

function calApi(method, path, q, body) {
  const sph = sphereCalApi(method, path, q, body);
  if (sph !== undefined) return sph;
  if (/^users\/me\/calendarList/.test(path)) {
    return { items: [{ id: DEMO_ME, summary: 'Основной', primary: true, backgroundColor: '#7FA6E8', accessRole: 'owner' },
      { id: 'work@demo', summary: 'Работа', backgroundColor: '#E0A04A', accessRole: 'owner' },
      { id: 'queue@demo', summary: 'Спутник · входящие', backgroundColor: '#888888', accessRole: 'owner' },
      ...Object.entries(cals).map(([id, c]) => ({ id, summary: c.summary, description: c.description, accessRole: c.role, selected: false }))] };
  }
  if (path.startsWith('calendars/queue%40demo/') || path.startsWith('calendars/queue@demo/')) {
    return { items: q.get('timeMin')?.startsWith('2029') ? [{ id: 'st', summary: 'Спутник · статус', description: JSON.stringify(seedInbox()) }] : [] };
  }
  if (method === 'POST') return { id: 'E' + n++, ...body };
  return { items: [] };
}

// Google Drive в памяти: файл напоминаний и копия слоя в appDataFolder (lib/layer.js).
const drive = {};
if (typeof window !== 'undefined') window.__demoDrive = drive; // для проверки синхронизации из Playwright
function driveApi(method, path, q, body) {
  const id = path.match(/\/files\/([^/?]+)/)?.[1];
  if (method === 'GET' && !id) {
    const name = /name='([^']+)'/.exec(q.get('q') ?? '')?.[1];
    const prop = /value='([^']+)'/.exec(q.get('q') ?? '')?.[1];
    return { files: Object.entries(drive).filter(([, f]) => (name ? f.name === name : f.props?.sputnik === prop)).map(([fid]) => ({ id: fid })) };
  }
  if (method === 'GET') return structuredClone(drive[id]?.data ?? null);
  if (method === 'POST') { const fid = 'F' + n++; drive[fid] = { name: body?.name, props: body?.appProperties, data: null }; return { id: fid }; }
  if (method === 'PATCH' && id) { drive[id] = { ...drive[id], data: structuredClone(body) }; return { id }; }
  return {};
}

export async function invoke(cmd, args = {}) {
  // Задержка «сети» в демо: localStorage demo.delay (мс) — чтобы ловить гонки, как с настоящим Google.
  let ms = 40;
  try { ms = Number(localStorage.getItem('demo.delay')) || 40; } catch {}
  await new Promise((r) => setTimeout(r, ms));
  switch (cmd) {
    case 'auth_status': return { has_secret: true, signed_in: true };
    case 'layer_read': return structuredClone(layer);
    case 'layer_write': layer = structuredClone(args.data); return null;
    case 'login': case 'logout': case 'save_client_secret': return null;
    case 'backups_last': return new Date().toISOString().slice(0, 10);
    case 'open_place': console.info('[demo] открыть', args.place); return null;
    case 'gapi': {
      // window.__demo = { offline: true } — «нет связи», { login: true } — нет права на скрытую папку Drive (слой).
      const d = globalThis.__demo ?? {};
      if (d.offline) throw 'error sending request for url (демо: нет связи)';
      const u = new URL(args.url);
      if (d.login && u.pathname.includes('/drive/v3/') && /appDataFolder|spaces=appData/.test(args.url)) throw '403 insufficient scope (демо)';
      const q = u.searchParams;
      if (u.host === 'tasks.googleapis.com') return tasksApi(args.method, u.pathname.replace('/tasks/v1/', ''), q, args.body);
      if (u.pathname.includes('/drive/v3/')) return driveApi(args.method, u.pathname, q, args.body);
      return calApi(args.method, u.pathname.replace('/calendar/v3/', ''), q, args.body);
    }
  }
  console.warn('[demo] неизвестная команда', cmd);
  return null;
}

export const isTauri = () => false;
