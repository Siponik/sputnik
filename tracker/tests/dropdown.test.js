// Выпадающий список (lib/dropdown.js): поиск, ходьба по пунктам, буквы, «несколько сразу», место меню.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { filterOpts, marks, moveActive, jumpTo, toggleIn, buttonText, placeMenu } from '../src/lib/dropdown.js';
import { listChoices } from '../src/lib/spheres.js';

const opts = [
  { id: 'a', label: 'Входящие' },
  { id: 'b', label: 'В работе', disabled: true },
  { id: 'c', label: 'На проверке' },
  { id: 'd', label: 'Готово' },
];

test('поиск: все слова, ё = е, без регистра', () => {
  const l = [{ id: 1, label: 'Ёлка к празднику' }, { id: 2, label: 'Сайт студии' }];
  assert.deepEqual(filterOpts(l, 'елка').map((o) => o.id), [1]);
  assert.deepEqual(filterOpts(l, 'САЙ студ').map((o) => o.id), [2]);
  assert.equal(filterOpts(l, '  ').length, 2);
  assert.equal(filterOpts(l, 'текстуры').length, 0);
});

test('подсветка совпадения', () => {
  assert.deepEqual(marks('Сайт студии', 'сай'), [{ t: 'Сай', hit: true }, { t: 'т студии', hit: false }]);
  assert.deepEqual(marks('Ёлка', 'ел'), [{ t: 'Ёл', hit: true }, { t: 'ка', hit: false }]);
  assert.deepEqual(marks('Готово', ''), [{ t: 'Готово', hit: false }]);
});

test('стрелки по кругу, недоступные пропускаются, Home/End', () => {
  assert.equal(moveActive(opts, -1, 'ArrowDown'), 0);
  assert.equal(moveActive(opts, 0, 'ArrowDown'), 2);
  assert.equal(moveActive(opts, 3, 'ArrowDown'), 0);
  assert.equal(moveActive(opts, 0, 'ArrowUp'), 3);
  assert.equal(moveActive(opts, -1, 'ArrowUp'), 3);
  assert.equal(moveActive(opts, 2, 'Home'), 0);
  assert.equal(moveActive(opts, 0, 'End'), 3);
  assert.equal(moveActive([{ id: 1, label: 'x', disabled: true }], -1, 'ArrowDown'), -1);
  assert.equal(moveActive([], -1, 'ArrowDown'), -1);
});

test('буква — прыжок к следующему пункту на неё', () => {
  assert.equal(jumpTo(opts, -1, 'г'), 3);
  assert.equal(jumpTo(opts, -1, 'в'), 0);
  assert.equal(jumpTo(opts, 0, 'в'), 0); // «В работе» недоступен — остаёмся
  assert.equal(jumpTo(opts, 2, 'я'), 2);
});

test('несколько сразу: порядок как в списке, подпись «первые два, +N»', () => {
  const l = [{ id: 15, label: 'За 15 минут' }, { id: 60, label: 'За час' }, { id: 1440, label: 'За день' }, { id: 10080, label: 'За неделю' }];
  assert.deepEqual(toggleIn([1440], 15, l), [15, 1440]);
  assert.deepEqual(toggleIn([15, 1440], 15, l), [1440]);
  assert.equal(buttonText(l, [], true), '');
  assert.equal(buttonText(l, [60, 15], true), 'За 15 минут, За час');
  assert.equal(buttonText(l, [15, 60, 1440, 10080], true), 'За 15 минут, За час, +2');
  assert.equal(buttonText(l, 60), 'За час');
  assert.equal(buttonText(l, 'нет'), '');
});

test('место меню: под кнопкой, не влезает — над ней, ширина от кнопки до 320', () => {
  const view = { w: 1200, h: 800 };
  const btn = { left: 100, top: 100, bottom: 134, width: 180 };
  const d = placeMenu(btn, 200, 120, view);
  assert.equal(d.up, false);
  assert.equal(d.top, 140);
  assert.equal(d.width, 180);
  assert.equal(placeMenu(btn, 200, 500, view).width, 320);
  const low = placeMenu({ left: 100, top: 700, bottom: 734, width: 180 }, 200, 120, view);
  assert.equal(low.up, true);
  assert.equal(low.bottom, 800 - 694);
  assert.equal(low.top, null);
  const right = placeMenu({ left: 1150, top: 100, bottom: 134, width: 40 }, 100, 200, view);
  assert.equal(right.left, 1200 - 8 - 200);
});

test('списки для выпадающего списка — группы по сферам', () => {
  const lay = { spheres: { w: { name: 'Работа', color: 'blue', order: 1 }, h: { name: 'Дом', order: 2 } }, lists: { l1: { sphere: 'w' }, l3: { sphere: 'h' } } };
  const { options, groups } = listChoices([{ id: 'l1', title: 'Сайт' }, { id: 'l2', title: 'Разное' }, { id: 'l3', title: 'Ремонт' }], lay);
  assert.deepEqual(groups.map((g) => g.name), ['Работа', 'Дом', 'Без сферы']);
  assert.deepEqual(options.map((o) => o.group), ['w', '', 'h']);
  assert.equal(listChoices([{ id: 'l2', title: 'Разное' }], {}).groups, null);
});
