// Ответ синхронизации не затирает правки, сделанные пока он шёл (src/lib/fresh.js).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { keepLocal } from '../src/lib/fresh.js';

const T = (id, status = 'needsAction') => ({ id, status });

test('отмеченная во время обмена задача остаётся отмеченной', () => {
  const fetched = [T('a'), T('b')]; // ответ запрошен до отметки
  const local = [T('a', 'completed'), T('b')];
  const out = keepLocal(fetched, local, new Set(['a', 'b']), new Map([['a', 200]]), 100);
  assert.equal(out.find((t) => t.id === 'a').status, 'completed');
});

test('правка до запроса — побеждает ответ Google', () => {
  const out = keepLocal([T('a', 'completed')], [T('a')], new Set(['a']), new Map([['a', 50]]), 100);
  assert.equal(out[0].status, 'completed');
});

test('созданная во время обмена задача не пропадает, удалённая не возвращается', () => {
  const out = keepLocal([T('a'), T('gone')], [T('a'), T('new')], new Set(['a', 'gone']), new Map(), 100);
  assert.deepEqual(out.map((t) => t.id), ['a', 'new']);
});

test('удалённая на другом компьютере уходит', () => {
  const out = keepLocal([T('a')], [T('a'), T('other')], new Set(['a', 'other']), new Map(), 100);
  assert.deepEqual(out.map((t) => t.id), ['a']);
});
