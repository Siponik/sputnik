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
      if (diff > 0) state = 'future';
      else if (!scheduled(d)) state = 'rest';
      else if (isDone(log, habit.id, s)) state = 'done';
      else if (isOff(log, habit.id, s)) state = 'off';
      else if (diff === 0) state = 'today';
      else if (s < created) state = 'before';
      else state = 'miss';
      cells.push({ date: s, state, today: diff === 0, title: `${d.getDate()} ${MONTH_GEN[d.getMonth()]}` });
      if (k === 0 && (w === 0 || d.getDate() <= 7)) months.push({ col: w, name: MONTH_SHORT[d.getMonth()] });
    }
  }
  return { streak, best, todayDone, cells, months };
}

const MONTH_SHORT = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
const MONTH_GEN = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];

export function scheduleLabel(days) {
  if (!days?.length || days.length === 7) return 'Каждый день';
  if (days.length === 5 && [0, 1, 2, 3, 4].every((d) => days.includes(d))) return 'По будням';
  return days.slice().sort().map((d) => WEEKDAYS[d]).join(' · ');
}
