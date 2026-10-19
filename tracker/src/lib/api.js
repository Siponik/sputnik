// Запросы к Google идут через Rust (команда gapi): там живёт токен входа.
import { invoke } from '@tauri-apps/api/core';

const TASKS = 'https://tasks.googleapis.com/tasks/v1';
const CAL = 'https://www.googleapis.com/calendar/v3';

export const gapi = (method, url, body = null) => invoke('gapi', { method, url, body });

export const auth = {
  status: () => invoke('auth_status'),
  saveSecret: (contents) => invoke('save_client_secret', { contents }),
  login: () => invoke('login'),
  logout: () => invoke('logout'),
};

export const layer = {
  read: () => invoke('layer_read'),
  write: (data) => invoke('layer_write', { data }),
};

// ---------- Google Tasks ----------

export async function listLists() {
  const r = await gapi('GET', `${TASKS}/users/@me/lists?maxResults=100`);
  return r?.items ?? [];
}

export const createList = (title) => gapi('POST', `${TASKS}/users/@me/lists`, { title });

export async function listTasks(listId) {
  let items = [];
  let page = '';
  do {
    const q = `maxResults=100&showCompleted=true&showHidden=true${page ? `&pageToken=${encodeURIComponent(page)}` : ''}`;
    const r = await gapi('GET', `${TASKS}/lists/${encodeURIComponent(listId)}/tasks?${q}`);
    items = items.concat(r?.items ?? []);
    page = r?.nextPageToken ?? '';
  } while (page);
  return items;
}

export function createTask(listId, body, parent = null) {
  const q = parent ? `?parent=${encodeURIComponent(parent)}` : '';
  return gapi('POST', `${TASKS}/lists/${encodeURIComponent(listId)}/tasks${q}`, body);
}

export function patchTask(listId, taskId, patch) {
  return gapi('PATCH', `${TASKS}/lists/${encodeURIComponent(listId)}/tasks/${encodeURIComponent(taskId)}`, patch);
}

export function deleteTask(listId, taskId) {
  return gapi('DELETE', `${TASKS}/lists/${encodeURIComponent(listId)}/tasks/${encodeURIComponent(taskId)}`);
}

export const completeTask = (listId, taskId, done) =>
  patchTask(listId, taskId, done ? { status: 'completed' } : { status: 'needsAction', completed: null });

// ---------- Google Calendar ----------

export async function eventsForDay(day = new Date()) {
  const start = new Date(day); start.setHours(0, 0, 0, 0);
  const end = new Date(start); end.setDate(end.getDate() + 1);
  const cals = await gapi('GET', `${CAL}/users/me/calendarList?minAccessRole=reader`);
  const chosen = (cals?.items ?? []).filter((c) => c.selected !== false);
  const lists = await Promise.all(chosen.map(async (c) => {
    try {
      const q = new URLSearchParams({ timeMin: start.toISOString(), timeMax: end.toISOString(), singleEvents: 'true', orderBy: 'startTime', maxResults: '50' });
      const r = await gapi('GET', `${CAL}/calendars/${encodeURIComponent(c.id)}/events?${q}`);
      return (r?.items ?? []).filter((e) => e.status !== 'cancelled').map((e) => ({ ...e, calendar: c.summaryOverride || c.summary }));
    } catch { return []; }
  }));
  return lists.flat().sort((a, b) => (a.start?.dateTime || a.start?.date || '').localeCompare(b.start?.dateTime || b.start?.date || ''));
}

// ---------- даты ----------

export const ymd = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
export const dueToYmd = (due) => (due ? due.slice(0, 10) : '');
export const ymdToDue = (s) => (s ? `${s}T00:00:00.000Z` : null);

const MONTHS = ['янв.', 'февр.', 'мар.', 'апр.', 'мая', 'июн.', 'июл.', 'авг.', 'сент.', 'окт.', 'нояб.', 'дек.'];
const DAYS = ['вс', 'пн', 'вт', 'ср', 'чт', 'пт', 'сб'];
export function humanDue(due) {
  if (!due) return '';
  const s = dueToYmd(due);
  const [y, m, d] = s.split('-').map(Number);
  const date = new Date(y, m - 1, d);
  const today = new Date(); today.setHours(0, 0, 0, 0);
  const diff = Math.round((date - today) / 864e5);
  if (diff === 0) return 'сегодня';
  if (diff === 1) return 'завтра';
  if (diff === -1) return 'вчера';
  return `${DAYS[date.getDay()]}, ${d} ${MONTHS[m - 1]}`;
}
export function dueState(task) {
  if (!task.due || task.status === 'completed') return '';
  const s = dueToYmd(task.due);
  const t = ymd(new Date());
  if (s < t) return 'overdue';
  if (s === t) return 'soon';
  return '';
}
