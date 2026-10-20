// Напоминания. В Google Tasks их нет, поэтому правило хранится в слое: tasks[id].remind.
//   { kind: 'before', days: 0..7, time: 'HH:MM' } — за N дней до срока в это время (0 — в день срока);
//   { kind: 'at', at: 'YYYY-MM-DDTHH:MM' } — в точное время (местное);
//   { kind: 'lead', min: N } — за N минут до начала: срок + время задачи (slot.s), без времени — срок в DEFAULT_TIME.
//     Следует за сроком и временем, когда их переносят. Его же ставит «напоминание по умолчанию» (settings.remind).
// tasks[id].remind — одно правило или массив (несколько напоминаний: «за день» и «за час»).
// У событий и дней рождения, созданных в Спутнике, напоминания живут в самом событии Google Календаря:
// extendedProperties.private.sputnikRemind = '15,60' (минуты до начала) и метка sputnikR = '1' для поиска.
// Трекер кладёт список ближайших напоминаний в файл на Google Drive (папка «Спутник»),
// а скрипт Google Apps Script (reminders/Code.gs) раз в минуту читает его и пишет в Telegram.
import { gapi, dueToYmd } from './api.js';

export const BEFORE = [
  { days: 0, name: 'В день срока' },
  { days: 1, name: 'За 1 день' },
  { days: 2, name: 'За 2 дня' },
  { days: 3, name: 'За 3 дня' },
  { days: 7, name: 'За неделю' },
  { days: 30, name: 'За месяц' },
];
// «До начала»: сколько минут до срока/времени задачи.
export const LEADS = [
  { min: 0, name: 'В момент начала' },
  { min: 15, name: 'За 15 минут' },
  { min: 60, name: 'За час' },
  { min: 1440, name: 'За день' },
  { min: 10080, name: 'За неделю' },
  { min: 43200, name: 'За месяц' },
];
// Дню рождения минуты и часы ни к чему; «в день» — в DEFAULT_TIME.
export const BDAY_LEADS = [
  { min: 0, name: 'В день рождения' },
  { min: 1440, name: 'За день' },
  { min: 4320, name: 'За 3 дня' },
  { min: 10080, name: 'За неделю' },
  { min: 43200, name: 'За месяц' },
];
export const leadsFor = (kind) => (kind === 'birthday' ? BDAY_LEADS : LEADS);
// Пока в настройках ничего не выбрано.
const DEFAULTS = { task: [60], event: [15], birthday: [1440, 0] };

/** Минуты напоминаний по умолчанию для task | event | birthday.
 *  settings.remind = { task: [...], event: [...], birthday: [...] }; старая запись { min } — для задач. */
export function defaultMins(settings, kind = 'task') {
  const r = settings?.remind;
  if (Array.isArray(r?.[kind])) return r[kind];
  if (kind === 'task' && r && 'min' in r) return r.min == null ? [] : [r.min];
  return DEFAULTS[kind];
}
/** Правило(а) для новой задачи или null. */
export function defaultRule(settings) { return minsToRule(defaultMins(settings, 'task')); }
export function minsToRule(mins) {
  const rules = [...new Set(mins)].sort((a, b) => b - a).map((min) => ({ kind: 'lead', min }));
  return !rules.length ? null : rules.length === 1 ? rules[0] : rules;
}
export const rulesOf = (r) => (!r ? [] : Array.isArray(r) ? r : [r]);
export const leadName = (min, kind = 'task') => leadsFor(kind).find((l) => l.min === min)?.name ?? LEADS.find((l) => l.min === min)?.name ?? `За ${min} мин`;
/** «за день и за час» */
export const leadsText = (mins, kind = 'task') => mins.slice().sort((a, b) => b - a).map((m) => leadName(m, kind).toLowerCase()).join(' и ');
export const DEFAULT_TIME = '10:00';

/** Момент срабатывания или null. slot — время задачи из слоя ({ s, e } или null). */
export function fireAt(remind, task, slot = null) {
  if (!remind) return null;
  if (remind.kind === 'lead') {
    const ymd = dueToYmd(task.due);
    if (!ymd) return null;
    const [y, m, d] = ymd.split('-').map(Number);
    const [hh, mm] = (slot?.s || DEFAULT_TIME).split(':').map(Number);
    return new Date(y, m - 1, d, hh, mm - (remind.min || 0));
  }
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

/** Подпись ближайшего напоминания («21 окт., 09:00»); remind — правило или массив. */
export function remindLabel(remind, task, slot = null) {
  const all = rulesOf(remind).map((r) => fireAt(r, task, slot)).filter(Boolean).sort((a, b) => a - b);
  if (!all.length) return '';
  const at = all.find((d) => d.getTime() > Date.now()) ?? all[all.length - 1];
  const day = at.toLocaleDateString('ru-RU', { day: 'numeric', month: 'short' });
  const time = at.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' });
  return `${day}, ${time}`;
}

// Прошедшее «до начала» не добавляем в файл (иначе бот пришлёт его сразу после создания задачи),
// но и не выкидываем, если оно уже там: скрипт может заглянуть в файл на пару минут позже срабатывания.
let publishedFrom = '';
let published = new Set();
function wasPublished(key) {
  if (publishedFrom !== lastBody) {
    publishedFrom = lastBody;
    const b = lastBody ? JSON.parse(lastBody) : [];
    published = new Set((Array.isArray(b) ? b : b.items ?? []).map((x) => x.key));
  }
  return published.has(key);
}

/** Список для облака: открытые задачи с напоминанием, которое ещё не прошло (или прошло меньше суток назад).
 *  cheers — свежие вехи серий привычек: бот поздравит сразу (fireAt = момент вехи). */
export function collect(lists, tasksByList, layTasks, habitList = null, cheers = [], events = []) {
  const now = Date.now();
  const items = [];
  for (const l of lists) {
    for (const t of tasksByList[l.id] ?? []) {
      if (t.status === 'completed' || t.deleted) continue;
      for (const r of rulesOf(layTasks?.[t.id]?.remind)) {
        const at = fireAt(r, t, layTasks?.[t.id]?.slot);
        if (!at || at.getTime() < now - 864e5) continue;
        const key = `${t.id}|${at.toISOString()}`;
        // «За день» у задачи на сегодня уже в прошлом — не шлём сразу после создания или переноса.
        if (r.kind === 'lead' && at.getTime() < now - 120e3 && !wasPublished(key)) continue;
        items.push({
          key,
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
  }
  // События и дни рождения с напоминаниями Спутника (api.remindEvents — ближайшие 32 дня, повторы развёрнуты).
  for (const e of events) {
    const mins = String(e.extendedProperties?.private?.sputnikRemind ?? '').split(',').filter((x) => x !== '').map(Number);
    const allDay = !e.start?.dateTime;
    const startAt = allDay ? (() => { const [y, m, d] = e.start.date.split('-').map(Number); const [hh, mm] = DEFAULT_TIME.split(':').map(Number); return new Date(y, m - 1, d, hh, mm); })() : new Date(e.start.dateTime);
    const birthday = e.extendedProperties?.private?.sputnik === 'birthday';
    for (const min of mins) {
      if (!Number.isFinite(min)) continue;
      const at = new Date(startAt.getTime() - min * 60e3);
      const key = `ev|${e.id}|${at.toISOString()}`;
      if (at.getTime() < now - 120e3 && !(wasPublished(key) && at.getTime() > now - 864e5)) continue;
      items.push({
        key,
        kind: birthday ? 'birthday' : 'event',
        title: birthday ? String(e.summary ?? '').replace(/^🎂\s*/, '') : e.summary || 'Событие',
        note: (e.description ?? '').split('\n')[0].slice(0, 200),
        list: birthday ? 'День рождения' : 'Google Календарь',
        due: allDay ? e.start.date : '',
        start: allDay ? '' : e.start.dateTime,
        lead: leadName(min, birthday ? 'birthday' : 'event'),
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
