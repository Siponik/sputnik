// Черновик задачи в боте (bot/src/draft.js): догадка по пересланному, правка кнопками и текстом, разделить пересланное.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import * as D from '../../bot/src/draft.js';

const TODAY = '2026-10-27'; // вторник
const ctx = { today: TODAY, lists: [{ id: 'W', title: 'Работа' }, { id: 'Z', title: 'Заказы клиентов' }, { id: 'P', title: 'Личное' }], def: 'P', learned: {}, words: {} };
const fwd = (text, extra = {}) => ({ text, forward_origin: { type: 'user', sender_user: { id: 7, first_name: 'Ольга' } }, ...extra });
const pick = (d) => [d.title, d.day, d.time, d.list, d.prio];

test('пересланное: название без приветствия и «можешь», срок «до пятницы 15:00», список по слову', () => {
  const d = D.guess(fwd('Привет! Можешь, пожалуйста, прислать скетч таверны до пятницы 15:00? Заказчик ждёт'), ctx);
  assert.deepEqual(pick(d), ['Прислать скетч таверны', '2026-10-30', '15:00', 'Z', null]);
  assert.equal(d.from, 'Ольга');
  assert.match(d.notes, /^Привет! Можешь/);
  assert.match(d.notes, /переслано от Ольга/);
});

test('пересланное: «срочно … к завтра», «вечером», «к среде», «срок 5 ноября»', () => {
  assert.deepEqual(pick(D.guess(fwd('Слушай, нужно срочно поправить UV на мече к завтра'), ctx)), ['Поправить UV на мече', '2026-10-28', null, 'P', 1]);
  assert.deepEqual(pick(D.guess(fwd('Не забудь купить корм коту вечером'), ctx)), ['Купить корм коту', TODAY, '19:00', 'P', null]);
  assert.deepEqual(pick(D.guess(fwd('А ты можешь глянуть рендер к среде? Там свет странный.'), ctx)), ['Глянуть рендер', '2026-10-28', null, 'P', null]);
  assert.equal(D.guess(fwd('Добрый день! Модель стула, срок 5 ноября'), ctx).day, '2026-11-05');
});

test('когда: до конца недели, на следующей неделе, в выходные, через пару дней', () => {
  assert.equal(D.when('сделать до конца недели', TODAY).day, '2026-10-30');
  assert.equal(D.when('на следующей неделе созвон', TODAY).day, '2026-11-02');
  assert.equal(D.when('в выходные убраться', TODAY).day, '2026-10-31');
  assert.equal(D.when('через пару дней', TODAY).day, '2026-10-29');
  assert.deepEqual(D.when('позвонить маме завтра 17:00', TODAY), { day: '2026-10-28', time: '17:00', rest: 'позвонить маме' });
});

test('без текста: фото из канала — название и ссылка на оригинал; ссылка без слов', () => {
  const d = D.guess({ photo: [{}], forward_origin: { type: 'channel', chat: { id: -100, title: 'Арт-канал', username: 'art' }, message_id: 55 } }, ctx);
  assert.equal(d.title, 'Фото от Арт-канал');
  assert.match(d.notes, /https:\/\/t\.me\/art\/55/);
  assert.equal(D.guess(fwd('https://example.com/ref.png'), ctx).title, 'Посмотреть ссылку example.com');
});

test('свой текст: заметка со второй строки, @список и !!', () => {
  const d = D.guess({ text: 'купить молоко завтра 18:00 @раб !!\nобезжиренное' }, ctx);
  assert.deepEqual(pick(d), ['Купить молоко', '2026-10-28', '18:00', 'W', 2]);
  assert.equal(d.notes, 'обезжиренное');
  assert.equal(d.from, '');
});

test('список: запомненный для отправителя главнее слов', () => {
  const d = D.guess(fwd('глянуть заказ'), { ...ctx, learned: { u7: 'W' } });
  assert.equal(d.list, 'W');
  assert.match(d.why, /Ольга/);
});

test('кнопки: срок → время → назад; список; приоритет; создать', () => {
  let d = { ...D.guess(fwd('сделать ревью в пт'), ctx), id: 'ab' };
  assert.equal(D.card(d, ctx).markup.inline_keyboard[0][0].callback_data, 'gab|ok');
  d = D.press(d, 'w', ctx).d;
  assert.equal(d.mode, 'when');
  assert.ok(JSON.stringify(D.card(d, ctx).markup).includes('gab|D2026-10-28'));
  d = D.press(d, 'D2026-10-28', ctx).d;
  assert.equal(d.mode, 'when'); // времени нет — выбор остаётся открытым
  d = D.press(d, 'H15:00', ctx).d;
  assert.deepEqual([d.day, d.time, d.mode], ['2026-10-28', '15:00', '']);
  d = D.press(D.press(d, 'l', ctx).d, 'L1', ctx).d;
  assert.equal(d.list, 'Z');
  d = D.press(d, 'P1', ctx).d;
  assert.equal(d.prio, 1);
  assert.match(D.card(d, ctx).text, /высокий/);
  assert.equal(D.press(d, 'ok', ctx).act, 'create');
  assert.deepEqual(D.parseData('gab|H15:00'), { id: 'ab', op: 'H15:00' });
  for (const row of D.card({ ...d, mode: 'when' }, ctx).markup.inline_keyboard) for (const b of row) assert.ok(Buffer.byteLength(b.callback_data) <= 64);
});

test('правка текстом: «завтра 18:00 @заказы» правит, обычная фраза — нет; режим «название»', () => {
  const d = { ...D.guess(fwd('сделать ревью в пт'), ctx), id: 'ab' };
  const e = D.editByText(d, 'завтра 18:00 @заказы', ctx);
  assert.deepEqual([e.day, e.time, e.list], ['2026-10-28', '18:00', 'Z']);
  assert.equal(D.editByText(d, 'купить хлеб', ctx), null);
  assert.equal(D.editByText(d, 'без срока', ctx).day, null);
  assert.equal(D.editByText({ ...d, mode: 'title' }, 'Ревью сцены', ctx).title, 'Ревью сцены');
});

test('несколько пересланных подряд: один черновик, можно разделить', () => {
  let d = { ...D.guess(fwd('Первое: сделать иконки'), ctx), id: 'ab' };
  d = D.merge(d, fwd('И ещё поправить шрифт до четверга'), ctx);
  assert.equal(d.cnt, 2);
  assert.equal(d.day, '2026-10-29');
  assert.match(D.card(d, ctx).text, /2 сообщ/);
  const parts = D.split(d);
  assert.deepEqual(parts.map((x) => x.title), ['Первое: сделать иконки', 'Поправить шрифт']);
  assert.equal(parts[1].day, '2026-10-29');
});

test('трекер: карточка из бота → задача (список, срок, время, приоритет, напоминание; тип и повтор из текста)', async () => {
  const { fromDraft, guessCtx } = await import('../src/lib/sharedbot.js');
  const lists = [{ id: 'W', title: 'Работа' }, { id: 'Z', title: 'Заказы' }];
  const t = fromDraft({ title: 'Скетч', notes: 'от Ольги', due: '2026-10-30', time: '15:00', listId: 'Z', prio: 1, rem: 15, src: 'скетч каждую неделю #work' }, { lists, layer: {}, tasks: {}, today: new Date(2026, 9, 27) });
  assert.deepEqual([t.title, t.listId, t.due, t.slot, t.notes], ['Скетч', 'Z', '2026-10-30', { s: '15:00', e: '16:00' }, 'от Ольги']);
  assert.deepEqual([t.layer.priority, t.layer.remind, t.layer.repeat, t.layer.type], [1, { kind: 'lead', min: 15 }, { every: 'week' }, 'work']);
  assert.equal(fromDraft({ title: 'X', listId: 'нет', rem: 'off' }, { lists, layer: {}, tasks: {} }).layer.remind, null);
  assert.deepEqual(guessCtx(lists, { settings: { route: { рендр: { list: 'Z', n: 2 }, чужое: { list: 'Q' } } } }), { lists, def: 'W', words: { рендр: 'Z' } });
});
