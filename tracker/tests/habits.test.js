// Серии привычек (lib/habits.js).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { stats, monthGrid, logKey, plural, milestonePos, nextMilestone, scheduleLabel, dayOffset } from '../src/lib/habits.js';
import { ymd } from '../src/lib/api.js';

const day = (n) => ymd(dayOffset(n));
const logOf = (id, offsets, extra = {}) => Object.fromEntries(offsets.map((n) => [logKey(id, day(n)), { done: true, t: 1, ...extra }]));

test('серия: подряд до вчера, сегодня ещё не отмечено', () => {
  const h = { id: 'h', days: [], createdAt: day(-30) };
  const s = stats(h, logOf('h', [-1, -2, -3]));
  assert.equal(s.streak, 3);
  assert.equal(s.todayDone, false);
});

test('серия: с сегодняшней отметкой и пропуском', () => {
  const h = { id: 'h', days: [], createdAt: day(-30) };
  const s = stats(h, logOf('h', [0, -1, -3, -4, -5, -6]));
  assert.equal(s.streak, 2);
  assert.equal(s.best, 4);
});

test('старые выходные (rest) серию не рвут', () => {
  const h = { id: 'h', days: [], createdAt: day(-30) };
  const log = { ...logOf('h', [-1, -3]), [logKey('h', day(-2))]: { rest: true } };
  assert.equal(stats(h, log).streak, 2);
});

test('monthGrid: число клеток кратно неделе, счётчик сделанного', () => {
  const h = { id: 'h', days: [], createdAt: '2026-01-01' };
  const log = { [logKey('h', '2026-02-03')]: { done: true }, [logKey('h', '2026-02-04')]: { done: true } };
  const g = monthGrid(h, log, 2026, 1); // февраль 2026: начинается в воскресенье
  assert.equal(g.cells.length % 7, 0);
  assert.equal(g.cells.filter((c) => c.state === 'blank').length, g.cells.length - 28);
  assert.equal(g.done, 2);
});

test('вехи, склонения, подписи', () => {
  assert.equal(nextMilestone(0), 7);
  assert.equal(nextMilestone(21), 50);
  assert.equal(nextMilestone(500), 100);
  assert.equal(milestonePos(0), 0);
  assert.equal(milestonePos(7), 25);
  assert.equal(milestonePos(100), 100);
  assert.deepEqual([1, 2, 5, 11, 21, 112].map((n) => plural(n, ['день', 'дня', 'дней'])), ['день', 'дня', 'дней', 'дней', 'день', 'дней']);
  assert.equal(scheduleLabel([0, 1, 2, 3, 4]), 'По будням');
  assert.equal(scheduleLabel([]), 'Каждый день');
  assert.equal(scheduleLabel([5, 0]), 'пн · сб');
});

// ---------- Привычки: карточки (23.10) ----------
import * as H from '../src/lib/habits.js';
import { habitItems, habitWinDue } from '../src/lib/reminders.js';
import { habitDay } from '../src/lib/calendar.js';

test('часть дня: явная, по времени, без времени — когда угодно; время напоминания', () => {
  assert.equal(H.partOf({ part: 'evening' }), 'evening');
  assert.equal(H.partOf({ time: '07:30' }), 'morning');
  assert.equal(H.partOf({ time: '12:00' }), 'day');
  assert.equal(H.partOf({ time: '21:00' }), 'evening');
  assert.equal(H.partOf({}), 'any');
  assert.equal(H.remindAt({ part: 'morning' }), '10:00');
  assert.equal(H.remindAt({ part: 'evening', time: '22:30' }), '22:30');
  assert.equal(H.remindAt({}), null);
  assert.deepEqual(H.sortHabits([{ id: 'a' }, { id: 'b', time: '21:00' }, { id: 'c', part: 'morning' }]).map((h) => h.id), ['c', 'b', 'a']);
});

test('количество: +1 до цели, на цели — сделано, ещё клик — сброс', () => {
  const h = { id: 'w', goal: { n: 3, unit: 'стаканов' } };
  let log = {};
  const step = () => { log = { ...log, [logKey('w', day(0))]: H.nextMark(log, h, day(0)) }; };
  step(); assert.equal(H.countOn(log, h, day(0)), 1); assert.equal(H.dayState(h, log, day(0)), 'p');
  step(); step(); assert.equal(H.dayState(h, log, day(0)), 'd');
  step(); assert.equal(H.countOn(log, h, day(0)), 0);
  // старая отметка без n у привычки с целью считается полной
  assert.equal(H.countOn({ [logKey('w', day(-1))]: { done: true } }, h, day(-1)), 3);
});

test('«не считать» серию не рвёт и в процент не входит', () => {
  const h = { id: 'h', days: [], createdAt: day(-30) };
  const log = { ...logOf('h', [-1, -3]), [logKey('h', day(-2))]: H.dayMark(h, 'skip') };
  assert.equal(stats(h, log).streak, 2);
  assert.equal(H.dayState(h, log, day(-2)), 'k');
});

test('N раз в неделю: серия в неделях, свободные дни — не пропуск', () => {
  const now = dayOffset(0);
  const mon = -((now.getDay() + 6) % 7); // смещение до понедельника этой недели
  const h = { id: 'e', perWeek: 2, createdAt: day(mon - 21) };
  // прошлые 2 недели — по 2 раза, эта — пока 0: серия 2 (текущая не рвёт)
  const log = logOf('e', [mon - 7, mon - 5, mon - 14, mon - 12]);
  assert.equal(stats(h, log).streak, 2);
  assert.equal(H.dayState(h, log, day(mon - 6)), 'w');
  assert.deepEqual(H.unitForms(h), ['неделя', 'недели', 'недель']);
  // норма недели набрана — больше не «по расписанию» (для «Сегодня» и напоминаний)
  const full = { ...log, ...logOf('e', [mon, mon + 1].filter((n) => n < 0)) };
  if (mon <= -2) assert.equal(H.scheduledOn(h, full, day(0)), false);
  assert.equal(habitDay(h, log, day(0), day(0)).sched, true);
});

test('точки за 7 дней: сегодня последняя, пропуск и сделано', () => {
  const h = { id: 'h', days: [], createdAt: day(-30) };
  const dots = H.last7(h, logOf('h', [0, -2]));
  assert.equal(dots.length, 7);
  assert.ok(dots[6].today);
  assert.equal(dots[6].st, 'd');
  assert.equal(dots[5].st, 'm');
  assert.equal(dots[4].st, 'd');
});

test('серия сорвалась: было N, лучшая остаётся', () => {
  const h = { id: 'h', days: [], createdAt: day(-40) };
  const log = logOf('h', [-2, -3, -4, -5, -6]);
  assert.deepEqual(H.broken(h, log), { was: 5 });
  assert.equal(H.broken(h, logOf('h', [-1, -2])), null); // идёт
  assert.equal(H.broken(h, { ...log, ...logOf('h', [0]) }), null); // начал заново сегодня
});

test('совет: сорвалась 3 раза подряд — после самой надёжной той же части дня', () => {
  const read = { id: 'r', name: 'Чтение', time: '22:30', days: [], createdAt: day(-30) };
  const sketch = { id: 's', name: 'Скетч', time: '21:00', days: [], createdAt: day(-30) };
  const log = logOf('s', Array.from({ length: 14 }, (_, i) => -i - 1));
  const tip = H.habitTip([read, sketch], log);
  assert.equal(tip.habit.id, 'r');
  assert.equal(tip.anchor.id, 's');
  assert.equal(tip.time, '21:30');
  assert.equal(H.habitTip([{ ...read, tipHide: day(3) }, sketch], log), null);
});

test('месяц: процент и итог', () => {
  const now = new Date();
  const h = { id: 'h', name: 'Вода', days: [], createdAt: ymd(new Date(now.getFullYear(), now.getMonth() - 2, 1)) };
  const all = Array.from({ length: now.getDate() }, (_, i) => -i);
  const r = H.monthRow(h, logOf('h', all), now.getFullYear(), now.getMonth(), now);
  assert.equal(r.pct, 100);
  assert.equal(r.cells.length, new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate());
  const sum = H.monthSummary([h], logOf('h', all), now.getFullYear(), now.getMonth(), now);
  assert.equal(sum.pct, 100);
});

test('напоминания привычек: время части дня, выключенный Telegram, уведомление Windows', () => {
  const now = new Date(2030, 0, 7, 9, 0);
  const h = { id: 'm', name: 'Зарядка', part: 'morning', days: [] };
  const items = habitItems([h, { ...h, id: 'n', remind: { tg: false } }], {}, now);
  assert.equal(items.filter((x) => x.key.startsWith('habit|m|')).length, 7);
  assert.equal(items.some((x) => x.key.startsWith('habit|n|')), false);
  const win = { ...h, remind: { win: true } };
  assert.equal(habitWinDue([win], {}, [], now).length, 0); // 9:00 — ещё рано
  const at = new Date(2030, 0, 7, 10, 5);
  assert.equal(habitWinDue([win], {}, [], at).length, 1);
  assert.equal(habitWinDue([win], {}, ['m|2030-01-07'], at).length, 0);
});
