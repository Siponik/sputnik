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

test('классы окон поверх (keys.overlay) не встречаются в обычных экранах', async () => {
  // 23.10: превью доски в «Шаблонах» называлось .pvw — как окно картинки, растягивалось на весь экран и глушило клавиши.
  const { readFileSync, readdirSync } = await import('node:fs');
  const dir = new URL('../src/lib/', import.meta.url);
  const own = { pvw: 'PreviewView.svelte' };
  for (const f of readdirSync(dir).filter((n) => n.endsWith('.svelte'))) {
    const src = readFileSync(new URL(f, dir), 'utf8');
    for (const [cls, owner] of Object.entries(own)) {
      if (f !== owner) assert.ok(!new RegExp(`class="([^"]* )?${cls}( [^"]*)?"`).test(src), `${f}: класс .${cls} занят окном ${owner}`);
    }
  }
});
