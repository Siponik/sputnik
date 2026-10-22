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

// ---------- участники и исполнители ----------

test('ключ участника — из почты, одинаковый у всех и без учёта регистра', () => {
  const k = sh.memberKey('Anya@Gmail.com');
  assert.equal(k, sh.memberKey(' anya@gmail.com'));
  assert.match(k, /^m[0-9a-v]{16}$/);
  assert.equal(sh.kindOf(k), 'member');
  assert.notEqual(k, sh.memberKey('max@gmail.com'));
});

test('участники: владелец первым, дальше по порядку вступления, цвета по порядку, убранных нет', () => {
  const recs = {};
  const add = (r) => (recs[r.k] = r);
  add(sh.make(sh.SPHERE_KEY, { name: 'Таверна', owner: 'me@gmail.com' }));
  add(sh.make(sh.memberKey('max@gmail.com'), { email: 'max@gmail.com', name: 'Макс', order: 2, joined: true }));
  add(sh.make(sh.memberKey('me@gmail.com'), { email: 'me@gmail.com', order: 0 }));
  add(sh.make(sh.memberKey('anya@gmail.com'), { email: 'anya@gmail.com', order: 1, joined: false }));
  add(sh.make(sh.memberKey('old@gmail.com'), { email: 'old@gmail.com', order: 3, joined: true, removed: true }));
  const m = sh.membersOf(recs);
  assert.deepEqual(m.map((x) => [x.email, x.owner, x.joined, x.letter]), [
    ['me@gmail.com', true, true, 'M'], ['anya@gmail.com', false, false, 'A'], ['max@gmail.com', false, true, 'М']]);
  assert.equal(m[0].color, 'var(--clay)');
  assert.equal(m[1].color, 'var(--type-study)');
  assert.equal(sh.nextOrder(recs), 4);
});

test('имя из почты, пока человек не назвался', () => {
  assert.equal(sh.nameOf('anya.k@gmail.com'), 'Anya');
  assert.equal(sh.nameOf(''), 'Участник');
});

test('фильтр «Все / Мои / Без исполнителя» и «мои и ничьи» для «Сегодня»', () => {
  const me = 'me@gmail.com';
  const mine = { who: me }, theirs = { who: 'anya@gmail.com' }, none = {};
  assert.deepEqual([mine, theirs, none].map((L) => sh.assignedMatch(L, me, 'mine')), [true, false, false]);
  assert.deepEqual([mine, theirs, none].map((L) => sh.assignedMatch(L, me, 'none')), [false, false, true]);
  assert.deepEqual([mine, theirs, none].map((L) => sh.assignedMatch(L, me, 'mineOrNone')), [true, false, true]);
  assert.deepEqual([mine, theirs, none].map((L) => sh.assignedMatch(L, me, 'all')), [true, true, true]);
  assert.equal(sh.assignedMatch(undefined, me, 'none'), true);
});

test('Конвейер: при «Этап →» задача уходит исполнителю следующего этапа, у пустого этапа — остаётся', () => {
  const L = { who: 'me', stageWho: { retopo: 'me', uv: 'max' } };
  assert.deepEqual(sh.handoff(L, 'uv'), { who: 'max' });
  assert.deepEqual(sh.handoff(L, 'retopo'), {});
  assert.deepEqual(sh.handoff(L, 'textures'), {});
  assert.deepEqual(sh.handoff({}, 'uv'), {});
});

test('исполнитель этапа ставится и снимается, остальные этапы не трогаются', () => {
  const L = { stageWho: { refs: 'anya' } };
  assert.deepEqual(sh.setStageWho(L, 'uv', 'max'), { stageWho: { refs: 'anya', uv: 'max' } });
  assert.deepEqual(sh.setStageWho(L, 'refs', null), { stageWho: {} });
  assert.deepEqual(L.stageWho, { refs: 'anya' }, 'исходная запись не меняется');
});

test('исполнитель и исполнители этапов — общие поля слоя, не личные', () => {
  assert.deepEqual(sh.sharedOf({ who: 'a', stageWho: { uv: 'b' }, remind: 1, t: 1 }, 'task'), { $who: 'a', $stageWho: { uv: 'b' } });
});

// ---------- шаг 2: окно участников ----------

test('сфера «общая», только если в ней есть кто-то кроме владельца', () => {
  assert.equal(sh.isTogether([{ owner: true }]), false);
  assert.equal(sh.isTogether([{ owner: true }, { owner: false }]), true);
});

test('«последний раз»: сегодня, вчера, раньше — датой', () => {
  const now = new Date(2026, 9, 22, 15, 0).getTime();
  assert.equal(sh.seenText(new Date(2026, 9, 22, 12, 40).getTime(), now), 'сегодня в 12:40');
  assert.equal(sh.seenText(new Date(2026, 9, 21, 9, 5).getTime(), now), 'вчера в 9:05');
  assert.match(sh.seenText(new Date(2026, 9, 20, 9, 5).getTime(), now), /^20 окт/);
  assert.equal(sh.seenText(null, now), '');
});

test('поле приглашения: несколько почт через запятую и пробел, без повторов, неверные отдельно', () => {
  assert.deepEqual(sh.parseEmails('Anya.Art@gmail.com, max.3d@gmail.com; anya.art@gmail.com нет@'), { ok: ['anya.art@gmail.com', 'max.3d@gmail.com'], bad: ['нет@'] });
  assert.deepEqual(sh.parseEmails(''), { ok: [], bad: [] });
});

test('участник: когда позвали и когда был — в списке участников', () => {
  const recs = {};
  const r = sh.make(sh.memberKey('a@x.ru'), { email: 'a@x.ru', order: 1, joined: true, seen: 500 }, 100);
  recs[r.k] = r;
  const [m] = sh.membersOf(recs);
  assert.equal(m.seen, 500);
  assert.equal(m.invited, 100);
});

// ---------- шаг 3 ----------
test('whoOptions: я первым, без исполнителя последним, поиск и цифры', () => {
  const ppl = [
    { email: 'me@x.com', name: 'Сипоник', joined: true, owner: true },
    { email: 'anya@x.com', name: 'Аня', joined: true },
    { email: 'max@x.com', name: 'Макс', joined: false },
  ];
  const rows = sh.whoOptions([ppl[1], ppl[0], ppl[2]], 'me@x.com', '', { 'anya@x.com': 2 });
  assert.deepEqual(rows.map((r) => r.label), ['Я', 'Аня', 'Макс', 'Без исполнителя']);
  assert.deepEqual(rows.map((r) => r.key), ['1', '2', '3', '0']);
  assert.equal(rows[1].n, 2);
  assert.equal(rows[2].note, 'ещё не принял');
  assert.deepEqual(sh.whoOptions(ppl, 'me@x.com', 'ма').map((r) => r.label), ['Макс']);
  assert.deepEqual(sh.whoOptions(ppl, 'me@x.com', 'без').map((r) => r.label), ['Без исполнителя']);
  assert.equal(sh.whoByDigit(ppl, 'me@x.com', '2'), 'anya@x.com');
  assert.equal(sh.whoByDigit(ppl, 'me@x.com', '0'), null);
  assert.equal(sh.whoByDigit(ppl, 'me@x.com', '7'), undefined);
});

test('memberByWord: @аня — участник, @работа — не участник', () => {
  const ppl = [{ email: 'anya.k@x.com', name: 'Аня' }, { email: 'max@x.com', name: 'Макс' }, { email: 'olga@x.com', name: 'Оля' }];
  assert.equal(sh.memberByWord(ppl, '@аня').email, 'anya.k@x.com');
  assert.equal(sh.memberByWord(ppl, 'ма').email, 'max@x.com');
  assert.equal(sh.memberByWord(ppl, 'olg').email, 'olga@x.com');
  assert.equal(sh.memberByWord(ppl, 'работа'), null);
  assert.equal(sh.memberByWord(ppl, '@'), null);
});

test('editOf и changeText: кто и что поменял', () => {
  let r = sh.make('t0000000000000001', { title: 'Стойка', $status: 'refs' }, 1000);
  r = sh.edit(r, { by: 'me@x.com' }, 1001);
  assert.equal(sh.changeText(sh.editOf(r), [], 'me@x.com'), '');
  const at = new Date(2026, 9, 22, 12, 40).getTime();
  r = sh.edit(r, { $status: 'block' }, at);
  r = sh.edit(r, { by: 'anya@x.com' }, at + 1);
  const ed = sh.editOf(r);
  assert.deepEqual(ed.fields, ['$status']);
  const ppl = [{ email: 'anya@x.com', name: 'Аня' }];
  assert.equal(sh.changeText(ed, ppl, 'me@x.com', (c) => (c === 'block' ? 'Блокаут' : c), at + 60e3), 'Аня · перенос в «Блокаут» · 12:40');
  r = sh.edit(r, { $who: 'me@x.com' }, at + 5000);
  r = sh.edit(r, { by: 'anya@x.com' }, at + 5001);
  assert.equal(sh.changeText(sh.editOf(r), ppl, 'me@x.com', undefined, at + 60e3), 'Аня · отдано: тебе · 12:40');
});

test('assignedToMe: только когда отдал другой и раньше было не мне', () => {
  const base = sh.make('t0000000000000002', { title: 'A', $who: 'anya@x.com', by: 'anya@x.com' }, 1);
  const rec = sh.edit(base, { $who: 'me@x.com', by: 'anya@x.com' }, 2);
  assert.equal(sh.assignedToMe(base, rec, 'me@x.com'), true);
  assert.equal(sh.assignedToMe(rec, rec, 'me@x.com'), false);
  assert.equal(sh.assignedToMe(base, sh.edit(rec, { by: 'me@x.com' }, 3), 'me@x.com'), false);
  assert.equal(sh.assignedToMe(null, rec, 'me@x.com'), true);
  assert.equal(sh.assignedToMe(base, sh.edit(rec, { status: 'completed' }, 3), 'me@x.com'), false);
  assert.equal(sh.assignedToMe(base, sh.make('m0000000000000001', { $who: 'me@x.com', by: 'a' }, 1), 'me@x.com'), false);
});

test('whoCounts и memberOf', () => {
  const tasks = [{ id: 'a' }, { id: 'b' }, { id: 'c', status: 'completed' }, { id: 'd', parent: 'a' }, { id: 'e' }];
  const L = { a: { who: 'x@y.z' }, b: { who: 'x@y.z' }, c: { who: 'x@y.z' } };
  assert.deepEqual(sh.whoCounts(tasks, L), { 'x@y.z': 2, '': 1 });
  assert.equal(sh.memberOf([], 'gone@y.z').gone, true);
  assert.equal(sh.memberOf([], null), null);
});
