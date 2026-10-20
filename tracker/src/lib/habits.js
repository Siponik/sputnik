// Расчёт серий привычек. Отметки хранятся в слое: log["<habitId>|YYYY-MM-DD"] = { done, rest, t }.
// rest — «выходной» из прошлых версий: такие дни серию не рвут. Новые выходные взять нельзя (функцию убрали).
// Время привычки — habits[id].time «ЧЧ:ММ» (необязательно).
import { ymd } from './api.js';

export const WEEKDAYS = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
export const MILESTONES = [7, 21, 50, 100]; // вехи серии: енот празднует, бот поздравляет

export const dayOffset = (n) => { const d = new Date(); d.setHours(0, 0, 0, 0); d.setDate(d.getDate() + n); return d; };
export const dow = (d) => (d.getDay() + 6) % 7; // пн = 0
export const logKey = (habitId, date) => `${habitId}|${date}`;
export const isDone = (log, habitId, date) => !!log?.[logKey(habitId, date)]?.done;
export const isOff = (log, habitId, date) => !!log?.[logKey(habitId, date)]?.rest && !isDone(log, habitId, date);

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
