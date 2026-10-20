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
    return { items: [{ id: 'primary', summary: 'Основной', primary: true, backgroundColor: '#7FA6E8', accessRole: 'owner' }] };
  }
  if (method === 'POST') return { id: 'E' + n++, ...body };
  return { items: [] };
}

export async function invoke(cmd, args = {}) {
  await new Promise((r) => setTimeout(r, 40));
  switch (cmd) {
    case 'auth_status': return { has_secret: true, signed_in: true };
    case 'layer_read': return structuredClone(layer);
    case 'layer_write': layer = structuredClone(args.data); return null;
    case 'login': case 'logout': case 'save_client_secret': return null;
    case 'gapi': {
      const u = new URL(args.url);
      const q = u.searchParams;
      if (u.host === 'tasks.googleapis.com') return tasksApi(args.method, u.pathname.replace('/tasks/v1/', ''), q, args.body);
      return calApi(args.method, u.pathname.replace('/calendar/v3/', ''), q, args.body);
    }
  }
  console.warn('[demo] неизвестная команда', cmd);
  return null;
}

export const isTauri = () => false;
