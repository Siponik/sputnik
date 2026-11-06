// Золотые данные для reminders. «Сейчас» подменено: 2026-10-21 14:00 (среда). Запуск: TZ=Europe/Moscow node tools/golden/reminders.mjs
import { writeFileSync, mkdirSync } from 'node:fs';

const NOW = new Date(2026, 9, 21, 14, 0).getTime();
const RealDate = Date;
class FakeDate extends RealDate {
  constructor(...a) { if (a.length) super(...a); else super(NOW); }
  static now() { return NOW; }
}
globalThis.Date = FakeDate;
const R = await import('../../tracker/src/lib/reminders.js');

const OUT = new URL('../../app/test/golden/', import.meta.url);
mkdirSync(OUT, { recursive: true });
const write = (name, data) => writeFileSync(new URL(name, OUT), '[\n' + data.map((x) => JSON.stringify(x)).join(',\n') + '\n]\n');
const out = [];
const iso = (d) => (d ? d.toISOString() : null);

const SET = [null, {}, { remind: { min: 15 } }, { remind: { min: null } }, { remind: { task: [5, 60], event: [] } }, { remind: { birthday: [0] } }];
for (const s of SET) for (const k of ['task', 'event', 'birthday']) out.push({ fn: 'defaultMins', s, k, out: R.defaultMins(s, k) });
for (const s of SET) out.push({ fn: 'defaultRule', s, out: R.defaultRule(s) });
for (const m of [[], [60], [60, 15, 60], [0, 1440, 10080]]) out.push({ fn: 'minsToRule', m, out: R.minsToRule(m) });
for (const r of [null, { kind: 'lead', min: 5 }, [{ kind: 'lead', min: 5 }]]) out.push({ fn: 'rulesOf', r, out: R.rulesOf(r) });
for (const k of ['task', 'event', 'birthday']) for (const m of [0, 5, 60, 1440, 4320, 43200, 7]) out.push({ fn: 'leadName', m, k, out: R.leadName(m, k) });
for (const k of ['task', 'birthday']) for (const m of [[60, 1440], [0], [], [4320, 0, 7]]) out.push({ fn: 'leadsText', m, k, out: R.leadsText(m, k) });

const TASKS = [{ due: '2026-10-21T00:00:00.000Z' }, { due: '2026-11-01T00:00:00.000Z' }, {}, { due: '2027-01-01T00:00:00.000Z' }];
const RULES = [{ kind: 'lead', min: 60 }, { kind: 'lead' }, { kind: 'lead', min: 1440 }, { kind: 'at', at: '2026-10-22T09:30' }, { kind: 'at', at: 'мусор' }, { kind: 'at' },
  { kind: 'before', days: 1, time: '09:00' }, { kind: 'before' }, { kind: 'x' }, null];
const SLOTS = [null, { s: '18:30', e: '19:00' }, { s: '00:10' }, {}];
for (const dt of ['10:00', '09:00', 'off', 'x']) {
  R.setDefaultTime(dt);
  for (const t of TASKS) for (const r of RULES) for (const sl of SLOTS) {
    out.push({ fn: 'fireAt', dt, t, r, sl, out: iso(R.fireAt(r, t, sl)) });
  }
  for (const t of TASKS) for (const sl of SLOTS) {
    out.push({ fn: 'remindLabel', dt, t, r: RULES.slice(0, 4), sl, out: R.remindLabel(RULES.slice(0, 4), t, sl) });
    out.push({ fn: 'remindLabel', dt, t, r: RULES[6], sl, out: R.remindLabel(RULES[6], t, sl) });
  }
}
R.setDefaultTime('10:00');
for (let m = 1; m <= 12; m++) {
  const t = { due: `2026-${String(m).padStart(2, '0')}-0${(m % 9) + 1}T00:00:00.000Z` };
  out.push({ fn: 'remindLabel', dt: '10:00', t, r: { kind: 'lead', min: 0 }, sl: { s: '07:05' }, out: R.remindLabel({ kind: 'lead', min: 0 }, t, { s: '07:05' }) });
}

const lists = [{ id: 'L', title: 'Работа' }, { id: 'M', title: 'Дом' }];
const tbl = { L: [
  { id: 'a', title: 'Отчёт', notes: 'первая строка\nвторая', due: '2026-10-22T00:00:00.000Z' },
  { id: 'b', title: '', due: '2026-10-21T00:00:00.000Z' }, { id: 'c', title: 'Сделано', due: '2026-10-22T00:00:00.000Z', status: 'completed' },
  { id: 'd', title: 'Удалено', due: '2026-10-22T00:00:00.000Z', deleted: true }, { id: 'e', title: 'Старое', due: '2026-10-10T00:00:00.000Z' },
], M: [{ id: 'g', title: 'Пол', notes: 'x'.repeat(300), due: '2026-10-21T00:00:00.000Z' }, { id: 'h', title: 'Точно' }] };
const lay = {
  a: { remind: [{ kind: 'lead', min: 60 }, { kind: 'lead', min: 1440 }], slot: { s: '12:00' }, given: { name: 'Оля', at: '2026-10-21T08:00:00.000Z' } },
  b: { remind: { kind: 'lead', min: 0 }, slot: { s: '13:59' }, given: { at: '2026-10-19T08:00:00.000Z' } },
  c: { remind: { kind: 'lead', min: 60 }, given: { name: 'Аня', at: '2026-10-21T08:00:00.000Z' } },
  e: { remind: { kind: 'before', days: 0, time: '09:00' } },
  g: { remind: { kind: 'before', days: 0, time: '13:00' }, given: { name: 'Ким', at: '2026-10-21T10:59:00.000Z' } },
  h: { remind: { kind: 'at', at: '2026-10-21T15:00' }, given: { at: 'мусор' } },
};
const events = [
  { id: 'e1', summary: 'Встреча', description: 'Зум\nссылка', start: { dateTime: '2026-10-22T10:00:00+03:00' }, extendedProperties: { private: { sputnikRemind: '15,60' } } },
  { id: 'e2', summary: '🎂 Маша', start: { date: '2026-10-25' }, extendedProperties: { private: { sputnikRemind: '0,1440', sputnik: 'birthday' } } },
  { id: 'e3', summary: '', start: { dateTime: '2026-10-21T14:30:00+03:00' }, extendedProperties: { private: { sputnikRemind: '60,15,abc,' } } },
  { id: 'e4', summary: 'Без', start: { date: '2026-10-21' } },
];
const cheers = [{ habit: { id: 'h1' }, key: '7', text: 'Вода: 7 дней подряд', at: '2026-10-21T11:00:00.000Z' }];
out.push({ fn: 'collect', lists, tasks: tbl, lay, hl: null, cheers, events, out: R.collect(lists, tbl, lay, null, cheers, events) });
out.push({ fn: 'collect', lists, tasks: tbl, lay, hl: { id: 'HL', title: 'Привычки' }, cheers, events: [], out: R.collect(lists, tbl, lay, { id: 'HL', title: 'Привычки' }, cheers, []) });
out.push({ fn: 'collect', lists, tasks: tbl, lay: null, hl: null, cheers: [], events: [], out: R.collect(lists, tbl, null, null, [], []) });
R.setDefaultTime('off');
out.push({ fn: 'collectOff', lists, tasks: tbl, lay, hl: null, cheers: [], events, out: R.collect(lists, tbl, lay, null, [], events) });
R.setDefaultTime('10:00');
for (const now of [NOW, NOW + 864e5 * 3]) out.push({ fn: 'assignedItems', lists, tasks: tbl, lay, now, out: R.assignedItems(lists, tbl, lay, now) });

const habits = [
  { id: 'h2', name: 'Бег', createdAt: '2026-08-10T10:00:00Z', days: [0, 2, 4], time: '07:30', end: '08:15', remind: { win: true } },
  { id: 'h3', name: 'Чтение', createdAt: '2026-10-22T10:00:00Z', time: '21:00', goal: { n: 20, unit: 'страниц' }, remind: { win: true } },
  { id: 'h4', name: 'Зал', perWeek: 2, time: '19:00', goal: { n: 2 } },
  { id: 'h5', name: 'Медитация', win: { s: '13:00', e: '15:20' }, part: 'day', remind: { win: true } },
  { id: 'h6', name: 'Тихо', time: '09:00', remind: { tg: false, win: true } },
  { id: 'h7', name: 'Вечер', part: 'evening', remind: { win: true } },
  { id: 'h8', name: 'День', part: 'day', remind: { win: true } },
  { id: 'h9', name: 'Без времени' },
];
const log = { 'h2|2026-10-21': { done: true }, 'h4|2026-10-19': { done: true }, 'h4|2026-10-20': { done: true }, 'h8|2026-10-21': { done: true } };
for (const now of [new Date(NOW), new Date(2026, 9, 21, 7, 0), new Date(2026, 9, 21, 19, 30), new Date(2026, 9, 25, 23, 59)]) {
  out.push({ fn: 'habitItems', habits, log, now: now.getTime(), out: R.habitItems(habits, log, now) });
  for (const sent of [[], ['h5|' + `2026-10-${now.getDate()}`]]) out.push({ fn: 'habitWinDue', habits, log, sent, now: now.getTime(), out: R.habitWinDue(habits, log, sent, now).map((h) => h.id) });
}
write('reminders.json', out);
console.log(out.length);
