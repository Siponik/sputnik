// Повторяющиеся задачи: следующий срок и какие задачи пора продолжить (src/lib/repeat.js).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import { nextDue, dueRepeats, repeatLabel, takeRepeat } from '../src/lib/repeat.js';
import { layerPatches } from '../src/lib/inbox.js';

const T = '2026-10-21'; // среда

test('каждый день / неделю / год — от старого срока', () => {
  assert.equal(nextDue({ every: 'day' }, T, T), '2026-10-22');
  assert.equal(nextDue({ every: 'week' }, T, T), '2026-10-28');
  assert.equal(nextDue({ every: 'year' }, '2026-10-21', T), '2027-10-21');
});

test('по будням: с пятницы — на понедельник', () => {
  assert.equal(nextDue({ every: 'weekdays' }, '2026-10-23', '2026-10-23'), '2026-10-26');
  assert.equal(nextDue({ every: 'weekdays' }, T, T), '2026-10-22');
});

test('каждый месяц держится за число: 31 → 30 ноября → 31 декабря', () => {
  assert.equal(nextDue({ every: 'month' }, '2026-10-31', '2026-10-31'), '2026-11-30');
  assert.equal(nextDue({ every: 'month' }, '2026-10-31', '2026-12-01'), '2026-12-31');
  assert.equal(nextDue({ every: 'month' }, '2027-01-31', '2027-01-31'), '2027-02-28');
});

test('просрочка: следующий срок не в прошлом, день недели сохраняется', () => {
  assert.equal(nextDue({ every: 'week' }, '2026-10-05', T), '2026-10-26'); // понедельник → ближайший понедельник
  assert.equal(nextDue({ every: 'day' }, '2026-10-01', T), T);
});

test('без срока — от сегодня; неизвестное правило — ничего', () => {
  assert.equal(nextDue({ every: 'day' }, '', T), '2026-10-22');
  assert.equal(nextDue({ every: 'hour' }, T, T), null);
  assert.equal(nextDue(null, T, T), null);
});

test('продолжаем только выполненные задачи с правилом и без repeatNext', () => {
  const lists = [{ id: 'L' }];
  const tasks = { L: [
    { id: 'a', status: 'completed' },
    { id: 'b', status: 'needsAction' },
    { id: 'c', status: 'completed' },
    { id: 'd', status: 'completed', parent: 'a' },
    { id: 'e', status: 'completed' },
  ] };
  const lay = { a: { repeat: { every: 'day' } }, b: { repeat: { every: 'day' } }, c: { repeat: { every: 'day' }, repeatNext: 'x' }, d: { repeat: { every: 'day' } } };
  assert.deepEqual(dueRepeats(lists, tasks, lay).map((x) => x.task.id), ['a']);
});

test('подпись', () => {
  assert.equal(repeatLabel({ every: 'week' }), 'каждую неделю');
  assert.equal(repeatLabel(null), '');
});


test('повтор словами: «каждую неделю», «по будням», «ежедневно»', () => {
  assert.deepEqual(takeRepeat('полить цветы каждую неделю'), { rule: { every: 'week' }, rest: 'полить цветы' });
  assert.deepEqual(takeRepeat('отчёт по будням 10:00'), { rule: { every: 'weekdays' }, rest: 'отчёт 10:00' });
  assert.equal(takeRepeat('Ежедневно зарядка').rule.every, 'day');
  assert.equal(takeRepeat('каждый будний день стендап').rule.every, 'weekdays');
  assert.deepEqual(takeRepeat('просто задача'), { rule: null, rest: 'просто задача' });
});

test('повтор из бота переносится в слой, мусор — нет', () => {
  const st = { pendingLayer: { a: { repeat: { every: 'month' } }, b: { repeat: { every: 'hour' } } } };
  const p = Object.fromEntries(layerPatches(st, {}));
  assert.deepEqual(p.a.repeat, { every: 'month' });
  assert.equal(p.b.repeat, undefined);
});

test('бот понимает повтор в тексте задачи', () => {
  const props = {};
  const ctx = vm.createContext({
    console, JSON, Date,
    Utilities: { formatDate: () => '2026-10-21' },
    PropertiesService: { getScriptProperties: () => ({ getProperty: (k) => props[k] ?? null, setProperty: (k, v) => { props[k] = v; }, deleteProperty: () => {} }) },
  });
  for (const f of ['Code.gs', 'Bot.gs', 'BotTasks.gs']) vm.runInContext(readFileSync(new URL(`../../reminders/${f}`, import.meta.url), 'utf8'), ctx, { filename: f });
  const p = ctx.parseTask_('полить цветы каждую неделю в пятницу');
  assert.equal(p.title, 'Полить цветы');
  assert.deepEqual({ ...p.repeat }, { every: 'week' });
  assert.equal(p.day, '2026-10-23');
  assert.equal(ctx.parseTask_('купить хлеб').repeat, null);
});
