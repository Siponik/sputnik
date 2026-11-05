// Золотые данные для dupes, search, timer, fresh. Запуск: node tools/golden/small1.mjs
import { writeFileSync, mkdirSync } from 'node:fs';
import { findDupes } from '../../tracker/src/lib/dupes.js';
import { norm, score, findTasks, findPlaces } from '../../tracker/src/lib/search.js';
import { spentMin, runningId, toggle, stopPatch, fmtMin, clock } from '../../tracker/src/lib/timer.js';
import { keepLocal } from '../../tracker/src/lib/fresh.js';

const OUT = new URL('../../app/test/golden/', import.meta.url);
mkdirSync(OUT, { recursive: true });
const write = (name, data) => writeFileSync(new URL(name, OUT), '[\n' + data.map((x) => JSON.stringify(x)).join(',\n') + '\n]\n');

// dupes
const d = [];
const lists = [{ id: 'L', title: 'Работа' }, { id: 'M', title: 'Дом' }];
const tasks = { L: [
  { id: 'b', title: 'Отчёт', due: '2026-10-21T00:00:00.000Z' }, { id: 'a', title: ' отчёт ', due: '2026-10-21T00:00:00.000Z' },
  { id: 'c', title: 'Отчёт', due: '2026-10-22T00:00:00.000Z' }, { id: 'e', title: 'Отчёт', due: '2026-10-21T00:00:00.000Z', status: 'completed' },
  { id: 'f', title: 'Отчёт', due: '2026-10-21T00:00:00.000Z', parent: 'c' }, { id: 'g', title: '  ' }, { id: 'h', title: '' },
  { id: 'i', title: 'Без срока' }, { id: 'j', title: 'без срока' }, { id: 'k', title: 'без срока', deleted: true },
], M: [{ id: 'x', title: 'Купить' }, { id: 'y', title: 'Купить' }, { id: 'z', title: 'Купить' }] };
for (const lay of [{}, { a: { t: 1 }, b: { t: 1, prio: 1 } }, { y: { a: 1, b: 2 }, z: { a: 1, b: 2 }, j: { t: 5 } }, undefined])
  d.push({ fn: 'findDupes', tasks, lists, lay: lay ?? null, out: findDupes(tasks, lists, lay) });
write('dupes.json', d);

// search
const s = [];
const NORMS = ['  Ёлка  в   лесу ', 'ЁЖ', null, '', 'Привет\tмир'];
for (const x of NORMS) s.push({ fn: 'norm', s: x, out: norm(x) });
const Q = ['отч', 'ёлка', 'елка', 'рендер сцены', 'сцен', '(', 'a.b', 'мир', '', '  ', 'ким', 'кл'];
const T = [['Отчёт за месяц', ''], ['Ёлка на НГ', 'купить игрушки'], ['Финальный рендер «сцены»', ''], ['Звонок (клиент)', 'Ким'], ['a.b тест', ''], ['axb', 'мир']];
for (const q of Q) for (const [title, notes] of T) s.push({ fn: 'score', q, title, notes, out: score(q, title, notes) });
const sl = [{ id: 'L', title: 'Работа' }, { id: 'M', title: 'Дом' }];
const st = { L: [
  { id: '1', title: 'Отчёт клиенту', status: 'completed' }, { id: '2', title: 'отчёт', notes: '' }, { id: '3', title: 'Подзадача отчёта', parent: '2' },
  { id: '4', title: 'Ёлка' }, { id: '5', title: 'Елка' }, { id: '6', title: 'Арбуз отчёт' }, { id: '7', title: 'арбуз отчёт' },
], M: [{ id: '8', title: 'Отчёт по дому', notes: 'счета' }, { id: '9', title: 'Другое', notes: 'отчёт внутри' }, { id: '10' }] };
for (const q of ['отч', 'ел', 'арбуз', 'счета', 'нет такого', 'о'])
  for (const limit of [30, 2]) s.push({ fn: 'findTasks', q, lists: sl, tasks: st, limit, out: findTasks(q, sl, st, limit).map((r) => ({ task: r.task.id, list: r.list.id, parent: r.parent?.id ?? null, s: r.s })) });
const places = [{ id: 'today', name: 'Сегодня', alias: ['today', 'tod'] }, { id: 'cal', name: 'Календарь' }, { id: 'L', name: 'Ёлки и палки' }];
for (const q of ['', 'сег', 'tod', 'ЕЛК', 'ка', 'x']) s.push({ fn: 'findPlaces', q, places, out: findPlaces(q, places).map((p) => p.id) });
write('search.json', s);

// timer
const tm = [];
const NOW = 1_800_000_000_000;
const Ls = [null, {}, { spent: 10 }, { spent: 5, timer: { start: NOW - 90_000 } }, { timer: { start: NOW + 5000 } }, { spent: 1.5, timer: { start: NOW - 13 * 3600e3 } }, { timer: { start: 0 } }];
for (const L of Ls) { tm.push({ fn: 'spentMin', L, now: NOW, out: spentMin(L, NOW) }); tm.push({ fn: 'stopPatch', L: L ?? {}, now: NOW, out: stopPatch(L ?? {}, NOW) }); }
const lt = { a: { spent: 3 }, b: { timer: { start: NOW - 60_000 } }, c: { timer: { start: NOW - 30_000 }, spent: 2 }, d: { timer: null } };
for (const lay of [lt, {}, null, { a: {} }]) tm.push({ fn: 'runningId', lay, out: runningId(lay) });
for (const id of ['a', 'b', 'c', 'zz']) tm.push({ fn: 'toggle', lay: lt, id, now: NOW, out: toggle(lt, id, NOW) });
for (const m of [0, 0.5, 1, 12.9, 59, 60, 65, 125.7, 1440]) tm.push({ fn: 'fmtMin', m, out: fmtMin(m) });
for (const ms of [-5, 0, 999, 1000, 727000, 3600000, 36125000]) tm.push({ fn: 'clock', ms, out: clock(ms) });
write('timer.json', tm);

// fresh
const f = [];
const A = (id, v) => ({ id, v });
const fetched = [A('a', 'g'), A('b', 'g'), A('c', 'g'), A('d', 'g')];
const local = [A('a', 'l'), A('b', 'l'), A('e', 'l'), A('f', 'l')];
for (const before of [['a', 'b', 'c', 'f'], [], ['a', 'b', 'c', 'd', 'e', 'f']])
  for (const touched of [[], [['a', 200], ['b', 50], ['c', 300], ['e', 500]]])
    f.push({ fn: 'keepLocal', fetched, local, before, touched, t0: 100, out: keepLocal(fetched, local, new Set(before), new Map(touched), 100) });
write('fresh.json', f);
console.log(d.length, s.length, tm.length, f.length);
