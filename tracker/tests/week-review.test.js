// Итог недели в боте (reminders/BotTasks.gs → cmdReview_, reviewTick_).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

function bot({ tasks = [], dow = '5', hm = '18:05' } = {}) {
  const props = { TELEGRAM_BOT_TOKEN: 'x', TELEGRAM_CHAT_ID: '1' }, sent = [];
  const [H, M] = hm.split(':');
  const ctx = vm.createContext({
    console,
    Utilities: { formatDate: (d, tz, f) => ({ 'yyyy-MM-dd': '2026-10-23', u: dow, H, m: M }[f]) },
    PropertiesService: { getScriptProperties: () => ({ getProperty: (k) => props[k] ?? null, setProperty: (k, v) => { props[k] = v; }, deleteProperty: (k) => { delete props[k]; } }) },
    UrlFetchApp: { fetch: (url, o) => { sent.push(JSON.parse(o.payload).text); return { getResponseCode: () => 200, getContentText: () => '{}' }; } },
    Tasks: {
      Tasklists: { list: () => ({ items: [{ id: 'W', title: 'Работа' }, { id: 'P', title: 'Личное' }, { id: 'H', title: 'Привычки' }] }) },
      Tasks: { list: (listId, o) => ({ items: tasks.filter((t) => t.list === listId && (o.showCompleted || t.status !== 'completed')) }) },
    },
  });
  for (const f of ['Code.gs', 'Bot.gs', 'BotTasks.gs', 'Inbox.gs']) vm.runInContext(readFileSync(new URL(`../../reminders/${f}`, import.meta.url), 'utf8'), ctx, { filename: f });
  return { ctx, props, sent };
}
const done = (id, title, list, completed) => ({ id, title, list, status: 'completed', completed });
const open = (id, title, list, due) => ({ id, title, list, status: 'needsAction', due: due && `${due}T00:00:00.000Z`, position: id });

const TASKS = [
  done('a', 'Скетч таверны', 'W', '2026-10-22T10:00:00Z'), done('b', 'Ревью иконок', 'W', '2026-10-21T10:00:00Z'),
  done('c', 'Купить молоко', 'P', '2026-10-20T10:00:00Z'), done('h', 'Зарядка', 'H', '2026-10-22T10:00:00Z'),
  open('d', 'Смета <клиент>', 'W', '2026-10-21'), open('e', 'Созвон', 'W', '2026-10-27'), open('f', 'Без срока', 'P'),
];

test('итог: сделано по спискам, просроченное, следующая неделя; привычки не считаются', () => {
  const t = bot({ tasks: TASKS }).ctx.handle_('/итог');
  assert.match(t, /Сделано: 3<\/b> · Работа 2, Личное 1/);
  assert.match(t, /• Скетч таверны\n• Ревью иконок\n• Купить молоко/);
  assert.doesNotMatch(t, /Зарядка/);
  assert.match(t, /Просрочено: 1[\s\S]*Смета &lt;клиент&gt;/);
  assert.match(t, /На следующей неделе со сроком: 1/);
});

test('пустая неделя — без упрёков', () => {
  assert.match(bot().ctx.cmdReview_(''), /выполненных задач нет/);
});

test('сам приходит в пятницу после 18:00 и один раз; в другие дни и до 18:00 — нет', () => {
  const b = bot({ tasks: TASKS });
  b.ctx.reviewTick_(); b.ctx.reviewTick_();
  assert.equal(b.sent.length, 1);
  const thu = bot({ tasks: TASKS, dow: '4' }); thu.ctx.reviewTick_();
  const early = bot({ tasks: TASKS, hm: '17:59' }); early.ctx.reviewTick_();
  assert.equal(thu.sent.length + early.sent.length, 0);
});

test('/review off и on', () => {
  const b = bot({ tasks: TASKS });
  assert.match(b.ctx.handle_('/review off'), /выключен/);
  b.ctx.reviewTick_();
  assert.equal(b.sent.length, 0);
  b.ctx.handle_('/review on');
  b.ctx.reviewTick_();
  assert.equal(b.sent.length, 1);
});
