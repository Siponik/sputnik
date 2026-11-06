// Золотые данные для create. Запуск: TZ=Europe/Moscow node tools/golden/create.mjs
import { writeFileSync, mkdirSync } from 'node:fs';
import * as C from '../../tracker/src/lib/create.js';
import { parseLine } from '../../tracker/src/lib/route.js';

const OUT = new URL('../../app/test/golden/', import.meta.url);
mkdirSync(OUT, { recursive: true });
const write = (name, data) => writeFileSync(new URL(name, OUT), '[\n' + data.map((x) => JSON.stringify(x)).join(',\n') + '\n]\n');
const out = [];
const today = '2026-10-21';
const DAYS = ['2026-10-21', '2026-10-22', '2026-10-24', '2026-10-27', '2026-10-28', '2026-11-30', '2026-10-01', '2026-12-31', '2027-01-01', '2028-02-29', '2026-03-12'];
for (const d of DAYS) {
  for (const n of [1, -1, 10, -365]) out.push({ fn: 'plus', d, n, out: C.plus(d, n) });
  out.push({ fn: 'shortDay', d, out: C.shortDay(d) }, { fn: 'longDay', d, out: C.longDay(d) }, { fn: 'eventDay', d, out: C.eventDay(d, today) },
    { fn: 'dayMonth', d, out: C.dayMonth(d) }, { fn: 'weekday', d, out: C.weekday(d) }, { fn: 'whenChip', d, out: C.whenChip(d, today) },
    { fn: 'nextBirthday', d, out: C.nextBirthday(d, today) }, { fn: 'daysTill', d, out: C.daysTill(d, today) });
  for (const sl of [null, { s: '15:00' }, {}]) out.push({ fn: 'dueShort', d, sl, out: C.dueShort(d, today, sl) });
  for (const y of [1990, '1985', 0, null, 1800, 2026, 2030, 'abc']) out.push({ fn: 'ageAt', y, d, out: C.ageAt(y, d, today) });
}
out.push({ fn: 'dueShort', d: '', sl: null, out: C.dueShort('', today) }, { fn: 'whenChip', d: '', out: C.whenChip('', today) });
for (const s of ['00:00', '23:59', '9:5']) out.push({ fn: 'toMin', s, out: C.toMin(s) });
for (const n of [0, 61, 1439, 1500]) out.push({ fn: 'fromMin', n, out: C.fromMin(n) });
for (const [s, n] of [['10:00', 30], ['23:30', 60], ['09:15', -15]]) out.push({ fn: 'addMin', s, n, out: C.addMin(s, n) });
for (const n of ['Андрей', 'Анна Петровна', 'Аня', 'Иван', 'Игорь', 'Мария', 'Маша', '', null, '  Оля ', 'Любовь', 'Лео', 'ИВАН', 'Ия', 'Max']) out.push({ fn: 'dative', n, out: C.dative(n) });
for (const n of [0, 1, 2, 5, 11, 12, 21, 22, 25, 101, 111, 112, 121]) out.push({ fn: 'years', n, out: C.years(n) });
for (const d of ['2026-10-20', '2026-10-10', '2026-09-30']) out.push({ fn: 'daysTill', d, out: C.daysTill(d, today) });

const events = [
  { summary: 'Утро', start: { dateTime: '2026-10-21T08:00:00+03:00' }, end: { dateTime: '2026-10-21T09:30:00+03:00' } },
  { summary: '', start: { dateTime: '2026-10-21T14:00:00+03:00' }, end: { dateTime: '2026-10-21T15:00:00+03:00' } },
  { summary: 'Ночь', start: { dateTime: '2026-10-20T22:00:00+03:00' }, end: { dateTime: '2026-10-21T01:00:00+03:00' } },
  { summary: 'Долго', start: { dateTime: '2026-10-21T20:00:00+03:00' }, end: { dateTime: '2026-10-22T02:00:00+03:00' } },
  { summary: 'Весь день', start: { date: '2026-10-21' }, end: { date: '2026-10-22' } },
  { summary: 'Другой', start: { dateTime: '2026-10-23T10:00:00+03:00' }, end: { dateTime: '2026-10-23T11:00:00+03:00' } },
  { summary: 'Коротко', start: { dateTime: '2026-10-21T16:00:00+03:00' }, end: { dateTime: '2026-10-21T16:05:00+03:00' } },
];
for (const sl of [null, { s: '14:30', e: '15:30' }, { s: '10:00' }, { s: '00:30' }, { s: '23:00', e: '23:45' }, { s: '15:00', e: '16:00' }, { s: '16:05', e: '17:00' }, { s: '21:00' }, {}])
  for (const day of ['2026-10-21', '2026-10-22']) {
    out.push({ fn: 'dayChunk', events, day, sl, out: C.dayChunk(events, day, sl, 'Моё') });
    out.push({ fn: 'dayChunk3', events, day, sl, out: C.dayChunk(events, day, sl, '', 3) });
    out.push({ fn: 'freeCheck', events, day, sl, out: C.freeCheck(events, day, sl) });
  }
out.push({ fn: 'freeCheck', events: null, day: today, sl: { s: '10:00' }, out: C.freeCheck(null, today, { s: '10:00' }) });

const lt = [{ id: 'a', updated: '2026-10-01' }, { id: 'b', updated: '2026-10-05' }, { id: 'c', status: 'completed' }, { id: 'd', parent: 'a' }, { id: 'e' },
  { id: 's1', parent: 'a', title: 'Блокаут', position: '002' }, { id: 's2', parent: 'a', title: 'Лоуполи', position: '001' }, { id: 's3', parent: 'b', title: 'Без этапа' },
  { id: 's4', parent: 'e', title: 'Скульпт', position: '1' }];
const lay = { a: { status: 'doing', ord: 5 }, b: { status: 'todo', ord: -3 }, e: {}, s1: { stage: 'block' }, s2: { stage: 'low' }, s4: { stage: 'sculpt' } };
for (const [col, first] of [['todo', 'todo'], ['doing', 'todo'], ['x', 'x'], ['todo', 'x']]) {
  out.push({ fn: 'colCount', lt, lay, col, first, out: C.colCount(lt, lay, col, first) });
  out.push({ fn: 'topOrd', lt, lay, col, first, out: C.topOrd(lt, lay, col, first) });
}
out.push({ fn: 'stageChecklist', lt, lay, out: C.stageChecklist(lt, lay) });
out.push({ fn: 'stageChecklist', lt: lt.slice(0, 5), lay, out: C.stageChecklist(lt.slice(0, 5), lay) });
for (const t of ['Сундук с золотом', '  ', '', null, 'ёж', 'a', '3D модель', '!!!']) out.push({ fn: 'initials', t, out: C.initials(t) });

const SK = ['Бег 3 раза в неделю', 'Встреча по проекту', 'День рождения мамы 5 мая', 'Обсудить смету с клиентом 14:00', 'Пить воду 8 стаканов каждый день',
  'Созвон с Олей завтра в 15:00', 'встречать гостей', 'др Ани 12 марта', 'драйвер обновить', 'зарядка по будням', 'к врачу в пятницу', 'купить лампочки 17:00',
  'медитация', 'отчёт', 'подарок на день рождения', 'позвонить маме', 'с утра отправить смету 10:00', 'Созвон с Олей завтра 15:00', 'встреча с Аней', 'планёрка каждый день',
  'полить цветы ежедневно', 'обед с командой', 'встреча со Светой 12:00', 'уборка каждую неделю', 'ДР Пети завтра', 'СОЗВОН', 'созвоны', ''];
for (const s of SK) {
  const p = parseLine(s, { today: new Date(2026, 9, 21) });
  const pp = { day: p.day, time: p.time, repeat: p.repeat };
  out.push({ fn: 'suggestKind', s, p: pp, out: C.suggestKind(s, pp) });
  for (const k of ['task', 'event', 'habit', 'birthday']) out.push({ fn: 'kindHint', s, p: pp, k, out: C.kindHint(s, pp, k) });
}
out.push({ fn: 'suggestKind', s: null, p: {}, out: C.suggestKind(null) });
for (const r of [null, {}, { every: 'day' }, { every: 'weekdays' }, { every: 'week' }, { every: 'month' }, { every: 'year' }, { every: 'x' }]) out.push({ fn: 'recurrenceOf', r, out: C.recurrenceOf(r) });

const PH = ['', 'Пить воду 8 стаканов каждый день', 'Пить воду 8 стаканов', 'английский 3 раза в неделю вечером', 'зарядка каждое утро', 'чтение 20 страниц по будням',
  'бег 5 км по выходным', 'отжимания 30 раз ежедневно', '1 стакан', 'медитация 10 мин перед сном', 'зал 2 раза в неделю днём', 'шаги 10000 шагов', 'учить 50 слов',
  'гулять после обеда', 'прочитать 2 главы по вечерам', 'зарядка 9 раз в неделю', 'приседания 100000 приседаний', 'Йога утром каждый день', 'КАЖДЫЙ ВЕЧЕР ДНЕВНИК', null];
for (const s of PH) for (const off of [{}, { freq: true }, { part: true, goal: true }]) out.push({ fn: 'parseHabit', s, off, out: C.parseHabit(s, off) });

out.push({ fn: 'GIFT_DAYS', out: C.GIFT_DAYS });
for (const [b, d] of [['2026-10-25', 3], ['2026-01-02', 7]]) out.push({ fn: 'giftDate', b, d, out: C.giftDate(b, d) });
for (const s of ['🎂 Аня', '  Иван ', '', null, '🎉🎂 Маша Петрова', '123 Оля']) out.push({ fn: 'bdayName', s, out: C.bdayName(s) });
const bd = (id, date, gift, extra = {}) => ({ id, summary: '🎂 Аня', start: { date }, extendedProperties: { private: { sputnik: 'birthday', sputnikGift: gift, ...extra } } });
const gev = [bd('e1', '2026-10-25', '7'), bd('e2', '2026-10-21', '3', { sputnikGiftList: 'L1' }), { ...bd('e3', '2026-11-30', '30'), recurringEventId: 'r3' },
  bd('e4', '2026-10-20', '7'), bd('e5', '2026-10-24', '0'), bd('e6', '2026-10-24', 'x'), { ...bd('e7', '2026-10-24', '7'), summary: '🎂' },
  { id: 'e8', start: { date: '2026-10-24' }, extendedProperties: { private: { sputnikGift: '7' } } }, { ...bd('e9', '2026-10-24', '7'), start: {} },
  { ...bd('e10', '2026-10-28', '7'), summary: '🎂 Иван' }, { ...bd('e11', '2026-10-29', '7'), summary: '🎂 Анна Петровна' }];
for (const t of ['2026-10-21', '2026-10-18', '2026-11-01']) out.push({ fn: 'giftsDue', ev: gev, t, out: C.giftsDue(gev, t) });
out.push({ fn: 'giftsDue', ev: null, t: today, out: C.giftsDue(null, today) });
write('create.json', out);
console.log(out.length);
