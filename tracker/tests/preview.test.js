// Картинка задачи: размеры, разбор data URL, что принимаем (src/lib/preview.js).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import * as pv from '../src/lib/preview.js';

test('fitSize: вписывает по длинной стороне и не растягивает маленькое', () => {
  assert.deepEqual(pv.fitSize(4000, 2000, 1600), { w: 1600, h: 800 });
  assert.deepEqual(pv.fitSize(1000, 3000, 240), { w: 80, h: 240 });
  assert.deepEqual(pv.fitSize(100, 50, 240), { w: 100, h: 50 });
  assert.deepEqual(pv.fitSize(0, 50, 240), { w: 0, h: 0 });
});

test('dataUrlParts: тип и данные', () => {
  assert.deepEqual(pv.dataUrlParts('data:image/jpeg;base64,QUJD'), { mime: 'image/jpeg', b64: 'QUJD' });
  assert.equal(pv.dataUrlParts('blob:xyz'), null);
  assert.equal(pv.dataUrlParts(null), null);
});

test('isImage и rejectWhy: картинки берём, остальное и слишком большое — нет', () => {
  assert.ok(pv.isImage({ type: 'image/png' }));
  assert.ok(pv.isImage({ type: 'image/jpeg' }));
  assert.ok(!pv.isImage({ type: 'image/svg+xml' }));
  assert.ok(!pv.isImage({ type: 'application/pdf' }));
  assert.equal(pv.rejectWhy({ type: 'image/webp', size: 1000 }), '');
  assert.match(pv.rejectWhy({ type: 'text/plain', size: 10 }), /PNG/);
  assert.match(pv.rejectWhy({ type: 'image/png', size: 31 * 1024 * 1024 }), /30 МБ/);
  assert.match(pv.rejectWhy(null), /не картинка/);
});

test('imageFrom: файл из перетаскивания или из буфера обмена', () => {
  const png = { type: 'image/png', size: 5 };
  assert.equal(pv.imageFrom({ files: [{ type: 'text/plain' }, png] }), png);
  assert.equal(pv.imageFrom({ files: [], items: [{ kind: 'file', type: 'image/png', getAsFile: () => png }] }), png);
  assert.equal(pv.imageFrom({ files: [], items: [{ kind: 'string', type: 'text/plain' }] }), null);
  assert.equal(pv.imageFrom(null), null);
  assert.ok(pv.dragHasFile({ types: ['Files'] }));
  assert.ok(!pv.dragHasFile({ types: ['text/plain'] }));
});

test('fileName: без запрещённых знаков и не длинное', () => {
  assert.equal(pv.fileName('Меч: ретопология / v2'), 'Меч ретопология v2 · превью.jpg');
  assert.equal(pv.fileName(''), 'Задача · превью.jpg');
  assert.ok(pv.fileName('х'.repeat(200)).length < 100);
});

test('has: картинка есть, только если есть маленькая копия', () => {
  assert.ok(pv.has({ preview: { thumb: 'data:image/jpeg;base64,AA', file: 'F1' } }));
  assert.ok(!pv.has({ preview: null }));
  assert.ok(!pv.has(undefined));
});
