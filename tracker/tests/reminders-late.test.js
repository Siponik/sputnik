// Напоминание «до начала», которое уже лежит в файле, не пропадает из него, даже если скрипт опоздал (src/lib/reminders.js).
import { test } from 'node:test';
import assert from 'node:assert/strict';

const writes = [];
globalThis.window = { __TAURI_INTERNALS__: { invoke: async (cmd, a) => {
  if (a.method === 'GET') return { files: [{ id: 'F' }] };
  writes.push(a.body);
  return {};
} } };
const { collect, publish } = await import('../src/lib/reminders.js');

const ymd = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const hm = (d) => `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
const lists = [{ id: 'L', title: 'Работа' }];

function setup(minAgo) {
  const start = new Date(Date.now() - minAgo * 60e3); // начало задачи; напоминание «в момент начала»
  start.setSeconds(0, 0);
  const tasks = { L: [{ id: 't', title: 'Рендер', status: 'needsAction', due: `${ymd(start)}T00:00:00.000Z` }] };
  const lay = { t: { remind: { kind: 'lead', min: 0 }, slot: { s: hm(start), e: '23:59' } } };
  return () => collect(lists, tasks, lay);
}

test('прошедшее «до начала» не добавляется заново, а уже записанное — остаётся', async () => {
  assert.equal(setup(10)().length, 0, 'новое прошедшее — не шлём');

  const now = setup(0);
  const items = now();
  assert.equal(items.length, 1);
  await publish(items);
  assert.equal(writes.at(-1).items.length, 1);

  // Прошло 10 минут, а скрипт ещё не забрал напоминание — в файле оно остаётся.
  const realNow = Date.now;
  Date.now = () => realNow() + 10 * 60e3;
  try { assert.equal(now().length, 1); } finally { Date.now = realNow; }
});
