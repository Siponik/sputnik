// Напоминания для задач, созданных в Telegram, — без запуска трекера (reminders/BotTasks.gs → BOT_REM, Code.gs).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

function setup({ fileItems = [], defaults = null } = {}) {
  const props = { TELEGRAM_BOT_TOKEN: 'x', TELEGRAM_CHAT_ID: '1' }, calls = [];
  let now = Date.parse('2026-10-20T10:00:00Z');
  const task = { id: 'T1', status: 'needsAction', due: null };
  const fileData = () => JSON.stringify({ items: fileItems, ...(defaults ? { defaults } : {}) });
  const file = { isTrashed: () => false, getLastUpdated: () => 1, getBlob: () => ({ getDataAsString: fileData }) };
  const ctx = vm.createContext({
    console: { ...console, error: () => {} }, JSON,
    Date: class extends Date { constructor(...a) { super(...(a.length ? a : [now])); } static now() { return now; } },
    Utilities: { formatDate: (d, tz, f) => {
      const m = new Date(d.getTime() + 3 * 3600e3);
      if (f === 'H:mm') return `${m.getUTCHours()}:${String(m.getUTCMinutes()).padStart(2, '0')}`;
      return m.toISOString().slice(0, 10);
    } },
    PropertiesService: { getScriptProperties: () => ({ getProperty: (k) => props[k] ?? null, setProperty: (k, v) => { props[k] = v; }, deleteProperty: (k) => { delete props[k]; } }) },
    DriveApp: { getFilesByName: () => { let i = 0; return { hasNext: () => i === 0, next: () => (i++, file) }; } },
    CalendarApp: { getCalendarsByName: () => [] },
    UrlFetchApp: { fetch: (url, o) => { calls.push({ method: url.split('/').pop(), body: JSON.parse(o.payload) }); return { getResponseCode: () => 200, getContentText: () => '{"ok":true}' }; } },
    Tasks: {
      Tasks: { insert: (b) => { Object.assign(task, b); return task; }, get: () => task, patch: () => ({}) },
      Tasklists: { list: () => ({ items: [{ id: 'L', title: 'Работа' }] }) },
    },
  });
  for (const f of ['Code.gs', 'Bot.gs', 'BotTasks.gs']) vm.runInContext(readFileSync(new URL(`../../reminders/${f}`, import.meta.url), 'utf8'), ctx, { filename: f });
  const sent = () => calls.filter((c) => c.method === 'sendMessage' && /Рендер/.test(c.body.text));
  return { ctx, props, task, sent, queue: () => JSON.parse(props.BOT_REM || '[]'), at: (iso) => { now = Date.parse(iso); } };
}

test('задача «завтра 17:00» из бота — напоминание за час, ключ как у трекера', () => {
  const { ctx, queue } = setup();
  ctx.cmdAdd_('Рендер завтра 17:00');
  const q = queue();
  assert.equal(q.length, 1);
  assert.equal(q[0].fireAt, '2026-10-21T13:00:00.000Z'); // 16:00 по Москве
  assert.equal(q[0].key, 'T1|2026-10-21T13:00:00.000Z');
  assert.equal(q[0].due, '2026-10-21');
});

test('по умолчанию из трекера: за день и в момент начала; прошедшие не ставятся', () => {
  const { ctx, queue } = setup({ defaults: { task: [0, 1440, 60 * 24 * 7] } });
  ctx.cmdAdd_('Рендер завтра 17:00');
  assert.deepEqual(queue().map((x) => x.fireAt).sort(), ['2026-10-20T14:00:00.000Z', '2026-10-21T14:00:00.000Z']);
});

test('без времени — от 10:00; без срока — ничего', () => {
  const a = setup();
  a.ctx.cmdAdd_('Рендер завтра');
  assert.equal(a.queue()[0].fireAt, '2026-10-21T06:00:00.000Z');
  const b = setup();
  b.ctx.cmdAdd_('Рендер');
  assert.equal(b.queue().length, 0);
});

test('приходит один раз и уходит из очереди', () => {
  const { ctx, sent, queue, at } = setup();
  ctx.cmdAdd_('Рендер завтра 17:00');
  at('2026-10-21T12:59:00Z'); ctx.remindersTick_();
  assert.equal(sent().length, 0);
  at('2026-10-21T13:00:30Z'); ctx.remindersTick_();
  assert.equal(sent().length, 1);
  at('2026-10-21T13:01:30Z'); ctx.remindersTick_();
  assert.equal(sent().length, 1);
  assert.equal(queue().length, 0);
});

test('срок перенесли — старое напоминание не приходит', () => {
  const { ctx, sent, task, at } = setup();
  ctx.cmdAdd_('Рендер завтра 17:00');
  task.due = '2026-10-23T00:00:00.000Z';
  at('2026-10-21T13:00:30Z'); ctx.remindersTick_();
  assert.equal(sent().length, 0);
});

test('трекер посчитал то же напоминание — сообщение одно', () => {
  const item = { key: 'T1|2026-10-21T13:00:00.000Z', taskId: 'T1', listId: 'L', list: 'Работа', title: 'Рендер', due: '2026-10-21', fireAt: '2026-10-21T13:00:00.000Z' };
  const { ctx, sent, at } = setup({ fileItems: [item] });
  ctx.cmdAdd_('Рендер завтра 17:00');
  at('2026-10-21T13:00:30Z'); ctx.remindersTick_();
  at('2026-10-21T13:01:30Z'); ctx.remindersTick_();
  assert.equal(sent().length, 1);
});
