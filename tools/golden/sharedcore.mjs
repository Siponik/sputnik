// Золотые данные для sharedcore. Запуск: TZ=Europe/Moscow node tools/golden/sharedcore.mjs
import { writeFileSync, mkdirSync } from 'node:fs';
import * as sh from '../../tracker/src/lib/sharedcore.js';

const OUT = new URL('../../app/test/golden/', import.meta.url);
mkdirSync(OUT, { recursive: true });
const write = (name, data) => writeFileSync(new URL(name, OUT), '[\n' + data.map((x) => JSON.stringify(x)).join(',\n') + '\n]\n');
const out = [];
const push = (fn, args, v) => out.push({ fn, a: args, out: v });
const NOW = new Date(2026, 9, 21, 14, 0).getTime();

const VALS = [null, 1, 'a', [1, 2], [2, 1], { a: 1, b: 2 }, { b: 2, a: 1 }, { a: 1 }, { a: 1, b: null }, [], {}, [{ x: 1 }], [{ x: 2 }], '1', 0, false, true];
for (const a of VALS) for (const b of VALS) push('same', [a, b], sh.same(a, b));
push('sameU', [null], sh.same(undefined, null));

for (const seed of [1, 7, 12345]) { let s = seed; const rnd = () => { s = (s * 16807) % 2147483647; return (s - 1) / 2147483646; }; const vals = Array.from({ length: 16 }, rnd); let j = 0; push('newKey', ['t', vals], sh.newKey('t', () => vals[j++])); }
for (const k of [sh.SPHERE_KEY, 'labc', 'tabc', 'mabc', 'xyz', '', null, 's123']) push('kindOf', [k], sh.kindOf(k));
for (const e of ['anya.k@gmail.com', ' Anya.K@Gmail.com ', '', null, 'олег@почта.рф', 'x@y.z', 'a'.repeat(200) + '@b.c']) push('memberKey', [e], sh.memberKey(e));
for (const id of ['sh:labc', 'MTIz', null, 5, 'sh:']) push('ids', [id], [sh.isSharedId(id), sh.listKey(id), sh.calOfSphere(id)]);
push('listId', ['labc'], sh.listId('labc'));
push('sphereId', ['c@g'], sh.sphereId('c@g'));

const r1 = sh.make('t0123456789abcdef', { list: 'l1', title: 'Модель', $status: 'doing', due: null }, 100);
push('make', ['t0123456789abcdef', { list: 'l1', title: 'Модель', $status: 'doing', due: null }, 100], r1);
const EDITS = [{ title: 'Модель' }, { title: 'Новое' }, { due: '2026-10-22' }, { due: null }, { $status: 'done', notes: 'x' }, {}, { list: 'l1', $tags: ['a'] }];
for (const p of EDITS) for (const now of [50, 100, 200]) push('edit', [r1, p, now], sh.edit(r1, p, now));
const A = { k: 'tA', f: { title: 'A', x: 1, only: 'a', n: null }, ft: { title: 5, x: 3, only: 1, n: 2 } };
const B = { k: 'tB', f: { title: 'B', x: 2, other: 'b', n: 'v' }, ft: { title: 5, x: 4, other: 1, n: 2 } };
const C = { f: { title: 'Z', gone: 1 }, ft: { title: 9 } };
const D = { k: 'tD', f: { title: 'A' }, ft: { title: 5, ghost: 7 } };
for (const [a, b] of [[A, B], [B, A], [A, C], [C, A], [null, B], [A, null], [A, D], [D, A], [{ k: 'k' }, { k: 'q' }]]) push('mergeRec', [a, b], sh.mergeRec(a, b));
for (const r of [A, null, {}, { ft: {} }]) push('lastTime', [r], sh.lastTime(r));
const long = sh.make('tlong', { notes: 'н'.repeat(7000), title: 'x' }, 5);
for (const r of [r1, long]) push('toEvent', [r], sh.toEvent(r));
const EVS = [sh.toEvent(r1), null, { status: 'cancelled', extendedProperties: { shared: { sputnik: 'rec' } } }, { extendedProperties: { shared: { sputnik: 'rec' } }, description: 'не json' },
  { extendedProperties: { shared: { sputnik: 'rec' } }, description: '{"k":"xyz","f":{}}' }, { extendedProperties: { shared: { sputnik: 'rec' } }, description: '{"k":"tq","f":{"a":1},"ft":[1]}' },
  { extendedProperties: { shared: { sputnik: 'rec' } }, description: '[1]' }, { description: '{"k":"tq","f":{}}' }, { extendedProperties: { shared: { sputnik: 'rec' } }, description: '{"k":"tq","f":[]}' },
  { extendedProperties: { shared: { sputnik: 'rec' } } }];
for (const e of EVS) push('fromEvent', [e], sh.fromEvent(e));
for (const n of [NOW, 0, 1e16]) push('newPos', [n], sh.newPos(n));

const T1 = { k: 'ta', f: { list: 'l1', title: 'Задача', notes: 'з', due: '2026-10-22T00:00:00.000Z', status: 'completed', completed: '2026-10-21T10:00:00.000Z', parent: 'tp', pos: '001', $status: 'doing', $who: 'b@x.y', by: 'a@x.y' }, ft: { title: NOW, list: NOW - 10, $who: NOW - 5000, by: NOW } };
const T2 = { k: 'tb', f: { list: 'l1' }, ft: {} };
const T3 = { k: 'tc', f: { list: 'l2', status: 'needsAction', completed: 'x', parent: 'ta', title: 'Под' }, ft: { title: 3 } };
for (const r of [T1, T2, T3]) push('taskView', [r], sh.taskView(r));
const L1 = { k: 'l1', f: { title: 'Список', created: 5, $view: 'stickers', by: 'a@x.y' }, ft: { title: NOW - 100, by: NOW - 100 } };
const L2 = { k: 'l0', f: { created: 5 }, ft: {} };
const L3 = { k: 'l9', f: { title: 'Ранний', created: 1 }, ft: {} };
for (const r of [L1, L2]) push('listView', [r, 'cal@x'], sh.listView(r, 'cal@x'));
for (const b of [{ title: 'x' }, { title: null, notes: null }, { due: null }, { status: 'completed' }, { status: 'completed', completed: 'c' }, { status: 'needsAction', completed: 'c' }, {}, { foo: 1 }])
  push('taskPatch', [b, NOW], sh.taskPatch(b, NOW));
for (const r of [T1, null, { f: { $a: null, b: 1, $c: [1] } }]) push('layerOf', [r], sh.layerOf(r));
const LAYS = [{ t: 5, status: 'doing', remind: 60, timer: {}, who: 'a', type: null }, { gone: true, t: 1 }, null, [1], { hidden: true, sphere: 's', group: 'x', view: 'stickers', sort: 'due', cvGroup: 'p', topics: [] }];
for (const L of LAYS) for (const k of ['task', 'list']) push('sharedOf', [L, k], sh.sharedOf(L, k));

const base = { k: 'ta', f: { $status: 'todo', $who: 'a', $prio: 1, $gone: 'x' }, ft: { $status: 10, $who: 10 } };
const cur = { k: 'ta', f: { $status: 'doing', $who: 'a', $prio: 2, $new: 'n', title: 't' }, ft: { $status: 50, $who: 10, $prio: 50, $new: 50 } };
const RLS = [{ t: 40, status: 'review', who: 'b', prio: 1 }, { t: 60, status: 'review', prio: 3 }, { t: 60, status: 'doing' }, null, { t: 5, prio: null, gone2: 1 }, { t: 100, status: 'todo', who: 'a', prio: 1, new: 'n' }];
for (const L of RLS) for (const [b, r] of [[base, cur], [null, cur], [base, { k: 'ta', f: {}, ft: {} }], [cur, cur]]) push('reconcile', [L, b, r], sh.reconcile(L, b, r));
push('reconcileList', [{ t: 1, view: 'x', group: 'y' }, null, { f: { $view: 'z', $group: 'q' }, ft: { $view: 5 } }], sh.reconcile({ t: 1, view: 'x', group: 'y' }, null, { f: { $view: 'z', $group: 'q' }, ft: { $view: 5 } }, 'list'));
const sb = { f: { name: 'Таверна', color: 'clay', icon: 'star' }, ft: {} };
const sr = { f: { name: 'Таверна 2', color: 'clay', icon: 'home' }, ft: { name: 50, icon: 50 } };
for (const S of [{ t: 40, name: 'Таверна', color: 'gold' }, { t: 60, name: 'Своё' }, null, { t: 1, icon: null }, { name: 'Таверна 2', color: 'clay', icon: 'home' }])
  for (const [b, r] of [[sb, sr], [null, sr], [sb, { f: {}, ft: {} }], [null, null]]) push('reconcileSphere', [S, b, r], sh.reconcileSphere(S, b, r));

const M = (email, f = {}, ft = {}) => ({ k: sh.memberKey(email), f: { email, ...f }, ft: { email: 7, ...ft } });
const recs = {
  [sh.SPHERE_KEY]: { k: sh.SPHERE_KEY, f: { name: 'Таверна', owner: 'own@x.ru' }, ft: {} },
  [T1.k]: T1, [T2.k]: T2, [T3.k]: T3, [L1.k]: L1, [L2.k]: L2, [L3.k]: L3,
  m1: { ...M('own@x.ru', { order: 0, name: 'Влад' }), k: sh.memberKey('own@x.ru') },
  m2: { ...M('b@x.y', { order: 2, joined: true, seen: NOW - 6000, color: 3 }), k: sh.memberKey('b@x.y') },
  m3: { ...M('anya.k@gmail.com', { order: 1, joined: true, seen: NOW - 10, pic: 'data:image/png;base64,AAAA' }), k: sh.memberKey('anya.k@gmail.com') },
  m4: { ...M('gone@x.y', { order: 3, removed: true }), k: sh.memberKey('gone@x.y') },
  m5: { ...M('new@x.y', { order: 4, color: 9, pic: 'http://evil' }), k: sh.memberKey('new@x.y') },
  m6: { k: 'mzz', f: { order: 9 }, ft: {} },
  t5: { k: 't5', f: { list: 'l1', title: 'Моя правка', by: 'a@x.y' }, ft: { title: NOW } },
};
const fixRecs = Object.fromEntries(Object.values(recs).map((r) => [r.k, r]));
push('setup', [fixRecs], null);
push('tasksOf', ['l1'], sh.tasksOf(fixRecs, 'l1'));
push('listsOf', ['cal'], sh.listsOf(fixRecs, 'cal'));
push('withChildren', ['ta'], sh.withChildren(fixRecs, 'ta'));
push('withChildren', ['zz'], sh.withChildren(fixRecs, 'zz'));
for (const c of [null, {}, { description: 'x sputnik-sphere y' }, { description: 5 }]) push('isSphereCal', [c], sh.isSphereCal(c));
const people = sh.membersOf(fixRecs);
push('membersOf', [], people);
push('membersOf0', [null], sh.membersOf(null));
for (const p of ['data:image/png;base64,AAAA', 'data:image/gif;base64,AA', 'data:image/jpeg;base64,AA==', 'data:image/webp;base64,' + 'A'.repeat(6000), 5, null, 'data:image/png;base64,A A'])
  push('okPic', [p], sh.okPic(p));
for (const pr of [null, { name: '  Влад   Иванов ', color: 2, pic: 'data:image/png;base64,QQ==' }, { name: 'x'.repeat(30), color: 6 }, { color: 1.5 }, { name: '   ' }])
  for (const rec of [null, { f: { name: 'Влад Иванов', color: 2 } }]) push('profilePatch', [rec, pr], sh.profilePatch(rec, pr)), push('profileFields', [pr], sh.profileFields(pr));
for (const e of ['anya.k@gmail.com', 'ivan_petrov@x', 'b+tag@x', '@x', '', null, 'олег@x']) push('nameOf', [e], sh.nameOf(e));
push('nextOrder', [], sh.nextOrder(fixRecs));
push('nextOrder0', [], sh.nextOrder({}));
for (const L of [null, { who: 'a@x' }, { who: '' }, { who: 5 }]) {
  push('whoOf', [L], sh.whoOf(L));
  for (const me of ['a@x', null]) for (const m of ['all', 'mine', 'none', 'mineOrNone']) push('assignedMatch', [L, me, m], sh.assignedMatch(L, me, m));
}
const SL = { who: 'a', stageWho: { low: 'b', high: 'a' }, passes: Array.from({ length: 8 }, (_, i) => ({ i })) };
for (const L of [SL, null, { who: 'a' }, { stageWho: { low: 'b' } }]) for (const c of ['low', 'high', 'none']) {
  push('handoff', [L, c], sh.handoff(L, c));
  push('setStageWho', [L, c, 'z'], sh.setStageWho(L, c, 'z'));
  push('setStageWho', [L, c, null], sh.setStageWho(L, c, null));
  push('stagePass', [L, 'block', c, 'me@x', NOW], sh.stagePass(L, 'block', c, 'me@x', NOW));
  push('stagePass', [L, 'high', c, 'me@x', NOW], sh.stagePass(L, 'high', c, 'me@x', NOW));
}
push('isTogether', [people], sh.isTogether(people));
push('isTogether', [[{ owner: true }]], sh.isTogether([{ owner: true }]));
for (const ms of [NOW - 60e3, new Date(2026, 9, 20, 9, 5).getTime(), new Date(2026, 9, 1, 9, 5).getTime(), new Date(2026, 9, 21, 0, 1).getTime(), 0, null, new Date(2026, 9, 22, 1).getTime()])
  push('seenText', [ms, NOW], sh.seenText(ms, NOW));
for (const t of ['a@b.cd, x@y.z; BAD  a@b.cd\nолег@почта.рф', '', null, 'a@b', ' ,; ']) push('parseEmails', [t], sh.parseEmails(t));
for (const e of ['b@x.y', 'old@x.y', null, '']) push('memberOf', [e], sh.memberOf(people, e));
const counts = { 'b@x.y': 2, '': 4 };
for (const me of ['b@x.y', 'own@x.ru', null]) {
  for (const q of ['', 'я', 'ан', 'без', 'никто', 'x.y', 'zzz', 'Ё']) push('whoOptions', [me, q, counts], sh.whoOptions(people, me, q, counts));
  for (const d of ['0', '1', '2', '3', '9']) { const r = sh.whoByDigit(people, me, d); push('whoByDigit', [me, d], r === undefined ? '<undefined>' : r); }
}
for (const w of ['@влад', 'ан', 'anya', 'b', '', '@', 'нет', 'Влад']) push('memberByWord', [w], sh.memberByWord(people, w));
const ED = [T1, T2, { f: { by: 'x' }, ft: { by: 5 } }, { f: { by: 'b@x.y', $status: 'review', title: 'x' }, ft: { $status: 1000, title: 3500, by: 9 } }, null];
for (const r of ED) push('editOf', [r], sh.editOf(r));
const name = (c) => ({ review: 'Ревью', doing: 'В работе' })[c] ?? c;
const EDS = [null, { by: 'me@x', fields: [] }, { by: 'b@x.y', at: NOW - 60e3, fields: ['status', '$status'] }, { by: 'b@x.y', at: NOW - 60e3, fields: ['$status'], col: 'review' },
  { by: 'b@x.y', at: NOW, fields: ['$status'], col: null }, { by: 'old@x.y', at: NOW - 864e5, fields: ['$who'], who: 'me@x' }, { by: 'b@x.y', at: NOW, fields: ['$who'], who: 'anya.k@gmail.com' },
  { by: 'b@x.y', at: NOW, fields: ['$who'], who: null }, { by: 'b@x.y', at: NOW, fields: ['title'] }, { by: 'b@x.y', at: NOW, fields: ['due'] }, { by: 'b@x.y', at: NOW, fields: ['notes'] },
  { by: 'b@x.y', at: new Date(2026, 8, 5).getTime(), fields: ['x'] }];
for (const ed of EDS) push('changeText', [ed, 'me@x'], sh.changeText(ed, people, 'me@x', name, NOW));
const AT = [[null, { k: 'ta', f: { $who: 'me', by: 'b' } }], [{ f: { $who: 'me' } }, { k: 'ta', f: { $who: 'me', by: 'b' } }], [null, { k: 'ta', f: { $who: 'me', by: 'me' } }],
  [null, { k: 'ta', f: { $who: 'me', by: 'b', status: 'completed' } }], [null, { k: 'la', f: { $who: 'me', by: 'b' } }], [null, null], [null, { k: 'ta', f: { $who: 'me' } }]];
for (const [b, r] of AT) for (const me of ['me', null]) push('assignedToMe', [b, r, me], !!sh.assignedToMe(b, r, me));
const tasks = [{ id: '1' }, { id: '2' }, { id: '3', status: 'completed' }, { id: '4', parent: '1' }, { id: '5' }, { id: '6' }];
const lt = { 1: { who: 'a' }, 2: { who: 'b' }, 4: { who: 'a' }, 5: { who: '' } };
push('whoCounts', [tasks, lt], sh.whoCounts(tasks, lt));
for (const me of ['a', null, 'z']) push('whoTally', [tasks, lt, me], sh.whoTally(tasks, lt, me));
push('WHO_MODES', [], sh.WHO_MODES);
const tbl = { L1: tasks, L2: [{ id: '9' }, { id: '10', parent: '9' }], 'sh:x': tasks };
for (const me of ['a', null]) push('forMe', [tbl, lt, me], sh.forMe(tbl, lt, me, (id) => id !== 'L2'));
const PS = [{ from: 'block', to: 'low', by: 'me@x', who: 'b@x.y' }, { from: 'block', to: 'low', by: 'b@x.y', who: null }, { from: 'block', to: 'low', by: 'b@x.y', who: 'b@x.y' },
  { from: 'block', to: 'low', by: 'me@x', who: 'me@x' }, { from: '', to: 'low', by: 'old@x.y', who: 'me@x' }, { from: 'x', to: 'y', by: 'me@x', who: 'old@x.y' }];
for (const p of PS) push('passText', [p, 'me@x'], sh.passText(p, people, 'me@x', name));
for (const L of [SL, { who: 'me@x' }, { who: 'b@x.y', stageWho: { low: 'me@x', high: 'anya.k@gmail.com' } }, null, { stageWho: { low: 'b@x.y' } }])
  for (const next of ['low', 'high', 'x', null]) for (const me of ['a', 'b', 'me@x']) push('nextHint', [L, next, me], sh.nextHint(L, next, me, people));
const cols = [{ id: 'low', name: 'Лоу' }, { id: 'high' }, { id: 'tex' }];
for (const L of [SL, null, { who: 'q' }]) for (const c of ['tex', 'low', null]) push('stageCrew', [L, cols, c], sh.stageCrew(L, cols, c));
const STORES = [null, { role: 'owner', recs: fixRecs }, { accepted: true, recs: fixRecs }, { cal: 'c@g', recs: fixRecs }, { cal: 'c2', recs: {} }];
for (const st of STORES) for (const me of ['b@x.y', 'gone@x.y', 'new@x.y', 'zzz@x']) {
  push('isInvite', [st, me], sh.isInvite(st, me));
  push('inviteInfo', [st, me], sh.inviteInfo(st, me));
}
const WR = [{ f: { $who: 'b@x.y', by: 'a@x.y' }, ft: { $who: NOW } }, { f: { $who: 'b@x.y', by: 'a@x.y' }, ft: { $who: NOW - 7000 } }, { f: { $who: 'anya.k@gmail.com', by: 'a@x.y' }, ft: { $who: NOW } },
  { f: { $who: 'new@x.y', by: 'a@x.y' }, ft: { $who: NOW } }, { f: { $who: 'a@x.y', by: 'a@x.y' }, ft: {} }, { f: { $who: 'b@x.y', by: 'q' }, ft: {} }, null, { f: {}, ft: {} }];
for (const r of WR) push('waitingFor', [r, 'a@x.y'], sh.waitingFor(r, people, 'a@x.y'));
for (const me of ['a@x.y', 'b@x.y', 'nobody']) push('unseenBy', [me], sh.unseenBy(fixRecs, people, me));
for (const [s, f] of [[null, false], [NOW - 36e5 - 1, false], [NOW - 36e5, false], [NOW - 120e3 - 1, true], [NOW - 120e3 - 1, false], [NOW - 1000, true]]) push('seenDue', [s, f, NOW], sh.seenDue(s, f, NOW));
for (const [n, e] of [['Таверна', 'own@x.ru'], ['Семья', null]]) push('askAccessText', [n, e], sh.askAccessText(n, e));
push('consts', [], [sh.MARK, sh.SUMMARY, sh.PREFIX, sh.NOTES_MAX, sh.SPHERE_FIELDS, sh.SPHERE_KEY, sh.MEMBER_COLORS, sh.NAME_MAX, sh.PIC_MAX]);
write('sharedcore.json', out);
console.log(out.length);
