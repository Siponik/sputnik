// Бот в Telegram (reminders/*.gs): разбор задач и времени. Файлы Apps Script грузим в песочницу с заглушками Google.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const TODAY = '2026-10-20'; // вторник
const gs = (name) => readFileSync(new URL(`../reminders/${name}`, import.meta.url), 'utf8');
const ctx = vm.createContext({
  console,
  Utilities: { formatDate: () => TODAY },
  PropertiesService: { getScriptProperties: () => ({ getProperty: () => null, setProperty() {}, deleteProperty() {} }) },
});
for (const f of ['Code.gs', 'Bot.gs', 'BotTasks.gs']) vm.runInContext(gs(f), ctx, { filename: f });

// Как разбирало «когда» приложение (тот же ответ даёт rust/core/src/when.rs): день, время, остаток.
const PHRASES = [
  ["позвонить маме завтра 17:00", "2026-10-21", "17:00", "позвонить маме"],
  ["скетч в пятницу 17.30", "2026-10-23", "17:30", "скетч"],
  ["созвон послезавтра в 15", "2026-10-22", "15:00", "созвон"],
  ["сдать рендер через 3 дня", "2026-10-23", null, "сдать рендер"],
  ["отпуск через 2 недели", "2026-11-03", null, "отпуск"],
  ["ревью 25 окт", "2026-10-25", null, "ревью"],
  ["новый год 1 января", "2027-01-01", null, "новый год"],
  ["налог 3.11", "2026-11-03", null, "налог"],
  ["встреча 5.01.2027 10:00", "2027-01-05", "10:00", "встреча"],
  ["спортзал во вторник", "2026-10-27", null, "спортзал"],
  ["митинг пн 9:15", "2026-10-26", "09:15", "митинг"],
  ["сегодня весь день 10:00 конференция", "2026-10-20", null, "конференция"],
  ["купить 2 молока", null, null, "купить 2 молока"],
  ["днюха 9 мая", "2027-05-09", null, "днюха"],
];

for (const [p, day, time, rest] of PHRASES) {
  test(`бот понимает «когда» как приложение: ${p}`, () => {
    const b = ctx.parseWhen_(p, TODAY);
    assert.deepEqual({ day: b.day, time: b.time, rest: b.rest }, { day, time, rest });
  });
}

test('parseTask_: список, тип, приоритет, заметка', () => {
  const t = ctx.parseTask_('скетч таверны в пятницу 17:00 #asset !! @работа\nреференсы в папке');
  assert.equal(t.title, 'Скетч таверны');
  assert.equal(t.notes, 'референсы в папке');
  assert.equal(t.day, '2026-10-23');
  assert.equal(t.time, '17:00');
  assert.equal(t.priority, 2);
  assert.equal(t.listWord, 'работа');
  assert.deepEqual({ ...t.kind }, { type: 'creative' });
  assert.deepEqual({ ...ctx.parseTask_('позвонить #клиент').kind }, { type: 'work', tag: 'client' }); // старый русский тег
  assert.equal(ctx.parseTask_('#хэштег в названии').title, '#хэштег в названии');
});

test('время сводки: /time 7:30', () => {
  assert.equal(ctx.parseTime_('7:30'), 450);
  assert.equal(ctx.parseTime_('07.05'), 425);
  assert.equal(ctx.parseTime_('8'), 480);
  assert.equal(ctx.parseTime_('24:00'), null);
  assert.equal(ctx.parseTime_('завтра'), null);
  assert.equal(ctx.hhmm_(450), '7:30');
  assert.equal(ctx.plusHour_('23:30'), '23:59');
});

test('esc_: разметка Telegram', () => {
  assert.equal(ctx.esc_('a < b & c > d'), 'a &lt; b &amp; c &gt; d');
});

test('утро: новости в сообщении — число, Dota 2 и три главных со ссылками; пусто — ничего', () => {
  const s = ctx.newsLines_({ count: 27, dota: { stage: 'big', title: 'Патч 7.42', url: 'https://d/1' }, top: [{ title: 'A & B', url: 'https://a' }, { title: 'C', url: 'https://c' }] });
  assert.ok(s.includes('Новости · 27'));
  assert.ok(s.includes('<a href="https://d/1">Dota 2: Патч 7.42</a>'));
  assert.ok(s.includes('<a href="https://a">A &amp; B</a>'));
  assert.equal(ctx.newsLines_(null), '');
  assert.equal(ctx.newsLines_({ count: 0 }), '');
});
