// Спутник · «Входящие от Claude»: задачи в Google Tasks из любого чата Claude.
// Схема — docs/claude-inbox.md. Канал — календарь-очередь «Спутник · входящие»:
// Claude создаёт в нём событие, в описании которого JSON-запрос; этот обработчик раз в минуту
// (из tick() в Code.gs) выполняет запрос в Google Tasks, пишет итог в статус и удаляет событие.
// Статус — не файл на Drive (Drive бывает переполнен), а служебное событие «Спутник · статус»
// в этом же календаре, 1 января 2030 года; JSON в описании. Claude читает его через подключение Календаря.

const INBOX_CALENDAR = 'Спутник · входящие';
const STATUS_TITLE = 'Спутник · статус';
const STATUS_DATE = new Date(2030, 0, 1);
const KEEP_PROCESSED_MS = 14 * 24 * 3600 * 1000;
const KEEP_PROCESSED_MAX = 40; // описание события — до ~8 тыс. символов
const KEEP_LAYER_MS = 30 * 24 * 3600 * 1000;
const KEEP_LAYER_MAX = 60;
const KEEP_LISTS_MAX = 20;
// Описание события статуса — до ~8 тыс. символов. Не влезает — сначала уходят старые итоги запросов, потом старые поля слоя.
const STATUS_BUDGET = 7800;
const DEDUP_MS = 2 * 24 * 3600 * 1000;
const OPS = ['list.ensure', 'task.create', 'task.complete'];

/** Запустить один раз: создаёт календарь-очередь и событие статуса. Повторный запуск безопасен. */
function setupInbox() {
  const cal = inboxCalendar_(true);
  const status = readStatus_();
  status.lists = (Tasks.Tasklists.list({ maxResults: 100 }).items || []).map((l) => l.title);
  writeStatus_(status);
  console.log('Календарь-очередь: ' + cal.getId());
  send_('🛰 Спутник: «Входящие от Claude» подключены. Задачи из чатов Claude будут появляться в Google Tasks.');
}

function inboxCalendar_(create) {
  const props = PropertiesService.getScriptProperties();
  const id = props.getProperty('INBOX_CALENDAR_ID');
  let cal = id ? CalendarApp.getCalendarById(id) : null;
  if (!cal) cal = CalendarApp.getCalendarsByName(INBOX_CALENDAR)[0] || null;
  if (!cal && create) {
    // selected: false — события очереди не видны в Google Календаре, но Claude может в него писать.
    cal = CalendarApp.createCalendar(INBOX_CALENDAR, {
      summary: 'Служебный: запросы из чатов Claude в Спутник. Обрабатываются автоматически.',
      selected: false,
      color: CalendarApp.Color.GRAY,
    });
  }
  if (cal) props.setProperty('INBOX_CALENDAR_ID', cal.getId());
  return cal;
}

// ---------- обработка ----------

function inboxTick_() {
  const cal = inboxCalendar_(false);
  if (!cal) return;
  const now = new Date();
  const events = cal.getEvents(new Date(now.getTime() - 30 * 864e5), new Date(now.getTime() + 864e5));
  if (!events.length) return;

  const status = readStatus_();
  let changed = false;
  let lists = null; // загружаем лениво
  const getLists = () => lists || (lists = Tasks.Tasklists.list({ maxResults: 100 }).items || []);

  for (const ev of events) {
    const title = ev.getTitle();
    if (ev.getTag('sputnik') === 'status') continue;
    if (title.indexOf(BRIEF_READY_TITLE) === 0) continue; // отметка «сводка готова» — её читает morningTick_ в Code.gs
    if (title.indexOf('⚠') === 0) continue; // уже помечено ошибкой — ждёт человека
    changed = true;
    let req = null;
    let key = 'event:' + ev.getId();
    try {
      req = parseRequest_(ev.getDescription());
      key = req.id;
      if (status.processed[key]) { ev.deleteEvent(); continue; } // уже выполняли
      const created = [];
      for (const op of req.ops) created.push(runOp_(op, getLists, status));
      status.processed[key] = { ok: true, at: new Date().toISOString(), from: req.from || '', created: created };
      ev.deleteEvent();
    } catch (e) {
      status.processed[key] = { ok: false, at: new Date().toISOString(), error: String(e.message || e) };
      ev.setTitle('⚠ ' + title);
      console.error(key + ': ' + e);
    }
  }

  if (!changed) return;
  const cutoff = Date.now() - KEEP_PROCESSED_MS;
  for (const k of Object.keys(status.processed)) if (Date.parse(status.processed[k].at) < cutoff) delete status.processed[k];
  if (lists) status.lists = lists.map((l) => l.title);
  writeStatus_(status);
}

/** Достаёт JSON из описания события, даже если Calendar обернул его в HTML. */
function parseRequest_(description) {
  let text = String(description || '')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&quot;/g, '"').replace(/&#39;|&apos;/g, "'").replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&nbsp;/g, ' ').replace(/&#(\d+);/g, (m, n) => String.fromCharCode(Number(n)))
    .replace(/&amp;/g, '&');
  const a = text.indexOf('{'), b = text.lastIndexOf('}');
  if (a < 0 || b < a) throw new Error('В описании нет JSON');
  let req;
  try { req = JSON.parse(text.slice(a, b + 1)); } catch (e) { throw new Error('JSON не разбирается: ' + e.message); }

  if (req.sputnik !== 1) throw new Error('Нужно поле "sputnik": 1');
  if (typeof req.id !== 'string' || !req.id || req.id.length > 64) throw new Error('Нужен "id" (строка до 64 символов)');
  if (!Array.isArray(req.ops) || !req.ops.length || req.ops.length > 30) throw new Error('"ops" — от 1 до 30 операций');
  req.ops.forEach((op, i) => {
    const where = 'ops[' + i + ']: ';
    if (OPS.indexOf(op.op) < 0) throw new Error(where + 'неизвестная операция ' + op.op);
    if (typeof op.list !== 'string' || !op.list.trim() || op.list.length > 100) throw new Error(where + 'нужен "list"');
    if (op.op !== 'list.ensure') {
      if (typeof op.title !== 'string' || !op.title.trim() || op.title.length > 250) throw new Error(where + '"title" от 1 до 250 символов');
    }
    if (op.notes != null && (typeof op.notes !== 'string' || op.notes.length > 4000)) throw new Error(where + '"notes" до 4000 символов');
    if (op.due != null && !/^\d{4}-\d{2}-\d{2}$/.test(op.due)) throw new Error(where + '"due" в виде ГГГГ-ММ-ДД');
    if (op.parent != null && typeof op.parent !== 'string') throw new Error(where + '"parent" — название задачи');
    if (op.layer != null && (typeof op.layer !== 'object' || Array.isArray(op.layer) || JSON.stringify(op.layer).length > 1500)) throw new Error(where + '"layer" — объект до 1500 символов');
    if (op.done != null && typeof op.done !== 'boolean') throw new Error(where + '"done" — true или false');
  });
  return req;
}

function findList_(lists, name) {
  const n = name.trim();
  return lists.find((l) => l.title === n) || lists.find((l) => l.title.trim().toLowerCase() === n.toLowerCase()) || null;
}

function ensureList_(getLists, name) {
  const lists = getLists();
  let l = findList_(lists, name);
  if (!l) { l = Tasks.Tasklists.insert({ title: name.trim() }); lists.push(l); }
  return l;
}

function openTasks_(listId) {
  let out = [], page;
  do {
    const r = Tasks.Tasks.list(listId, { maxResults: 100, showCompleted: false, pageToken: page });
    out = out.concat(r.items || []);
    page = r.nextPageToken;
  } while (page);
  return out;
}

function runOp_(op, getLists, status) {
  const list = ensureList_(getLists, op.list);
  if (op.op === 'list.ensure') {
    // Поля списка (шаблон, вид, сфера, темы) тоже ждут трекер — в pendingLists.
    if (op.layer) status.pendingLists[list.id] = Object.assign({ at: new Date().toISOString() }, op.layer);
    return { op: op.op, list: list.title };
  }

  const open = openTasks_(list.id);
  const title = op.title.trim();

  if (op.op === 'task.complete') {
    const t = open.find((x) => x.title === title);
    if (!t) throw new Error('Открытой задачи «' + title + '» в «' + list.title + '» нет');
    Tasks.Tasks.patch({ status: 'completed' }, list.id, t.id);
    return { op: op.op, list: list.title, title: title, taskId: t.id };
  }

  // task.create. Защита от двойной обработки: такая же открытая задача, созданная недавно.
  const twin = open.find((x) => x.title === title && Date.now() - Date.parse(x.updated) < DEDUP_MS);
  if (twin) return { op: op.op, list: list.title, title: title, taskId: twin.id, existed: true };

  const opts = {};
  if (op.parent) {
    const p = open.find((x) => x.title === op.parent.trim() && !x.parent);
    if (!p) throw new Error('Родительской задачи «' + op.parent + '» в «' + list.title + '» нет');
    opts.parent = p.id;
  }
  const body = { title: title };
  if (op.notes) body.notes = op.notes;
  if (op.due) body.due = op.due + 'T00:00:00.000Z';
  if (op.done) body.status = 'completed';
  const t = Tasks.Tasks.insert(body, list.id, opts);
  // Поля слоя Спутника ждут здесь, пока трекер не заберёт их в свой слой.
  if (op.layer && typeof op.layer === 'object') status.pendingLayer[t.id] = Object.assign({ listId: list.id, at: new Date().toISOString() }, op.layer);
  return { op: op.op, title: title.slice(0, 40), taskId: t.id };
}

// ---------- статус: служебное событие в календаре-очереди ----------

function statusEvent_() {
  const cal = inboxCalendar_(true);
  const props = PropertiesService.getScriptProperties();
  const id = props.getProperty('STATUS_EVENT_ID');
  let ev = null;
  if (id) { try { ev = cal.getEventById(id); } catch (e) { ev = null; } }
  if (!ev) ev = cal.getEventsForDay(STATUS_DATE).find((e) => e.getTag('sputnik') === 'status') || null;
  if (!ev) {
    ev = cal.createAllDayEvent(STATUS_TITLE, STATUS_DATE, { description: '{}' });
    ev.setTag('sputnik', 'status');
    ev.removeAllReminders();
  }
  props.setProperty('STATUS_EVENT_ID', ev.getId());
  return ev;
}

function readStatus_() {
  let s = {};
  try { s = JSON.parse(statusEvent_().getDescription() || '{}'); } catch (e) { s = {}; }
  s.processed = s.processed || {};
  s.pendingLayer = s.pendingLayer || {};
  s.pendingLists = s.pendingLists || {};
  s.lists = s.lists || [];
  return s;
}

function writeStatus_(s) {
  // Только последние KEEP_PROCESSED_MAX запросов: описание события не резиновое.
  const keys = Object.keys(s.processed).sort((a, b) => Date.parse(s.processed[b].at) - Date.parse(s.processed[a].at));
  for (const k of keys.slice(KEEP_PROCESSED_MAX)) delete s.processed[k];
  // pendingLayer и pendingLists ждут трекер не дольше KEEP_LAYER_MS (задачи из Telegram копят их быстрее, чем чаты Claude).
  const now = Date.now();
  const newest = (o) => Object.keys(o).sort((a, b) => Date.parse(o[b].at) - Date.parse(o[a].at));
  s.pendingLists = s.pendingLists || {};
  for (const o of [s.pendingLayer, s.pendingLists]) {
    for (const k of Object.keys(o)) {
      if (!o[k].at) o[k].at = new Date(now).toISOString();
      if (now - Date.parse(o[k].at) > KEEP_LAYER_MS) delete o[k];
    }
  }
  for (const k of newest(s.pendingLayer).slice(KEEP_LAYER_MAX)) delete s.pendingLayer[k];
  for (const k of newest(s.pendingLists).slice(KEEP_LISTS_MAX)) delete s.pendingLists[k];
  s.version = 1;
  s.updatedAt = new Date().toISOString();
  s.calendarId = inboxCalendar_(true).getId();
  fitStatus_(s);
  statusEvent_().setDescription(JSON.stringify(s));
}

/** Укладывает статус в STATUS_BUDGET: убирает самые старые итоги запросов (оставляет 5), потом самые старые поля слоя. */
function fitStatus_(s) {
  const newest = (o) => Object.keys(o).sort((a, b) => Date.parse(o[b].at) - Date.parse(o[a].at));
  const proc = newest(s.processed), lay = newest(s.pendingLayer);
  while (JSON.stringify(s).length > STATUS_BUDGET) {
    if (proc.length > 5) delete s.processed[proc.pop()];
    else if (lay.length) delete s.pendingLayer[lay.pop()];
    else if (proc.length) delete s.processed[proc.pop()];
    else break;
  }
  return s;
}
