// Настройки → «Клавиши» берут клавиши из того же списка, что окно «?» (src/lib/keys.js).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { HOTKEYS, settingsKeys } from '../src/lib/keys.js';

test('в Настройках 4 группы, у каждой есть клавиши', () => {
  const g = settingsKeys();
  assert.deepEqual(g.map((x) => x.group), ['Везде', 'Доска', 'Календарь', 'Стикеры']);
  for (const x of g) assert.ok(x.keys.length >= 3, x.group);
});

test('клавиши в Настройках — те же, что в окне «?»', () => {
  const all = new Set(HOTKEYS.flatMap((g) => g.keys.map((k) => k[0])));
  for (const x of settingsKeys()) for (const [k] of x.keys) assert.ok(all.has(k), k);
  assert.ok(settingsKeys()[0].keys.some(([k]) => k === 'Ctrl+B'));
  assert.ok(settingsKeys()[0].keys.some(([k]) => k === 'Ctrl+,'));
});
