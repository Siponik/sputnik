// Окно «Создать» v2 — чистые помощники (без Svelte): подписи дат, день рождения, свободное время, чек-лист этапа.
// Даты — строки 'ГГГГ-ММ-ДД', today передаётся снаружи, чтобы тесты не зависели от часов.
import { bucket } from './stickers.js';

const pad = (n) => String(n).padStart(2, '0');
const parse = (s) => { const [y, m, d] = s.split('-').map(Number); return new Date(y, m - 1, d); };
const fmt = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
export const plus = (s, n) => { const d = parse(s); d.setDate(d.getDate() + n); return fmt(d); };
export const toMin = (s) => { const [h, m] = s.split(':').map(Number); return h * 60 + m; };
export const fromMin = (m) => `${pad(Math.floor(Math.min(m, 1439) / 60))}:${pad(Math.min(m, 1439) % 60)}`;
export const addMin = (hhmm, n) => fromMin(toMin(hhmm) + n);

const WD = ['вс', 'пн', 'вт', 'ср', 'чт', 'пт', 'сб'];
const WDF = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
const MON = ['янв.', 'февр.', 'мар.', 'апр.', 'мая', 'июн.', 'июл.', 'авг.', 'сент.', 'окт.', 'нояб.', 'дек.'];
const MONG = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];

/** Чип «Понял:»: «сб, 24 окт.» */
export const shortDay = (s) => { const d = parse(s); return `${WD[d.getDay()]}, ${d.getDate()} ${MON[d.getMonth()]}`; };
/** Крупная строка события: «Чт, 22 октября» */
export const longDay = (s) => { const d = parse(s); return `${WDF[d.getDay()]}, ${d.getDate()} ${MONG[d.getMonth()]}`; };
/** «Когда» события: «завтра, чт 29 октября», «сегодня, ср 28 октября», «пт 30 октября». */
export function eventDay(s, today) {
  const d = parse(s), base = `${WD[d.getDay()]} ${d.getDate()} ${MONG[d.getMonth()]}`;
  return s === today ? `сегодня, ${base}` : s === plus(today, 1) ? `завтра, ${base}` : base;
}
/** День рождения: «12 марта» */
export const dayMonth = (s) => { const d = parse(s); return `${d.getDate()} ${MONG[d.getMonth()]}`; };
export const weekday = (s) => WD[parse(s).getDay()];

/** Срок по-человечески для превью: «сегодня», «завтра, 15:00», «сб», «24 окт.». */
export function dueShort(due, today, slot = null) {
  if (!due) return '';
  const t = slot?.s ? `, ${slot.s}` : '';
  if (due === today) return 'сегодня' + t;
  if (due === plus(today, 1)) return 'завтра' + t;
  if (due < today) return 'просрочено';
  if (bucket(due, today) === 'week') return weekday(due) + t;
  const d = parse(due);
  return `${d.getDate()} ${MON[d.getMonth()]}${t}`;
}

/** Чип «Когда» у стикера: today | week | later | date (срок дальше недели). */
export function whenChip(due, today) {
  if (!due) return 'later';
  const b = bucket(due, today);
  return b === 'later' ? 'date' : b;
}

// ---------- день рождения ----------

/** Имя в дательном падеже для «Подарок Ане»: Аня → Ане, Иван → Ивану, Мария → Марии, Андрей → Андрею. */
export function dative(name) {
  const n = String(name ?? '').trim();
  if (!n || /\s/.test(n)) return n;
  if (/ия$/i.test(n)) return n.slice(0, -1) + 'и';
  if (/[ая]$/i.test(n)) return n.slice(0, -1) + 'е';
  if (/[йь]$/i.test(n)) return n.slice(0, -1) + 'ю';
  if (/[бвгджзклмнпрстфхцчшщ]$/i.test(n)) return n + 'у';
  return n;
}

/** Ближайший день рождения (сегодня или позже) по дате любого года. */
export function nextBirthday(day, today) {
  const d = parse(day), t = parse(today);
  let x = new Date(t.getFullYear(), d.getMonth(), d.getDate());
  if (x < t) x = new Date(t.getFullYear() + 1, d.getMonth(), d.getDate());
  return fmt(x);
}

/** Сколько исполнится в ближайший день рождения (год — число или строка; нет года — null). */
export function ageAt(year, day, today) {
  const y = Number(year);
  if (!y || y < 1900 || y > 2100) return null;
  const a = Number(nextBirthday(day, today).slice(0, 4)) - y;
  return a > 0 && a < 130 ? a : null;
}

/** «через …» до дня: «1 день», «3 дня», «135 дней». */
export function daysTill(day, today) {
  const n = Math.round((parse(day) - parse(today)) / 864e5), a = n % 100, b = n % 10;
  return `${n} ${a > 10 && a < 20 ? 'дней' : b === 1 ? 'день' : b > 1 && b < 5 ? 'дня' : 'дней'}`;
}

/** «лет»: 1 год, 2 года, 5 лет. */
export function years(n) {
  const a = n % 100, b = n % 10;
  return `${n} ${a > 10 && a < 20 ? 'лет' : b === 1 ? 'год' : b > 1 && b < 5 ? 'года' : 'лет'}`;
}

// ---------- событие: свободно ли время ----------

/** События дня со временем → [{ a, b, title }] в минутах суток (начало до этого дня — 0, конец после — 1440). */
function timedOf(events, day) {
  return (events ?? [])
    .filter((x) => x.start?.dateTime && x.end?.dateTime && x.start.dateTime.slice(0, 10) <= day && x.end.dateTime.slice(0, 10) >= day)
    .map((x) => {
      const a = new Date(x.start.dateTime), b = new Date(x.end.dateTime);
      const am = fmt(a) < day ? 0 : a.getHours() * 60 + a.getMinutes();
      const bm = fmt(b) > day ? 1440 : b.getHours() * 60 + b.getMinutes();
      return { a: am, b: bm, title: x.summary || 'событие' };
    });
}

/**
 * Кусок сетки дня для превью события: hours часов вокруг slot (час до начала), без времени — с 9:00.
 * → { hours: [14, 15, …], items: [{ top, h, title, mine }] } — top и h в часах от начала куска.
 */
export function dayChunk(events, day, slot, title = '', hours = 5) {
  const s = slot?.s ? toMin(slot.s) : null;
  const start = s == null ? 9 : Math.max(0, Math.min(24 - hours, Math.floor(s / 60) - 1));
  const from = start * 60, to = from + hours * 60;
  const piece = (a, b, t, mine) => (b <= from || a >= to ? null
    : { top: (Math.max(a, from) - from) / 60, h: Math.max(0.25, (Math.min(b, to) - Math.max(a, from)) / 60), title: t, mine });
  const items = timedOf(events, day).map((x) => piece(x.a, x.b, x.title, false));
  if (s != null) items.push(piece(s, slot.e ? toMin(slot.e) : s + 60, title, true));
  return { hours: Array.from({ length: hours }, (_, i) => start + i), items: items.filter(Boolean) };
}

/**
 * events — события Google за день (start.dateTime/end.dateTime), slot — { s, e } нового события.
 * → { clash: 'название' } | { until: 'ЧЧ:ММ' } (следующее событие) | { free: true } (до конца дня свободно).
 */
export function freeCheck(events, day, slot) {
  if (!slot?.s) return null;
  const s = toMin(slot.s), e = toMin(slot.e || slot.s);
  const timed = timedOf(events, day);
  const clash = timed.find((x) => x.a < e && x.b > s);
  if (clash) return { clash: clash.title };
  const next = timed.filter((x) => x.a >= e).sort((x, y) => x.a - y.a)[0];
  return next ? { until: fromMin(next.a) } : { free: true };
}

// ---------- доски ----------

/** Сколько открытых задач в колонке (для лимита «2/3»). Колонка без статуса в слое — первая. */
export function colCount(listTasks = [], layTasks = {}, colId, firstCol) {
  return listTasks.filter((t) => !t.parent && t.status !== 'completed' && (layTasks?.[t.id]?.status ?? firstCol) === colId).length;
}

/** Порядок «сверху» колонки: меньше всех, кто там уже есть. */
export function topOrd(listTasks = [], layTasks = {}, colId, firstCol) {
  const ords = listTasks.filter((t) => !t.parent && t.status !== 'completed' && (layTasks?.[t.id]?.status ?? firstCol) === colId)
    .map((t, i) => layTasks?.[t.id]?.ord ?? i);
  return Math.min(0, ...ords) - 1;
}

/**
 * Чек-лист этапов для нового ассета — подзадачи с этапом (tasks[sub].stage) у последнего ассета списка,
 * у которого они есть. → [{ title, stage }] в порядке Google.
 */
export function stageChecklist(listTasks = [], layTasks = {}) {
  const tops = listTasks.filter((t) => !t.parent).sort((a, b) => (b.updated ?? '').localeCompare(a.updated ?? ''));
  for (const top of tops) {
    const subs = listTasks.filter((t) => t.parent === top.id && layTasks?.[t.id]?.stage)
      .sort((a, b) => (a.position || '').localeCompare(b.position || ''));
    if (subs.length) return subs.map((s) => ({ title: s.title, stage: layTasks[s.id].stage }));
  }
  return [];
}

/** Две буквы для миниатюры ассета: «Сундук с золотом» → «СУ». */
export const initials = (title) => (String(title ?? '').replace(/[^a-zа-яё0-9]/gi, '').slice(0, 2) || '··').toUpperCase();

// ---------- подсказка вида: «Похоже на встречу — сделать событием?» ----------

// Границы слова для кириллицы (\b в JS — только латиница).
const W = (re) => new RegExp(`(?:^|[^а-яёa-z0-9])(?:${re})(?=$|[^а-яёa-z0-9])`, 'i');
const MEET = W('созвон\\S*|встреч[аиеуы]|встречу|врач\\S*|к врачу|стоматолог\\S*|собеседовани\\S*|митинг\\S*|свидани\\S*|консультаци\\S*');
// «с Олей», «со Светой» — имя с большой буквы; или люди словом: клиент, команда, друзья…
const WITH = /(?:^|\s)(?:с|со)\s+(?:[А-ЯЁ][а-яё]+|(?:клиент|заказчик|команд|друз|друг|мам|пап|коллег|ребят)[а-яё]*)/;
const HABIT = W('каждый день|каждое утро|каждый вечер|ежедневно|по утрам|по вечерам|по будням|\\d+\\s+раза?\\s+в\\s+неделю');
const BDAY = W('день рождени[яе]|дня рождения|днюх[аиу]|др');

/**
 * На что похожа строка: { kind: 'event' | 'habit' | 'birthday', what, why } или null.
 * text — строка как есть, p — parseLine(text) (day, time, repeat). Вид окна сама не меняет —
 * окно показывает плашку с кнопкой (kindHint).
 */
export function suggestKind(text, p = {}) {
  const t = String(text ?? '');
  if (BDAY.test(t) && p.day) return { kind: 'birthday', what: 'день рождения', why: 'раз в год' };
  const h = HABIT.exec(t);
  if (h || p.repeat?.every === 'day' || p.repeat?.every === 'weekdays') {
    const phrase = h ? h[0].trim().toLowerCase() : p.repeat.every === 'day' ? 'каждый день' : 'по будням';
    return { kind: 'habit', what: 'привычку', why: `повторяется ${phrase}` };
  }
  const meet = MEET.test(t), withSb = WITH.test(t), time = !!p.time;
  if (meet || (time && withSb)) {
    const why = time && withSb ? 'у неё есть время и с кем-то' : time ? 'у неё есть время' : withSb ? 'она с кем-то' : 'её не отмечают сделанной';
    return { kind: 'event', what: 'встречу', why };
  }
  return null;
}

/** Подсказка для текущего вида: null — молчим (тот же вид, у события повтор нормален, день рождения не трогаем). */
export function kindHint(text, p, kind) {
  const s = suggestKind(text, p);
  if (!s || s.kind === kind || kind === 'birthday') return null;
  if (kind === 'event' && s.kind === 'habit') return null;
  return s;
}

// ---------- повтор события (Google Календарь, RRULE) ----------

const RRULES = { day: 'FREQ=DAILY', weekdays: 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR', week: 'FREQ=WEEKLY', month: 'FREQ=MONTHLY', year: 'FREQ=YEARLY' };
/** Правило повтора Спутника { every } → ['RRULE:…'] для события; без повтора — null. */
export const recurrenceOf = (rule) => (RRULES[rule?.every] ? [`RRULE:${RRULES[rule.every]}`] : null);

// ---------- привычка: умная строка «Пить воду 8 стаканов каждый день» ----------

// Фраза целиком, с границами слова для кириллицы; группа 1 — сама фраза.
const P = (re) => new RegExp(`(?:^|[^а-яёa-z0-9])(${re})(?=$|[^а-яёa-z0-9])`, 'i');
const H_FREQ = [
  [P('(\\d+)\\s+раза?\\s+в\\s+неделю'), (m) => ({ freq: 'week', perWeek: Math.min(6, Math.max(1, +m[2])) }), (m) => `${m[2]} ${+m[2] % 10 >= 2 && +m[2] % 10 <= 4 ? 'раза' : 'раз'} в неделю`],
  [P('по будням'), () => ({ freq: 'days', days: [0, 1, 2, 3, 4] }), () => 'по будням'],
  [P('по выходным'), () => ({ freq: 'days', days: [5, 6] }), () => 'по выходным'],
  [P('каждый день|ежедневно'), () => ({ freq: 'daily' }), () => 'каждый день'],
];
const H_PART = [
  [P('каждое утро|по утрам|утром'), 'morning', 'утро'],
  [P('днём|днем|после обеда'), 'day', 'день'],
  [P('каждый вечер|по вечерам|вечером|перед сном'), 'evening', 'вечер'],
];
const H_UNITS = [
  [/^стакан/, 'стаканов'], [/^страниц/, 'страниц'], [/^мин/, 'минут'], [/^км$/, 'км'], [/^шаг/, 'шагов'], [/^раз/, 'раз'],
];
const H_GOAL = P('(\\d{1,5})\\s+(стакан[а-яё]*|страниц[а-яё]*|минут[а-яё]*|мин|км|шаг[а-яё]*|раз|раза|отжиман[а-яё]*|приседан[а-яё]*|глав[а-яё]*|слов[а-яё]*)');

/**
 * Разбор строки привычки. off — куски, возвращённые в текст крестиком: { freq, part, goal }.
 * → { name, freq?, perWeek?, days?, part?, goal? { n, unit }, marks: [{ from, to, kind }], toks: [{ k, l }] }
 */
export function parseHabit(raw, off = {}) {
  const text = String(raw ?? '');
  const out = { marks: [], toks: [] };
  const taken = [];
  const free = (a, b) => taken.every(([x, y]) => b <= x || a >= y);
  const take = (m, kind) => {
    const from = m.index + m[0].length - m[1].length, to = from + m[1].length;
    if (!free(from, to)) return false;
    taken.push([from, to]);
    out.marks.push({ from, to, kind });
    return true;
  };
  if (!off.freq) for (const [re, val, label] of H_FREQ) {
    const m = re.exec(text);
    if (m && take(m, 'freq')) { Object.assign(out, val(m)); out.toks.push({ k: 'freq', l: label(m) }); break; }
  }
  if (!off.part) for (const [re, part, label] of H_PART) {
    const m = re.exec(text);
    if (m && take(m, 'part')) {
      out.part = part; out.toks.push({ k: 'part', l: label });
      if (!out.freq && /^кажд/i.test(m[1])) out.freq = 'daily';
      break;
    }
  }
  if (!off.goal) {
    const m = H_GOAL.exec(text);
    if (m && +m[2] > 1 && take(m, 'goal')) {
      const word = m[3].toLowerCase();
      const unit = H_UNITS.find(([re]) => re.test(word))?.[1] ?? word;
      out.goal = { n: Math.min(999, +m[2]), unit };
      out.toks.unshift({ k: 'goal', l: `цель ${out.goal.n} ${unit}` });
    }
  }
  out.marks.sort((a, b) => a.from - b.from);
  let name = '', i = 0;
  for (const mk of out.marks) { name += text.slice(i, mk.from) + ' '; i = mk.to; }
  name = (name + text.slice(i)).replace(/\s+/g, ' ').trim();
  out.name = name && name[0].toUpperCase() + name.slice(1);
  return out;
}

// ---------- подарок ко дню рождения ----------
// Событие дня рождения помнит, за сколько дней нужен подарок: extendedProperties.private.sputnikGift = дней
// (и sputnikGiftList — в какой список). Задача «Подарок Ане» появляется сама, когда до дня рождения остаётся столько дней.

export const GIFT_DAYS = [[3, 'за 3 дня'], [7, 'за неделю'], [14, 'за 2 недели'], [30, 'за месяц']];

/** День задачи «Подарок …»: день рождения минус days. */
export const giftDate = (bday, days) => plus(bday, -days);

/** Имя из названия события дня рождения: «🎂 Аня» → «Аня». */
export const bdayName = (summary) => String(summary ?? '').replace(/^[^\p{L}]+/u, '').trim();

/**
 * Какие задачи про подарок пора завести: events — вхождения дней рождения (singleEvents, start.date),
 * today — 'ГГГГ-ММ-ДД'. → [{ key, title, due, bday, listId }]; key — «id события|год», чтобы не заводить дважды.
 * Срок — день из sputnikGift; если трекер в тот день не запускали — сегодня.
 */
export function giftsDue(events, today) {
  const out = [];
  for (const e of events ?? []) {
    const p = e.extendedProperties?.private ?? {};
    const days = Number(p.sputnikGift);
    const bday = e.start?.date;
    if (p.sputnik !== 'birthday' || !(days > 0) || !bday) continue;
    const from = giftDate(bday, days);
    if (today < from || today > bday) continue;
    const name = bdayName(e.summary);
    if (!name) continue;
    out.push({ key: `${e.recurringEventId || e.id}|${bday.slice(0, 4)}`, title: `Подарок ${dative(name)}`, due: from, bday, listId: p.sputnikGiftList || null });
  }
  return out;
}
