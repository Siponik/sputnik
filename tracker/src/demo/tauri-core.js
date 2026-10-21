// Демо-режим (npm run demo): трекер открывается в обычном браузере, без Tauri и без Google.
// Подменяет invoke(): Google Tasks и Calendar — выдуманные данные в памяти, слой — в памяти (?fresh — сначала).
// Нужен, чтобы видеть экран и сравнивать с макетами (design/screens/ref/*.png). Ничего не уходит в сеть.
import { seedLists, seedTasks, seedLayer } from './data.js';

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

function calApi(method, path, q, body) {
  if (/^users\/me\/calendarList/.test(path)) {
    return { items: [{ id: 'primary', summary: 'Основной', primary: true, backgroundColor: '#7FA6E8', accessRole: 'owner' },
      { id: 'work@demo', summary: 'Работа', backgroundColor: '#E0A04A', accessRole: 'owner' }] };
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
  await new Promise((r) => setTimeout(r, 40));
  switch (cmd) {
    case 'auth_status': return { has_secret: true, signed_in: true };
    case 'layer_read': return structuredClone(layer);
    case 'layer_write': layer = structuredClone(args.data); return null;
    case 'login': case 'logout': case 'save_client_secret': return null;
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
