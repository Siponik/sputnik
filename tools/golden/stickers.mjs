// Золотые данные для today и stickers. Запуск: node tools/golden/stickers.mjs
import { writeFileSync, mkdirSync } from 'node:fs';
import * as TD from '../../tracker/src/lib/today.js';
import * as S from '../../tracker/src/lib/stickers.js';

const OUT = new URL('../../rust/core/tests/golden/', import.meta.url);
mkdirSync(OUT, { recursive: true });
const write = (name, data) => writeFileSync(new URL(name, OUT), '[\n' + data.map((x) => JSON.stringify(x)).join(',\n') + '\n]\n');

const td = [];
const P = [null, {}, { title: 'Позвонить' }, { title: 'X', day: '2026-10-22', time: '17:00' }, { title: 'X', day: '2026-10-28', priority: 1, repeat: { every: 'week' }, tag: 'Work' },
  { title: 'X', day: '2026-11-15', time: '23:30', priority: 3, tag: 'клиент' }, { title: 'X', tag: 'zzz', priority: 2 }, { title: 'X', tag: 'учёба', time: '09:05' }, { title: 'X', day: '2026-10-21', tag: 'client' }];
for (const today of ['2026-10-21', '2026-12-31']) for (const p of P) {
  td.push({ fn: 'understood', p, today, out: TD.understood(p, today) });
  if (p) for (const r of [{}, { listId: 'L', topic: 'buy', project: 'pr' }, { listId: 'M', topic: 'buy' }]) td.push({ fn: 'taskFrom', p, today, dest: 'L', r, out: TD.taskFrom(p, today, 'L', r) });
}
write('today.json', td);

const s = [];
const TODAYS = ['2026-10-21', '2026-10-25', '2026-10-26', '2026-12-31', '2027-02-28'];
const DUES = ['', '2026-10-19', '2026-10-20', '2026-10-21', '2026-10-22', '2026-10-25', '2026-10-26', '2026-11-01', '2026-11-02', '2027-01-01', '2027-03-01'];
for (const today of TODAYS) {
  s.push({ fn: 'weekEnd', today, out: S.weekEnd(today) }, { fn: 'todaySub', today, out: S.todaySub(today) });
  for (const n of [-1, 1, 7, 40]) s.push({ fn: 'plusDays', d: today, n, out: S.plusDays(today, n) });
  for (const due of DUES) {
    s.push({ fn: 'bucket', due, today, out: S.bucket(due, today) });
    for (const target of ['today', 'week', 'later']) s.push({ fn: 'whenDue', target, cur: due || null, today, out: S.whenDue(target, due || null, today) });
    for (const slot of [null, { s: '15:00' }]) for (const hide of [false, true]) s.push({ fn: 'dueLabel', due, today, slot, hide, out: S.dueLabel(due, today, slot, hide) });
  }
  for (const target of ['today', 'week', 'later']) s.push({ fn: 'newDue', target, today, out: S.newDue(target, today) });
}
for (const L of [null, {}, { topics: [] }, { topics: [{ id: 'x', name: 'X', color: 'gold' }] }]) s.push({ fn: 'topicsOf', L, out: S.topicsOf(L) });
for (const t of [null, { color: 'gold' }, { color: 'zz' }, {}]) s.push({ fn: 'topicColor', t, out: S.topicColor(t) });
const D = (d) => (d ? d + 'T00:00:00.000Z' : undefined);
const tasks = [
  { id: 'a', title: 'A', due: D('2026-10-19'), position: '5' }, { id: 'b', title: 'B', position: '1' }, { id: 'c', title: 'C', due: D('2026-10-23'), position: '2' },
  { id: 'd', title: 'D', due: D('2026-10-21'), position: '3' }, { id: 'e', title: 'E', due: D('2026-11-20'), position: '4' }, { id: 'f', title: 'F', position: '0' }, { id: 'g', title: 'G', due: D('2026-10-23'), position: '6' },
].map((t) => JSON.parse(JSON.stringify(t)));
const LT = [{}, { a: { topic: 'buy', pin: true }, b: { topic: 'buy', ord: 2 }, c: { topic: 'call', ord: 1 }, d: { topic: 'gone' }, f: { ord: 0, pin: true }, g: { ord: 1 } }, { a: { who: 'me@x' }, b: { who: 'ann@x' }, c: { who: 'old@x' }, e: { who: 'bob@x' } }];
const people = [{ email: 'ann@x', name: 'Аня', color: 'c1', joined: true }, { email: 'me@x', name: 'Я сам', color: 'c0', joined: true }, { email: 'bob@x', name: 'Боб', color: 'c2', joined: false }, { email: 'kim@x', name: 'Ким', color: 'c3', joined: false }];
const topics = S.DEFAULT_TOPICS;
for (const lay of LT) for (const sort of ['pin', 'due']) {
  s.push({ fn: 'order', items: tasks, lay, today: '2026-10-21', sort, out: S.order(tasks, lay, '2026-10-21', sort).map((t) => t.id) });
  for (const group of ['topic', 'when', 'people']) {
    const o = { group, topics, layTasks: lay, today: '2026-10-21', sort, people, me: 'me@x' };
    const ls = S.lanes(tasks, o);
    s.push({ fn: 'lanes', tasks, o, out: ls.map((l) => ({ ...l, items: l.items.map((t) => t.id) })) });
    for (const keep of [null, 'home', '']) { const v = S.visibleLanes(ls, { group, keep }); s.push({ fn: 'visibleLanes', o, keep, out: { shown: v.shown.map((l) => l.id), hidden: v.hidden.map((l) => l.id) } }); }
  }
}
s.push({ fn: 'lanes', tasks: [], o: { group: 'topic', topics, layTasks: {}, today: '2026-10-21' }, out: S.lanes([], { group: 'topic', topics, layTasks: {}, today: '2026-10-21' }).map((l) => ({ ...l, items: [] })) });
for (const [cur, to, sh] of [['topic', null, false], ['when', null, false], ['when', null, true], ['people', null, true], ['topic', 'when', false], ['topic', 'people', false], ['topic', {}, true]]) s.push({ fn: 'nextGroup', cur, to: to && typeof to === 'object' ? 'obj' : to, sh, out: S.nextGroup(cur, to, sh) });
for (const task of tasks.slice(0, 4)) s.push({ fn: 'topicOfTask', task, lay: LT[1], out: S.topicOfTask(task, LT[1], topics) });
for (const id of ['a', 'abc', 'Ёлка', '😀x', '', 'kXv8_xA9zLq', '123', 'MTIzNDU2Nzg5MDEyMzQ1Njc4']) s.push({ fn: 'tilt', id, out: S.tilt(id) });
const now = Date.parse('2026-10-28T12:00:00Z');
const jt = [{ status: 'completed', completed: new Date(now - 864e5).toISOString() }, { status: 'completed', completed: new Date(now - 8 * 864e5).toISOString() }, { status: 'completed' },
  { status: 'completed', parent: 'x', completed: new Date(now).toISOString() }, { status: 'needsAction' }, { status: 'completed', completed: new Date(now - 7 * 864e5).toISOString() }];
s.push({ fn: 'jarCount', tasks: jt, now, out: S.jarCount(jt, now) });
const RAW = ['купить батарейки #покуп в пятницу 17:00 !!!', 'позвонить маме #зв', '#дом убрать', 'тест #нет такой', 'полить цветы каждую неделю !', 'x !! y', 'ёлка #Здоровье завтра', '', '!!!', 'Срочно!!!', 'а #ДОК'];
for (const today of [[2026, 9, 21], [2026, 11, 31]]) for (const raw of RAW) s.push({ fn: 'parseSticker', raw, today: [today[0], today[1] + 1, today[2]], out: S.parseSticker(raw, topics, new Date(today[0], today[1], today[2], 9)) });
s.push({ fn: 'consts', out: { DEFAULT_TOPICS: S.DEFAULT_TOPICS, MISC: S.MISC, WHEN: S.WHEN } });
write('stickers.json', s);
console.log(td.length, s.length);
