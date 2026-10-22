// Общий бот (bot/src/logic.js): привязка по коду, напоминания с кнопками, задачи из чата.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { onUpdate, link, putState, tick, agenda, format, sha256 } from '../../bot/src/logic.js';

function memStore() {
  const users = new Map(), codes = new Map(), inbox = [], sent = [];
  let seq = 0;
  return {
    users, inbox, sent,
    user: async (chat) => users.get(chat) ?? null,
    userByKey: async (h) => [...users.values()].find((u) => u.key_hash === h) ?? null,
    putCode: async (code, chat, name, exp) => { for (const [k, c] of codes) if (c.chat === chat) codes.delete(k); codes.set(code, { chat, name, exp }); },
    takeCode: async (code) => { const c = codes.get(code); codes.delete(code); return c ?? null; },
    link: async (chat, key_hash, tz, name) => { users.set(chat, { chat, key_hash, tz, name, muted: 0, ...(users.get(chat) ? { state: users.get(chat).state } : {}) }); },
    unlink: async (chat) => { users.delete(chat); },
    setMuted: async (chat, v) => { users.get(chat).muted = v ? 1 : 0; },
    state: async (chat) => users.get(chat)?.state ?? null,
    putState: async (chat, state, tz, next) => { const u = users.get(chat); u.state = state; if (tz) u.tz = tz; u.next_at = next; },
    addSnooze: async (chat, item) => { const u = users.get(chat); u.state.snoozed = [...(u.state.snoozed ?? []), item]; u.next_at = Math.min(u.next_at ?? Infinity, Date.parse(item.fireAt)); },
    setNext: async (chat, n) => { users.get(chat).next_at = n; },
    due: async (now) => [...users.values()].filter((u) => !u.muted && u.next_at != null && u.next_at <= now),
    sentKeys: async (chat) => new Set(sent.filter((s) => s.chat === chat).map((s) => s.key)),
    markSent: async (chat, item, at) => { sent.push({ id: ++seq, chat, key: item.key, item, at }); return seq; },
    unmarkSent: async (chat, id) => { const i = sent.findIndex((s) => s.id === id); if (i >= 0) sent.splice(i, 1); },
    sentById: async (chat, id) => { const s = sent.find((x) => x.id === id && x.chat === chat); return s ? { item: s.item } : null; },
    purge: async () => {},
    addInbox: async (chat, body) => { inbox.push({ id: inbox.length + 1, chat, ...body }); },
  };
}
const tgLog = () => { const calls = []; const tg = async (method, body) => { calls.push({ method, ...body }); return { ok: true }; }; return { calls, tg }; };
const msg = (text, chat = 5) => ({ message: { chat: { id: chat, type: 'private' }, from: { first_name: 'Аня' }, text } });

test('привязка: /start → код → трекер вводит код → чат связан с ключом', async () => {
  const store = memStore(), { calls, tg } = tgLog();
  await onUpdate(msg('/start'), { store, tg, rand: () => 0.5 });
  assert.match(calls[0].text, /<b>550000<\/b>/);
  const key = 'k'.repeat(40);
  assert.equal((await link({ code: '111111', key }, { store, tg })).status, 404);
  const r = await link({ code: '550000', key, tz: 'Asia/Yekaterinburg' }, { store, tg });
  assert.equal(r.status, 200);
  assert.equal(store.users.get('5').key_hash, await sha256(key));
  assert.equal(store.users.get('5').tz, 'Asia/Yekaterinburg');
  // код одноразовый
  assert.equal((await link({ code: '550000', key }, { store, tg })).status, 404);
});

test('текст в чат — задача во «входящие» трекера; без привязки — просим /start', async () => {
  const store = memStore(), { calls, tg } = tgLog();
  await onUpdate(msg('купить корм'), { store, tg, rand: () => 0.1 });
  assert.equal(store.inbox.length, 0);
  assert.match(calls[0].text, /Код для подключения/);
  await store.link('5', 'h', 'Europe/Moscow', 'Аня');
  await onUpdate(msg('купить корм завтра 18:00'), { store, tg });
  assert.deepEqual(store.inbox.map((x) => [x.type, x.text]), [['add', 'купить корм завтра 18:00']]);
});

test('напоминание приходит один раз, с кнопками; «Готово» уходит в трекер, «Через час» повторяет', async () => {
  const store = memStore(), { calls, tg } = tgLog();
  await store.link('5', 'h', 'Europe/Moscow', 'Аня');
  const now = Date.parse('2026-10-22T07:00:00Z');
  const item = { key: 't1|x', taskId: 't1', listId: 'L', list: 'Дом', title: 'Полить <цветы>', due: '2026-10-22', fireAt: '2026-10-22T06:59:00Z' };
  const later = { key: 't2|x', taskId: 't2', listId: 'L', list: 'Дом', title: 'Позже', fireAt: '2026-10-22T09:00:00Z' };
  await putState('5', { items: [item, later], today: [] }, { store, now });
  assert.equal(store.users.get('5').next_at, Date.parse(item.fireAt));
  assert.equal(await tick({ store, tg, now }), 1);
  assert.equal(await tick({ store, tg, now: now + 60e3 }), 0);
  const sentMsg = calls.find((c) => c.method === 'sendMessage');
  assert.match(sentMsg.text, /Полить &lt;цветы&gt;/);
  assert.match(sentMsg.text, /Срок: 22 окт\./);
  const [done, snooze] = sentMsg.reply_markup.inline_keyboard[0];
  assert.equal(store.users.get('5').next_at, Date.parse(later.fireAt));

  await onUpdate({ callback_query: { id: 'q', data: done.callback_data, message: { chat: { id: 5 }, message_id: 1 } } }, { store, tg, now });
  assert.deepEqual(store.inbox.map((x) => [x.type, x.taskId, x.listId]), [['done', 't1', 'L']]);

  await onUpdate({ callback_query: { id: 'q2', data: snooze.callback_data, message: { chat: { id: 5 }, message_id: 1 } } }, { store, tg, now });
  assert.match(calls.at(-1).text, /Напомню в 11:00/); // Москва, +1 ч
  assert.equal(await tick({ store, tg, now: now + 61 * 60e3 }), 1);
});

test('пауза /off и опоздание больше 12 часов — не шлём', async () => {
  const store = memStore(), { tg } = tgLog();
  await store.link('5', 'h', 'Europe/Moscow', 'Аня');
  const now = Date.parse('2026-10-22T20:00:00Z');
  await putState('5', { items: [{ key: 'old', title: 'Старое', fireAt: '2026-10-22T06:00:00Z' }, { key: 'new', title: 'Новое', fireAt: '2026-10-22T19:59:00Z' }] }, { store, now });
  await onUpdate(msg('/off'), { store, tg });
  assert.equal(await tick({ store, tg, now }), 0);
  await onUpdate(msg('/on'), { store, tg });
  assert.equal(await tick({ store, tg, now }), 1);
});

test('/today и /week — по снимку трекера, в часовом поясе человека', () => {
  const now = Date.parse('2026-10-22T07:00:00Z'); // чт, 10:00 в Москве
  const today = [
    { title: 'Созвон', due: '2026-10-22', time: '15:00' },
    { title: 'Отчёт', due: '2026-10-20' },
    { title: 'Спортзал', due: '2026-10-24', time: '09:00' },
  ];
  const t = agenda(today, 'Europe/Moscow', now);
  assert.match(t, /Отчёт <i>\(просрочено\)/);
  assert.ok(t.indexOf('Отчёт') < t.indexOf('Созвон'));
  assert.doesNotMatch(t, /Спортзал/);
  const w = agenda(today, 'Europe/Moscow', now, 7);
  assert.match(w, /сб, 24 окт\.[\s\S]*09:00 Спортзал/);
  assert.equal(agenda([], 'Europe/Moscow', now), 'На сегодня задач нет 🌙');
  assert.match(format({ kind: 'event', title: 'Встреча', start: '2026-10-22T12:30:00Z' }, 'Europe/Moscow'), /22 окт\., 15:30/);
});

test('трекер: сообщение боту → задача; снимок недели для /today', async () => {
  const { fromText, snapshot } = await import('../src/lib/sharedbot.js');
  const lists = [{ id: 'A', title: 'Дом' }, { id: 'B', title: 'Работа' }];
  const today = new Date(2026, 9, 22, 10, 0);
  const t = fromText('купить корм завтра 18:00 @работа\nвзять большой', { lists, layer: {}, tasks: {}, today });
  assert.equal(t.title, 'Купить корм');
  assert.equal(t.listId, 'B');
  assert.equal(t.due, '2026-10-23');
  assert.deepEqual(t.slot, { s: '18:00', e: '19:00' });
  assert.equal(t.notes, 'взять большой');
  assert.equal(fromText('полить цветы', { lists, layer: {}, tasks: {}, today }).due, null); // без даты — без срока
  const snap = snapshot(lists, {
    A: [{ id: '1', title: 'Скоро', due: '2026-10-24T00:00:00.000Z' }, { id: '2', title: 'Далеко', due: '2026-11-20T00:00:00.000Z' }, { id: '3', title: 'Сделано', due: '2026-10-22T00:00:00.000Z', status: 'completed' }],
    B: [{ id: '4', title: 'Созвон', due: '2026-10-22T00:00:00.000Z' }],
  }, { 4: { slot: { s: '15:00' } } }, today);
  assert.deepEqual(snap, [{ title: 'Созвон', due: '2026-10-22', time: '15:00', list: 'Работа' }, { title: 'Скоро', due: '2026-10-24', list: 'Дом' }]);
});
