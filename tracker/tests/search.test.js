// Поиск Ctrl+K (lib/search.js).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { score, findTasks, findPlaces, norm } from '../src/lib/search.js';

test('norm: регистр, ё, пробелы', () => assert.equal(norm('  Ёлка   ДЛЯ  '), 'елка для'));

test('score: все слова должны найтись; начало названия весит больше', () => {
  assert.ok(score('рендер', 'Рендер таверны') > score('рендер', 'Финальный рендер'));
  assert.ok(score('рендер', 'Финальный рендер') > score('ендер', 'Финальный рендер'));
  assert.ok(score('рендер', 'Скетч', 'потом рендер') > 0);
  assert.equal(score('рендер таверн', 'Рендер замка'), 0);
  assert.equal(score('', 'что угодно'), 0);
  assert.ok(score('(1', 'Задача (1)') > 0, 'спецсимволы не ломают поиск');
});

test('findTasks: открытые выше выполненных, подзадачи с родителем', () => {
  const lists = [{ id: 'A', title: 'Работа' }, { id: 'B', title: 'Личное' }];
  const tasks = {
    A: [{ id: '1', title: 'Рендер v1', status: 'completed' }, { id: '2', title: 'Рендер v2', status: 'needsAction' }, { id: '3', title: 'рендер теней', parent: '2', status: 'needsAction' }],
    B: [{ id: '4', title: 'Купить ёлку', status: 'needsAction' }],
  };
  const r = findTasks('рендер', lists, tasks);
  assert.deepEqual(r.map((x) => x.task.id), ['2', '3', '1']);
  assert.equal(r[1].parent.id, '2');
  assert.equal(findTasks('елку', lists, tasks)[0].list.title, 'Личное');
});

test('findPlaces: по имени и синонимам', () => {
  const places = [{ id: 'c', name: 'Календарь', alias: ['неделя'] }, { id: 'w', name: 'Работа' }];
  assert.deepEqual(findPlaces('нед', places).map((p) => p.id), ['c']);
  assert.deepEqual(findPlaces('раб', places).map((p) => p.id), ['w']);
  assert.equal(findPlaces('', places).length, 2);
});
