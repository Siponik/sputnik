// Золотые данные для templates и boardedit. Запуск: node tools/golden/templates.mjs
import { writeFileSync, mkdirSync } from 'node:fs';
import * as T from '../../tracker/src/lib/templates.js';
import * as B from '../../tracker/src/lib/boardedit.js';

const OUT = new URL('../../rust/core/tests/golden/', import.meta.url);
mkdirSync(OUT, { recursive: true });
const write = (name, data) => writeFileSync(new URL(name, OUT), '[\n' + data.map((x) => JSON.stringify(x)).join(',\n') + '\n]\n');
const J = (x) => JSON.parse(JSON.stringify(x ?? null));

const work = T.templateOf('work');
const cols2 = [{ id: 'a', name: 'Идеи', color: 1, limit: 0 }, { id: 'done', name: 'Готово', color: 6, limit: 0 }];
const LAYS = [
  null, {},
  { lists: { A: { template: 'work' } } },
  { lists: { A: { template: 'work', cols: cols2, fields: ['due'], view: 'list' } } },
  { lists: { A: { template: 'study', cols: [{ id: 'a', name: 'A' }] } } },
  { lists: { A: { template: 'work' }, B: { template: 'work', fields: ['due'] } },
    templatesEdit: { work: { name: 'Работа', view: 'kanban', fields: ['due'], cols: [{ id: 'inbox', name: 'Новое' }, { id: 'done', name: 'Готово' }] }, study: { removed: true } } },
  { lists: { A: { template: 'mine1' }, H: { template: 'habits' } }, templates: { mine1: { name: 'Моё', cols: [{ id: 'x', name: 'Х' }, { id: 'done', name: 'Г' }] }, mine2: { name: 'Пусто', cols: [] }, mine3: { removed: true, name: 'r', cols: [{ id: 'done' }] }, mine4: null, mine5: { name: 'С видом', view: 'pipe', fields: ['due'], cols: [{ id: 'done', name: 'Г', color: 2, limit: 1 }] } } },
  { lists: { A: { template: 'nope', view: 'stickers' } } },
];
const t = [];
for (const lay of LAYS) {
  t.push({ fn: 'templatesFrom', lay, out: T.templatesFrom(lay) });
  for (const id of ['work', 'client', 'mine1', 'mine5', 'study', 'zzz', null]) t.push({ fn: 'templateOf', id, lay, out: T.templateOf(id, lay) });
  for (const L of ['A', 'B', 'H', 'Z']) {
    t.push({ fn: 'boardOf', id: L, lay, out: J(T.boardOf(L, lay)) });
    for (const tid of ['work', 'study', 'mine1']) t.push({ fn: 'follows', id: L, lay, tid, out: T.follows(L, lay, tid) });
  }
}
for (const tt of [...T.BUILTIN, { id: 'zz' }]) t.push({ fn: 'shortName', t: tt, out: T.shortName(tt) });
for (const c of [null, {}, { color: 3 }, { color: 9 }]) t.push({ fn: 'colColor', c, out: T.colColor(c) });
for (const id of ['work', 'mine', null]) t.push({ fn: 'isBuiltin', id, out: T.isBuiltin(id) });
for (const [list, lay] of [[{ id: 'A', title: 'Привычки' }, {}], [{ id: 'A', title: 'мои ПРИВЫЧКИ' }, {}], [{ id: 'A', title: 'Привычки дома' }, {}], [{ id: 'A' }, { lists: { A: { template: 'habits' } } }], [{ id: 'A', title: 'x' }, {}]])
  t.push({ fn: 'isHabitList', list, lay, out: T.isHabitList(list, lay) });
for (const L of [null, {}, { cols: cols2 }, { cols: [cols2[0]] }, { fields: [] }, { cols: [{ id: 'done' }, { id: 'a' }] }]) t.push({ fn: 'isOwn', L, out: T.isOwn(L) });
const d1 = { view: 'kanban', fields: ['due'], cols: [{ id: 'a', name: '  ', color: 2, limit: 3, extra: 1 }, { id: 'done', name: 'Готово' }] };
t.push({ fn: 'ownPatch', d: d1, out: T.ownPatch(d1) }, { fn: 'resetPatch', out: T.resetPatch() });
const b = T.boardOf('A', { lists: { A: { template: 'work' } } });
for (const o of [{ ...b, view: 'list' }, { ...b, fields: [...b.fields].reverse() }, { ...b, fields: ['due'] }, { ...b, cols: b.cols.map((c, i) => (i ? c : { ...c, limit: 5 })) }, { ...b, cols: b.cols.map((c) => ({ ...c, name: c.name + ' ' })) }])
  t.push({ fn: 'sameShape', a: J(b), b: J(o), out: T.sameShape(b, o) });
const from = [{ id: 'a', name: 'Входящие' }, { id: 'doing', name: 'Пилю' }, { id: 'x', name: 'Странное' }, { id: 'y', name: 'Ещё' }, { id: 'done', name: 'Готово' }];
const to = [{ id: 'inbox', name: 'входящие' }, { id: 'doing', name: 'В работе' }, { id: 'review', name: 'Ревью' }, { id: 'done', name: 'Сдано' }];
const to2 = [{ id: 'q', name: 'ГОТОВО' }, { id: 'done', name: 'Ёлка' }];
for (const [o, n] of [[from, to], [to, from], [from, to2], [work.cols, T.templateOf('client').cols], [T.templateOf('asset3d').cols, work.cols], [[{ id: 'a', name: 'Ёж' }, { id: 'done', name: 'x' }], [{ id: 'b', name: 'еж' }, { id: 'done', name: 'y' }]]]) {
  t.push({ fn: 'matchCols', o, n, out: T.matchCols(o, n) });
  t.push({ fn: 'lostMoves', o, n, out: T.lostMoves(o, n) });
}
const TK = (id, extra = {}) => ({ id, title: id, status: 'needsAction', ...extra });
const tl = [TK('1'), TK('2'), TK('3'), TK('4'), TK('5')];
const lt = { 1: { status: 'a' }, 2: { status: 'b' }, 3: { status: 'keep' }, 5: { status: 'loop1' } };
for (const mv of [{ a: 'b', b: 'c' }, { a: 'a' }, {}, { loop1: 'loop2', loop2: 'loop1' }, { keep: 'x', x: 'keep' }]) t.push({ fn: 'relocate', tl, lt, mv, out: T.relocate(tl, lt, mv) });
t.push({ fn: 'relocate', tl: null, lt: null, mv: {}, out: T.relocate(null, null, {}) });
const lay1 = { lists: { A: { template: 'work' } }, tasks: { t1: { status: 'review' }, t2: { status: 'doing' } } };
const draft = { view: 'kanban', fields: ['due'], cols: [work.cols[0], work.cols[1], work.cols[3]] };
for (const removed of [[], [{ id: 'review', to: 'inbox' }]]) t.push({ fn: 'saveListPlan', lay: lay1, id: 'A', draft, tl: [TK('t1'), TK('t2')], removed, out: T.saveListPlan(lay1, 'A', draft, [TK('t1'), TK('t2')], removed) });
const lay2 = { lists: { A: { template: 'work', cols: [{ id: 'inbox', name: 'Входящие' }, { id: 'c1', name: 'На ревью' }, { id: 'c2', name: 'Потом' }, { id: 'done', name: 'Готово' }], fields: ['due'] } }, tasks: { t1: { status: 'c1' }, t2: { status: 'c2' }, t3: { status: 'inbox' } } };
t.push({ fn: 'resetListPlan', lay: lay2, id: 'A', tl: [TK('t1'), TK('t2'), TK('t3')], out: T.resetListPlan(lay2, 'A', [TK('t1'), TK('t2'), TK('t3')]) });
const lay3 = { lists: { A: { template: 'work', fields: ['due'], cols: work.cols } }, tasks: { t1: { status: 'doing' }, t2: { status: 'review' }, t4: { status: 'gone' }, t6: { status: 'done' } } };
const tl3 = [TK('t1'), TK('t2'), TK('t3'), TK('t4'), TK('t5', { status: 'completed' }), TK('s', { parent: 't1' }), TK('t6')];
for (const [tid, mp] of [['client', null], ['client', { review: 'done', doing: 'estimate' }], ['study', null], ['asset3d', null], ['zzz', null], ['work', { inbox: 'bad' }]])
  t.push({ fn: 'switchPlan', lay: lay3, id: 'A', tid, tl: tl3, mp, out: T.switchPlan(lay3, 'A', tid, tl3, mp) });
for (const L of [null, {}, { sort: 'due' }, { sort: 'prio' }, { sort: 'pin' }]) t.push({ fn: 'sortOf', L, out: T.sortOf(L) });
const items = [TK('a', { position: '1', due: '2026-11-05T00:00:00.000Z' }), TK('b', { position: '2' }), TK('c', { position: '3', due: '2026-10-30T00:00:00.000Z' }), TK('d', { position: '0' }), TK('e', { position: '2', due: '2026-10-30T00:00:00.000Z' })];
for (const lay of [{ a: { priority: 3 }, b: { priority: 1 }, c: {} }, { a: { priority: 3, ord: -5 }, b: { priority: 1 } }, {}, null, { d: { ord: 1.5 }, e: { ord: 1.5 }, b: { ord: 0 } }])
  for (const sort of ['own', 'due', 'prio']) t.push({ fn: 'orderTasks', items, lay, sort, out: T.orderTasks(items, lay, sort).map((x) => x.id) });
for (const L of [null, {}, { archive: 0 }, { archive: 7 }, { archive: 5 }, { archive: '3' }]) t.push({ fn: 'archiveDays', L, out: T.archiveDays(L) });
const now = Date.parse('2026-10-28T12:00:00Z');
for (const [task, days] of [[{ status: 'completed', completed: new Date(now - 0.01 * 864e5).toISOString() }, 0], [{ status: 'completed', completed: new Date(now - 4 * 864e5).toISOString() }, 3], [{ status: 'completed', completed: new Date(now - 4 * 864e5).toISOString() }, 7], [{ status: 'needsAction' }, 0], [{ status: 'completed' }, 0], [{ status: 'completed', completed: new Date(now - 3 * 864e5).toISOString() }, 3]])
  t.push({ fn: 'isArchived', task, days, now, out: T.isArchived(task, days, now) });
t.push({ fn: 'blankTemplate', name: 'Х', now: 1700000000000, out: (() => { const r = Date.now; Date.now = () => 1700000000000; const o = T.blankTemplate('Х'); Date.now = r; return o; })() });
t.push({ fn: 'BUILTIN', out: T.BUILTIN }, { fn: 'VIEWS', out: T.VIEWS }, { fn: 'FIELDS', out: T.FIELDS }, { fn: 'SORTS', out: T.SORTS });
write('templates.json', t);

const e = [];
for (const bb of [work, T.templateOf('asset3d'), { view: 'list', cols: [{ id: 'a', name: 'A' }, { id: 'done', name: 'D', color: 2 }] }]) e.push({ fn: 'draftOf', b: J(bb), out: B.draftOf(bb) });
const cs = work.cols;
for (const [f, tt] of [[0, 2], [2, 0], [3, 0], [0, 3], [0, 9], [1, -5], [1, 1], [-1, 0], [5, 0]]) e.push({ fn: 'moveCol', cols: cs, from: f, to: tt, out: B.moveCol(cs, f, tt) });
for (const c of [{ id: 'a' }, { id: 'a', color: 6 }, { id: 'a', color: 2, limit: 1 }]) { e.push({ fn: 'recolor', c, out: B.recolor(c) }); for (const dd of [1, -1, 30, -30]) e.push({ fn: 'relimit', c, d: dd, out: B.relimit(c, dd) }); }
e.push({ fn: 'newCol', now: 1700000000000, out: B.newCol(1700000000000) });
const rem = [{ id: 'x', name: 'X', to: 'doing', toName: 'В работе', n: 2 }];
for (const [i, removed, n] of [[1, [], 0], [0, [], 3], [3, [], 0], [-1, [], 0], [1, rem, 4], [2, rem, 1]]) e.push({ fn: 'dropCol', cols: cs, i, removed, n, out: B.dropCol(cs, i, removed, n) });
e.push({ fn: 'dropCol', cols: cs.slice(2), i: 0, removed: [], n: 0, out: B.dropCol(cs.slice(2), 0, [], 0) });
for (const f of ['due', 'money']) e.push({ fn: 'toggleField', fields: ['due', 'prio'], f, out: B.toggleField(['due', 'prio'], f) });
for (const n of [0, 1, 2, 4, 5, 11, 12, 14, 21, 22, 25, 101, 111, 112, 1001]) { e.push({ fn: 'tasksWord', n, out: B.tasksWord(n) }); e.push({ fn: 'listsWord', n, out: B.listsWord(n) }); }
for (const c of [{ id: 'inbox', name: 'Входящие ' }, { id: 'inbox', name: 'Другое' }, { id: 'new', name: 'x' }]) e.push({ fn: 'colIsOwn', c, base: cs, out: B.colIsOwn(c, cs) });
const fr = B.draftOf(work);
const drafts = [fr, { ...fr, view: 'list' }, { ...fr, fields: ['prio', 'due', 'type'] }, { ...fr, fields: ['due'] },
  { ...fr, cols: [{ ...fr.cols[1] }, { ...fr.cols[0] }, fr.cols[2], fr.cols[3]] }, { ...fr, cols: [fr.cols[0], { ...fr.cols[1], name: 'Пилю' }, { id: 'n', name: 'Новая' }, fr.cols[3]] },
  { ...fr, cols: fr.cols.map((c, i) => (i === 1 ? { ...c, limit: 5 } : c)) }];
for (const dr of drafts) e.push({ fn: 'changes', from: fr, draft: dr, out: B.changes(fr, dr) });
const tasks = [{ id: 'a', status: 'completed', due: 'x' }, { id: 'b' }, { id: 'c', due: '2026-10-10' }, { id: 'd', parent: 'b', due: 'x' }, { id: 'e', due: '2026-10-11' }];
const subs = { b: ['d'] };
for (const lay of [{}, { b: { priority: 1, type: 'work' } }, { e: { spent: 3, client: 'x' } }, null]) e.push({ fn: 'sampleTask', tasks, lay, subs, out: B.sampleTask(tasks, lay, (id) => subs[id] ?? [])?.id ?? null });
e.push({ fn: 'sampleTask', tasks: [], lay: {}, subs: {}, out: B.sampleTask([], {}, () => []) });
for (const [n, i, total] of [[null, 0, 4], [null, 3, 4], [null, 1, 4], [5, 1, 4], [0, 0, 4], [2, 0, 1]]) e.push({ fn: 'previewCount', n, i, total, out: B.previewCount(n, i, total) });
e.push({ fn: 'fieldInfo', id: 'money', out: B.fieldInfo('money') }, { fn: 'fieldInfo', id: 'zz', out: B.fieldInfo('zz') ?? null });
write('boardedit.json', e);
console.log(t.length, e.length);
