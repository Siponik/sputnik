// «Входящие от Claude»: все поля Спутника из запроса чата — сферы, виды списков, темы стикеров, поля задач.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import { layerPatches, pullPatches } from '../src/lib/inbox.js';

const AT = '2026-10-21T10:00:00.000Z';

test('поля задачи: колонка, тема, закрепление, клиент, сумма, напоминания, время, принято', () => {
  const st = { pendingLayer: { a: { at: AT, status: 'doing', pin: true, client: 'Studio', money: 45000, remind: [60, 1440, -5], spent: 90.4, accept: true, topic: 'buy' } } };
  const [[, p]] = layerPatches(st, {});
  assert.equal(p.status, 'doing');
  assert.deepEqual(p.stageAt, { doing: Date.parse(AT) });
  assert.equal(p.topic, 'buy');
  assert.equal(p.pin, true);
  assert.equal(p.client, 'Studio');
  assert.equal(p.money, '45000');
  assert.deepEqual(p.remind, [{ kind: 'lead', min: 60 }, { kind: 'lead', min: 1440 }]);
  assert.equal(p.spent, 90);
  assert.equal(p.inbox, 'accepted');
});

test('время без конца — на час', () => {
  const st = { pendingLayer: { a: { slot: { s: '17:30' } }, b: { slot: { s: '23:30' } } } };
  const P = Object.fromEntries(layerPatches(st, {}));
  assert.deepEqual(P.a.slot, { s: '17:30', e: '18:30' });
  assert.deepEqual(P.b.slot, { s: '23:30', e: '23:59' });
});

test('мусор не проходит', () => {
  const st = { pendingLayer: { a: { status: 'в работе!', pin: 'yes', remind: 'час', spent: -3, accept: 1 } } };
  assert.deepEqual(layerPatches(st, {})[0][1], { pulled: true });
});

test('списки: шаблон, вид, новая сфера по названию, темы; второй раз не переносятся', () => {
  const lay = { spheres: { work: { name: 'Работа', order: 3 } }, lists: {}, tasks: {} };
  const st = { pendingLists: {
    L1: { at: AT, template: 'asset3d', view: 'pipe', sphere: 'Тест', sphereColor: 'gold', sphereIcon: 'cube' },
    L2: { at: AT, template: 'Личное', view: 'stickers', sphere: 'тест', topics: ['Покупки', { name: 'Кот', color: 'study' }], group: 'when' },
    L3: { at: AT, template: 'нет-такого', view: 'плитка', sphere: 'работа' },
  } };
  const r = pullPatches(st, lay);
  assert.equal(r.spheres.length, 1);
  const [sid, sp] = r.spheres[0];
  assert.deepEqual({ ...sp }, { name: 'Тест', color: 'gold', icon: 'cube', order: 4, removed: false });
  const L = Object.fromEntries(r.lists);
  assert.deepEqual(L.L1, { pulled: AT, template: 'asset3d', view: 'pipe', sphere: sid });
  assert.equal(L.L2.template, 'personal');
  assert.equal(L.L2.sphere, sid);
  assert.deepEqual(L.L2.topics.map((t) => [t.id, t.name, t.color]), [['buy', 'Покупки', 'gold'], ['кот', 'Кот', 'study']]);
  assert.equal(L.L2.group, 'when');
  assert.deepEqual(L.L3, { pulled: AT, sphere: 'work' });
  const again = pullPatches(st, { ...lay, lists: { L1: { pulled: AT }, L2: { pulled: AT }, L3: { pulled: AT } } });
  assert.equal(again.lists.length, 0);
});

test('тема задачи — по названию из тем списка, новая добавляется в список', () => {
  const lay = { lists: { S: { topics: [{ id: 'buy', name: 'Покупки', color: 'gold' }] } }, tasks: {} };
  const st = { pendingLayer: { a: { listId: 'S', topic: 'покупки' }, b: { listId: 'S', topic: 'Ёлка' }, c: { listId: 'S', topic: 'елка' } } };
  const r = pullPatches(st, lay);
  const T = Object.fromEntries(r.tasks);
  assert.equal(T.a.topic, 'buy');
  assert.equal(T.b.topic, T.c.topic);
  const [[lid, lp]] = r.lists;
  assert.equal(lid, 'S');
  assert.deepEqual(lp.topics.map((t) => t.name), ['Покупки', 'Ёлка']);
});

// Inbox.gs с поддельными Google Tasks и календарём.
function inbox() {
  const lists = [], tasks = [];
  let n = 0;
  const ctx = vm.createContext({
    console, JSON, Date,
    Tasks: {
      Tasklists: { list: () => ({ items: lists }), insert: (b) => { const l = { id: 'L' + ++n, title: b.title }; lists.push(l); return l; } },
      Tasks: {
        list: (listId) => ({ items: tasks.filter((t) => t.list === listId && t.status !== 'completed') }),
        insert: (b, listId, o) => { const t = { id: 'T' + ++n, list: listId, updated: new Date().toISOString(), status: 'needsAction', ...b, parent: o?.parent }; tasks.push(t); return t; },
      },
    },
  });
  vm.runInContext(readFileSync(new URL('../../reminders/Inbox.gs', import.meta.url), 'utf8'), ctx, { filename: 'Inbox.gs' });
  return { ctx, lists, tasks };
}

test('Inbox.gs: поля списка ждут в pendingLists, done создаёт выполненную задачу', () => {
  const { ctx, lists, tasks } = inbox();
  const status = { processed: {}, pendingLayer: {}, pendingLists: {} };
  const getLists = () => lists;
  const req = ctx.parseRequest_(JSON.stringify({ sputnik: 1, id: 'r1', ops: [
    { op: 'list.ensure', list: 'Тест · Стикеры', layer: { template: 'personal', view: 'stickers', sphere: 'Тест' } },
    { op: 'task.create', list: 'Тест · Стикеры', title: 'Купить молоко', layer: { topic: 'Покупки', pin: true } },
    { op: 'task.create', list: 'Тест · Стикеры', title: 'Оплатить интернет', done: true },
  ] }));
  const out = req.ops.map((op) => ctx.runOp_(op, getLists, status));
  const lid = lists[0].id;
  assert.equal(status.pendingLists[lid].view, 'stickers');
  assert.equal(status.pendingLayer[out[1].taskId].topic, 'Покупки');
  assert.equal(tasks.find((t) => t.title === 'Оплатить интернет').status, 'completed');
  assert.throws(() => ctx.parseRequest_(JSON.stringify({ sputnik: 1, id: 'r2', ops: [{ op: 'task.create', list: 'X', title: 'a', layer: [1] }] })), /layer/);
});

test('Inbox.gs: статус укладывается в бюджет — сначала уходят старые итоги запросов', () => {
  const { ctx } = inbox();
  const s = { processed: {}, pendingLayer: {} };
  for (let i = 0; i < 60; i++) s.processed['r' + i] = { ok: true, at: new Date(Date.UTC(2026, 9, 1, 0, i)).toISOString(), created: [{ op: 'task.create', title: 'x'.repeat(40), taskId: 'id' + i }] };
  for (let i = 0; i < 30; i++) s.pendingLayer['t' + i] = { at: new Date(Date.UTC(2026, 9, 2, 0, i)).toISOString(), listId: 'L', topic: 'Покупки' };
  ctx.fitStatus_(s);
  assert.ok(JSON.stringify(s).length <= 7800);
  assert.equal(Object.keys(s.pendingLayer).length, 30);
  assert.ok(s.processed.r59 && !s.processed.r0);
});

test('Inbox.gs: перечень списков в статусе обновляется и без запросов — раз в 15 минут', () => {
  const { ctx, lists } = inbox();
  const props = {};
  ctx.PropertiesService = { getScriptProperties: () => ({ getProperty: (k) => props[k] ?? null, setProperty: (k, v) => { props[k] = v; } }) };
  let status = { processed: {}, pendingLayer: {}, pendingLists: {}, lists: ['Мои задачи'], listsAt: new Date().toISOString() };
  let writes = 0;
  ctx.readStatus_ = () => JSON.parse(JSON.stringify(status));
  ctx.writeStatus_ = (s) => { status = s; writes++; };
  lists.push({ id: 'L1', title: 'Мои задачи' });

  ctx.listsTick_();
  assert.equal(writes, 0, 'ничего не поменялось — статус не трогаем');

  lists.push({ id: 'L2', title: 'Джем' });
  ctx.listsTick_();
  assert.equal(writes, 0, 'через минуту ещё не проверяет');

  props.INBOX_LISTS_AT = String(Date.now() - 16 * 60 * 1000);
  ctx.listsTick_();
  assert.equal(writes, 1);
  assert.deepEqual([...status.lists], ['Мои задачи', 'Джем']);

  // без перемен, но давно не отмечали — отметить проверку
  assert.equal(ctx.setLists_(status, ['Мои задачи', 'Джем'], Date.now()), false);
  assert.equal(ctx.setLists_(status, ['Мои задачи', 'Джем'], Date.now() + 7 * 3600 * 1000), true);
});
