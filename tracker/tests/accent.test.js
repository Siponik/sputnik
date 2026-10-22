// Акцентный цвет (src/lib/accent.js): наборы, свой цвет, CSS для тем.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import * as accent from '../src/lib/accent.js';

test('Глина по умолчанию — CSS пустой, работают токены как есть', () => {
  assert.equal(accent.accentCss(undefined), '');
  assert.equal(accent.accentCss('clay'), '');
  assert.equal(accent.accentCss('нечто'), '');
});

test('все наборы читаются: на тёмном фоне и на белом контраст не меньше 4.5', () => {
  for (const a of accent.ACCENTS) {
    assert.ok(accent.contrast(a.dark, '#1C1B19') >= 4.5, a.id + ' тёмная');
    assert.ok(accent.contrast(a.light, '#FFFFFF') >= 4.5, a.id + ' светлая');
  }
});

test('набор: CSS меняет три переменные в тёмной и светлой теме', () => {
  const css = accent.accentCss('mint');
  assert.match(css, /:root:root \{ --clay: #5DBB98;/);
  assert.match(css, /\[data-theme="light"\] \{ --clay: #1E7356;/);
  assert.match(css, /prefers-color-scheme: light/);
  assert.equal((css.match(/--on-clay/g) || []).length, 3);
});

test('свой цвет: слишком светлый темнеет для светлой темы, слишком тёмный светлеет для тёмной', () => {
  const y = accent.accentOf('#ffee00');
  assert.equal(y.id, 'custom');
  assert.equal(y.dark, '#FFEE00');
  assert.ok(accent.contrast(y.light, '#FFFFFF') >= 4.5);
  const n = accent.accentOf('#102030');
  assert.ok(accent.contrast(n.dark, '#1C1B19') >= 4.5);
  assert.equal(n.light, '#102030');
});

test('текст на акценте: на светлом акценте тёмный, на тёмном — белый', () => {
  assert.equal(accent.vars('#FFEE00', 'dark').on, '#1C1B19');
  assert.equal(accent.vars('#2D5BA8', 'light').on, '#FFFFFF');
});
