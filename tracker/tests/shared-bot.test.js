// Общий бот (bot/src/logic.js): привязка по коду, напоминания с кнопками, задачи из чата.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { onUpdate, link, putState, tick, agenda, format, sha256 } from '../../bot/src/logic.js';
import { ackDrafts } from '../../bot/src/drafts.js';

function memStore() {
  const users = new Map(), codes = new Map(), inbox = [], sent = [], drafts = new Map();
  let qseq = 0;
  let seq = 0;
  const tries = [];
  return {
    users, q: inbox, sent,
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
    tries: async (ip, since) => tries.filter((t) => t.ip === ip && t.at > since).length,
    addTry: async (ip, at) => { tries.push({ ip, at }); },
    addInbox: async (chat, body) => { inbox.push({ id: ++qseq, chat, ...body }); return qseq; },
    updateInbox: async (chat, id, body) => { const i = inbox.findIndex((x) => x.id === id && x.chat === chat); if (i < 0) return false; inbox[i] = { id, chat, ...body }; return true; },
    dropInbox: async (chat, id) => { const i = inbox.findIndex((x) => x.id === id && x.chat === chat); if (i < 0) return false; inbox.splice(i, 1); return true; },
    inbox: async (chat) => inbox.filter((x) => x.chat === chat).map(({ chat: _c, ...x }) => x),
    ack: async (chat, ids) => { for (const id of ids) { const i = inbox.findIndex((x) => x.id === id && x.chat === chat); if (i >= 0) inbox.splice(i, 1); } },
    drafts,
    draft: async (chat, id) => structuredClone(drafts.get(chat + '|' + id) ?? null),
    lastDraft: async (chat) => structuredClone([...drafts.entries()].filter(([k]) => k.startsWith(chat + '|') && !k.endsWith('|~')).map(([, d]) => d).sort((a, b) => b.at - a.at)[0] ?? null),
    putDraft: async (chat, d, at) => { drafts.set(chat + '|' + d.id, structuredClone({ ...d, at })); },
    dropDraft: async (chat, id) => { drafts.delete(chat + '|' + id); },
    draftMeta: async (chat) => structuredClone(drafts.get(chat + '|~') ?? null),
    setDraftMeta: async (chat, m) => { drafts.set(chat + '|~', structuredClone(m)); },
  };
}
const tgLog = () => { const calls = []; let mid = 500; const tg = async (method, body) => { const id = method === 'sendMessage' ? ++mid : null; calls.push({ method, ...body, ...(id ? { message_id: id } : {}) }); return { ok: true, result: id ? { message_id: id } : true }; }; return { calls, tg }; };
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

test('перебор кодов: после 10 неверных с одного адреса — ждать час', async () => {
  const store = memStore(), { tg } = tgLog();
  await onUpdate(msg('/start'), { store, tg, rand: () => 0.5 });
  const key = 'k'.repeat(40), now = Date.now();
  for (let i = 0; i < 10; i++) assert.equal((await link({ code: String(100000 + i), key }, { store, tg, ip: 'x', now })).status, 404);
  assert.equal((await link({ code: '550000', key }, { store, tg, ip: 'x', now })).status, 429);
  assert.equal((await link({ code: '550000', key }, { store, tg, ip: 'y', now })).status, 200);
});

test('текст в чат — задача во «входящие» трекера; без привязки — просим /start', async () => {
  const store = memStore(), { calls, tg } = tgLog();
  await onUpdate(msg('купить корм'), { store, tg, rand: () => 0.1 });
  assert.equal(store.q.length, 0);
  assert.match(calls[0].text, /Код для подключения/);
  await store.link('5', 'h', 'Europe/Moscow', 'Аня');
  await onUpdate(msg('купить корм завтра 18:00'), { store, tg, now: Date.parse('2026-10-27T09:00:00Z') });
  const [x] = store.q;
  assert.deepEqual([x.type, x.text, x.draft.title, x.draft.due, x.draft.time, x.draft.src], ['add', 'Купить корм', 'Купить корм', '2026-10-28', '18:00', 'купить корм завтра 18:00']);
  assert.match(calls.at(-1).text, /Записал/);
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
  const [[done, tomorrow], [q15, snooze]] = sentMsg.reply_markup.inline_keyboard;
  assert.deepEqual([tomorrow.text, q15.text], ['📅 На завтра', '⏰ 15 мин']);
  assert.equal(store.users.get('5').next_at, Date.parse(later.fireAt));

  await onUpdate({ callback_query: { id: 'q', data: done.callback_data, message: { chat: { id: 5 }, message_id: 1 } } }, { store, tg, now });
  assert.deepEqual(store.q.map((x) => [x.type, x.taskId, x.listId]), [['done', 't1', 'L']]);

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
  assert.match(format({ kind: 'assigned', title: 'Сундук', note: 'Аня отдаёт тебе задачу', list: 'Ассеты' }, 'Europe/Moscow'), /^👤 <b>Сундук<\/b>\nАня отдаёт/);
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

// ---------- черновики задач (bot/src/draft.js, drafts.js) ----------

const NOW = Date.parse('2026-10-27T09:00:00Z'); // вторник, 12:00 по Москве
async function linked() {
  const store = memStore(), log = tgLog();
  await store.link('5', 'h', 'Europe/Moscow', 'Аня');
  await putState('5', { items: [], today: [], lists: [{ id: 'W', title: 'Работа' }, { id: 'Z', title: 'Заказы клиентов' }], def: 'W', words: { корм: 'W' } }, { store, now: NOW });
  const press = async (label, now = NOW) => {
    const card = [...log.calls].reverse().find((c) => c.reply_markup?.inline_keyboard?.flat().some((b) => b.text.includes(label)));
    assert.ok(card, 'нет кнопки ' + label);
    const b = card.reply_markup.inline_keyboard.flat().find((x) => x.text.includes(label));
    const message_id = card.message_id;
    await onUpdate({ callback_query: { id: 'q', data: b.callback_data, message: { chat: { id: 5 }, message_id } } }, { store, tg: log.tg, now });
  };
  const last = () => [...log.calls].reverse().find((c) => c.method === 'sendMessage' || c.method === 'editMessageText');
  return { store, ...log, press, last };
}
const fwdMsg = (text) => ({ message: { chat: { id: 5, type: 'private' }, from: { first_name: 'Аня' }, text, forward_origin: { type: 'user', sender_user: { id: 7, first_name: 'Ольга' } } } });

test('пересланное: черновик с догадкой, в очередь — только после «✅ Создать»', async () => {
  const b = await linked();
  await onUpdate(fwdMsg('Привет! Можешь прислать скетч таверны до пятницы 15:00? Заказчик ждёт'), { store: b.store, tg: b.tg, now: NOW });
  assert.equal(b.store.q.length, 0);
  assert.match(b.last().text, /Черновик.*Ольга[\s\S]*Прислать скетч таверны[\s\S]*пт, 30 окт\. · 15:00[\s\S]*Заказы клиентов/);
  await b.press('Создать');
  const [x] = b.store.q;
  assert.deepEqual([x.draft.title, x.draft.due, x.draft.time, x.draft.listId], ['Прислать скетч таверны', '2026-10-30', '15:00', 'Z']);
  assert.match(x.draft.notes, /переслано от Ольга/);
  assert.match(b.last().text, /Записал/);
  // трекер забрал — карточка «В Спутнике» без кнопок
  await ackDrafts('5', [x.id], { store: b.store, tg: b.tg, now: NOW });
  assert.match(b.last().text, /В Спутнике/);
  assert.deepEqual(b.last().reply_markup.inline_keyboard, []);
  assert.equal(b.store.q.length, 0);
});

test('кнопки: срок, список, приоритет; выбранный список запоминается для отправителя', async () => {
  const b = await linked();
  await onUpdate(fwdMsg('глянуть рендер'), { store: b.store, tg: b.tg, now: NOW });
  await b.press('Срок'); await b.press('Завтра'); await b.press('19:00');
  await b.press('Список'); await b.press('Заказы');
  await b.press('Приоритет'); await b.press('высокий');
  await b.press('Создать');
  const [x] = b.store.q;
  assert.deepEqual([x.draft.due, x.draft.time, x.draft.listId, x.draft.prio], ['2026-10-28', '19:00', 'Z', 1]);
  await onUpdate(fwdMsg('и ещё одно дело'), { store: b.store, tg: b.tg, now: NOW + 3600e3 });
  assert.match(b.last().text, /Заказы клиентов.*как в прошлый раз от Ольга/);
});

test('свой текст: сразу в очередь, кнопки правят запись, текст «@заказы» тоже; «Отменить» убирает', async () => {
  const b = await linked();
  await onUpdate(msg('купить корм коту'), { store: b.store, tg: b.tg, now: NOW });
  assert.equal(b.store.q[0].draft.listId, 'W'); // выученное слово «корм»
  await b.press('Срок'); await b.press('Завтра');
  assert.equal(b.store.q[0].draft.due, '2026-10-28');
  await onUpdate(msg('@заказы !!'), { store: b.store, tg: b.tg, now: NOW + 60e3 });
  assert.equal(b.store.q.length, 1);
  assert.deepEqual([b.store.q[0].draft.listId, b.store.q[0].draft.prio], ['Z', 2]);
  assert.ok(b.calls.some((c) => c.method === 'deleteMessage'));
  await b.press('Отменить', NOW + 120e3);
  assert.equal(b.store.q.length, 0);
  assert.match(b.last().text, /Отменил/);
});

test('трекер уже забрал — правка честно говорит «поправь в Спутнике»', async () => {
  const b = await linked();
  await onUpdate(msg('позвонить в банк'), { store: b.store, tg: b.tg, now: NOW });
  await ackDrafts('5', [b.store.q[0].id], { store: b.store, tg: b.tg, now: NOW });
  await onUpdate(msg('завтра'), { store: b.store, tg: b.tg, now: NOW + 60e3 });
  assert.equal(b.store.q.length, 0);
  assert.match(b.last().text, /уже в Спутнике/);
});

test('/ask on — свой текст черновиком; несколько пересланных подряд — «Разделить»', async () => {
  const b = await linked();
  await onUpdate(msg('/ask on'), { store: b.store, tg: b.tg, now: NOW });
  await onUpdate(msg('сделать иконки'), { store: b.store, tg: b.tg, now: NOW });
  assert.equal(b.store.q.length, 0);
  assert.match(b.last().text, /Черновик/);
  await onUpdate(fwdMsg('поправить шрифт'), { store: b.store, tg: b.tg, now: NOW + 5000 });
  await onUpdate(fwdMsg('обновить превью'), { store: b.store, tg: b.tg, now: NOW + 6000 });
  assert.match(b.last().text, /2 сообщ/);
  await b.press('Разделить', NOW + 7000);
  assert.deepEqual(b.store.q.map((x) => x.draft.title), ['Поправить шрифт', 'Обновить превью']);
});

test('«📅 На завтра» под напоминанием — запись move для трекера', async () => {
  const b = await linked();
  const item = { key: 't1|x', taskId: 't1', listId: 'L', title: 'Рендер', due: '2026-10-27', fireAt: '2026-10-27T08:59:00Z' };
  await putState('5', { items: [item], today: [] }, { store: b.store, now: NOW });
  await tick({ store: b.store, tg: b.tg, now: NOW });
  await b.press('На завтра');
  assert.deepEqual(b.store.q.map((x) => [x.type, x.taskId, x.due]), [['move', 't1', '2026-10-28']]);
  // списки от трекера не потерялись после PUT /state без них
  assert.equal(b.store.users.get('5').state.lists.length, 2);
});
