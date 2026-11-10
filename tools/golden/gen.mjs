// Золотые данные для порта на Rust: прогоняет настоящие функции трекера (tracker/src/lib/*.js) на наборе входов
// и пишет входы и ответы в rust/core/tests/golden/*.json. Rust-тесты (rust/core/tests/*.rs) читают эти файлы и
// требуют те же ответы — так порт не расходится со старым кодом.
// Запуск: node tools/golden/gen.mjs   (из корня репозитория). Файлы коммитим.
import { writeFileSync, mkdirSync } from 'node:fs';
import { parseWhen, whenText } from '../../tracker/src/lib/when.js';
import { merge } from '../../tracker/src/lib/layer.js';

const OUT = new URL('../../rust/core/tests/golden/', import.meta.url);
mkdirSync(OUT, { recursive: true });
// Один случай — одна строка: файл остаётся небольшим и читаемым в diff.
const write = (name, data) => writeFileSync(new URL(name, OUT), Array.isArray(data) ? '[\n' + data.map((x) => JSON.stringify(x)).join(',\n') + '\n]\n' : JSON.stringify(data) + '\n');

// ---------- when ----------
const TODAYS = [[2026, 9, 20], [2026, 11, 30], [2027, 0, 31]]; // вторник; перед Новым годом; конец января
const PHRASES = [
  'позвонить маме завтра 17:00', 'аня 12 марта', 'отпуск 3 мая', 'скетч в пятницу 17.30', 'созвон послезавтра в 15',
  'сдать рендер через 3 дня', 'отпуск через 2 недели', 'ревью 25 окт', 'новый год 1 января', 'налог 3.11',
  'встреча 5.01.2027 10:00', 'спортзал во вторник', 'митинг пн 9:15', 'сегодня весь день 10:00 конференция',
  'просто задача', 'купить 2 молока', 'через неделю', 'через день', 'в среду', 'суббота', 'в воскресенье 8:00',
  'отчёт 28.02', 'день рождения 31 декабря', 'позвонить 1.5', 'завтра в 9', 'в 18 выпить чаю', 'ужин в 19.30',
  'встреча 15:45, потом кино', 'через 10 дней', 'через 1 неделю', 'ЗАВТРА', 'Сегодня', 'в Пятницу', '  много   пробелов  завтра ',
  '', 'весь день завтра', '12 января 14:00', '5 июня', '30.12', '1.1.26', 'в 25 часов', 'встреча в 7',
];
const when = [];
for (const [y, m, d] of TODAYS) {
  const today = new Date(y, m, d, 9, 0);
  for (const text of PHRASES) {
    const r = parseWhen(text, today);
    when.push({ today: [y, m + 1, d], text, out: { day: r.day, time: r.time, allDay: r.allDay, rest: r.rest } });
  }
}
const texts = [];
for (const [y, m, d] of TODAYS) {
  const today = new Date(y, m, d, 9, 0);
  for (const day of ['2026-10-19', '2026-10-20', '2026-10-21', '2026-10-22', '2026-10-25', '2027-01-05', '2026-12-31', '2027-02-01', '']) {
    for (const slot of [null, { s: '15:00', e: '16:00' }]) {
      texts.push({ today: [y, m + 1, d], day, slot, out: whenText(day, slot, today) });
    }
  }
}
write('when_parse.json', when);
write('when_text.json', texts);

// ---------- layer.merge ----------
const rng = (seed) => () => { seed |= 0; seed = (seed + 0x6D2B79F5) | 0; let t = Math.imul(seed ^ (seed >>> 15), 1 | seed); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
const R = rng(20261105);
const pick = (a) => a[Math.floor(R() * a.length)];
const SECT = ['tasks', 'lists', 'habits', 'log', 'cals', 'settings', 'templates', 'templatesEdit', 'spheres', 'future'];
const rec = () => {
  const r = R();
  if (r < 0.1) return { gone: true, t: pick([1, 2, 3, 5, 8]) };
  const o = {};
  if (R() < 0.8) o.t = pick([0, 1, 2, 3, 5, 8, 13]);
  if (R() < 0.7) o.status = pick(['inbox', 'doing', 'done']);
  if (R() < 0.5) o.priority = pick([1, 2, 3]);
  if (R() < 0.4) o.name = pick(['а', 'б', 'в']);
  if (R() < 0.2) o.slot = { s: pick(['09:00', '10:00']), e: '11:00' };
  if (R() < 0.15) o.tags = pick([['a'], ['a', 'b'], []]);
  return o;
};
const section = () => {
  const o = {};
  for (const k of ['a', 'b', 'c', 'd']) if (R() < 0.6) o[k] = rec();
  return o;
};
const layer = () => {
  if (R() < 0.05) return null;
  const l = {};
  if (R() < 0.8) l.version = 1;
  for (const s of SECT) if (R() < 0.5) l[s] = section();
  return l;
};
const cases = [];
cases.push({ local: { tasks: { a: { status: 'doing', t: 5 } } }, remote: null });
cases.push({ local: null, remote: { tasks: { a: { status: 'doing', t: 5 } }, spheres: { s: { name: 'Работа', t: 3 } } } });
cases.push({ local: { tasks: { a: { status: 'doing', t: 10 }, b: { status: 'inbox', t: 1 } } }, remote: { tasks: { a: { status: 'review', t: 5 }, b: { status: 'done', t: 7 } } } });
cases.push({ local: { tasks: { a: { t: 2, status: 'x' } } }, remote: { tasks: { a: { status: 'x', t: 2 } } } });
for (let i = 0; i < 150; i++) cases.push({ local: layer(), remote: layer() });
write('layer_merge.json', cases.map((c) => ({ ...c, out: merge(c.local, c.remote) })));
console.log('golden: when', when.length + texts.length, 'layer', cases.length);
