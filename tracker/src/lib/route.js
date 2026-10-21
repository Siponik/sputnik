// Окно «Создать» v2: умная строка и авто-определение списка (docs/design-v2.md — «Окно «Создать» v2»).
// Обычный алгоритм очков, без ИИ и без сети: работает при каждом вводе, офлайн.
//   parseLine('смета для клиента завтра 15:00 !!', { today })  → { title, day, time, priority, repeat, at, tag, marks }
//   route(text, { lists, layer, tasks, current })              → [{ listId, score, why, topic?, project? }] по убыванию
//   learn(route, title, listId, topic)                          → новые записи settings.route (вручную выбранный список)
// Слой: lists[id].template / view / topics, tasks[id].project, settings.route[основа] = { list, topic?, n }.
import { parseWhen } from './when.js';
import { takeRepeat } from './repeat.js';
import { templateOf } from './templates.js';
import { topicsOf } from './stickers.js';

const norm = (s) => String(s ?? '').toLowerCase().replace(/ё/g, 'е');
const STOP = new Set(['для', 'над', 'под', 'про', 'или', 'это', 'того', 'чтобы', 'надо', 'нужно', 'потом', 'когда', 'после', 'перед', 'через', 'около', 'возле', 'всех', 'всем', 'свой', 'свою', 'своё', 'мне', 'тебе']);
/** Значимые слова: без предлогов и коротких, строчными, ё = е. */
export const words = (text) => norm(text).split(/[^a-zа-я0-9]+/).filter((w) => w.length >= 4 && !STOP.has(w));
/** Основа слова — первые 5 букв (для выученных слов). */
export const stem = (w) => norm(w).slice(0, 5);
/** Одно слово в разных формах: общее начало не короче 4 букв («иконкам» ~ «иконок»). */
export function sameWord(a, b) {
  const n = Math.min(a.length, b.length);
  let i = 0;
  while (i < n && a[i] === b[i]) i++;
  return i >= 4 || (i === n && n >= 3);
}

// ---------- умная строка ----------

/**
 * Разбор строки: что, когда, приоритет, @список, #тема/#тип, повтор.
 * off — что пользователь «вернул в текст» крестиком на чипе: { when, prio, at, tag, repeat }.
 * marks — распознанные куски для подсветки: [{ from, to, kind: 'when' | 'prio' | 'at' | 'tag' }] по исходной строке.
 */
export function parseLine(raw, { today = new Date(), off = {} } = {}) {
  let txt = ` ${raw} `;
  const found = []; // { text, kind }
  const cut = (re, kind) => {
    const m = txt.match(re);
    if (!m) return null;
    found.push({ text: m[2] ?? m[1], kind });
    txt = txt.replace(m[0], m[0].startsWith(' ') ? ' ' : '');
    return m;
  };
  let at = null, tag = null, priority = null, repeat = null;
  if (!off.at) { const m = cut(/(\s)(@[^\s@]+)/, 'at'); if (m) at = m[2].slice(1); }
  if (!off.prio) { const m = cut(/(\s)(!{1,3})(?=\s)/, 'prio'); if (m) priority = 4 - m[2].length; }
  if (!off.tag) { const m = cut(/(\s)(#[^\s#]+)/, 'tag'); if (m) tag = m[2].slice(1); }
  if (!off.repeat) {
    const r = takeRepeat(txt);
    if (r.rule) {
      repeat = r.rule;
      const gone = diffWords(txt, r.rest);
      for (const g of gone) found.push({ text: g, kind: 'when' });
      txt = ` ${r.rest} `;
    }
  }
  let day = null, time = null;
  if (!off.when) {
    const w = parseWhen(txt, today);
    day = w.day; time = w.time;
    for (const g of diffWords(txt, w.rest)) found.push({ text: g, kind: 'when' });
    txt = w.rest;
  }
  const rest = txt.replace(/\s+/g, ' ').trim();
  return { title: rest && rest[0].toUpperCase() + rest.slice(1), rest, day, time, priority, repeat, at, tag, marks: locate(raw, found) };
}

/** Слова из a, которых нет в b (по порядку), — склеенные в куски подряд идущих. */
function diffWords(a, b) {
  const aw = a.trim().split(/\s+/).filter(Boolean), bw = b.trim().split(/\s+/).filter(Boolean);
  const out = [];
  let j = 0, cur = [];
  for (const w of aw) {
    if (j < bw.length && bw[j] === w) { j++; if (cur.length) { out.push(cur.join(' ')); cur = []; } }
    else cur.push(w);
  }
  if (cur.length) out.push(cur.join(' '));
  return out;
}

/** Куски → места в исходной строке (первое ещё не занятое вхождение), соседние куски одного вида склеиваются. */
function locate(raw, found) {
  const marks = [];
  const lower = raw.toLowerCase();
  for (const f of found) {
    const needle = f.text.toLowerCase().replace(/\s+/g, ' ');
    let from = -1, pos = 0;
    while ((from = lower.indexOf(needle, pos)) >= 0 && marks.some((m) => from < m.to && from + needle.length > m.from)) pos = from + 1;
    if (from < 0) continue;
    marks.push({ from, to: from + needle.length, kind: f.kind });
  }
  marks.sort((a, b) => a.from - b.from);
  const out = [];
  for (const m of marks) {
    const last = out[out.length - 1];
    if (last && last.kind === m.kind && !raw.slice(last.to, m.from).trim()) last.to = m.to;
    else out.push({ ...m });
  }
  return out;
}

// ---------- словари ----------

/** Слова по шаблонам списков (начало слова). */
export const DICT = {
  asset3d: ['lowpoly', 'highpoly', 'ретоп', 'скульпт', 'uv', 'развертк', 'текстур', 'запек', 'рендер', 'модел', 'ассет', 'пропс', 'блокаут'],
  work: ['клиент', 'смет', 'макет', 'правк', 'ревью', 'созвон', 'бриф', 'счет', 'заказ'],
  study: ['урок', 'курс', 'лекци', 'глав', 'конспект'],
  personal: ['купить', 'забрать', 'оплатить', 'позвонить', 'записаться', 'продлить', 'убрать', 'почистить', 'починить', 'подарок'],
};
DICT.client = DICT.work;

/** Темы стикеров: по имени темы (как в DEFAULT_TOPICS) — начала слов. «=» — только целое слово. */
export const TOPIC_WORDS = {
  'покупки': ['купи', 'куплю', 'заказа', 'забра', 'посылк'],
  'звонки': ['позвон', 'набра', 'напис'],
  'здоровье': ['врач', 'стоматолог', 'анализ', '=зал'],
  'документы': ['продл', 'полис', 'паспорт', 'налог', 'оплат'],
  'дом': ['убра', 'почист', 'почин', 'постира'],
};
const hit = (w, entry) => (entry[0] === '=' ? w === entry.slice(1) : w.startsWith(entry));
/** Короткие слова словарей (uv, зал) тоже считаются, поэтому здесь — все слова, а не только значимые. */
const allWords = (text) => norm(text).split(/[^a-zа-я0-9]+/).filter((w) => w.length >= 2);

// ---------- маршрут ----------

/** #тег → шаблоны списков (теги как в строке «Сегодня» и в боте; старые русские тоже). */
export const TAG_TPL = { asset: ['asset3d'], work: ['work', 'client'], client: ['client', 'work'], study: ['study'], personal: ['personal'],
  'ассет': ['asset3d'], 'работа': ['work', 'client'], 'клиент': ['client', 'work'], 'учеба': ['study'], 'личное': ['personal'] };

const W = { at: 1000, tag: 8, learn: 6, word: 4, topic: 3, sim: 3, simMax: 4, project: 4, current: 2 };
const MIN_SCORE = 4;
const MONTH = 30 * 864e5;

/** Вид доски списка: свой или вид шаблона. */
export const viewOf = (listId, layer) => layer?.lists?.[listId]?.view ?? templateOf(layer?.lists?.[listId]?.template, layer).view ?? 'kanban';

/** Проекты списка (Конвейер): имена из tasks[id].project, по частоте. */
export function projectsOf(listTasks = [], layTasks = {}) {
  const n = new Map();
  for (const t of listTasks) {
    const p = !t.parent && layTasks?.[t.id]?.project;
    if (p) n.set(p, (n.get(p) ?? 0) + 1);
  }
  return [...n.entries()].sort((a, b) => b[1] - a[1]).map(([p]) => p);
}

/** «@раб» → список: точное совпадение, начало названия, часть названия (как бот). */
export function findList(lists, word) {
  const k = (s) => norm(s).replace(/[\s\-_·.]+/g, '');
  const w = k(word);
  if (!w) return null;
  return lists.find((l) => k(l.title) === w) ?? lists.find((l) => k(l.title).startsWith(w)) ?? lists.find((l) => k(l.title).includes(w)) ?? null;
}

/**
 * Куда положить задачу. text — название (без даты и приоритета) или вся строка.
 * lists — [{ id, title }] (без «Привычек» и скрытых), layer — слой, tasks — { listId: [задачи Google] },
 * current — список, открытый на доске. now — для «недавних» задач.
 */
export function route(text, { lists = [], layer = {}, tasks = {}, current = null, now = Date.now() } = {}) {
  if (!lists.length) return [];
  const at = text.match(/(?:^|\s)@([^\s@]+)/);
  const atList = at ? findList(lists, at[1]) : null;
  const tagM = text.match(/(?:^|\s)#([^\s#]+)/);
  const tagTpl = tagM ? TAG_TPL[norm(tagM[1])] ?? [] : [];
  const ws = words(text.replace(/(?:^|\s)[@#]\S+/g, ' '));
  const all = allWords(text.replace(/(?:^|\s)[@#]\S+/g, ' '));
  const learned = layer?.settings?.route ?? {};
  const layTasks = layer?.tasks ?? {};

  const out = lists.map((l, i) => {
    const r = { listId: l.id, score: 0, i, parts: {}, word: null, topic: null, topicWord: null, project: null, projectWord: null, simN: 0 };
    const add = (kind, pts) => { r.score += pts; r.parts[kind] = (r.parts[kind] ?? 0) + pts; };
    const tpl = templateOf(layer?.lists?.[l.id]?.template, layer).id;
    const view = viewOf(l.id, layer);

    if (atList?.id === l.id) add('at', W.at);
    if (tagTpl.includes(tpl)) add('tag', tagTpl[0] === tpl ? W.tag : W.tag / 2);

    // выученные слова
    for (const w of ws) {
      const e = learned[stem(w)];
      if (e && typeof e === 'object' && e.list === l.id) {
        add('learn', W.learn + 2 * Math.min(e.n ?? 1, 5));
        r.learnWord ??= w;
        if (e.topic && !r.topic) { r.topic = e.topic; r.topicWord = w; r.topicWhy = 'learn'; }
      }
    }
    // словарь по шаблону
    for (const w of all) {
      if ((DICT[tpl] ?? []).some((e) => hit(w, e))) { add('word', W.word); r.word ??= w; }
    }
    // темы стикеров: имя темы или словарь темы
    if (view === 'stickers') {
      const topics = topicsOf(layer?.lists?.[l.id]);
      for (const w of all) {
        const t = topics.find((t) => sameWord(w, norm(t.name)) || (TOPIC_WORDS[norm(t.name)] ?? []).some((e) => hit(w, e)));
        if (t) {
          add('word', W.topic);
          r.word ??= w;
          if (!r.topic) { r.topic = t.id; r.topicWord = w; }
          break;
        }
      }
    }
    // похожесть на открытые и недавние задачи списка и на название списка
    const titleWords = words(l.title);
    const known = [...titleWords];
    for (const t of tasks[l.id] ?? []) {
      if (t.parent) continue;
      if (t.status === 'completed' && !(Date.parse(t.completed ?? t.updated ?? '') > now - MONTH)) continue;
      known.push(...words(t.title));
    }
    const simHits = ws.filter((w) => known.some((k) => sameWord(w, k)));
    r.simN = simHits.length;
    r.titleHit = simHits.some((w) => titleWords.some((k) => sameWord(w, k)));
    if (simHits.length) add('sim', W.sim * Math.min(simHits.length, W.simMax));
    // проект Конвейера
    if (view === 'pipe') {
      for (const p of projectsOf(tasks[l.id], layTasks)) {
        const w = ws.find((w) => words(p).some((k) => sameWord(w, k)));
        if (w) { add('project', W.project); r.project = p; r.projectWord = w; break; }
      }
    }
    if (l.id === current) add('current', W.current);
    return r;
  });

  out.sort((a, b) => b.score - a.score || (b.listId === current) - (a.listId === current) || a.i - b.i);
  const best = out[0];
  // Мало очков — остаёмся на текущей доске.
  if (best.score - (best.parts.current ?? 0) < MIN_SCORE) {
    const cur = out.find((r) => r.listId === current);
    if (cur) { out.splice(out.indexOf(cur), 1); out.unshift(cur); }
  }
  return out.map((r, i) => ({
    listId: r.listId,
    score: r.score,
    why: whyOf(r, i === 0 && r.score - (r.parts.current ?? 0) < MIN_SCORE, at?.[1], tagM?.[1]),
    ...(r.topic ? { topic: r.topic, topicWhy: r.topicWhy === 'learn' ? `запомнил «${r.topicWord}»` : `по слову «${r.topicWord}»` } : {}),
    ...(r.project ? { project: r.project, projectWord: r.projectWord } : {}),
  }));
}

function whyOf(r, weak, atWord, tagWord) {
  if (r.parts.at) return `указано @${atWord}`;
  if (r.parts.tag) return `указано #${tagWord}`;
  if (weak) return r.parts.current ? 'текущая доска' : 'по умолчанию';
  if (r.parts.learn) return `запомнил «${r.learnWord}»`;
  // Много общих слов с задачами, и среди них — слово из названия доски: это сильнее одного слова словаря.
  if ((r.simN >= 3 && r.titleHit) || (r.parts.sim && !r.parts.word)) return 'похоже на задачи этой доски';
  if (r.parts.word) return `по слову «${r.word}»`;
  if (r.parts.project) return `проект «${r.project}»`;
  return r.parts.current ? 'текущая доска' : 'по умолчанию';
}

/**
 * Обучение: пользователь сам выбрал список (или тему) и создал задачу. 1–2 значимых слова названия → settings.route.
 * Возвращает только изменённые записи { основа: { list, topic?, n } } — их пишут в слой поверх старых.
 */
export function learn(current = {}, title, listId, topic = null) {
  const out = {};
  for (const w of words(title).slice(0, 2)) {
    const k = stem(w);
    const e = current?.[k];
    const same = e && typeof e === 'object' && e.list === listId;
    out[k] = { list: listId, ...(topic ? { topic } : {}), n: same ? (e.n ?? 1) + 1 : 1 };
  }
  return out;
}
