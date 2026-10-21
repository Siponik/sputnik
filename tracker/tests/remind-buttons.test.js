// Кнопки под напоминанием в Telegram: «✓ Готово» и «⏰ Через час» (reminders/Code.gs, BotTasks.gs).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

function setup(items) {
  const props = { TELEGRAM_BOT_TOKEN: 'x', TELEGRAM_CHAT_ID: '1' }, calls = [];
  let now = Date.parse('2026-10-20T10:00:00Z');
  const file = { isTrashed: () => false, getLastUpdated: () => 1, getBlob: () => ({ getDataAsString: () => JSON.stringify({ items }) }) };
  const ctx = vm.createContext({
    console, JSON,
    Date: class extends Date { constructor(...a) { super(...(a.length ? a : [now])); } static now() { return now; } },
    Utilities: { formatDate: (d, tz, f) => (f === 'H:mm' ? `${(d.getUTCHours() + 3) % 24}:${String(d.getUTCMinutes()).padStart(2, '0')}` : '2026-10-20') },
    PropertiesService: { getScriptProperties: () => ({ getProperty: (k) => props[k] ?? null, setProperty: (k, v) => { props[k] = v; }, deleteProperty: (k) => { delete props[k]; } }) },
    DriveApp: { getFilesByName: () => { let i = 0; return { hasNext: () => i === 0, next: () => (i++, file) }; } },
    UrlFetchApp: { fetch: (url, o) => { calls.push({ method: url.split('/').pop(), body: JSON.parse(o.payload) }); return { getResponseCode: () => 200, getContentText: () => '{"ok":true}' }; } },
    Tasks: { Tasks: { get: () => ({ status: 'needsAction' }), patch: () => ({}) }, Tasklists: { list: () => ({ items: [] }) } },
  });
  for (const f of ['Code.gs', 'Bot.gs', 'BotTasks.gs']) vm.runInContext(readFileSync(new URL(`../../reminders/${f}`, import.meta.url), 'utf8'), ctx, { filename: f });
  return { ctx, props, calls, advance: (min) => { now += min * 60e3; } };
}

const taskItem = { key: 't1|x', taskId: 't1', listId: 'L', list: 'Работа', title: 'Рендер', due: '2026-10-20', fireAt: '2026-10-20T09:59:00Z' };
const eventItem = { key: 'ev|e1|x', kind: 'event', title: 'Созвон', start: '2026-10-20T10:15:00Z', fireAt: '2026-10-20T09:59:30Z' };

test('у задачи — «Готово» и «Через час», у события — только «Через час»', () => {
  const { ctx, calls } = setup([taskItem, eventItem, { key: 'm', kind: 'milestone', title: '🎉 7 дней', fireAt: '2026-10-20T09:00:00Z' }]);
  ctx.remindersTick_();
  const msgs = calls.filter((c) => c.method === 'sendMessage');
  assert.equal(msgs.length, 3);
  const kb = (m) => m.body.reply_markup?.inline_keyboard[0].map((b) => b.text);
  assert.deepEqual(kb(msgs.find((m) => m.body.text.includes('Рендер'))), ['✓ Готово', '⏰ Через час']);
  assert.deepEqual(kb(msgs.find((m) => m.body.text.includes('Созвон'))), ['⏰ Через час']);
  assert.equal(kb(msgs.find((m) => m.body.text.includes('7 дней'))), undefined);
});

test('«Через час» — напоминание приходит снова ровно через час и один раз', () => {
  const { ctx, calls, props, advance } = setup([taskItem]);
  ctx.remindersTick_();
  const sent = calls.find((c) => c.method === 'sendMessage');
  const btn = sent.body.reply_markup.inline_keyboard[0][1];
  ctx.onCallback_({ id: 'q', data: btn.callback_data, message: { chat: { id: 1 }, message_id: 5, reply_markup: sent.body.reply_markup } });
  const edit = calls.find((c) => c.method === 'editMessageReplyMarkup');
  assert.equal(edit.body.reply_markup.inline_keyboard[0][1].text, '⏰ Напомню в 14:00');
  assert.equal(calls.find((c) => c.method === 'answerCallbackQuery').body.text, 'Напомню в 14:00');

  const count = () => calls.filter((c) => c.method === 'sendMessage').length;
  advance(30); ctx.remindersTick_();
  assert.equal(count(), 1, 'через полчаса — ещё рано');
  advance(31); ctx.remindersTick_();
  assert.equal(count(), 2, 'через час — повтор');
  advance(1); ctx.remindersTick_();
  assert.equal(count(), 2, 'только один раз');
  assert.equal(JSON.parse(props.SNOOZED).length, 0);
});

test('старое напоминание без записи — честный ответ', () => {
  const { ctx, calls } = setup([]);
  ctx.onCallback_({ id: 'q', data: 'z:999', message: { chat: { id: 1 }, message_id: 5, reply_markup: { inline_keyboard: [] } } });
  assert.equal(calls.find((c) => c.method === 'answerCallbackQuery').body.text, 'Это напоминание уже не найти');
});
