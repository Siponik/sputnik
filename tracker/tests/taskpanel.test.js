// Окно задачи v2 (lib/taskpanel.js): счётчики колонок, вид этапа, подписи напоминаний, «Ещё».
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { colCounts, stageMode, leadChip, customChip, splitRemind, joinRemind, moreFilled } from '../src/lib/taskpanel.js';

const cols = [{ id: 'inbox' }, { id: 'doing', limit: 3 }, { id: 'done' }];

test('счётчики колонок: только открытые задачи верхнего уровня, без статуса — первая колонка', () => {
  const tasks = [
    { id: 'a' }, { id: 'b' }, { id: 'c', status: 'completed' }, { id: 'd', parent: 'b' }, { id: 'e' },
  ];
  const lay = { b: { status: 'doing' }, e: { status: 'нет-такой' } };
  assert.deepEqual(colCounts(tasks, cols, lay), { inbox: 2, doing: 1, done: 0 });
  assert.deepEqual(colCounts([], []), {});
});

test('вид этапа: Конвейер — дорожка, до 4 колонок — чипы, больше — список', () => {
  assert.equal(stageMode('pipe', cols), 'track');
  assert.equal(stageMode('kanban', cols), 'chips');
  assert.equal(stageMode('list', [1, 2, 3, 4, 5].map((id) => ({ id }))), 'menu');
});

test('подписи напоминаний', () => {
  assert.equal(leadChip(60), 'за час');
  assert.equal(leadChip(0), 'в момент начала');
  assert.equal(leadChip(7), 'за 7 мин');
  assert.equal(customChip({ kind: 'before', days: 1, time: '09:30' }), 'за 1 день в 09:30');
  assert.equal(customChip({ kind: 'before', days: 0 }), 'в день срока в 10:00');
  assert.match(customChip({ kind: 'at', at: '2026-10-29T18:00' }), /^29 окт\.? в 18:00$/);
  assert.equal(customChip(null), '');
});

test('напоминания: разобрать и собрать обратно', () => {
  const r = [{ kind: 'lead', min: 60 }, { kind: 'before', days: 1, time: '10:00' }];
  assert.deepEqual(splitRemind(r), { leads: [60], custom: r[1] });
  assert.deepEqual(splitRemind(null), { leads: [], custom: null });
  assert.deepEqual(joinRemind([60], r[1]), r);
  assert.deepEqual(joinRemind([15]), { kind: 'lead', min: 15 });
  assert.equal(joinRemind([], null), null);
});

test('«Ещё» открыто сразу, если там что-то заполнено', () => {
  assert.equal(moreFilled({}), false);
  assert.equal(moreFilled({ repeat: { every: 'week' } }), true);
  assert.equal(moreFilled({ type: 'work' }), true);
  assert.equal(moreFilled({ preview: { thumb: 'x' } }), true);
  assert.equal(moreFilled(undefined), false);
});
