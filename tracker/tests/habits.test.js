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
