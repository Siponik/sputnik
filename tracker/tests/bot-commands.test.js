// Команды бота с поддельным Google Tasks: /week, /move, задачи в утреннем сообщении.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const TODAY = '2026-10-20'; // вторник
function bot(tasks) {
  const props = {}, patches = [];
  const lists = [{ id: 'W', title: 'Работа' }, { id: 'H', title: 'Привычки' }];
  const ctx = vm.createContext({
    console,
    Utilities: { formatDate: () => TODAY },
    PropertiesService: { getScriptProperties: () => ({ getProperty: (k) => props[k] ?? null, setProperty: (k, v) => { props[k] = v; }, deleteProperty: (k) => { delete props[k]; } }) },
    Tasks: {
      Tasklists: { list: () => ({ items: lists }) },
      Tasks: {
        list: (listId) => ({ items: tasks.filter((t) => t.list === listId && t.status !== 'completed') }),
        get: (listId, id) => { const t = tasks.find((x) => x.id === id && x.list === listId); if (!t) throw new Error('404'); return t; },
        patch: (body, listId, id) => { patches.push({ body, listId, id }); const t = tasks.find((x) => x.id === id); Object.assign(t, body); return t; },
      },
    },
    CalendarApp: { getCalendarsByName: () => [] },
  });
  for (const f of ['Code.gs', 'Bot.gs', 'BotTasks.gs', 'Inbox.gs']) vm.runInContext(readFileSync(new URL(`../../reminders/${f}`, import.meta.url), 'utf8'), ctx, { filename: f });
  ctx.readStatus_ = () => ({ pendingLayer: {} }); ctx.writeStatus_ = (st) => { ctx.lastStatus = st; };
  return { ctx, props, patches };
}
const T = (id, title, due, extra = {}) => ({ id, title, list: 'W', status: 'needsAction', position: id, due: due ? `${due}T00:00:00.000Z` : undefined, ...extra });

test('/week: просроченное, дни недели, без привычек и дальних сроков', () => {
  const { ctx } = bot([T('a', 'Старое', '2026-10-18'), T('b', 'Сегодняшнее', TODAY), T('c', 'В пятницу', '2026-10-23'), T('d', 'Через месяц', '2026-11-20'), T('e', 'Без срока'), T('h', 'Зарядка', TODAY, { list: 'H' })]);
  const r = ctx.handle_('/week');
  assert.match(r.text, /⚠ Просрочено[\s\S]*Старое/);
  assert.match(r.text, /Вторник, сегодня[\s\S]*Сегодняшнее/);
  assert.match(r.text, /Пятница, 23 окт\.[\s\S]*В пятницу/);
  assert.doesNotMatch(r.text, /Через месяц|Без срока|Зарядка/);
  assert.equal(r.markup.inline_keyboard.flat().length, 3);
});

test('/move номер завтра 17:00 — срок и время', () => {
  const b = bot([T('a', 'Рендер', TODAY)]);
  b.ctx.handle_('/today');
  const r = b.ctx.handle_('/move 1 завтра 17:00');
  assert.equal(r, '📅 <b>Рендер</b> → завтра 17:00');
  assert.equal(b.patches[0].body.due, '2026-10-21T00:00:00.000Z');
  assert.deepEqual({ ...b.ctx.lastStatus.pendingLayer.a.slot }, { s: '17:00', e: '18:00' });
});

test('/перенеси по названию и без срока', () => {
  const b = bot([T('a', 'Купить молоко', TODAY), T('b', 'Позвонить', TODAY)]);
  assert.equal(b.ctx.handle_('/перенеси молоко в пятницу'), '📅 <b>Купить молоко</b> → 23 окт.');
  b.ctx.handle_('/today');
  assert.equal(b.ctx.handle_('/move 1 без срока'), '📅 <b>Позвонить</b> → без срока');
  assert.equal(b.patches[1].body.due, null);
  assert.match(b.ctx.handle_('/move 1 когда-нибудь'), /Не понял, на когда/);
  assert.match(b.ctx.handle_('/move 9 завтра'), /Номера 9 нет/);
});

test('утреннее сообщение: задачи дня', () => {
  const { ctx } = bot([T('a', 'Старое', '2026-10-18'), T('b', 'Сегодня <важно>', TODAY), T('c', 'Завтра', '2026-10-21')]);
  const s = ctx.todayBrief_();
  assert.match(s, /Сегодня 2 задачи<\/b> \(просрочено 1\)/);
  assert.match(s, /⚠ Старое/);
  assert.match(s, /Сегодня &lt;важно&gt;/);
  assert.doesNotMatch(s, /Завтра/);
  assert.match(bot([]).ctx.todayBrief_(), /нет/);
});
