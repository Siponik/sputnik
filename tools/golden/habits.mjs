// Золотые данные для habits. «Сейчас» подменено: 2026-10-21 14:00 (среда). Запуск: node tools/golden/habits.mjs
import { writeFileSync, mkdirSync } from 'node:fs';

const NOW = new Date(2026, 9, 21, 14, 0).getTime();
const RealDate = Date;
class FakeDate extends RealDate {
  constructor(...a) { if (a.length) super(...a); else super(NOW); }
  static now() { return NOW; }
}
globalThis.Date = FakeDate;
const H = await import('../../tracker/src/lib/habits.js');

const OUT = new URL('../../rust/core/tests/golden/', import.meta.url);
mkdirSync(OUT, { recursive: true });
const write = (name, data) => writeFileSync(new URL(name, OUT), '[\n' + data.map((x) => JSON.stringify(x)).join(',\n') + '\n]\n');

const rng = (seed) => () => { seed |= 0; seed = (seed + 0x6D2B79F5) | 0; let t = Math.imul(seed ^ (seed >>> 15), 1 | seed); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
const R = rng(20261021);
const ymd = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const day = (n) => ymd(new Date(2026, 9, 21 + n));

const habits = [
  { id: 'h1', name: 'Вода', createdAt: '2026-06-01T10:00:00Z', goal: { n: 8, unit: 'стаканов' }, part: 'morning' },
  { id: 'h2', name: 'Бег', createdAt: '2026-08-10T10:00:00Z', days: [0, 2, 4], time: '07:30', end: '08:15' },
  { id: 'h3', name: 'Чтение', createdAt: '2026-09-25T10:00:00Z', time: '21:00' },
  { id: 'h4', name: 'Зал', createdAt: '2026-05-01T10:00:00Z', perWeek: 3 },
  { id: 'h5', name: 'Медитация', win: { s: '7:00', e: '7:20' }, part: 'morning' },
  { id: 'h6', name: 'Растяжка', time: '07:45', days: [0, 1, 2, 3, 4] },
  { id: 'h7', name: 'Новая', createdAt: '2026-10-20T10:00:00Z', part: 'evening', win: { s: '18:00', e: '24:00' } },
  { id: 'h8', name: 'Йога', time: '08:30', createdAt: '2026-01-01' },
];
const log = {};
for (const h of habits) for (let i = -200; i <= 3; i++) {
  const r = R();
  const k = `${h.id}|${day(i)}`;
  const streakZone = i > -12; // свежие дни — чаще сделано, чтобы были серии
  if (r < (streakZone ? 0.8 : 0.55)) log[k] = h.goal ? { n: 8, done: true, t: 1 } : { done: true, t: 1 };
  else if (r < 0.62) log[k] = { skip: true, t: 1 };
  else if (r < 0.66) log[k] = { rest: true, t: 1 };
  else if (r < 0.72 && h.goal) log[k] = { n: 3, t: 1 };
  else if (r < 0.74) log[k] = { gone: true, t: 1 };
}
// h3: три пропуска подряд для совета; h8 — надёжная для якоря
for (const i of [-1, -2, -3, -4]) delete log[`h3|${day(i)}`];
for (let i = -14; i <= 0; i++) log[`h8|${day(i)}`] = { done: true, t: 1 };
// h6: сорвавшаяся серия
log['h6|' + day(-1)] = {}; for (let i = -6; i <= -2; i++) log[`h6|${day(i)}`] = { done: true };

const o = [];
o.push({ fn: 'setup', habits, log });
for (const h of habits) {
  o.push({ fn: 'stats', id: h.id, out: H.stats(h, log) });
  for (const [y, m] of [[2026, 9], [2026, 8], [2026, 10], [2026, 1]]) { o.push({ fn: 'monthGrid', id: h.id, y, m, out: H.monthGrid(h, log, y, m) }); o.push({ fn: 'monthRow', id: h.id, y, m, out: H.monthRow(h, log, y, m) }); }
  for (const i of [-30, -8, -3, -2, -1, 0, 1, 2]) {
    const d = day(i);
    o.push({ fn: 'dayState', id: h.id, d, out: H.dayState(h, log, d) });
    o.push({ fn: 'scheduledOn', id: h.id, d, out: H.scheduledOn(h, log, d) });
    o.push({ fn: 'countOn', id: h.id, d, out: H.countOn(log, h, d) });
    o.push({ fn: 'nextMark', id: h.id, d, out: H.nextMark(log, h, d) });
  }
  for (const st of ['done', 'skip', 'miss']) o.push({ fn: 'dayMark', id: h.id, st, out: H.dayMark(h, st) });
  o.push({ fn: 'last7', id: h.id, out: H.last7(h, log) });
  for (const s of [0, 3, 6, 7, 20, 49, 99, 150]) o.push({ fn: 'milestoneDate', id: h.id, s, out: H.milestoneDate(h, log, s) });
  o.push({ fn: 'broken', id: h.id, out: H.broken(h, log) });
  for (const f of ['partOf', 'partName', 'habitWin', 'winLabel', 'remindAt', 'habitSpan', 'spanLabel', 'unitForms', 'scheduleLine', 'goalN']) o.push({ fn: f, id: h.id, out: H[f](h) ?? null });
  o.push({ fn: 'cardLine', id: h.id, out: H.cardLine(h, log) });
  o.push({ fn: 'totalDone', id: h.id, out: H.totalDone(h, log) });
  for (const t of ['06:00', '23:50', 'x']) { o.push({ fn: 'moveWin', id: h.id, t, out: H.moveWin(h, t) }); o.push({ fn: 'moveEnd', id: h.id, t, out: H.moveEnd(h, t) }); }
}
for (const [y, m] of [[2026, 9], [2026, 0]]) o.push({ fn: 'monthSummary', y, m, out: H.monthSummary(habits, log, y, m) });
o.push({ fn: 'habitTip', out: (() => { const t = H.habitTip(habits, log); return t && { habit: t.habit.id, anchor: t.anchor.id, time: t.time, misses: t.misses }; })() });
o.push({ fn: 'sortHabits', out: H.sortHabits(habits).map((h) => h.id) });
for (const n of [0, 1, 3, 6.5, 7, 10, 21, 35, 50, 100, 120]) { o.push({ fn: 'milestonePos', n, out: H.milestonePos(n) }); o.push({ fn: 'nextMilestone', n, out: H.nextMilestone(n) }); }
for (const n of [0, 1, 2, 5, 11, 12, 21, 22, 111]) o.push({ fn: 'plural', n, out: H.plural(n, ['день', 'дня', 'дней']) });
for (const d of [null, [], [0, 1, 2, 3, 4], [4, 0, 2], [0, 1, 2, 3, 4, 5, 6], [6]]) o.push({ fn: 'scheduleLabel', d, out: H.scheduleLabel(d) });
for (const p of ['morning', 'day', 'evening', 'any', 'zz']) o.push({ fn: 'partWin', p, out: H.partWin(p) });
for (const w of [null, { s: '7:30', e: '8:00' }, { s: '08:00', e: '07:00' }, { s: '18:00', e: '24:00' }, { s: '24:00', e: '24:00' }, { s: '6:00', e: '12:00' }, { s: 'x', e: '1:00' }]) {
  o.push({ fn: 'cleanWin', w, out: H.cleanWin(w) }); o.push({ fn: 'wholePart', w, out: H.wholePart(w) }); o.push({ fn: 'winFields', w, out: H.winFields(w) });
}
for (const r of ['7', '730', '7.30', '07:05', '24', '24:00', '25', '7:60', ' 9,15 ', '', null, '1230', '123']) for (const e of [false, true]) o.push({ fn: 'normTime', r, e, out: H.normTime(r, e) });
for (const [t, e] of [['07:00', '08:00'], ['07:00', '06:00'], ['x', '08:00'], ['07:00', null], ['23:00', '23:59']]) o.push({ fn: 'normEnd', t, e, out: H.normEnd(t, e) });
for (const [t, m] of [['07:00', 60], ['23:30', 60], ['23:59', 30], ['x', 60], ['10:00', 15]]) o.push({ fn: 'endAfter', t, m, out: H.endAfter(t, m) });
for (const i of [0, -3, 5]) o.push({ fn: 'dayOffset', i, out: ymd(H.dayOffset(i)) });
write('habits.json', o);
console.log(o.length);
