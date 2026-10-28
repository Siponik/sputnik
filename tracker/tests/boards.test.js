// Шаблон и список — раздельно (src/lib/templates.js: boardOf, «своё», перенос задач, «Вернуть как в шаблоне»).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  boardOf, follows, isOwn, ownPatch, resetPatch, matchCols, relocate, lostMoves,
  saveListPlan, resetListPlan, archiveDays, isArchived, templateOf, sameShape, sortOf, orderTasks,
} from '../src/lib/templates.js';

const T = (id, extra = {}) => ({ id, title: id, status: 'needsAction', ...extra });
const work = templateOf('work');

test('boardOf: список без своей копии — колонки и поля шаблона', () => {
  const lay = { lists: { A: { template: 'work' } } };
  const b = boardOf('A', lay);
  assert.equal(b.id, 'work');
  assert.deepEqual(b.cols.map((c) => c.id), ['inbox', 'doing', 'review', 'done']);
  assert.deepEqual(b.fields, work.fields);
  assert.equal(b.view, 'kanban');
  assert.equal(b.own, false);
});

test('boardOf: своя копия накладывается поверх шаблона', () => {
  const cols = [{ id: 'a', name: 'Идеи', color: 1, limit: 0 }, { id: 'done', name: 'Готово', color: 6, limit: 0 }];
  const lay = { lists: { A: { template: 'work', cols, fields: ['due'], view: 'list' } } };
  const b = boardOf('A', lay);
  assert.deepEqual(b.cols.map((c) => c.name), ['Идеи', 'Готово']);
  assert.deepEqual(b.fields, ['due']);
  assert.equal(b.view, 'list');
  assert.equal(b.own, true);
  assert.equal(b.base.id, 'work');
  b.cols[0].name = 'x'; // копия, слой не меняется
  assert.equal(lay.lists.A.cols[0].name, 'Идеи');
});

test('boardOf: битая копия колонок (без «готово» или одна колонка) не ломает доску', () => {
  const lay = { lists: { A: { template: 'study', cols: [{ id: 'a', name: 'A' }] } } };
  assert.deepEqual(boardOf('A', lay).cols.map((c) => c.id), templateOf('study').cols.map((c) => c.id));
  assert.equal(isOwn(lay.lists.A), false);
});

test('правка шаблона доходит только до списков «по шаблону»', () => {
  const lay = {
    lists: { A: { template: 'work' }, B: { template: 'work', fields: ['due'] } },
    templatesEdit: { work: { name: 'Работа', view: 'kanban', fields: ['due'], cols: [{ id: 'inbox', name: 'Новое' }, { id: 'done', name: 'Готово' }] } },
  };
  assert.equal(follows('A', lay, 'work'), true);
  assert.equal(follows('B', lay, 'work'), false);
  assert.equal(boardOf('A', lay).cols[0].name, 'Новое');
  // у «своего» B поля свои, а колонок своих нет — колонки по-прежнему шаблонные
  assert.deepEqual(boardOf('B', lay).fields, ['due']);
});

test('ownPatch: чистая копия, пустое название — «Без названия»', () => {
  const p = ownPatch({ view: 'kanban', fields: ['due'], cols: [{ id: 'a', name: '  ', color: 2, limit: 3, extra: 1 }, { id: 'done', name: 'Готово' }] });
  assert.deepEqual(p.cols, [{ id: 'a', name: 'Без названия', color: 2, limit: 3 }, { id: 'done', name: 'Готово', color: 0, limit: 0 }]);
  assert.deepEqual(resetPatch(), { cols: null, fields: null, view: null });
});

test('matchCols: по названию, потом тот же id, иначе по порядку; «готово» — в последнюю', () => {
  const from = [{ id: 'a', name: 'Входящие' }, { id: 'doing', name: 'Пилю' }, { id: 'x', name: 'Странное' }, { id: 'y', name: 'Ещё' }, { id: 'done', name: 'Готово' }];
  const to = [{ id: 'inbox', name: 'входящие' }, { id: 'doing', name: 'В работе' }, { id: 'review', name: 'Ревью' }, { id: 'done', name: 'Сдано' }];
  assert.deepEqual(matchCols(from, to), { a: 'inbox', doing: 'doing', x: 'review', y: 'review', done: 'done' });
});

test('relocate: задачи из пропавших колонок переезжают, цепочки разворачиваются', () => {
  const tasks = [T('1'), T('2'), T('3'), T('4')];
  const lay = { 1: { status: 'a' }, 2: { status: 'b' }, 3: { status: 'keep' } }; // у 4 колонки нет — первая
  assert.deepEqual(relocate(tasks, lay, { a: 'b', b: 'c' }), [{ id: '1', status: 'c' }, { id: '2', status: 'c' }]);
  assert.deepEqual(relocate(tasks, lay, { a: 'a' }), []);
});

test('lostMoves: только колонки, которых нет в новой раскладке', () => {
  const now = [{ id: 'inbox', name: 'Входящие' }, { id: 'mine', name: 'Своя' }, { id: 'done', name: 'Готово' }];
  assert.deepEqual(lostMoves(now, work.cols), { mine: 'doing' });
});

test('saveListPlan: список становится «своим», задачи удалённой колонки уезжают куда сказали', () => {
  const lay = { lists: { A: { template: 'work' } }, tasks: { t1: { status: 'review' }, t2: { status: 'doing' } } };
  const draft = { view: 'kanban', fields: ['due'], cols: [work.cols[0], work.cols[1], work.cols[3]] };
  const auto = saveListPlan(lay, 'A', draft, [T('t1'), T('t2')]);
  assert.deepEqual(auto.moves, [{ id: 't1', status: 'doing' }]); // «На ревью» по порядку → «В работе»
  assert.equal(isOwn(auto.patch), true);
  const manual = saveListPlan(lay, 'A', draft, [T('t1')], [{ id: 'review', to: 'inbox' }]);
  assert.deepEqual(manual.moves, [{ id: 't1', status: 'inbox' }]);
});

test('resetListPlan: «Вернуть как в шаблоне» — копия убрана, задачи из своих колонок — в шаблонные', () => {
  const cols = [{ id: 'inbox', name: 'Входящие' }, { id: 'c1', name: 'На ревью' }, { id: 'c2', name: 'Потом' }, { id: 'done', name: 'Готово' }];
  const lay = { lists: { A: { template: 'work', cols, fields: ['due'] } }, tasks: { t1: { status: 'c1' }, t2: { status: 'c2' }, t3: { status: 'inbox' } } };
  const p = resetListPlan(lay, 'A', [T('t1'), T('t2'), T('t3')]);
  assert.deepEqual(p.patch, resetPatch());
  assert.deepEqual(p.moves, [{ id: 't1', status: 'review' }, { id: 't2', status: 'review' }]);
  // после сброса список снова идёт за шаблоном
  const after = { ...lay, lists: { A: { ...lay.lists.A, ...p.patch } } };
  assert.equal(follows('A', after, 'work'), true);
  assert.equal(boardOf('A', after).view, 'kanban');
});

test('архив: сразу / 3 дня / неделя, по умолчанию 3', () => {
  const now = Date.parse('2026-10-28T12:00:00Z');
  const done = (d) => ({ status: 'completed', completed: new Date(now - d * 864e5).toISOString() });
  assert.equal(archiveDays({}), 3);
  assert.equal(archiveDays({ archive: 0 }), 0);
  assert.equal(archiveDays({ archive: 7 }), 7);
  assert.equal(archiveDays({ archive: 5 }), 3);
  assert.equal(isArchived(done(0.01), 0, now), true);
  assert.equal(isArchived(done(4), 3, now), true);
  assert.equal(isArchived(done(4), 7, now), false);
  assert.equal(isArchived({ status: 'needsAction' }, 0, now), false);
});

test('sameShape: только вид поменяли — форма та же, список не становится «своим»', () => {
  const b = boardOf('A', { lists: { A: { template: 'work' } } });
  assert.equal(sameShape(b, { ...b, view: 'list' }), true);
  assert.equal(sameShape(b, { ...b, fields: [...b.fields].reverse() }), true);
  assert.equal(sameShape(b, { ...b, fields: ['due'] }), false);
  assert.equal(sameShape(b, { ...b, cols: b.cols.map((c, i) => (i ? c : { ...c, limit: 5 })) }), false);
});

test('порядок в колонке: свой / срок / приоритет', () => {
  const items = [T('a', { position: '1', due: '2026-11-05T00:00:00.000Z' }), T('b', { position: '2' }), T('c', { position: '3', due: '2026-10-30T00:00:00.000Z' })];
  const lay = { a: { priority: 3 }, b: { priority: 1 }, c: {} };
  const ids = (xs) => xs.map((t) => t.id).join('');
  assert.equal(sortOf({}), 'own');
  assert.equal(sortOf({ sort: 'pin' }), 'own'); // у стикеров своё значение — для доски это «свой»
  assert.equal(ids(orderTasks(items, lay, 'own')), 'bca'); // приоритет, без него — между !! и !
  assert.equal(ids(orderTasks(items, { ...lay, a: { priority: 3, ord: -5 } }, 'own')), 'abc'); // свой порядок главнее
  assert.equal(ids(orderTasks(items, lay, 'due')), 'cab'); // без срока внизу
  assert.equal(ids(orderTasks(items, lay, 'prio')), 'bca');
});

