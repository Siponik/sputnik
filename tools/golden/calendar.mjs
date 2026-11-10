// Золотые данные для calendar. «Сейчас» подменено: 2026-10-21 14:00 (среда). Запуск: TZ=Europe/Moscow node tools/golden/calendar.mjs
import { writeFileSync, mkdirSync } from 'node:fs';

const NOW = new Date(2026, 9, 21, 14, 0).getTime();
const RealDate = Date;
class FakeDate extends RealDate {
  constructor(...a) { if (a.length) super(...a); else super(NOW); }
  static now() { return NOW; }
}
globalThis.Date = FakeDate;
const C = await import('../../tracker/src/lib/calendar.js');

const OUT = new URL('../../rust/core/tests/golden/', import.meta.url);
mkdirSync(OUT, { recursive: true });
const write = (name, data) => writeFileSync(new URL(name, OUT), '[\n' + data.map((x) => JSON.stringify(x)).join(',\n') + '\n]\n');
const out = [];
const strip = (L) => ({ HT: L.HT, Y: L.Y, height: L.height, labels: L.labels, lines: L.lines, bands: L.bands, busy: L.busy,
  ys: [0, 1, 59, 60, 90, 600, 630, 1000, 1439, 1440, 1500, -5].map(L.yAt) });

const LAYS = [
  [[{ s: 600, e: 690 }], [], 0], [[{ s: 540, e: 1020 }, { s: 1080, e: 1140 }], [], 0], [[{ s: 600, e: 720 }], [], 600],
  [[], [], 0], [[], [14], 0], [[], [14, -1, 30], 800], [[{ s: 0, e: 30 }, { s: 1410, e: 1440 }], [], 0],
  [[{ s: 700, e: 700 }, { s: 1430, e: 1500 }], [3], 1000], [[{ s: 60, e: 1380 }], [], 300], [[{ s: 600, e: 660 }], [22], 2000],
];
for (const [it, hot, fit] of LAYS) out.push({ fn: 'hourLayout', it, hot, fit, out: strip(C.hourLayout(it, hot, fit)) });

for (const d of ['2026-10-22', '2026-10-19', '2026-10-25', '2026-01-01', '2026-12-31', '2027-02-28', '2024-02-29', '2026-03-01'])
  for (const m of ['week', 'month']) {
    out.push({ fn: 'periodDays', d, m, out: C.periodDays(d, m) });
    out.push({ fn: 'periodTitle', d, m, out: C.periodTitle(d, m) });
    for (const dir of [1, -1, 2]) out.push({ fn: 'shiftPeriod', d, m, dir, out: C.shiftPeriod(d, m, dir) });
  }
for (const s of ['2026-01-31', '2026-03-31', '2024-02-29']) for (const dir of [1, -1, 12]) out.push({ fn: 'shiftPeriod', d: s, m: 'month', dir, out: C.shiftPeriod(s, 'month', dir) });
for (const s of ['07:05', '00:00', '23:59', '9:3']) out.push({ fn: 'toMin', s, out: C.toMin(s) });
for (const n of [0, 425, 1439, 1440, 61]) out.push({ fn: 'fromMin', n, out: C.fromMin(n) });
for (const t of ['work', 'asset3d', 'personal', 'study', 'x', null]) out.push({ fn: 'typeOfTemplate', t, out: C.typeOfTemplate(t ?? undefined) });
out.push({ fn: 'typeColor', t: 'work', out: C.typeColor('work') });

const week = C.periodDays('2026-10-21', 'week');
const events = [
  { id: 'e1', summary: 'Встреча', calendar: 'c1', start: { dateTime: '2026-10-21T10:00:00+03:00' }, end: { dateTime: '2026-10-21T11:30:00+03:00' } },
  { id: 'e2', summary: '', start: { date: '2026-10-20' }, end: { date: '2026-10-23' } },
  { id: 'e3', summary: 'Ночь', start: { dateTime: '2026-10-22T22:00:00+03:00' }, end: { dateTime: '2026-10-24T02:00:00+03:00' } },
  { id: 'e4', summary: 'ДР', kind: 'birthday', start: { date: '2026-10-25' } },
  { id: 'e5', summary: 'Без времени' },
  { id: 'e6', summary: 'Точка', start: { dateTime: '2026-10-19T09:00:00Z' } },
  { id: 'e7', summary: 'Вне', start: { date: '2026-11-20' }, end: { date: '2026-11-21' } },
  { id: 'e8', summary: 'Сутки', start: { dateTime: '2026-10-23T00:00:00+03:00' }, end: { dateTime: '2026-10-24T00:00:00+03:00' } },
  { id: 'e9', summary: 'Старт до', start: { dateTime: '2026-10-18T23:00:00+03:00' }, end: { dateTime: '2026-10-19T01:00:00+03:00' } },
];
out.push({ fn: 'eventsByDay', events, days: week, out: C.eventsByDay(events, week) });
out.push({ fn: 'eventsByDay', events, days: [], out: C.eventsByDay(events, []) });

const lists = [{ id: 'L', title: 'Работа' }, { id: 'M', title: 'Дом' }];
const tbl = { L: [
  { id: 'a', title: 'Отчёт', due: '2026-10-21T00:00:00.000Z' }, { id: 'b', title: '', due: '2026-10-20T00:00:00.000Z' },
  { id: 'c', title: 'Сделано', due: '2026-10-19T00:00:00.000Z', status: 'completed' }, { id: 'd', title: 'Под', due: '2026-10-21T00:00:00.000Z', parent: 'a' },
  { id: 'e', title: 'Без срока' }, { id: 'f', title: 'Далеко', due: '2026-12-01T00:00:00.000Z' },
], M: [{ id: 'g', title: 'Пол', due: '2026-10-25T00:00:00.000Z' }, { id: 'h', title: 'Окна', due: '2026-10-22T00:00:00.000Z' }] };
const lay = { a: { slot: { s: '10:00', e: '11:15' } }, g: { slot: { s: '18:30' } }, h: { slot: {} } };
const typeOf = (l, t) => (l === 'L' ? 'work' : t === 'g' ? 'personal' : 'study');
out.push({ fn: 'tasksByDay', lists, tasks: tbl, lay, days: week, out: C.tasksByDay(lists, tbl, lay, typeOf, week) });
out.push({ fn: 'tasksByDay', lists, tasks: tbl, lay: null, days: week, out: C.tasksByDay(lists, tbl, null, typeOf, week) });

const BLK = [
  [{ id: 1, s: 600, e: 660 }, { id: 2, s: 630, e: 700 }, { id: 3, s: 720, e: 750 }, { id: 4, s: null, e: null }],
  [{ id: 1, s: 600, e: 610 }, { id: 2, s: 610, e: 620 }, { id: 3, s: 620, e: 640 }, { id: 4, s: 600, e: 900 }],
  [{ id: 1, s: 100, e: 130 }, { id: 2, s: 105, e: 110 }, { id: 3, s: -30, e: 20 }, { id: 4, s: 1430, e: 1500 }],
  [], [{ id: 1, s: 600, e: 600 }, { id: 2, s: 600, e: 600 }, { id: 3, s: 600, e: 600 }],
];
for (const it of BLK) {
  const L = C.hourLayout(it.filter((x) => x.s != null), [], 0);
  out.push({ fn: 'layoutBlocks', it, out: C.layoutBlocks(it, L.yAt) });
}

const BUSY = [
  [{ s: 500, e: 600 }, { s: 590, e: 700 }, { s: 800, e: 900, kind: 'task', done: true }, { s: 1200, e: 1300 }, { s: null }],
  [{ s: 700, e: 650 }, { s: 900, e: 960, kind: 'habit', done: true }, { s: 900, e: 960, kind: 'habit' }, { s: 1000, e: 1100, kind: 'event', done: true }],
  [],
];
for (const it of BUSY) {
  out.push({ fn: 'busy', it, out: C.busy(it) });
  out.push({ fn: 'busyLo', it, out: C.busy(it, 0, 1440) });
  out.push({ fn: 'busyMinutes', it, out: C.busyMinutes(it) });
}
const DI = [
  {}, { '2026-10-21': [{ s: 840, e: 1260 }], '2026-10-22': [{ s: 540, e: 1200 }], '2026-10-23': [{ s: 600, e: 1260 }] },
  { '2026-10-21': [{ s: 900, e: 960 }], '2026-10-22': [{ s: 540, e: 1260 }], '2026-10-23': [{ s: 540, e: 1260 }] },
  { '2026-10-22': [{ s: 540, e: 1260 }], '2026-10-23': [{ s: 540, e: 1260 }], '2026-10-21': [{ s: 540, e: 1260 }] },
  { '2026-10-22': [{ s: 540, e: 1260 }], '2026-10-23': [{ s: 540, e: 1260 }], '2026-10-21': [{ s: 540, e: 1260 }], '2026-10-24': [{ s: 600, e: 1200 }], '2026-10-25': [{ s: 540, e: 1260 }] },
  { '2026-10-22': [{ s: 600, e: 660, kind: 'task', done: true }, { s: 700, e: 1260 }] },
];
for (const di of DI) out.push({ fn: 'bestWindow', di, days: week, out: C.bestWindow(di, week) });
out.push({ fn: 'bestWindow', di: {}, days: C.periodDays('2026-10-12', 'week'), out: C.bestWindow({}, C.periodDays('2026-10-12', 'week')) });

const habits = [
  { id: 'h2', name: 'Бег', createdAt: '2026-08-10T10:00:00Z', days: [0, 2, 4], time: '07:30', end: '08:15' },
  { id: 'h3', name: 'Чтение', createdAt: '2026-10-22T10:00:00Z', time: '21:00' },
  { id: 'h4', name: 'Зал', perWeek: 2, time: '19:00' },
  { id: 'h5', name: 'Медитация', win: { s: '7:00', e: '7:20' }, part: 'morning' },
  { id: 'h7', name: 'Вечер', part: 'evening', win: { s: '18:00', e: '24:00' } },
  { id: 'h9', name: 'Без времени' },
];
const log = { 'h2|2026-10-21': { done: true, t: 1 }, 'h4|2026-10-19': { done: true }, 'h4|2026-10-20': { done: true }, 'h3|2026-10-21': { done: true } };
for (const d of week) {
  for (const h of habits) out.push({ fn: 'habitDay', id: h.id, d, out: C.habitDay(h, log, d, '2026-10-21') });
  out.push({ fn: 'habitBlocks', habits, log, d, out: C.habitBlocks(habits, log, d, '2026-10-21') });
}
for (const d of [...week, '2026-01-01', '2026-12-31', '2026-10-28', '2026-10-14']) {
  out.push({ fn: 'dayLabel', d, out: C.dayLabel(d) });
  out.push({ fn: 'whenLabel', d, out: C.whenLabel(d) });
}
for (const n of [0, null, 60, 90, 1, 125, 6000, 59]) out.push({ fn: 'hoursLabel', n, out: C.hoursLabel(n) });
write('calendar.json', out);
console.log(out.length);
