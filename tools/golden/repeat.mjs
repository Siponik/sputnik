// Золотые данные для rust/core/tests (repeat.json). Запуск: node tools/golden/repeat.mjs
import { writeFileSync, mkdirSync } from 'node:fs';
import { nextDue, dueRepeats, repeatLabel, takeRepeat, existingNext, CARRY } from '../../tracker/src/lib/repeat.js';

const OUT = new URL('../../rust/core/tests/golden/', import.meta.url);
mkdirSync(OUT, { recursive: true });
const write = (name, data) => writeFileSync(new URL(name, OUT), '[\n' + data.map((x) => JSON.stringify(x)).join(',\n') + '\n]\n');

const out = [];
const RULES = [{ every: 'day' }, { every: 'weekdays' }, { every: 'week' }, { every: 'month' }, { every: 'year' }, { every: 'hour' }, null, {}];
const DUES = ['', '2026-10-21', '2026-10-23', '2026-10-24', '2026-10-31', '2026-01-31', '2027-01-31', '2028-02-29', '2026-12-31', '2026-10-05', '2026-10-01', '2024-02-29'];
const TODAYS = ['2026-10-21', '2026-12-01', '2027-03-01', '2026-10-31', '2028-03-01'];
for (const rule of RULES) for (const due of DUES) for (const today of TODAYS) out.push({ fn: 'nextDue', rule, due, today, out: nextDue(rule, due, today) });
for (const rule of RULES) out.push({ fn: 'repeatLabel', rule, out: repeatLabel(rule) });
const PHR = ['полить цветы каждую неделю', 'отчёт по будням 10:00', 'Ежедневно зарядка', 'каждый будний день стендап', 'просто задача',
  'КАЖДЫЙ ГОД налог', 'оплата ежемесячно', 'каждый  день', 'каждыйдень', 'а каждый месяц б каждый год', 'еженедельно', '', 'по будням'];
for (const text of PHR) out.push({ fn: 'takeRepeat', text, out: takeRepeat(text) });
const lists = [{ id: 'L' }, { id: 'M' }];
const tasks = { L: [
  { id: 'a', status: 'completed' }, { id: 'b', status: 'needsAction' }, { id: 'c', status: 'completed' },
  { id: 'd', status: 'completed', parent: 'a' }, { id: 'e', status: 'completed' }, { id: 'f', status: 'completed', deleted: true },
], M: [{ id: 'g', status: 'completed' }] };
const lay = { a: { repeat: { every: 'day' } }, b: { repeat: { every: 'day' } }, c: { repeat: { every: 'day' }, repeatNext: 'x' }, d: { repeat: { every: 'day' } }, f: { repeat: { every: 'week' } }, g: { repeat: { every: 'year' } } };
out.push({ fn: 'dueRepeats', lists, tasks, lay, out: dueRepeats(lists, tasks, lay) });
out.push({ fn: 'dueRepeats', lists, tasks, lay: null, out: dueRepeats(lists, tasks, null) });
const L = [{ id: 'a', title: 'Полить', due: '2026-10-21T00:00:00.000Z' }, { id: 'b', title: ' Полить ', due: '2026-10-28T00:00:00.000Z' },
  { id: 'c', title: 'Полить', due: '2026-10-28T00:00:00.000Z', parent: 'a' }, { id: 'd', title: 'Другое', due: '2026-10-28T00:00:00.000Z' }, { id: 'e', title: 'Полить' }];
for (const day of ['2026-10-28', '2026-10-21', '']) for (const t of [L[0], { id: 'z', title: 'Другое' }, { id: 'y' }]) out.push({ fn: 'existingNext', list: L, task: t, day, out: existingNext(L, t, day) });
out.push({ fn: 'CARRY', out: CARRY });
write('repeat.json', out);
console.log(out.length);
