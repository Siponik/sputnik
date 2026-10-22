// Общая сфера — чистая логика, без запросов (их делает lib/shared.js).
// Сфера, которую видят и меняют несколько человек, живёт в своём Google Календаре: Google Tasks поделиться
// не даёт, а календарём — даёт. Каждая запись (сфера, список, задача) — одно служебное событие, в описании
// которого лежит JSON: { v, k, f: { поле: значение }, ft: { поле: время изменения, мс } }.
// Сливаем по полям: у каждого поля побеждает более свежая правка, поэтому двое, поменявшие разные поля
// одной задачи почти одновременно, не затирают друг друга.
//
// Поля задачи: list (ключ списка), title, notes, due, status ('needsAction' | 'completed'), completed, parent, pos —
// как у Google Tasks; поля слоя Спутника (колонка, этап, тема, приоритет…) — с префиксом '$' ('$status', '$type').
// Поля списка: title, created и поля слоя списка с '$' ('$template', '$view', '$topics'…).
// Поля сферы: name, color, icon, owner (почта владельца).
// Участник — своя запись (ключ из почты, memberKey): email, name, order (порядок вступления — от него цвет),
// joined (принял приглашение), seen (последний обмен, не чаще раза в час), removed (убран или вышел). Отдельными записями, а не полем сферы: владелец зовёт,
// а участник в это же время отмечает «принял» — и никто никого не затирает.
// Последний, кто менял запись, — поле by (почта), время — в ft.by.

export const MARK = 'sputnik-sphere'; // метка в описании календаря общей сферы
export const SUMMARY = 'Спутник · служебная запись';
export const PREFIX = 'sh:'; // id общих списков — sh:<ключ>, общих сфер — sh:<id календаря>
export const NOTES_MAX = 6000; // описание события у Google не бесконечное

// Поля слоя, которые у каждого участника свои: напоминания, таймер и учёт времени, решение по «Входящим».
const OWN_TASK = new Set(['t', 'gone', 'timer', 'spent', 'remind', 'inbox', 'pulled', 'cheer', 'given']);
// Раскладка стикеров (group, sort) у каждого своя: «По людям» у одного не должно перекладывать стену другому.
const OWN_LIST = new Set(['t', 'gone', 'hidden', 'sphere', 'group', 'sort', 'cvGroup']);
export const SPHERE_FIELDS = ['name', 'color', 'icon'];

const isObj = (v) => v && typeof v === 'object' && !Array.isArray(v);

/** Одинаковы ли значения (порядок ключей не важен). */
export function same(a, b) {
  if (a === b) return true;
  if ((a ?? null) === null && (b ?? null) === null) return true;
  if (typeof a !== typeof b || a === null || b === null || typeof a !== 'object') return false;
  if (Array.isArray(a) !== Array.isArray(b)) return false;
  const ka = Object.keys(a).filter((k) => a[k] !== undefined), kb = Object.keys(b).filter((k) => b[k] !== undefined);
  return ka.length === kb.length && ka.every((k) => same(a[k], b[k]));
}

// ---------- ключи ----------

// id события Google — только 0-9 и a-v (base32hex), 5–1024 знака. Ключ записи = id её события:
// вид (s — сфера, l — список, t — задача) + 16 случайных знаков.
const B32 = '0123456789abcdefghijklmnopqrstuv';
export function newKey(kind, rnd = Math.random) {
  let s = kind;
  for (let i = 0; i < 16; i++) s += B32[Math.floor(rnd() * 32)];
  return s;
}
export const SPHERE_KEY = 's0000000000000000';
export const kindOf = (k) => (k === SPHERE_KEY ? 'sphere' : ({ l: 'list', t: 'task', m: 'member' })[k?.[0]] ?? null);

/** Ключ записи участника — из почты (одна запись на человека, у всех одинаковая). */
export function memberKey(email) {
  const e = String(email ?? '').trim().toLowerCase();
  let h1 = 0x811c9dc5, h2 = 0x01000193;
  for (let i = 0; i < e.length; i++) { const c = e.charCodeAt(i); h1 = Math.imul(h1 ^ c, 16777619) >>> 0; h2 = Math.imul(h2 + c, 2246822519) >>> 0; }
  let s = 'm';
  for (const h of [h1, h2]) for (let i = 0; i < 8; i++) s += B32[(h >>> (i * 4)) & 31];
  return s;
}

export const isSharedId = (id) => typeof id === 'string' && id.startsWith(PREFIX);
export const listId = (lk) => PREFIX + lk;
export const listKey = (id) => (isSharedId(id) ? id.slice(PREFIX.length) : null);
export const sphereId = (cal) => PREFIX + cal;
export const calOfSphere = (id) => (isSharedId(id) ? id.slice(PREFIX.length) : null);

// ---------- записи ----------

/** Новая запись: все поля с одним временем. */
export function make(k, fields, now = Date.now()) {
  const f = {}, ft = {};
  for (const [n, v] of Object.entries(fields)) if (v !== undefined) { f[n] = v; ft[n] = now; }
  return { v: 1, k, f, ft };
}

/** Правка записи: меняются только поля, значение которых действительно другое. null — поле очищено. */
export function edit(rec, patch, now = Date.now()) {
  const f = { ...rec.f }, ft = { ...rec.ft };
  let changed = false;
  for (const [n, v] of Object.entries(patch)) {
    if (v === undefined || same(f[n], v)) continue;
    f[n] = v; ft[n] = Math.max(now, (ft[n] ?? 0) + 1); changed = true;
  }
  return changed ? { ...rec, f, ft } : rec;
}

/** Слияние двух версий записи по полям: у каждого поля — более свежее значение (при равенстве — одинаково везде). */
export function mergeRec(a, b) {
  if (!a) return b;
  if (!b) return a;
  const f = {}, ft = {};
  for (const n of new Set([...Object.keys(a.f ?? {}), ...Object.keys(b.f ?? {})])) {
    const ta = a.ft?.[n] ?? 0, tb = b.ft?.[n] ?? 0;
    const pickB = tb !== ta ? tb > ta : JSON.stringify(b.f?.[n] ?? null) > JSON.stringify(a.f?.[n] ?? null);
    const [src, t] = pickB ? [b, tb] : [a, ta];
    if (n in (src.f ?? {})) f[n] = src.f[n];
    ft[n] = t;
  }
  return { v: 1, k: a.k ?? b.k, f, ft };
}

export const lastTime = (rec) => Math.max(0, ...Object.values(rec?.ft ?? {}));

// ---------- событие календаря ----------

/** Тело события для записи: на далёкую дату, «свободно», без напоминаний — в календаре оно никому не мешает. */
export function toEvent(rec) {
  const f = { ...rec.f };
  if (typeof f.notes === 'string' && f.notes.length > NOTES_MAX) f.notes = f.notes.slice(0, NOTES_MAX);
  return {
    id: rec.k,
    summary: SUMMARY,
    description: JSON.stringify({ v: 1, k: rec.k, f, ft: rec.ft }),
    start: { date: '2000-01-01' },
    end: { date: '2000-01-02' },
    transparency: 'transparent',
    reminders: { useDefault: false, overrides: [] },
    extendedProperties: { shared: { sputnik: 'rec' } },
  };
}

/** Запись из события или null (чужое событие, испорченное описание, удалённое). */
export function fromEvent(ev) {
  if (!ev || ev.status === 'cancelled' || ev.extendedProperties?.shared?.sputnik !== 'rec') return null;
  try {
    const j = JSON.parse(ev.description ?? '');
    if (!isObj(j) || !isObj(j.f) || typeof j.k !== 'string' || !kindOf(j.k)) return null;
    return { v: 1, k: j.k, f: j.f, ft: isObj(j.ft) ? j.ft : {} };
  } catch { return null; }
}

// ---------- как запись выглядит для трекера ----------

const pad = (n) => String(Math.max(0, Math.floor(n))).padStart(20, '0');
/** Порядок новой задачи: как в Google Tasks — новые сверху. */
export const newPos = (now = Date.now()) => pad(1e15 - now);

/** Задача в том же виде, что приходит из Google Tasks. */
export function taskView(rec) {
  const f = rec.f;
  return {
    id: rec.k,
    title: f.title ?? '',
    notes: f.notes ?? '',
    ...(f.due ? { due: f.due } : {}),
    status: f.status === 'completed' ? 'completed' : 'needsAction',
    ...(f.status === 'completed' && f.completed ? { completed: f.completed } : {}),
    ...(f.parent ? { parent: f.parent } : {}),
    position: f.pos ?? '',
    updated: new Date(lastTime(rec) || 0).toISOString(),
    shared: true,
  };
}

/** Список в том же виде, что приходит из Google Tasks; cal — календарь его сферы. */
export function listView(rec, cal) {
  return { id: listId(rec.k), title: rec.f.title ?? 'Без названия', updated: new Date(lastTime(rec) || 0).toISOString(), shared: cal };
}

/** Правка задачи в духе Google Tasks (title, notes, due, status, completed) → поля записи. */
export function taskPatch(body, now = Date.now()) {
  const p = {};
  if ('title' in body) p.title = body.title ?? '';
  if ('notes' in body) p.notes = body.notes ?? '';
  if ('due' in body) p.due = body.due ?? null;
  if ('status' in body) {
    p.status = body.status === 'completed' ? 'completed' : 'needsAction';
    p.completed = p.status === 'completed' ? (body.completed ?? new Date(now).toISOString()) : null;
  }
  return p;
}

// ---------- поля слоя ----------

/** Поля слоя из записи (без '$'). */
export function layerOf(rec) {
  const out = {};
  for (const [n, v] of Object.entries(rec?.f ?? {})) if (n[0] === '$') out[n.slice(1)] = v;
  return out;
}

/** Общие поля из записи слоя (без личных), с '$'. */
export function sharedOf(layRec, kind) {
  const own = kind === 'list' ? OWN_LIST : OWN_TASK;
  const out = {};
  if (!isObj(layRec) || layRec.gone) return out;
  for (const [n, v] of Object.entries(layRec)) if (!own.has(n) && v !== undefined) out['$' + n] = v;
  return out;
}

/**
 * Трёхстороннее сведение полей слоя: L — запись слоя на этом компьютере, base — запись календаря, какой мы её
 * видели в прошлый раз, rec — какая она сейчас. Поле поменяли только там — берём оттуда; поменяли и тут и там —
 * побеждает более свежее (t записи слоя против времени поля в календаре).
 * toLayer — что вписать в слой, toRec — что дописать в календарь.
 */
export function reconcile(L, base, rec, kind = 'task') {
  const loc = sharedOf(L, kind);
  const b = base?.f ?? {}, r = rec?.f ?? {};
  const toLayer = {}, toRec = {};
  const names = new Set([...Object.keys(loc), ...Object.keys(r).filter((n) => n[0] === '$')]);
  for (const n of names) {
    const lv = loc[n], bv = b[n], rv = r[n];
    const localChanged = lv !== undefined && !same(lv, bv);
    const remoteChanged = !same(rv, bv);
    if (same(lv, rv)) continue;
    if (remoteChanged && (!localChanged || (rec.ft?.[n] ?? 0) >= (L?.t ?? 0))) toLayer[n.slice(1)] = rv ?? null;
    else if (localChanged) toRec[n] = lv;
    else if (lv === undefined) toLayer[n.slice(1)] = rv ?? null;
  }
  return { toLayer, toRec };
}

/** Поля сферы: то же сведение, но поля без '$'. */
export function reconcileSphere(S, base, rec) {
  const toLayer = {}, toRec = {};
  for (const n of SPHERE_FIELDS) {
    const lv = S?.[n], bv = base?.f?.[n], rv = rec?.f?.[n];
    if (same(lv, rv)) continue;
    const localChanged = lv !== undefined && !same(lv, bv);
    const remoteChanged = !same(rv, bv);
    if (remoteChanged && (!localChanged || (rec.ft?.[n] ?? 0) >= (S?.t ?? 0))) { if (rv !== undefined) toLayer[n] = rv; }
    else if (localChanged) toRec[n] = lv;
    else if (lv === undefined && rv !== undefined) toLayer[n] = rv;
  }
  return { toLayer, toRec };
}

// ---------- хранилище одной сферы ----------

/** Задачи списка lk (вместе с подзадачами). */
export function tasksOf(recs, lk) {
  return Object.values(recs).filter((r) => kindOf(r.k) === 'task' && r.f.list === lk).map(taskView);
}

/** Списки сферы по порядку создания. */
export function listsOf(recs, cal) {
  return Object.values(recs).filter((r) => kindOf(r.k) === 'list')
    .sort((a, b) => (a.f.created ?? 0) - (b.f.created ?? 0) || a.k.localeCompare(b.k))
    .map((r) => listView(r, cal));
}

/** Ключи задачи и всех её подзадач (удаляются вместе, как в Google Tasks). */
export function withChildren(recs, k) {
  const out = [k];
  for (const r of Object.values(recs)) if (kindOf(r.k) === 'task' && r.f.parent === k) out.push(r.k);
  return out;
}

/** Календарь — общая сфера Спутника? */
export const isSphereCal = (c) => typeof c?.description === 'string' && c.description.includes(MARK);

// ---------- участники и исполнители ----------

// Цвета участников по порядку вступления: владелец — clay, дальше типы задач (docs/design-v2.md, «Участник — кружок»).
export const MEMBER_COLORS = ['var(--clay)', 'var(--type-study)', 'var(--type-work)', 'var(--type-personal)', 'var(--gold)', 'var(--signal-done)'];

/** Участники сферы по порядку: [{ email, name, order, owner, joined, seen, invited, color, letter }]; убранные — не показываем.
 *  seen — когда Спутник участника последний раз обменивался со сферой (мс), invited — когда позвали. */
export function membersOf(recs) {
  const owner = recs?.[SPHERE_KEY]?.f?.owner ?? null;
  const out = Object.values(recs ?? {})
    .filter((r) => kindOf(r.k) === 'member' && r.f.email && !r.f.removed)
    .map((r) => ({ email: r.f.email, name: r.f.name || nameOf(r.f.email), order: r.f.order ?? 0, owner: r.f.email === owner, joined: !!r.f.joined || r.f.email === owner,
      seen: r.f.seen ?? null, invited: r.ft?.email ?? null }))
    .sort((a, b) => (b.owner - a.owner) || a.order - b.order || a.email.localeCompare(b.email));
  return out.map((m, i) => ({ ...m, color: MEMBER_COLORS[i % MEMBER_COLORS.length], letter: (m.name || m.email).trim()[0]?.toUpperCase() ?? '?' }));
}

/** Имя из почты, пока человек не назвался: anya.k@gmail.com → «Anya». */
export function nameOf(email) {
  const n = String(email ?? '').split('@')[0].split(/[._+-]/)[0] ?? '';
  return n ? n[0].toUpperCase() + n.slice(1) : 'Участник';
}

/** Следующий порядок для нового участника. */
export const nextOrder = (recs) => 1 + Math.max(0, ...Object.values(recs ?? {}).filter((r) => kindOf(r.k) === 'member').map((r) => r.f.order ?? 0));

/** Кто исполнитель задачи (почта или null) — по слою задачи. */
export const whoOf = (L) => (L && typeof L.who === 'string' && L.who ? L.who : null);

/**
 * Фильтр «Все / Мои / Без исполнителя» (и «Ничьи» на стикерах): mode = all | mine | none.
 * «Сегодня» и календарь показывают из общих сфер mine+none: свои и ничьи.
 */
export function assignedMatch(L, me, mode) {
  const w = whoOf(L);
  if (mode === 'mine') return !!me && w === me;
  if (mode === 'none') return !w;
  if (mode === 'mineOrNone') return !w || (!!me && w === me);
  return true;
}

/**
 * Передача на Конвейере при «Этап →»: исполнитель ассета становится исполнителем следующего этапа,
 * если у этапа он назначен; у этапа никого — исполнитель не меняется. Возвращает поля для слоя.
 */
export function handoff(L, toCol) {
  const next = L?.stageWho?.[toCol];
  return next && next !== whoOf(L) ? { who: next } : {};
}

/** Исполнитель этапа: { stageWho } с этапом col (who = null — снять). */
export function setStageWho(L, col, who) {
  const cur = { ...(L?.stageWho ?? {}) };
  if (who) cur[col] = who; else delete cur[col];
  return { stageWho: cur };
}

/** Сфера по-настоящему общая — в ней есть кто-то кроме владельца (иначе метку «общая» не показываем). */
export const isTogether = (people) => people.filter((m) => !m.owner).length > 0;

/** «последний раз сегодня в 12:40» / «вчера в 9:05» / «20 окт.» — для строки участника. */
export function seenText(ms, now = Date.now()) {
  if (!ms) return '';
  const d = new Date(ms), n = new Date(now);
  const hm = `${d.getHours()}:${String(d.getMinutes()).padStart(2, '0')}`;
  const day = (x) => new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime();
  const diff = Math.round((day(n) - day(d)) / 864e5);
  if (diff === 0) return `сегодня в ${hm}`;
  if (diff === 1) return `вчера в ${hm}`;
  return d.toLocaleDateString('ru-RU', { day: 'numeric', month: 'short' });
}

/** Разбор поля приглашения: почты через запятую, пробел или точку с запятой; неверные — отдельно. */
export function parseEmails(text) {
  const ok = [], bad = [];
  for (const raw of String(text ?? '').split(/[\s,;]+/)) {
    const e = raw.trim().toLowerCase();
    if (!e) continue;
    (/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e) ? ok : bad).push(e);
  }
  return { ok: [...new Set(ok)], bad };
}

// ---------- шаг 3: выбор исполнителя, «Изменения», «тебе отдали» ----------

const fold = (s) => String(s ?? '').toLowerCase().replace(/ё/g, 'е').trim();

/** Участник по почте (или «бывший» — убранный: кружок без цвета, имя из почты). */
export function memberOf(people, email) {
  if (!email) return null;
  return people.find((p) => p.email === email)
    ?? { email, name: nameOf(email), letter: nameOf(email)[0], color: 'var(--ink-faint)', joined: true, gone: true };
}

/**
 * Строки поповера «Кому отдать…»: «Я» первым, остальные участники, «Без исполнителя» последним.
 * q — поиск по имени и почте; n — открытых задач у человека (counts[email], ничьих — counts['']).
 * Цифра строки (1–9, 0 — без исполнителя) — key.
 */
export function whoOptions(people, me, q = '', counts = {}) {
  const f = fold(q);
  const hit = (p) => !f || fold(p.name).includes(f) || fold(p.email).includes(f) || (p.email === me && 'я'.startsWith(f));
  const ppl = [...people.filter((p) => p.email === me), ...people.filter((p) => p.email !== me)].filter(hit);
  const rows = ppl.map((p, i) => ({ email: p.email, m: p, label: p.email === me ? 'Я' : p.name,
    note: p.joined ? '' : 'ещё не принял', n: counts[p.email] ?? 0, key: i < 9 ? String(i + 1) : '' }));
  if (!f || 'без исполнителя'.includes(f) || 'никто'.includes(f)) rows.push({ email: null, m: null, label: 'Без исполнителя', note: '', n: counts[''] ?? 0, key: '0' });
  return rows;
}

/** Цифра на клавиатуре → почта исполнителя (undefined — такой строки нет, null — без исполнителя). */
export function whoByDigit(people, me, d) {
  if (d === '0') return null;
  const row = whoOptions(people, me).find((r) => r.key === d && r.email);
  return row ? row.email : undefined;
}

/** «@аня» в умной строке → участник, если имя или почта начинаются с этого слова (иначе null — значит, это список). */
export function memberByWord(people, word) {
  const w = fold(word).replace(/^@/, '');
  if (!w) return null;
  return people.find((p) => fold(p.name) === w) ?? people.find((p) => fold(p.name).startsWith(w) || fold(p.email.split('@')[0]).startsWith(w)) ?? null;
}

/**
 * Последнее изменение записи: кто (by — последний, кто писал), когда (at, мс) и какие поля поменял той же правкой.
 */
export function editOf(rec) {
  const by = rec?.f?.by;
  if (!by) return null;
  // ft.by не растёт, пока правит один и тот же человек, поэтому «когда» — самое свежее поле, а его правка — поля рядом.
  const ts = Object.entries(rec.ft ?? {}).filter(([n]) => n !== 'by');
  const at = Math.max(0, ...ts.map(([, t]) => t));
  if (!at) return null;
  const fields = ts.filter(([, t]) => at - t < 3000).map(([n]) => n);
  return { by, at, fields, col: rec.f.$status ?? null, who: rec.f.$who ?? null };
}

/** Строка «Изменения» в окне задачи: «Аня · перенос в «Блокаут» · 12:40»; свои правки не показываем. */
export function changeText(ed, people, me, colName = (c) => c, now = Date.now()) {
  if (!ed || ed.by === me) return '';
  const who = memberOf(people, ed.by)?.name ?? nameOf(ed.by);
  const f = new Set(ed.fields);
  let what = 'правка';
  if (f.has('status')) what = 'отметка «сделано»';
  else if (f.has('$status')) what = `перенос${ed.col ? ` в «${colName(ed.col)}»` : ''}`;
  else if (f.has('$who')) what = ed.who ? `отдано: ${ed.who === me ? 'тебе' : memberOf(people, ed.who).name}` : 'снят исполнитель';
  else if (f.has('title')) what = 'новое название';
  else if (f.has('due')) what = 'новый срок';
  else if (f.has('notes')) what = 'заметка';
  const when = seenText(ed.at, now).replace(/^сегодня в /, '');
  return `${who} · ${what} · ${when}`;
}

/**
 * Задачу отдали мне: в записи исполнитель — я, раньше был не я, и поменял это не я.
 * base — запись, какой мы её видели в прошлый раз (null — новая запись).
 */
export function assignedToMe(base, rec, me) {
  if (!me || !rec || kindOf(rec.k) !== 'task') return false;
  return rec.f.$who === me && base?.f?.$who !== me && rec.f.by && rec.f.by !== me && rec.f.status !== 'completed';
}

/** Открытых задач у каждого исполнителя (для поповера): { почта: n, '': ничьих }. */
export function whoCounts(tasks, layTasks) {
  const out = {};
  for (const t of tasks) {
    if (t.parent || t.status === 'completed') continue;
    const w = whoOf(layTasks?.[t.id]) ?? '';
    out[w] = (out[w] ?? 0) + 1;
  }
  return out;
}

// ---------- шаг 4: «Все / Мои / Без исполнителя», «Сегодня» и календарь ----------

/** Счётчики для фильтра доски по открытым задачам верхнего уровня: { all, mine, none }. */
export function whoTally(tasks, layTasks, me) {
  const out = { all: 0, mine: 0, none: 0 };
  for (const t of tasks) {
    if (t.parent || t.status === 'completed') continue;
    out.all++;
    const w = whoOf(layTasks?.[t.id]);
    if (!w) out.none++;
    else if (me && w === me) out.mine++;
  }
  return out;
}

export const WHO_MODES = ['all', 'mine', 'none'];

/**
 * Задачи для «Сегодня» и календаря: из общих сфер (together(listId)) — только мои и ничьи; подзадачи идут за родителем.
 * Остальные списки — как есть.
 */
export function forMe(tasksByList, layTasks, me, together) {
  const out = {};
  for (const [id, ts] of Object.entries(tasksByList ?? {})) {
    if (!together(id)) { out[id] = ts; continue; }
    const keep = new Set(ts.filter((t) => !t.parent && assignedMatch(layTasks?.[t.id], me, 'mineOrNone')).map((t) => t.id));
    out[id] = ts.filter((t) => (t.parent ? keep.has(t.parent) : keep.has(t.id)));
  }
  return out;
}

// ---------- шаг 6: Конвейер — исполнители этапов и передача ----------

/** Как назвать человека в тексте: «ты» / «тебе» для себя, иначе имя. */
const who2 = (people, email, me, dat = false) => (email === me ? (dat ? 'тебе' : 'ты') : memberOf(people, email)?.name ?? 'никто');

/**
 * Передача при «Этап →» (с записью в историю): поля слоя для переноса с этапа from на этап to.
 * by — кто нажал. passes — последние 8 передач { from, to, by, who, at }.
 */
export function stagePass(L, from, to, by, now = Date.now()) {
  const h = handoff(L, to);
  const who = h.who ?? whoOf(L);
  const passes = [...(Array.isArray(L?.passes) ? L.passes : []), { from, to, by, who: who ?? null, at: now }].slice(-8);
  // Кто делал законченный этап — остаётся в «Кто на этапах», даже если этапу никого не назначали.
  const keep = whoOf(L) && !L?.stageWho?.[from] ? { stageWho: { ...(L?.stageWho ?? {}), [from]: whoOf(L) } } : {};
  return { ...h, ...keep, passes };
}

/** Строка истории «Как передаётся»: «Аня · «Референсы» готовы → тебе». */
export function passText(p, people, me, colName = (c) => c) {
  const by = who2(people, p.by, me);
  const head = `${by[0].toUpperCase()}${by.slice(1)} · «${colName(p.from)}» готов${p.from ? 'о' : ''}`;
  if (!p.who) return `${head} → на этапе никого`;
  if (p.who !== p.by) return `${head} → ${who2(people, p.who, me, true)}`;
  return `${head} → «${colName(p.to)}» ${p.who === me ? 'остаётся у тебя' : `снова у: ${memberOf(people, p.who).name}`}`;
}

/** Подсказка у кнопки следующего этапа: у кого он останется. */
export function nextHint(L, next, me, people) {
  if (!next) return '';
  const cur = whoOf(L), to = L?.stageWho?.[next] ?? null;
  const target = to ?? cur;
  if (!target) return 'этап без исполнителя';
  // Имена не склоняем: «уйдёт: Макс», а не «к Макс».
  if (target === cur) return target === me ? 'этап твой — останется у тебя' : `останется: ${memberOf(people, target).name}`;
  return target === me ? 'уйдёт к тебе' : `уйдёт: ${memberOf(people, target).name}`;
}

/** Кто на этапах: [{ col, who }] — у текущего этапа это тот, кто ведёт ассет (если у этапа своего нет). */
export function stageCrew(L, cols, cur) {
  return cols.map((c) => ({ col: c, who: L?.stageWho?.[c.id] ?? (c.id === cur ? whoOf(L) : null) }));
}
