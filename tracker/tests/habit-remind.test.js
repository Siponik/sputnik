// Напоминания о привычках (reminders.habitItems): по расписанию, без отмеченных, на неделю вперёд.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { habitItems } from '../src/lib/reminders.js';

const now = new Date(2026, 9, 21, 9, 0); // среда, 21 октября, 9:00
const days = (items) => items.map((x) => x.key.split('|')[2]);

test('каждый день — 7 напоминаний, первое сегодня', () => {
  const items = habitItems([{ id: 'h', name: 'Зарядка', days: [], time: '19:30' }], {}, now);
  assert.equal(items.length, 7);
  assert.deepEqual(new Date(items[0].fireAt), new Date(2026, 9, 21, 19, 30));
  assert.equal(items[0].kind, 'habit');
  assert.equal(items[0].taskId, undefined); // без кнопки «✓ Готово» в боте
});

test('без времени — ничего', () => {
  assert.deepEqual(habitItems([{ id: 'h', name: 'Чтение', days: [], time: null }], {}, now), []);
});

test('только дни по расписанию (пн = 0)', () => {
  const items = habitItems([{ id: 'h', name: 'Бег', days: [0, 4], time: '07:00' }], {}, now);
  assert.deepEqual(days(items), ['2026-10-23', '2026-10-26']); // пт и пн
});

test('сегодня уже отмечено или время прошло — не напоминаем', () => {
  const h = { id: 'h', name: 'Зарядка', days: [], time: '19:30' };
  assert.equal(days(habitItems([h], { 'h|2026-10-21': { done: true } }, now))[0], '2026-10-22');
  assert.equal(days(habitItems([{ ...h, time: '08:00' }], {}, now))[0], '2026-10-22');
});
