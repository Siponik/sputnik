// Учёт времени по задаче (src/lib/timer.js).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spentMin, runningId, toggle, stopPatch, fmtMin, clock } from '../src/lib/timer.js';

const H = 3600e3;

test('набранное + идущий таймер; забытый на ночь — не больше 12 ч', () => {
  assert.equal(spentMin({ spent: 30 }, 0), 30);
  assert.equal(spentMin({ spent: 30, timer: { start: 1 } }, 15 * 60e3 + 1), 45);
  assert.equal(spentMin({ timer: { start: 1 } }, 20 * H), 12 * 60);
  assert.equal(spentMin(undefined), 0);
});

test('запуск другой задачи останавливает текущую, повторный — останавливает', () => {
  const lay = { a: { timer: { start: 1 }, spent: 10 }, b: {} };
  const p = Object.fromEntries(toggle(lay, 'b', 30 * 60e3 + 1));
  assert.deepEqual(p.a, { spent: 40, timer: null });
  assert.deepEqual(p.b, { timer: { start: 30 * 60e3 + 1 } });
  assert.deepEqual(toggle({ a: { timer: { start: 1 } } }, 'a', 60e3 + 1), [['a', { spent: 1, timer: null }]]);
});

test('идёт только один — самый свежий', () => {
  assert.equal(runningId({ a: { timer: { start: 5 } }, b: { timer: { start: 9 } }, c: {} }), 'b');
  assert.equal(runningId({ a: { timer: null } }), null);
  assert.deepEqual(stopPatch({ spent: 1.04 }, 0), { spent: 1, timer: null });
});

test('подписи', () => {
  assert.equal(fmtMin(0.5), 'меньше минуты');
  assert.equal(fmtMin(12), '12 мин');
  assert.equal(fmtMin(65), '1 ч 05 мин');
  assert.equal(clock(3725e3), '1:02:05');
});
