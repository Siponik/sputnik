// Общая сфера: записи в календаре, слияние по полям, сведение полей слоя (lib/sharedcore.js).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import * as sh from '../src/lib/sharedcore.js';

test('ключ — допустимый id события Google (0-9, a-v), вид — по первой букве', () => {
  const k = sh.newKey('t');
  assert.match(k, /^[0-9a-v]{17}$/);
  assert.equal(sh.kindOf(k), 'task');
  assert.equal(sh.kindOf(sh.newKey('l')), 'list');
  assert.equal(sh.kindOf(sh.SPHERE_KEY), 'sphere');
  assert.equal(sh.kindOf('xyz'), null);
});

test('id общих списков и сфер', () => {
  assert.equal(sh.listKey(sh.listId('labc')), 'labc');
  assert.equal(sh.calOfSphere(sh.sphereId('x@group.calendar.google.com')), 'x@group.calendar.google.com');
  assert.equal(sh.isSharedId('MTIzNDU2'), false);
  assert.equal(sh.listKey('MTIzNDU2'), null);
});

test('запись туда и обратно через событие', () => {
  const rec = sh.make('t0123456789abcdef', { list: 'l1', title: 'Модель', $status: 'doing' }, 100);
  const ev = sh.toEvent(rec);
  assert.equal(ev.id, rec.k);
  assert.equal(ev.transparency, 'transparent');
  assert.deepEqual(ev.reminders, { useDefault: false, overrides: [] });
  assert.deepEqual(sh.fromEvent(ev), rec);
});

test('чужие, испорченные и удалённые события — не записи', () => {
  assert.equal(sh.fromEvent({ summary: 'Встреча' }), null);
  assert.equal(sh.fromEvent({ extendedProperties: { shared: { sputnik: 'rec' } }, description: 'не json' }), null);
  const ev = sh.toEvent(sh.make('t0123456789abcdef', { title: 'a' }));
  assert.equal(sh.fromEvent({ ...ev, status: 'cancelled' }), null);
});

test('длинная заметка обрезается, чтобы влезть в описание события', () => {
  const ev = sh.toEvent(sh.make('t0123456789abcdef', { notes: 'я'.repeat(sh.NOTES_MAX + 500) }));
  assert.equal(JSON.parse(ev.description).f.notes.length, sh.NOTES_MAX);
});

test('правка меняет время только у изменённых полей', () => {
  const a = sh.make('t1', { title: 'A', due: null }, 100);
  const b = sh.edit(a, { title: 'B', due: null }, 200);
  assert.equal(b.f.title, 'B');
  assert.equal(b.ft.title, 200);
  assert.equal(b.ft.due, 100);
  assert.equal(sh.edit(b, { title: 'B' }, 300), b, 'ничего не поменялось — та же запись');
});

test('слияние по полям: двое поменяли разные поля одной задачи — сохраняются оба', () => {
  const base = sh.make('t1', { title: 'Модель', $status: 'inbox', $priority: 2 }, 100);
  const mine = sh.edit(base, { $status: 'doing' }, 200);
  const theirs = sh.edit(base, { $priority: 1 }, 210);
  const m1 = sh.mergeRec(mine, theirs), m2 = sh.mergeRec(theirs, mine);
  assert.deepEqual(m1, m2, 'одинаково с обеих сторон');
  assert.equal(m1.f.$status, 'doing');
  assert.equal(m1.f.$priority, 1);
  assert.equal(m1.f.title, 'Модель');
});

test('слияние: одно поле поменяли оба — побеждает более свежая правка', () => {
  const base = sh.make('t1', { title: 'Модель' }, 100);
  const a = sh.edit(base, { title: 'Модель стула' }, 300);
  const b = sh.edit(base, { title: 'Модель стола' }, 200);
  assert.equal(sh.mergeRec(a, b).f.title, 'Модель стула');
  assert.equal(sh.mergeRec(b, a).f.title, 'Модель стула');
});

test('задача выглядит как задача Google Tasks', () => {
  const rec = sh.make('t1', { list: 'l1', title: 'Рендер', notes: '', due: '2026-10-23T00:00:00.000Z', status: 'completed', completed: '2026-10-22T10:00:00.000Z', parent: 't0', pos: '01' }, 1000);
  const t = sh.taskView(rec);
  assert.equal(t.id, 't1');
  assert.equal(t.status, 'completed');
  assert.equal(t.completed, '2026-10-22T10:00:00.000Z');
  assert.equal(t.parent, 't0');
  assert.equal(t.due, '2026-10-23T00:00:00.000Z');
  assert.equal(t.position, '01');
});

test('правка в духе Google Tasks: отметка ставит и снимает время выполнения', () => {
  assert.deepEqual(sh.taskPatch({ status: 'completed' }, Date.UTC(2026, 9, 22)), { status: 'completed', completed: '2026-10-22T00:00:00.000Z' });
  assert.deepEqual(sh.taskPatch({ status: 'needsAction', completed: null }), { status: 'needsAction', completed: null });
  assert.deepEqual(sh.taskPatch({ due: null, title: 'x' }), { title: 'x', due: null });
});

test('новые задачи — выше старых, как в Google Tasks', () => {
  assert.ok(sh.newPos(2000) < sh.newPos(1000));
});

test('общие поля слоя — без личных (напоминания, таймер, учёт времени)', () => {
  const out = sh.sharedOf({ status: 'doing', priority: 1, remind: { kind: 'lead', min: 60 }, timer: { start: 1 }, spent: 30, t: 5 }, 'task');
  assert.deepEqual(out, { $status: 'doing', $priority: 1 });
  assert.deepEqual(sh.sharedOf({ template: 'work', view: 'kanban', hidden: true, sphere: 'x', t: 1 }, 'list'), { $template: 'work', $view: 'kanban' });
  assert.deepEqual(sh.sharedOf({ gone: true, t: 1 }, 'task'), {});
});

test('сведение слоя: поменяли там — берём в слой, поменяли тут — отдаём в календарь', () => {
  const base = sh.make('t1', { $status: 'inbox', $priority: 2 }, 100);
  const remote = sh.edit(base, { $status: 'review' }, 300);
  const L = { status: 'inbox', priority: 1, remind: { kind: 'lead', min: 15 }, t: 200 };
  const r = sh.reconcile(L, base, remote);
  assert.deepEqual(r.toLayer, { status: 'review' });
  assert.deepEqual(r.toRec, { $priority: 1 });
});

test('сведение слоя: поменяли одно поле и тут и там — побеждает свежее', () => {
  const base = sh.make('t1', { $status: 'inbox' }, 100);
  const remote = sh.edit(base, { $status: 'review' }, 300);
  assert.deepEqual(sh.reconcile({ status: 'doing', t: 400 }, base, remote), { toLayer: {}, toRec: { $status: 'doing' } });
  assert.deepEqual(sh.reconcile({ status: 'doing', t: 250 }, base, remote), { toLayer: { status: 'review' }, toRec: {} });
});

test('сведение слоя: новый участник получает все поля, а его пустой слой ничего не затирает', () => {
  const rec = sh.make('t1', { title: 'A', $status: 'doing', $topic: 'дом' }, 100);
  assert.deepEqual(sh.reconcile(undefined, null, rec), { toLayer: { status: 'doing', topic: 'дом' }, toRec: {} });
  assert.deepEqual(sh.reconcile({ remind: { kind: 'lead', min: 60 }, t: 500 }, rec, rec), { toLayer: { status: 'doing', topic: 'дом' }, toRec: {} });
});

test('сведение слоя: правка только тут (base = текущая запись) уходит в календарь', () => {
  const rec = sh.make('t1', { $status: 'doing' }, 100);
  assert.deepEqual(sh.reconcile({ status: 'done', ord: 2, t: 200 }, rec, rec), { toLayer: {}, toRec: { $status: 'done', $ord: 2 } });
  assert.deepEqual(sh.reconcile({ status: 'doing', t: 200 }, rec, rec), { toLayer: {}, toRec: {} });
});

test('сведение сферы: название, цвет, значок', () => {
  const base = sh.make(sh.SPHERE_KEY, { name: 'Студия', color: 'clay', icon: 'cube' }, 100);
  const remote = sh.edit(base, { name: 'Студия 2' }, 300);
  assert.deepEqual(sh.reconcileSphere({ name: 'Студия', color: 'gold', icon: 'cube', order: 3, t: 200 }, base, remote),
    { toLayer: { name: 'Студия 2' }, toRec: { color: 'gold' } });
});

test('задачи и списки хранилища', () => {
  const recs = {};
  const add = (r) => (recs[r.k] = r);
  add(sh.make('lb', { title: 'Второй', created: 2 }));
  add(sh.make('la', { title: 'Первый', created: 1 }));
  add(sh.make('t1', { list: 'la', title: 'Родитель' }));
  add(sh.make('t2', { list: 'la', title: 'Подзадача', parent: 't1' }));
  add(sh.make('t3', { list: 'lb', title: 'Другая' }));
  add(sh.make(sh.SPHERE_KEY, { name: 'С' }));
  assert.deepEqual(sh.listsOf(recs, 'cal').map((l) => [l.id, l.shared]), [['sh:la', 'cal'], ['sh:lb', 'cal']]);
  assert.deepEqual(sh.tasksOf(recs, 'la').map((t) => t.id).sort(), ['t1', 't2']);
  assert.deepEqual(sh.withChildren(recs, 't1'), ['t1', 't2']);
});

test('календарь общей сферы узнаём по метке в описании', () => {
  assert.equal(sh.isSphereCal({ description: `${sh.MARK} v1 — служебный` }), true);
  assert.equal(sh.isSphereCal({ summary: 'Работа' }), false);
});
