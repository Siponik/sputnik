// Расчёт серий привычек. Отметки хранятся в слое: log["<habitId>|YYYY-MM-DD"] = { done, rest, skip, n, t }.
// rest — «выходной» из прошлых версий, skip — «не считать» (болел, уезжал): такие дни серию не рвут и в % не входят.
// n — сколько набрано у привычки с целью на день (habits[id].goal = { n, unit }); done ставится, когда n >= goal.n.
// Время привычки — habits[id].time «ЧЧ:ММ» (необязательно), часть дня — habits[id].part, «N раз в неделю» — perWeek.
// Экран «Привычки: карточки» — docs/design-v2.md.
import { ymd } from './api.js';

export const WEEKDAYS = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
export const MILESTONES = [7, 21, 50, 100]; // вехи серии: енот празднует, бот поздравляет

export const dayOffset = (n) => { const d = new Date(); d.setHours(0, 0, 0, 0); d.setDate(d.getDate() + n); return d; };
export const dow = (d) => (d.getDay() + 6) % 7; // пн = 0
export const logKey = (habitId, date) => `${habitId}|${date}`;
export const isDone = (log, habitId, date) => !!log?.[logKey(habitId, date)]?.done;
export const isOff = (log, habitId, date) => { const e = log?.[logKey(habitId, date)]; return !!(e?.rest || e?.skip) && !isDone(log, habitId, date); };

/** Ближайшая веха больше n (после последней — она же). */
export const nextMilestone = (n) => MILESTONES.find((m) => m > n) ?? MILESTONES[MILESTONES.length - 1];

/** Положение n на шкале вех в процентах: равные отрезки между 0 · 7 · 21 · 50 · 100. */
export function milestonePos(n) {
  const pts = [0, ...MILESTONES];
  for (let q = 1; q < pts.length; q++) if (n <= pts[q]) return ((q - 1 + (n - pts[q - 1]) / (pts[q] - pts[q - 1])) / MILESTONES.length) * 100;
  return 100;
}

export function plural(n, forms) {
  const a = n % 10, b = n % 100;
  if (a === 1 && b !== 11) return forms[0];
  if (a >= 2 && a <= 4 && (b < 12 || b > 14)) return forms[1];
  return forms[2];
}

/** Текущая серия, лучшая серия и сетка за 13 недель. */
export function stats(habit, log) {
  if (habit.perWeek > 0) return weekStats(habit, log);
  const days = habit.days?.length ? habit.days : [0, 1, 2, 3, 4, 5, 6];
  const scheduled = (d) => days.includes(dow(d));
  const created = habit.createdAt ? habit.createdAt.slice(0, 10) : ymd(dayOffset(-365));
  const todayDone = isDone(log, habit.id, ymd(dayOffset(0)));

  let streak = 0;
  for (let i = todayDone ? 0 : 1; i <= 730; i++) {
    const d = dayOffset(-i), s = ymd(d);
    if (s < created && !isDone(log, habit.id, s)) break;
    if (!scheduled(d) || isOff(log, habit.id, s)) continue;
    if (isDone(log, habit.id, s)) streak++; else break;
  }

  let best = 0, run = 0;
  for (let i = 730; i >= 0; i--) {
    const d = dayOffset(-i), s = ymd(d);
    if (!scheduled(d) || isOff(log, habit.id, s)) continue;
    if (isDone(log, habit.id, s)) { run++; if (run > best) best = run; }
    else if (i !== 0 && s >= created) run = 0;
  }

  // Сетка: 13 недель с понедельника, текущая неделя последняя.
  const monday = dayOffset(-dow(dayOffset(0)) - 7 * 12);
  const cells = [];
  const months = [];
  for (let w = 0; w < 13; w++) {
    for (let k = 0; k < 7; k++) {
      const d = new Date(monday); d.setDate(monday.getDate() + w * 7 + k);
      const s = ymd(d);
      const diff = Math.round((d - dayOffset(0)) / 864e5);
      let state;
      // future — дни этой недели впереди: по расписанию видны контуром (plan), остальные пустые.
      // before — привычки ещё не было (до первого дня в Спутнике): ровная бледная клетка, не путать с «не по расписанию».
      if (diff > 0) state = scheduled(d) ? 'plan' : 'future';
      else if (isDone(log, habit.id, s)) state = 'done';
      else if (!scheduled(d)) state = 'rest';
      else if (s < created) state = 'before';
      else if (isOff(log, habit.id, s)) state = 'off';
      else if (diff === 0) state = 'today';
      else state = 'miss';
      cells.push({ date: s, state, today: diff === 0, title: `${d.getDate()} ${MONTH_GEN[d.getMonth()]}` });
      // Подпись месяца — над первой неделей, где есть 1-е число (и над первой колонкой, если до следующей ≥ 3 колонок).
      if (k === 0 && (w === 0 || d.getDate() <= 7)) months.push({ col: w, name: MONTH_SHORT[d.getMonth()] });
    }
  }
  // Подписи шириной в 3 колонки не должны налезать: самая первая уступает, если следующая слишком близко.
  if (months.length > 1 && months[1].col - months[0].col < 3) months.shift();
  return { streak, best, todayDone, cells, months };
}

/** Календарь одного месяца для карточки привычки (design/screens/Habits.dc.html, «Привычки: календарь одного месяца»).
 *  cells — пн…вс, пустые клетки до 1-го и после последнего числа (blank); state: done | miss | off | fut | today | blank.
 *  off — не по расписанию или привычки ещё не было (бледное число). done / sched — «14 из 19»: сделано / запланировано до сегодня. */
export function monthGrid(habit, log, year, month) {
  const days = habit.days?.length ? habit.days : [0, 1, 2, 3, 4, 5, 6];
  const created = habit.createdAt ? habit.createdAt.slice(0, 10) : '0000';
  const today = ymd(dayOffset(0));
  const first = new Date(year, month, 1);
  const dim = new Date(year, month + 1, 0).getDate();
  const lead = dow(first);
  const cells = [];
  let done = 0, sched = 0;
  for (let i = 0; i < Math.ceil((lead + dim) / 7) * 7; i++) {
    const n = i - lead + 1;
    if (n < 1 || n > dim) { cells.push({ key: `b${i}`, n: '', state: 'blank', title: '' }); continue; }
    const d = new Date(year, month, n), s = ymd(d);
    const isDoneDay = isDone(log, habit.id, s);
    const scheduledDay = days.includes(dow(d));
    let state, what;
    if (s > today) { state = 'fut'; what = scheduledDay ? 'по плану' : 'не по расписанию'; }
    else if (isDoneDay) { state = s === today ? 'today done' : 'done'; what = 'сделано'; done++; sched++; }
    else if (s === today) { state = scheduledDay ? 'today' : 'off'; what = scheduledDay ? 'сегодня' : 'не по расписанию'; if (scheduledDay) sched++; }
    else if (s < created) { state = 'off'; what = 'привычки ещё не было'; }
    else if (!scheduledDay) { state = 'off'; what = 'не по расписанию'; }
    else if (isOff(log, habit.id, s)) { state = 'off'; what = 'выходной, серия сохранена'; }
    else { state = 'miss'; what = 'пропуск'; sched++; }
    cells.push({ key: s, n, state, title: `${n} ${MONTH_GEN[month]} · ${what}` });
  }
  return { cells, done, sched };
}

export const MONTH_NAMES = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];

const MONTH_SHORT =['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
const MONTH_GEN = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];

export function scheduleLabel(days) {
  if (!days?.length || days.length === 7) return 'Каждый день';
  if (days.length === 5 && [0, 1, 2, 3, 4].every((d) => days.includes(d))) return 'По будням';
  return days.slice().sort().map((d) => WEEKDAYS[d]).join(' · ');
}

// ---------- Привычки: карточки (23.10) ----------

/** Части дня: время напоминания, если у привычки нет точного времени. */
export const PARTS = [
  { id: 'morning', name: 'Утро', at: '10:00' },
  { id: 'day', name: 'День', at: '15:00' },
  { id: 'evening', name: 'Вечер', at: '21:00' },
  { id: 'any', name: 'Когда угодно', at: null },
];
/** Часть дня: явная habits[id].part, иначе по времени (утро до 12, день 12–18, вечер после), без времени — «когда угодно». */
export function partOf(h) {
  if (PARTS.some((p) => p.id === h?.part)) return h.part;
  const m = /^(\d{1,2}):/.exec(h?.time ?? '');
  if (!m) return 'any';
  return +m[1] < 12 ? 'morning' : +m[1] < 18 ? 'day' : 'evening';
}
export const partName = (h) => PARTS.find((p) => p.id === partOf(h)).name;
/** Во сколько напоминать: точное время или время части дня («когда угодно» без времени — не напоминаем). */
export const remindAt = (h) => h?.time || PARTS.find((p) => p.id === partOf(h)).at;

/** Порядок карточек: по части дня, внутри — по времени. */
export function sortHabits(list) {
  const pi = (h) => PARTS.findIndex((p) => p.id === partOf(h));
  return list.slice().sort((a, b) => pi(a) - pi(b) || (a.time ?? '99').localeCompare(b.time ?? '99'));
}

/** Цель на день: 0 — просто отметка. */
export const goalN = (h) => (h?.goal?.n > 1 ? Math.round(h.goal.n) : 0);
/** Сколько набрано за день (у простой отметки — 1 или 0). */
export function countOn(log, h, day) {
  const e = log?.[logKey(h.id, day)];
  if (!e || e.gone) return 0;
  if (typeof e.n === 'number') return e.n;
  return e.done ? goalN(h) || 1 : 0;
}
/** Запись отметки после «+1» (или «отметить»): по достижении цели — done; на сделанной — снять. */
export function nextMark(log, h, day) {
  const g = goalN(h);
  if (!g) return { done: !isDone(log, h.id, day), rest: false, skip: false };
  if (isDone(log, h.id, day)) return { done: false, n: 0, skip: false };
  const n = countOn(log, h, day) + 1;
  return { done: n >= g, n, skip: false };
}
/** Запись для меню дня: done | miss | skip. */
export function dayMark(h, state) {
  const g = goalN(h);
  if (state === 'done') return { done: true, rest: false, skip: false, ...(g ? { n: g } : {}) };
  if (state === 'skip') return { done: false, rest: false, skip: true, ...(g ? { n: 0 } : {}) };
  return { done: false, rest: false, skip: false, ...(g ? { n: 0 } : {}) };
}

const ALL_DAYS = [0, 1, 2, 3, 4, 5, 6];
const daysOf = (h) => (h.days?.length ? h.days : ALL_DAYS);
const mondayOf = (d) => { const m = new Date(d); m.setHours(0, 0, 0, 0); m.setDate(m.getDate() - dow(m)); return m; };
const addD = (d, n) => { const x = new Date(d); x.setDate(x.getDate() + n); return x; };

/** Сделано за неделю (с понедельника) и сколько дней «не считать». */
function weekCount(h, log, monday) {
  let done = 0, skip = 0;
  for (let k = 0; k < 7; k++) {
    const s = ymd(addD(monday, k));
    if (isDone(log, h.id, s)) done++; else if (isOff(log, h.id, s)) skip++;
  }
  return { done, skip };
}
/** Нужно за неделю: perWeek, но не больше дней, которые можно было отметить. */
const weekNeed = (h, skip) => Math.max(1, Math.min(h.perWeek, 7 - skip));

/** «N раз в неделю»: серия — в неделях. Текущая неделя серию не рвёт, пока не кончилась. */
function weekStats(h, log) {
  const today = dayOffset(0);
  const created = h.createdAt ? h.createdAt.slice(0, 10) : ymd(dayOffset(-365));
  const mon0 = mondayOf(today);
  const cur = weekCount(h, log, mon0);
  const curOk = cur.done >= weekNeed(h, cur.skip);
  let streak = curOk ? 1 : 0;
  for (let w = 1; w <= 104; w++) {
    const mon = addD(mon0, -7 * w);
    const c = weekCount(h, log, mon);
    if (ymd(addD(mon, 6)) < created && !c.done) break;
    if (c.done >= weekNeed(h, c.skip)) streak++; else break;
  }
  let best = 0, run = 0;
  for (let w = 104; w >= 0; w--) {
    const mon = addD(mon0, -7 * w);
    const c = weekCount(h, log, mon);
    if (c.done >= weekNeed(h, c.skip)) { run++; best = Math.max(best, run); }
    else if (w !== 0 && ymd(addD(mon, 6)) >= created) run = 0;
  }
  return { streak, best, todayDone: isDone(log, h.id, ymd(today)), week: cur.done, cells: [], months: [] };
}

/** Можно ли делать привычку в этот день (по расписанию). У «N раз в неделю» — пока норма недели не набрана (или сделано в этот день). */
export function scheduledOn(h, log, day) {
  const d = parseDay(day);
  if (h.perWeek > 0) {
    if (isDone(log, h.id, day)) return true;
    const c = weekCount(h, log, mondayOf(d));
    return c.done < weekNeed(h, c.skip);
  }
  return daysOf(h).includes(dow(d));
}
const parseDay = (s) => { const [y, m, d] = s.split('-').map(Number); return new Date(y, m - 1, d); };

/** Единицы серии: дни, занятия (по дням недели) или недели. */
export function unitForms(h) {
  if (h.perWeek > 0) return ['неделя', 'недели', 'недель'];
  return !h.days?.length || h.days.length === 7 ? ['день', 'дня', 'дней'] : ['занятие', 'занятия', 'занятий'];
}

/** Состояние дня для точек, таблицы месяца и календаря панели:
 *  d — сделано, p — частично, m — пропуск, k — не считать, o — не по расписанию / привычки ещё не было, f — будущее, w — свободный день недели у «N раз в неделю». */
export function dayState(h, log, day, today = ymd(dayOffset(0))) {
  const e = log?.[logKey(h.id, day)];
  if (isDone(log, h.id, day)) return 'd';
  if (day > today) return 'f';
  if (e?.skip || e?.rest) return 'k';
  if (goalN(h) && countOn(log, h, day) > 0) return 'p';
  const created = h.createdAt ? h.createdAt.slice(0, 10) : '0000';
  if (day < created) return 'o';
  if (h.perWeek > 0) return 'w';
  if (!daysOf(h).includes(dow(parseDay(day)))) return 'o';
  return day === today ? 'w' : 'm';
}

/** Точки за 7 дней, сегодня — последняя. */
export function last7(h, log, now = new Date()) {
  const today = ymd(now);
  const out = [];
  for (let i = 6; i >= 0; i--) {
    const d = addD(new Date(now.getFullYear(), now.getMonth(), now.getDate()), -i), s = ymd(d);
    out.push({ day: s, wd: WEEKDAYS[dow(d)], st: dayState(h, log, s, today), today: i === 0 });
  }
  return out;
}

/** Месяц: клетки по числам + процент. sched — дней, которые «считались» (до сегодня включительно, без «не считать»). */
export function monthRow(h, log, year, month, now = new Date()) {
  const today = ymd(now);
  const dim = new Date(year, month + 1, 0).getDate();
  const cells = [];
  let done = 0, sched = 0, miss = 0;
  for (let n = 1; n <= dim; n++) {
    const s = ymd(new Date(year, month, n));
    const st = dayState(h, log, s, today);
    cells.push({ day: s, n, st, today: s === today });
    if (st === 'd') done++;
    if (st === 'm') miss++;
    if (st === 'd' || st === 'm' || st === 'p') sched++;
  }
  if (h.perWeek > 0) {
    // норма — perWeek за неделю, считаем по прошедшим дням месяца (и не раньше, чем привычка появилась)
    const created = h.createdAt ? h.createdAt.slice(0, 10) : '0000';
    const past = cells.filter((c) => c.day <= today && c.day >= created && c.st !== 'k').length;
    sched = Math.max(done, Math.ceil((past / 7) * h.perWeek));
    miss = 0;
  }
  return { cells, done, sched, miss, pct: sched ? Math.round((done / sched) * 100) : null };
}

/** Итог месяца для енота под таблицей: общий %, прошлый месяц, без пропусков, слабый день недели. */
export function monthSummary(habits, log, year, month, now = new Date()) {
  const sum = (y, m) => {
    let done = 0, sched = 0;
    const rows = habits.map((h) => { const r = monthRow(h, log, y, m, now); done += r.done; sched += r.sched; return { h, r }; });
    return { rows, pct: sched ? Math.round((done / sched) * 100) : null };
  };
  const cur = sum(year, month);
  const prev = sum(month ? year : year - 1, month ? month - 1 : 11);
  const clean = cur.rows.filter(({ h, r }) => !h.perWeek && r.sched >= 3 && !r.miss).map(({ h }) => h.name);
  const wd = Array.from({ length: 7 }, () => ({ d: 0, s: 0 }));
  for (const { r } of cur.rows) for (const c of r.cells) {
    if (c.st !== 'd' && c.st !== 'm') continue;
    const k = dow(parseDay(c.day));
    wd[k].s++; if (c.st === 'd') wd[k].d++;
  }
  let weak = null;
  wd.forEach((x, i) => { if (x.s >= 2 && x.d < x.s && (weak === null || x.d / x.s < wd[weak].d / wd[weak].s)) weak = i; });
  return { pct: cur.pct, prev: prev.pct, clean, weak: weak === null ? null : WEEKDAY_FULL[weak] };
}
const WEEKDAY_FULL = ['понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота', 'воскресенье'];

/** Дата, когда будет следующая веха, если не пропускать: «7 ноября». У «N раз в неделю» — null. */
export function milestoneDate(h, log, streak, now = new Date()) {
  if (h.perWeek > 0) return null;
  let left = nextMilestone(streak) - streak;
  if (left <= 0) return null;
  const today = ymd(now);
  let d = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  if (isDone(log, h.id, today)) d = addD(d, 1);
  for (let i = 0; i < 800; i++, d = addD(d, 1)) {
    if (daysOf(h).includes(dow(d)) && --left === 0) return `${d.getDate()} ${MONTH_GEN[d.getMonth()]}`;
  }
  return null;
}

/** Серия сорвалась: последний день по расписанию до сегодня пропущен, а до него была серия. was — какой она была. */
export function broken(h, log, now = new Date()) {
  if (h.perWeek > 0) return null;
  const today = ymd(now);
  if (isDone(log, h.id, today)) return null;
  const created = h.createdAt ? h.createdAt.slice(0, 10) : '0000';
  let d = addD(new Date(now.getFullYear(), now.getMonth(), now.getDate()), -1);
  let i = 0;
  for (; i < 60; i++, d = addD(d, -1)) {
    const s = ymd(d);
    if (s < created) return null;
    const st = dayState(h, log, s, today);
    if (st === 'm' || st === 'p') break;
    if (st === 'd') return null; // серия идёт
  }
  if (i >= 60) return null;
  let was = 0;
  for (d = addD(d, -1); was < 800; d = addD(d, -1)) {
    const st = dayState(h, log, ymd(d), today);
    if (st === 'd') was++;
    else if (st === 'o' || st === 'k') continue;
    else break;
  }
  return was >= 2 ? { was } : null;
}

const toMin = (t) => { const m = /^(\d{1,2}):(\d{2})$/.exec(t ?? ''); return m ? +m[1] * 60 + +m[2] : null; };
const fromMin = (n) => `${String(Math.floor(n / 60) % 24).padStart(2, '0')}:${String(n % 60).padStart(2, '0')}`;

/** Совет енота: привычка со временем сорвалась 3 раза подряд — перенести сразу после самой надёжной привычки той же части дня.
 *  { habit, anchor, time, misses } или null. Скрытые «Не сейчас» — habits[id].tipHide (до даты). */
export function habitTip(habits, log, now = new Date()) {
  const today = ymd(now);
  const reliability = (h) => {
    let d = 0, s = 0;
    for (let i = 1; i <= 14; i++) {
      const st = dayState(h, log, ymd(addD(now, -i)), today);
      if (st === 'd') { d++; s++; } else if (st === 'm' || st === 'p') s++;
    }
    return s ? d / s : 0;
  };
  for (const h of habits) {
    if (!h.time || h.perWeek > 0 || (h.tipHide && h.tipHide >= today)) continue;
    let misses = 0, i = 1;
    for (; i <= 21 && misses < 3; i++) {
      const st = dayState(h, log, ymd(addD(now, -i)), today);
      if (st === 'm' || st === 'p') misses++;
      else if (st === 'd') break;
    }
    if (misses < 3) continue;
    const part = partOf(h);
    const anchor = habits
      .filter((a) => a.id !== h.id && a.time && partOf(a) === part && reliability(a) >= 0.7)
      .sort((a, b) => reliability(b) - reliability(a) || stats(b, log).streak - stats(a, log).streak)[0];
    if (!anchor) continue;
    const time = fromMin(toMin(anchor.time) + 30);
    if (time === h.time) continue;
    return { habit: h, anchor, time, misses };
  }
  return null;
}

/** Подпись под названием карточки: «Утро · в 21:00», «2 из 3 на неделе», «Утро · 5 из 8 стаканов». */
export function cardLine(h, log, now = new Date()) {
  const today = ymd(now);
  const bits = [partName(h)];
  if (h.perWeek > 0) {
    const c = weekCount(h, log, mondayOf(now));
    bits.push(`${c.done} из ${h.perWeek} на неделе`);
  } else if (goalN(h)) bits.push(`${countOn(log, h, today)} из ${goalN(h)} ${h.goal.unit || ''}`.trim());
  else if (h.time) bits.push(`в ${h.time}`);
  if (h.days?.length && h.days.length < 7 && !h.perWeek) bits.push(scheduleLabel(h.days).toLowerCase());
  return bits.join(' · ');
}

/** Расписание словами для панели: «каждый день · вечер · 21:00 · с 12 мая». */
export function scheduleLine(h) {
  const bits = [h.perWeek > 0 ? `${h.perWeek} ${plural(h.perWeek, ['раз', 'раза', 'раз'])} в неделю` : scheduleLabel(h.days).toLowerCase(), partName(h).toLowerCase()];
  if (h.time) bits.push(h.time);
  if (h.createdAt) { const d = parseDay(h.createdAt.slice(0, 10)); bits.push(`с ${d.getDate()} ${MONTH_GEN[d.getMonth()]}`); }
  return bits.join(' · ');
}

/** Сколько раз сделано всего. */
export const totalDone = (h, log) => Object.keys(log ?? {}).filter((k) => k.startsWith(h.id + '|') && log[k]?.done && !log[k].gone).length;

export { MONTH_GEN };
