// Общий редактор доски — шаблон и список (src/lib/boardedit.js).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import * as E from '../src/lib/boardedit.js';
import { templateOf } from '../src/lib/templates.js';

const work = templateOf('work');
const ids = (cols) => cols.map((c) => c.id).join(' ');

test('draftOf — копия, правка черновика не трогает шаблон', () => {
  const d = E.draftOf(work);
  d.cols[0].name = 'x'; d.fields.push('time');
  assert.equal(work.cols[0].name, 'Входящие');
  assert.ok(!work.fields.includes('time'));
});

test('moveCol: «Готово» не двигается и ничего не встаёт после неё', () => {
  assert.equal(ids(E.moveCol(work.cols, 0, 2)), 'doing review inbox done');
  assert.equal(ids(E.moveCol(work.cols, 0, 9)), 'doing review inbox done');
  assert.equal(E.moveCol(work.cols, 3, 0), work.cols);
  assert.equal(ids(E.moveCol(work.cols, 2, 0)), 'review inbox doing done');
  assert.equal(E.moveCol(work.cols, 1, 1), work.cols);
});

test('цвет по кругу, лимит 0…20', () => {
  assert.equal(E.recolor({ color: 6 }).color, 0);
  assert.equal(E.relimit({ limit: 0 }, -1).limit, 0);
  assert.equal(E.relimit({ limit: 20 }, 1).limit, 20);
  assert.equal(E.relimit({ limit: 2 }, 1).limit, 3);
});

test('dropCol: задачи едут в соседнюю, цепочки переезжают дальше; «Готово» и последние две не удаляются', () => {
  const a = E.dropCol(work.cols, 2, [], 4); // «На ревью» → «В работе»
  assert.equal(ids(a.cols), 'inbox doing done');
  assert.deepEqual(a.removed, [{ id: 'review', name: 'На ревью', to: 'doing', toName: 'В работе', n: 4 }]);
  const b = E.dropCol(a.cols, 1, a.removed, 1); // теперь «В работе» → «Входящие», и задачи ревью тоже
  assert.deepEqual(b.removed.map((r) => `${r.id}>${r.to}`), ['review>inbox', 'doing>inbox']);
  assert.equal(E.dropCol(b.cols, 0), null);
  assert.equal(E.dropCol(work.cols, 3), null);
  assert.equal(E.dropCol(work.cols, 0).removed[0].to, 'doing'); // у первой — правая
});

test('toggleField', () => {
  assert.deepEqual(E.toggleField(['due'], 'prio'), ['due', 'prio']);
  assert.deepEqual(E.toggleField(['due', 'prio'], 'due'), ['prio']);
});

test('слова: задачи и списки', () => {
  assert.equal(E.tasksWord(1), '1 задача');
  assert.equal(E.tasksWord(3), '3 задачи');
  assert.equal(E.tasksWord(11), '11 задач');
  assert.equal(E.tasksWord(22), '22 задачи');
  assert.equal(E.tasksWord(0), '0 задач');
  assert.equal(E.listsWord(1), '1 список');
  assert.equal(E.listsWord(3), '3 списка');
  assert.equal(E.listsWord(5), '5 списков');
});

test('colIsOwn: новая или переименованная колонка — «своя»', () => {
  assert.equal(E.colIsOwn({ id: 'inbox', name: 'Входящие' }, work.cols), false);
  assert.equal(E.colIsOwn({ id: 'inbox', name: 'Новое' }, work.cols), true);
  assert.equal(E.colIsOwn({ id: 'c1', name: 'Тест' }, work.cols), true);
});

test('changes: что поменялось — для строки «изменения: …»', () => {
  const d = E.draftOf(work);
  assert.deepEqual(E.changes(work, d), []);
  d.cols.splice(2, 0, { id: 'c1', name: 'Тест на 2 компах', color: 4, limit: 0 });
  d.fields = E.toggleField(d.fields, 'time');
  assert.deepEqual(E.changes(work, d), ['колонка «Тест на 2 компах»', 'поля']);
  const m = E.draftOf(work); m.cols = E.moveCol(m.cols, 0, 1); m.view = 'list';
  assert.deepEqual(E.changes(work, m), ['порядок колонок', 'вид']);
});

test('sampleTask: открытая задача, где видно больше полей; нет задач — null', () => {
  const tasks = [{ id: 'a', status: 'needsAction' }, { id: 'b', status: 'needsAction', due: '2026-10-30' }, { id: 'c', status: 'completed', due: 'x' }, { id: 's', parent: 'b', status: 'needsAction' }];
  assert.equal(E.sampleTask(tasks, { b: { priority: 1 } }).id, 'b');
  assert.equal(E.sampleTask([], {}), null);
});

test('previewCount: настоящие (до 3), у пустого — для вида', () => {
  assert.equal(E.previewCount(7, 0, 4), 3);
  assert.equal(E.previewCount(0, 0, 4), 0);
  assert.equal(E.previewCount(null, 0, 4), 3);
  assert.equal(E.previewCount(null, 3, 4), 2);
  assert.equal(E.previewCount(null, 1, 4), 1);
});
