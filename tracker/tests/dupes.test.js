// Поиск дублей задач (src/lib/dupes.js).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { findDupes } from '../src/lib/dupes.js';

const T = (id, title, due = '', extra = {}) => ({ id, title, status: 'needsAction', due: due && `${due}T00:00:00.000Z`, ...extra });

test('одинаковое название и срок в одном списке — дубль; оставляем ту, у которой больше полей', () => {
  const tasks = { L: [T('a', 'Полить цветы', '2026-10-22'), T('b', 'полить цветы ', '2026-10-22'), T('c', 'Полить цветы', '2026-10-23')] };
  const g = findDupes(tasks, [{ id: 'L', title: 'Дом' }], { b: { topic: 'home', repeat: { every: 'day' }, t: 1 } });
  assert.equal(g.length, 1);
  assert.equal(g[0].keep.id, 'b');
  assert.deepEqual(g[0].extra.map((t) => t.id), ['a']);
});

test('выполненные, подзадачи и разные списки — не дубли', () => {
  const tasks = {
    L: [T('a', 'Х', '2026-10-22'), T('b', 'Х', '2026-10-22', { status: 'completed' }), T('c', 'Х', '2026-10-22', { parent: 'p' })],
    M: [T('d', 'Х', '2026-10-22')],
  };
  assert.equal(findDupes(tasks, [{ id: 'L' }, { id: 'M' }]).length, 0);
});

test('без срока тоже считается: три одинаковых — одна остаётся', () => {
  const g = findDupes({ L: [T('a', 'Звонок'), T('b', 'Звонок'), T('c', 'Звонок')] }, [{ id: 'L' }]);
  assert.equal(g[0].extra.length, 2);
});
