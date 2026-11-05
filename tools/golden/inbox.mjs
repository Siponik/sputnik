// Золотые данные для inbox. «Сейчас» подменено: 2026-10-21 14:00. Запуск: TZ=Europe/Moscow node tools/golden/inbox.mjs
import { writeFileSync, mkdirSync } from 'node:fs';

const NOW = new Date(2026, 9, 21, 14, 0).getTime();
const RealDate = Date;
class FakeDate extends RealDate {
  constructor(...a) { if (a.length) super(...a); else super(NOW); }
  static now() { return NOW; }
}
FakeDate.parse = RealDate.parse;
globalThis.Date = FakeDate;
const I = await import('../../tracker/src/lib/inbox.js');

const OUT = new URL('../../app/test/golden/', import.meta.url);
mkdirSync(OUT, { recursive: true });
const write = (name, data) => writeFileSync(new URL(name, OUT), '[\n' + data.map((x) => JSON.stringify(x)).join(',\n') + '\n]\n');
const out = [];

const status = {
  processed: {
    r1: { ok: true, from: 'Чат 1', at: '2026-10-21T10:00:00Z', created: [{ op: 'task.create', taskId: 't1' }, { op: 'task.create', taskId: 't2', existed: true }, { op: 'list.ensure', taskId: 'x' }, null] },
    r2: { ok: true, at: '2026-10-21T12:00:00Z', created: [{ op: 'task.create', taskId: 't3' }, { op: 'task.create' }] },
    r3: { ok: false, from: 'Плохо', created: [{ op: 'task.create', taskId: 't4' }] },
    r4: null, r5: { ok: true, from: 'Чат 5', created: [{ op: 'task.create', taskId: 't5' }] },
    r6: { ok: true, from: 'Чат 6', at: '2026-10-20T08:00:00Z', created: [{ op: 'task.create', taskId: 't6' }] },
  },
  pendingLayer: {
    t1: { type: 'meeting', project: 'Башня', tags: ['a', 1, 'b'], priority: 2, stage: 'low', repeat: { every: 'week' }, slot: { s: '10:00', e: '11:30' }, status: 'doing', at: '2026-10-21T10:00:00Z',
      topic: 'Покупки', listId: 'L1', pin: true, client: '  ООО Ёж ', money: 1500, remind: [60, 1440, -5, 1.5, 999999], spent: 30.6, accept: true },
    t2: { type: 'plain', priority: 5, slot: { s: '23:30' }, status: 'плохой статус', topic: 'Новая тема', listId: 'L1', money: ' 200 ₽ ', remind: 15, spent: 0 },
    t3: { slot: { s: '12:00', e: '11:00' }, status: 'review', at: 'мусор', topic: '   ', listId: 'L2', remind: '15', spent: 2e5 },
    t4: { slot: { s: '25:00' }, client: 'x'.repeat(101), money: 'y'.repeat(41), topic: 'z'.repeat(41), repeat: { every: 'hour' }, tags: 'нет' },
    t5: { topic: 'дом', listId: 'L3' }, t6: { topic: 'Новая', listId: null },
    t7: { type: 'work' },
  },
  pendingLists: {
    L1: { at: 'a1', template: 'Работа', view: 'stickers', sphere: 'Дом', topics: ['Покупки', { name: 'Звонки', color: 'teal' }, 'покупки', '', { name: 'Своя' }, 'Своя ' + 'x'], group: 'when' },
    L2: { at: 'a2', template: 'asset3d', view: 'нет', sphere: 'Новая сфера!', sphereColor: 'nope', sphereIcon: 'heart', group: 'x' },
    L3: { at: 'a3', sphere: 'новая сфера!', topics: [] },
    L4: { at: 'old', template: 'нет такого' },
    L5: null, L6: 'строка',
    L7: { sphere: 'Работа', sphereColor: 'sky', sphereIcon: 'nope', topics: Array.from({ length: 15 }, (_, i) => 'Т' + i) },
  },
};
const lists = [{ id: 'L1', title: 'Дом' }, { id: 'L2', title: 'Работа' }, { id: 'L3', title: 'X' }];
const tbl = { L1: [{ id: 't1' }, { id: 't2' }, { id: 't5', status: 'completed' }], L2: [{ id: 't3' }, { id: 't6' }, { id: 'zz' }], L3: [{ id: 't4' }] };
const lay = {
  spheres: { 'sp-dom': { name: 'Дом', color: 'clay', icon: 'home', order: 2 }, 'sp-rab': { name: 'Работа', order: 5 } },
  lists: { L4: { pulled: 'old' }, L3: { view: 'stickers', topics: [{ id: 'home', name: 'Дом', color: 'teal' }] } },
  tasks: { t3: { inbox: 'rejected' }, t7: { pulled: true } },
};
out.push({ fn: 'claudeTasks', status, out: I.claudeTasks(status) });
out.push({ fn: 'claudeTasks', status: null, out: I.claudeTasks(null) });
for (const lt of [lay.tasks, null, {}]) out.push({ fn: 'pending', status, lt, out: I.pending(status, lists, tbl, lt) });
for (const lt of [lay.tasks, null]) out.push({ fn: 'layerPatches', status, lt, out: I.layerPatches(status, lt) });
for (const l of [lay, null, {}, { spheres: { a: { name: 'Новая сфера!', order: 9 } } }]) out.push({ fn: 'pullPatches', status, lay: l, out: I.pullPatches(status, l) });
out.push({ fn: 'pullPatches', status: null, lay, out: I.pullPatches(null, lay) });
write('inbox.json', out);
console.log(out.length);
