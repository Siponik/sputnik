// Слияние слоя между компьютерами (lib/layer.js).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { merge, same, emptyLayer, needsLogin, SECTIONS } from '../src/lib/layer.js';

test('первый запуск: облака нет — заливаем локальный слой', () => {
  const local = { ...emptyLayer(), tasks: { a: { status: 'doing', t: 5 } } };
  const r = merge(local, null);
  assert.equal(r.remoteChanged, true);
  assert.equal(r.localChanged, false);
  assert.deepEqual(r.merged.tasks, local.tasks);
});

test('второй компьютер: пустой слой получает всё из облака', () => {
  const remote = { ...emptyLayer(), tasks: { a: { status: 'doing', t: 5 } }, spheres: { s: { name: 'Работа', t: 3 } } };
  const r = merge(emptyLayer(), remote);
  assert.equal(r.localChanged, true);
  assert.equal(r.remoteChanged, false);
  assert.deepEqual(r.merged.spheres, remote.spheres);
});

test('по каждой записи побеждает более свежая', () => {
  const local = { tasks: { a: { status: 'doing', t: 10 }, b: { status: 'inbox', t: 1 } } };
  const remote = { tasks: { a: { status: 'review', t: 5 }, b: { status: 'done', t: 7 } } };
  const r = merge(local, remote);
  assert.equal(r.merged.tasks.a.status, 'doing');
  assert.equal(r.merged.tasks.b.status, 'done');
  assert.equal(r.localChanged, true);
  assert.equal(r.remoteChanged, true);
});

test('одинаковые слои — ничего не пишем', () => {
  const a = { ...emptyLayer(), log: { 'h|2026-10-20': { done: true, t: 3 } }, settings: { motion: { v: 'min', t: 2 } } };
  const b = structuredClone(a);
  b.settings.motion = { t: 2, v: 'min' }; // другой порядок ключей
  const r = merge(a, b);
  assert.equal(r.localChanged, false);
  assert.equal(r.remoteChanged, false);
});

test('старые записи без t: оба компьютера выбирают одно и то же и не перетягивают запись', () => {
  const A = { lists: { L: { template: 'work' } } };
  const B = { lists: { L: { template: 'asset3d' } } };
  const fromA = merge(A, B).merged.lists.L;
  const fromB = merge(B, A).merged.lists.L;
  assert.deepEqual(fromA, fromB);
  // После обмена оба сходятся и больше не пишут.
  const settled = merge(merge(A, B).merged, merge(B, A).merged);
  assert.equal(settled.localChanged || settled.remoteChanged, false);
});

test('надгробие свежее записи — удаление не откатывается', () => {
  const local = { habits: { h: { gone: true, t: 20 } }, log: { 'h|2026-10-19': { gone: true, t: 20 } } };
  const remote = { habits: { h: { days: [0, 1], t: 10 } }, log: { 'h|2026-10-19': { done: true, t: 10 } } };
  const r = merge(local, remote);
  assert.deepEqual(r.merged.habits.h, { gone: true, t: 20 });
  assert.equal(r.merged.log['h|2026-10-19'].done, undefined);
  assert.equal(r.remoteChanged, true);
});

test('новые разделы от более свежей версии трекера не теряются', () => {
  const remote = { future: { x: { y: 1, t: 1 } } };
  const r = merge(emptyLayer(), remote);
  assert.deepEqual(r.merged.future, { x: { y: 1, t: 1 } });
  for (const s of SECTIONS) assert.ok(r.merged[s] && typeof r.merged[s] === 'object');
});

test('same и needsLogin', () => {
  assert.ok(same({ a: [1, { b: 2 }] }, { a: [1, { b: 2 }] }));
  assert.ok(!same({ a: [1] }, { a: { 0: 1 } }));
  assert.ok(!same({ a: 1 }, { a: 1, b: undefined }));
  assert.ok(needsLogin('Google ответил 403: Request had insufficient authentication scopes.'));
  assert.ok(!needsLogin('Нет связи с Google: dns error'));
});
