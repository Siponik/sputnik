// Напоминания (lib/reminders.js): когда срабатывают и что уходит в файл для бота.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fireAt, setDefaultTime, collect, defaultMins, defaultRule, minsToRule, rulesOf, leadsText } from '../src/lib/reminders.js';

const local = (y, m, d, hh = 0, mm = 0) => new Date(y, m - 1, d, hh, mm);
const task = (due, extra = {}) => ({ id: 't1', title: 'Рендер', due: `${due}T00:00:00.000Z`, status: 'needsAction', ...extra });

test('fireAt lead: от времени задачи, без времени — от 10:00', () => {
  assert.deepEqual(fireAt({ kind: 'lead', min: 60 }, task('2026-10-21'), { s: '15:00', e: '16:00' }), local(2026, 10, 21, 14, 0));
  assert.deepEqual(fireAt({ kind: 'lead', min: 0 }, task('2026-10-21')), local(2026, 10, 21, 10, 0));
  assert.deepEqual(fireAt({ kind: 'lead', min: 1440 }, task('2026-10-21'), { s: '09:30', e: '10:30' }), local(2026, 10, 20, 9, 30));
  assert.equal(fireAt({ kind: 'lead', min: 60 }, { title: 'без срока' }), null);
});

test('fireAt before / at — старые правила', () => {
  assert.deepEqual(fireAt({ kind: 'before', days: 1, time: '09:00' }, task('2026-10-21')), local(2026, 10, 20, 9, 0));
  assert.deepEqual(fireAt({ kind: 'before', days: 0 }, task('2026-10-21')), local(2026, 10, 21, 10, 0));
  assert.deepEqual(fireAt({ kind: 'at', at: '2026-10-22T08:15' }, task('2026-10-21')), local(2026, 10, 22, 8, 15));
  assert.equal(fireAt({ kind: 'at', at: 'чепуха' }, task('2026-10-21')), null);
  assert.equal(fireAt(null, task('2026-10-21')), null);
});

test('напоминания по умолчанию', () => {
  assert.deepEqual(defaultMins(undefined, 'task'), [60]);
  assert.deepEqual(defaultMins({}, 'birthday'), [1440, 0]);
  assert.deepEqual(defaultMins({ remind: { min: 15 } }, 'task'), [15]); // старая запись
  assert.deepEqual(defaultMins({ remind: { min: null } }, 'task'), []);
  assert.deepEqual(defaultMins({ remind: { event: [0, 60] } }, 'event'), [0, 60]);
  assert.deepEqual(defaultRule({ remind: { task: [] } }), null);
  assert.deepEqual(minsToRule([60, 1440, 60]), [{ kind: 'lead', min: 1440 }, { kind: 'lead', min: 60 }]);
  assert.deepEqual(rulesOf({ kind: 'lead', min: 5 }), [{ kind: 'lead', min: 5 }]);
  assert.equal(leadsText([60, 1440]), 'за день и за час');
});

test('collect: открытые задачи, свежие сроки, без выполненных', () => {
  const now = Date.now();
  const soon = new Date(now + 3 * 864e5);
  const due = `${soon.getFullYear()}-${String(soon.getMonth() + 1).padStart(2, '0')}-${String(soon.getDate()).padStart(2, '0')}`;
  const lists = [{ id: 'L', title: 'Работа' }];
  const tasks = { L: [task(due, { id: 'a' }), task(due, { id: 'b', status: 'completed' }), task(due, { id: 'c', deleted: true }), { id: 'd', title: 'старая', due: '2020-01-01T00:00:00.000Z' }] };
  const lay = { a: { remind: [{ kind: 'lead', min: 60 }, { kind: 'lead', min: 1440 }] }, b: { remind: { kind: 'lead', min: 0 } }, c: { remind: { kind: 'lead', min: 0 } }, d: { remind: { kind: 'lead', min: 0 } } };
  const items = collect(lists, tasks, lay);
  assert.equal(items.length, 2);
  assert.ok(items.every((i) => i.taskId === 'a' && i.list === 'Работа' && i.due === due));
  assert.ok(items[0].fireAt < items[1].fireAt, 'по времени');
  assert.equal(new Set(items.map((i) => i.key)).size, 2, 'ключи разные');
});

test('collect: события и дни рождения с напоминаниями', () => {
  const start = new Date(Date.now() + 2 * 864e5);
  const ev = { id: 'e1', summary: 'Созвон', start: { dateTime: start.toISOString() }, extendedProperties: { private: { sputnikR: '1', sputnikRemind: '15,60' } } };
  const bd = { id: 'e2', summary: '🎂 Аня', start: { date: '2099-05-01' }, extendedProperties: { private: { sputnik: 'birthday', sputnikRemind: '0' } } };
  const items = collect([], {}, {}, null, [], [ev, bd]);
  assert.equal(items.filter((i) => i.kind === 'event').length, 2);
  const b = items.find((i) => i.kind === 'birthday');
  assert.equal(b.title, 'Аня');
  assert.equal(b.due, '2099-05-01');
  assert.equal(b.lead, 'В день рождения');
});

test('«Задачи без времени — во сколько» (Настройки): без времени напоминание идёт от выбранного часа', () => {
  setDefaultTime('09:00');
  try {
    assert.deepEqual(fireAt({ kind: 'lead', min: 0 }, task('2026-10-21')), local(2026, 10, 21, 9, 0));
    assert.deepEqual(fireAt({ kind: 'lead', min: 60 }, task('2026-10-21'), { s: '15:00', e: '16:00' }), local(2026, 10, 21, 14, 0));
  } finally { setDefaultTime(null); }
  assert.deepEqual(fireAt({ kind: 'lead', min: 0 }, task('2026-10-21')), local(2026, 10, 21, 10, 0));
});

test('«Задачи без времени — не напоминать»: молчат только «до начала» у задач без времени', () => {
  setDefaultTime('off');
  try {
    assert.equal(fireAt({ kind: 'lead', min: 60 }, task('2026-10-21')), null);
    assert.deepEqual(fireAt({ kind: 'lead', min: 60 }, task('2026-10-21'), { s: '15:00', e: '16:00' }), local(2026, 10, 21, 14, 0));
    assert.deepEqual(fireAt({ kind: 'before', days: 1, time: '09:00' }, task('2026-10-21')), local(2026, 10, 20, 9, 0));
  } finally { setDefaultTime(null); }
});
