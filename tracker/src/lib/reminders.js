// Напоминания. В Google Tasks их нет, поэтому правило хранится в слое: tasks[id].remind.
//   { kind: 'before', days: 0..7, time: 'HH:MM' } — за N дней до срока в это время (0 — в день срока);
//   { kind: 'at', at: 'YYYY-MM-DDTHH:MM' } — в точное время (местное).
// Трекер кладёт список ближайших напоминаний в файл на Google Drive (папка «Спутник»),
// а скрипт Google Apps Script (reminders/Code.gs) раз в минуту читает его и пишет в Telegram.
import { gapi, dueToYmd } from './api.js';

export const BEFORE = [
  { days: 0, name: 'В день срока' },
  { days: 1, name: 'За 1 день' },
  { days: 2, name: 'За 2 дня' },
  { days: 3, name: 'За 3 дня' },
  { days: 7, name: 'За неделю' },
];
export const DEFAULT_TIME = '10:00';

/** Момент срабатывания или null. */
export function fireAt(remind, task) {
  if (!remind) return null;
  if (remind.kind === 'at') {
    const d = remind.at ? new Date(remind.at) : null;
    return d && !isNaN(d) ? d : null;
  }
  if (remind.kind === 'before') {
    const ymd = dueToYmd(task.due);
    if (!ymd) return null;
    const [y, m, d] = ymd.split('-').map(Number);
    const [hh, mm] = (remind.time || DEFAULT_TIME).split(':').map(Number);
    return new Date(y, m - 1, d - (remind.days || 0), hh, mm);
  }
  return null;
}

export function remindLabel(remind, task) {
  const at = fireAt(remind, task);
  if (!at) return '';
  const day = at.toLocaleDateString('ru-RU', { day: 'numeric', month: 'short' });
  const time = at.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' });
  return `${day}, ${time}`;
}

/** Список для облака: открытые задачи с напоминанием, которое ещё не прошло (или прошло меньше суток назад).
 *  cheers — свежие вехи серий привычек: бот поздравит сразу (fireAt = момент вехи). */
export function collect(lists, tasksByList, layTasks, habitList = null, cheers = []) {
  const now = Date.now();
  const items = [];
  for (const l of lists) {
    for (const t of tasksByList[l.id] ?? []) {
      if (t.status === 'completed' || t.deleted) continue;
      const at = fireAt(layTasks?.[t.id]?.remind, t);
      if (!at || at.getTime() < now - 864e5) continue;
      items.push({
        key: `${t.id}|${at.toISOString()}`,
        taskId: t.id,
        listId: l.id,
        list: l.title,
        title: t.title || 'Без названия',
        note: (t.notes ?? '').split('\n')[0].slice(0, 200),
        due: dueToYmd(t.due),
        fireAt: at.toISOString(),
      });
    }
  }
  if (habitList) {
    for (const c of cheers) {
      items.push({
        key: `cheer|${c.habit.id}|${c.key}`,
        kind: 'milestone',
        taskId: c.habit.id,
        listId: habitList.id,
        list: habitList.title,
        title: `🎉 ${c.text}`,
        note: 'Новая веха серии. Енот празднует!',
        due: '',
        fireAt: c.at,
      });
    }
  }
  return items.sort((a, b) => a.fireAt.localeCompare(b.fireAt));
}

// ---------- файл на Google Drive ----------

const DRIVE = 'https://www.googleapis.com/drive/v3';
const UPLOAD = 'https://www.googleapis.com/upload/drive/v3';
export const FILE_NAME = 'sputnik-reminders.json';
let folderId = null;
let fileId = null;
let lastBody = '';

async function findByProp(value) {
  const q = encodeURIComponent(`appProperties has { key='sputnik' and value='${value}' } and trashed=false`);
  const r = await gapi('GET', `${DRIVE}/files?q=${q}&fields=files(id)&pageSize=1`);
  return r?.files?.[0]?.id ?? null;
}

async function ensureFolder() {
  if (folderId) return folderId;
  folderId = await findByProp('folder');
  if (!folderId) {
    const f = await gapi('POST', `${DRIVE}/files?fields=id`, { name: 'Спутник', mimeType: 'application/vnd.google-apps.folder', appProperties: { sputnik: 'folder' } });
    folderId = f.id;
  }
  return folderId;
}

/** Записывает список напоминаний на Drive, если он изменился. */
export async function publish(items) {
  const body = JSON.stringify(items);
  if (body === lastBody) return;
  if (!fileId) fileId = await findByProp('reminders');
  if (!fileId) {
    const parent = await ensureFolder();
    const f = await gapi('POST', `${DRIVE}/files?fields=id`, { name: FILE_NAME, parents: [parent], mimeType: 'application/json', appProperties: { sputnik: 'reminders' } });
    fileId = f.id;
  }
  await gapi('PATCH', `${UPLOAD}/files/${fileId}?uploadType=media`, { version: 1, updated: new Date().toISOString(), items });
  lastBody = body;
}
