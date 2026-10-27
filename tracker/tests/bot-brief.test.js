// Утренняя сводка общего бота (bot/src/brief.js): когда слать, ожидание свежих новостей, команда /brief.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { briefTick, briefDue, briefMessage, newsLines } from '../../bot/src/brief.js';
import { onUpdate } from '../../bot/src/logic.js';

function store(users) {
  const brief = new Map();
  return {
    brief: async (chat) => brief.get(chat) ?? null,
    briefUsers: async () => users.map((u) => ({ ...u, ...(brief.get(u.chat) ?? {}) })),
    setBrief: async (chat, patch) => { const cur = brief.get(chat) ?? {}; for (const [k, v] of Object.entries(patch)) if (v != null) cur[k] = v; brief.set(chat, cur); },
    user: async (chat) => users.find((u) => u.chat === chat) ?? null,
    state: async (chat) => users.find((u) => u.chat === chat)?.state ?? null,
    setMuted: async (chat, v) => { users.find((u) => u.chat === chat).muted = v ? 1 : 0; },
    briefMap: brief,
  };
}
const tgLog = () => { const calls = []; return { calls, tg: async (method, body) => { calls.push({ method, ...body }); return { ok: true }; } }; };
// 27.10.2026 — вторник; время по Москве (UTC+3).
const msk = (hhmm, day = '2026-10-27') => Date.parse(`${day}T${hhmm}:00+03:00`);
const NEWS = { date: '2026-10-27', count: 12, top: [{ title: 'Blender 5.0', url: 'https://x/1' }, { title: 'Steam <осень>', url: 'https://x/2' }], dota: { stage: 'big', title: 'Патч 7.42', url: 'https://d' } };
const state = { at: msk('07:00'), today: [{ title: 'Отправить рендер', due: '2026-10-27', time: '11:00' }, { title: 'Купить корм', due: '2026-10-28' }] };

test('сводка: задачи дня, новости со ссылками, кнопка; HTML экранируется', () => {
  const { text, markup } = briefMessage(state, NEWS, 'Europe/Moscow', msk('08:00'));
  assert.match(text, /Спутник · утро<\/b> · 27\.10/);
  assert.match(text, /11:00 Отправить рендер/);
  assert.doesNotMatch(text, /Купить корм/);
  assert.match(text, /Новости · 12/);
  assert.match(text, /Dota 2: Патч 7\.42/);
  assert.match(text, /Steam &lt;осень&gt;/);
  assert.equal(markup.inline_keyboard[0][0].text, 'Открыть новости');
  // вчерашние — с пометкой, старше двух дней — без новостей
  assert.match(newsLines({ ...NEWS, date: '2026-10-26' }, '2026-10-27'), /вчерашние/);
  const old = briefMessage(state, { ...NEWS, date: '2026-10-20' }, 'Europe/Moscow', msk('08:00'));
  assert.doesNotMatch(old.text, /Новости/);
  assert.equal(old.markup, null);
});

test('когда слать: окно после времени сводки, ждём свежие новости до часа, будни', () => {
  const p = { at: 480, days: 'all', off: false, sent: '' };
  assert.equal(briefDue(p, 'Europe/Moscow', msk('07:59'), '2026-10-27'), null);
  assert.equal(briefDue(p, 'Europe/Moscow', msk('08:00'), '2026-10-27'), 'send');
  assert.equal(briefDue(p, 'Europe/Moscow', msk('08:30'), '2026-10-26'), 'wait');
  assert.equal(briefDue(p, 'Europe/Moscow', msk('09:00'), '2026-10-26'), 'send');
  assert.equal(briefDue(p, 'Europe/Moscow', msk('11:01'), '2026-10-27'), null);
  assert.equal(briefDue({ ...p, sent: '2026-10-27' }, 'Europe/Moscow', msk('08:10'), '2026-10-27'), null);
  assert.equal(briefDue({ ...p, off: true }, 'Europe/Moscow', msk('08:10'), '2026-10-27'), null);
  assert.equal(briefDue({ ...p, days: 'work' }, 'Europe/Moscow', msk('08:10', '2026-10-31'), '2026-10-31'), null); // суббота
  // свой часовой пояс: 08:00 в Екатеринбурге — это 06:00 по Москве
  assert.equal(briefDue(p, 'Asia/Yekaterinburg', msk('06:00'), '2026-10-27'), 'send');
});

test('cron: шлёт один раз в день, новости читает только когда кому-то пора', async () => {
  const s = store([{ chat: '5', tz: 'Europe/Moscow', muted: 0, state }, { chat: '6', tz: 'Europe/Moscow', muted: 1 }]);
  const { calls, tg } = tgLog();
  let reads = 0;
  const news = async () => { reads++; return NEWS; };
  assert.equal(await briefTick({ store: s, tg, news, now: msk('07:30') }), 0);
  assert.equal(reads, 0);
  assert.equal(await briefTick({ store: s, tg, news, now: msk('08:00') }), 1);
  assert.equal(calls[0].chat_id, '5');
  assert.equal(await briefTick({ store: s, tg, news, now: msk('08:01') }), 0);
  assert.equal(s.briefMap.get('5').sent, '2026-10-27');
});

test('cron: новости ещё не собрались — ждём, через час шлём со вчерашними', async () => {
  const s = store([{ chat: '5', tz: 'Europe/Moscow', muted: 0, state }]);
  const { calls, tg } = tgLog();
  const news = async () => ({ ...NEWS, date: '2026-10-26' });
  assert.equal(await briefTick({ store: s, tg, news, now: msk('08:00') }), 0);
  assert.equal(await briefTick({ store: s, tg, news, now: msk('09:00') }), 1);
  assert.match(calls[0].text, /вчерашние/);
});

test('/brief: сейчас, время, будни, пауза', async () => {
  const users = [{ chat: '5', tz: 'Europe/Moscow', muted: 0, state }];
  const s = store(users);
  const { calls, tg } = tgLog();
  const msg = (text) => ({ message: { chat: { id: 5, type: 'private' }, from: { first_name: 'Аня' }, text } });
  const ctx = { store: s, tg, news: async () => NEWS, now: msk('12:00') };
  await onUpdate(msg('/brief'), ctx);
  assert.match(calls.at(-1).text, /Спутник · утро/);
  await onUpdate(msg('/brief 7:30'), ctx);
  assert.match(calls.at(-1).text, /каждый день в 7:30/);
  assert.equal(s.briefMap.get('5').at, 450);
  await onUpdate(msg('/brief будни'), ctx);
  assert.match(calls.at(-1).text, /по будням в 7:30/);
  await onUpdate(msg('/brief выкл'), ctx);
  assert.match(calls.at(-1).text, /выключена/);
  assert.equal(await briefTick({ store: s, tg, news: ctx.news, now: msk('07:40') }), 0);
  await onUpdate(msg('/brief вкл'), ctx);
  assert.equal(await briefTick({ store: s, tg, news: ctx.news, now: msk('07:40') }), 1);
});
