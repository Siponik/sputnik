// Раскладка сетки недели (lib/calendar.js) и «Входящие от Claude» (lib/inbox.js).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { hourLayout, periodDays, toMin, fromMin, HOUR_PX, HOUR_EMPTY, BAND_MAX } from '../src/lib/calendar.js';
import { pending, layerPatches } from '../src/lib/inbox.js';

test('hourLayout: занятые часы 40 px, пустые сжаты в полосы', () => {
  const L = hourLayout([{ s: toMin('10:00'), e: toMin('11:30') }]);
  assert.equal(L.HT[10], HOUR_PX);
  assert.equal(L.HT[11], HOUR_PX);
  assert.equal(L.HT[12], BAND_MAX / 12);
  assert.equal(L.height, 2 * HOUR_PX + 2 * BAND_MAX);
  assert.deepEqual(L.bands.map((b) => [b.a, b.b, b.h]), [[0, 10, BAND_MAX], [12, 24, BAND_MAX]]);
  assert.equal(L.yAt(toMin('10:30')), BAND_MAX + HOUR_PX / 2);
  assert.ok(L.labels.some((l) => l.text === '00–10') && L.labels.some((l) => l.text === '12–00'));
});

test('hourLayout: короткая полоса — 12 px на час и без подписи', () => {
  const L = hourLayout([{ s: toMin('09:00'), e: toMin('17:00') }, { s: toMin('18:00'), e: toMin('19:00') }]);
  assert.equal(L.HT[17], HOUR_EMPTY);
  const b = L.bands.find((x) => x.a === 17);
  assert.equal(b.h, HOUR_EMPTY);
  assert.equal(b.text, '17–18');
  assert.ok(!L.labels.some((l) => l.text === '17–18'));
});

test('hourLayout fit: сутки укладываются в окно', () => {
  const L = hourLayout([{ s: 600, e: 720 }], [], 600);
  assert.ok(L.height <= 600 + 72);
  assert.ok(L.HT[10] >= 30 && L.HT[10] <= 72);
});

test('periodDays: неделя с понедельника, месяц — 42 дня', () => {
  const w = periodDays('2026-10-22', 'week');
  assert.equal(w[0], '2026-10-19');
  assert.equal(w.length, 7);
  const m = periodDays('2026-10-22', 'month');
  assert.equal(m.length, 42);
  assert.equal(m[0], '2026-09-28');
  assert.equal(fromMin(toMin('07:05')), '07:05');
});

const status = {
  processed: {
    m1: { ok: true, from: 'чат', at: '2026-10-20T10:00:00Z', created: [{ op: 'task.create', taskId: 'a' }, { op: 'task.create', taskId: 'b', existed: true }] },
    m2: { ok: false, created: [{ op: 'task.create', taskId: 'c' }] },
  },
  pendingLayer: {
    a: { type: 'creative', priority: 1, slot: { s: '17:00', e: '18:00' }, tags: ['x', 3] },
    z: { type: 'unknown', priority: 9, slot: { s: '18:00', e: '17:00' } },
    done: { type: 'work' },
  },
};

test('inbox.pending: только новые открытые задачи без решения', () => {
  const lists = [{ id: 'L', title: 'Работа' }];
  const tasks = { L: [{ id: 'a', status: 'needsAction' }, { id: 'b', status: 'needsAction' }, { id: 'c', status: 'needsAction' }] };
  assert.deepEqual(pending(status, lists, tasks, {}).map((x) => x.task.id), ['a']);
  assert.deepEqual(pending(status, lists, tasks, { a: { inbox: 'accepted' } }), []);
});

test('inbox.layerPatches: проверяет поля и не переносит дважды', () => {
  const p = Object.fromEntries(layerPatches(status, { done: { pulled: true } }));
  assert.deepEqual(p.a, { pulled: true, type: 'creative', priority: 1, slot: { s: '17:00', e: '18:00' }, tags: ['x'] });
  assert.deepEqual(p.z, { pulled: true });
  assert.equal(p.done, undefined);
});
