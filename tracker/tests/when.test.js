// Разбор «когда» словами (lib/when.js) — строка «Сегодня», окно даты, задачи из чатов.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseWhen, whenText } from '../src/lib/when.js';

const TUE = new Date(2026, 9, 20, 9, 0); // вторник, 20 октября 2026

const cases = [
  ['позвонить маме завтра 17:00', { day: '2026-10-21', time: '17:00', rest: 'позвонить маме' }],
  ['скетч в пятницу 17.30', { day: '2026-10-23', time: '17:30', rest: 'скетч' }],
  ['созвон послезавтра в 15', { day: '2026-10-22', time: '15:00', rest: 'созвон' }],
  ['сдать рендер через 3 дня', { day: '2026-10-23', time: null, rest: 'сдать рендер' }],
  ['отпуск через 2 недели', { day: '2026-11-03', time: null, rest: 'отпуск' }],
  ['ревью 25 окт', { day: '2026-10-25', time: null, rest: 'ревью' }],
  ['новый год 1 января', { day: '2027-01-01', time: null, rest: 'новый год' }],
  ['налог 3.11', { day: '2026-11-03', time: null, rest: 'налог' }],
  ['встреча 5.01.2027 10:00', { day: '2027-01-05', time: '10:00', rest: 'встреча' }],
  ['спортзал во вторник', { day: '2026-10-27', time: null, rest: 'спортзал' }], // сегодняшний день недели — через неделю
  ['митинг пн 9:15', { day: '2026-10-26', time: '09:15', rest: 'митинг' }],
  ['сегодня весь день 10:00 конференция', { day: '2026-10-20', time: null, rest: 'конференция' }],
  ['просто задача', { day: null, time: null, rest: 'просто задача' }],
  ['купить 2 молока', { day: null, time: null, rest: 'купить 2 молока' }],
];

for (const [text, want] of cases) {
  test(`parseWhen: ${text}`, () => {
    const got = parseWhen(text, TUE);
    assert.deepEqual({ day: got.day, time: got.time, rest: got.rest }, want);
  });
}

test('whenText: подписи срока', () => {
  assert.deepEqual(whenText('2026-10-21', { s: '15:00', e: '16:00' }, TUE), { date: 'Завтра, 21 октября', time: '15:00–16:00' });
  assert.deepEqual(whenText('2026-10-20', null, TUE), { date: 'Сегодня, 20 октября', time: 'весь день' });
  assert.equal(whenText('2027-01-05', null, TUE).date, 'Вт, 5 января 2027');
  assert.deepEqual(whenText('', null, TUE), { date: 'Без срока', time: '' });
});
