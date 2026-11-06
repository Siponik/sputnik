// Золотые данные для shell. Запуск: TZ=Europe/Moscow node tools/golden/shell.mjs
import { writeFileSync, mkdirSync } from 'node:fs';
import * as S from '../../tracker/src/lib/shell.js';

const OUT = new URL('../../app/test/golden/', import.meta.url);
mkdirSync(OUT, { recursive: true });
const write = (name, data) => writeFileSync(new URL(name, OUT), '[\n' + data.map((x) => JSON.stringify(x)).join(',\n') + '\n]\n');
const out = [];
const AT = new Date(2026, 9, 21, 9, 5).getTime();
for (const d of [AT, null, 0, '2026-10-21T06:30:00Z']) out.push({ fn: 'hm', d, out: S.hm(d) });

const SYNCS = [{}, { busy: true }, { err: 'Сбой' }, { at: AT }, { at: AT, err: 'x', busy: true }];
const CLOUDS = [{}, { state: 'busy' }, { state: 'login' }, { state: 'err' }, { state: 'err', err: 'Нет места' }, { state: 'ok' }, { state: 'ok', at: AT }, { state: 'idle' }];
const UPDS = [{}, { found: { version: '0.8.3' } }, { err: 'не вышло' }, { busy: true, found: { version: '0.8.3' }, progress: 0.426 }, { busy: true }, { checkedAt: AT }];
for (const sync of SYNCS) for (const off of [false, true]) {
  out.push({ fn: 'googleLine', sync, off, out: S.googleLine(sync, off) });
  for (const cloud of CLOUDS) out.push({ fn: 'statusDots', sync, off, cloud, upd: UPDS[(SYNCS.indexOf(sync) + CLOUDS.indexOf(cloud)) % UPDS.length], out: S.statusDots({ sync, offline: off, cloud, upd: UPDS[(SYNCS.indexOf(sync) + CLOUDS.indexOf(cloud)) % UPDS.length] }) });
}
for (const c of CLOUDS) out.push({ fn: 'cloudLine', c, out: S.cloudLine(c) });
for (const u of UPDS) out.push({ fn: 'versionLine', u, out: S.versionLine(u) });
for (const r of [null, {}, { shared: true }, { shared: true, linked: true }, { shared: true, err: 'x' }, { err: 'y' }, { at: AT, n: 5 }]) out.push({ fn: 'remindLine', r, out: S.remindLine(r) });
for (const [s, i] of [[null, null], [{ ownBot: { v: true } }, null], [{ ownBot: { v: false } }, { a: 1 }], [{}, { a: 1 }], [{ ownBot: {} }, '']]) out.push({ fn: 'ownBot', s, i, out: S.ownBot(s, i) });
for (const v of ['0.7.3-beta.2', '0.7.3', null, '0.7.3-beta.', 'x-beta.12']) {
  out.push({ fn: 'isBeta', v, out: S.isBeta(v) });
  for (const [own, pref] of [[null, {}], [{ show: true }, {}], [{}, { beta: true }], [{}, { beta: 'yes' }]]) out.push({ fn: 'betaShow', own, v, pref, out: S.betaShow(own, v, pref) });
}
const NOTES = ['- Один\n- Два\n* Три\n• Четыре', 'просто\r\nтекст\n\n  строки  \nещё\nи ещё', '', null, '✦ Звезда\nобычная\n-без пробела', '##  Что нового\n- a\n- b'];
for (const t of NOTES) for (const n of [3, 1]) out.push({ fn: 'notesOf', t, n, out: S.notesOf(t, n) });
for (const [f, p, now] of [[null, {}, AT], [{ version: '0.8.3' }, {}, AT], [{ version: '0.8.3' }, { skip: '0.8.3' }, AT], [{ version: '0.8.3' }, { skip: '0.8.2' }, AT],
  [{ version: '0.8.3' }, { remindAt: AT + 1 }, AT], [{ version: '0.8.3' }, { remindAt: AT }, AT]]) out.push({ fn: 'showUpdChip', f, p, now, out: S.showUpdChip(f, p, now) });
for (const [h, m] of [[9, 5], [19, 59], [20, 0], [23, 30], [3, 15]]) {
  const now = new Date(2026, 9, 21, h, m).getTime();
  out.push({ fn: 'eveningAt', now, out: S.eveningAt(new Date(now)) });
  for (const p of [{}, { night: true }]) out.push({ fn: 'nightNow', now, p, out: S.nightNow(p, new Date(now)) });
}

// slider: сценарий с подставными таймерами
function fakeTimers() {
  let now = 0, id = 0; const q = new Map();
  return { setTimeout: (f, ms) => { q.set(++id, { f, at: now + ms }); return id; }, clearTimeout: (i) => q.delete(i),
    tick(ms) { const end = now + ms; for (;;) { const due = [...q.entries()].filter(([, t]) => t.at <= end).sort((a, b) => a[1].at - b[1].at || a[0] - b[0])[0]; if (!due) break; q.delete(due[0]); now = due[1].at; due[1].f(); } now = end; } };
}
const SCEN = [
  [['enter'], ['tick', 100], ['tick', 60], ['leave'], ['tick', 200], ['enter'], ['tick', 400], ['leave'], ['tick', 300]],
  [['enter'], ['tick', 200], ['hold', true], ['leave'], ['tick', 500], ['hold', false], ['tick', 299], ['tick', 1]],
  [['peek'], ['tick', 1499], ['tick', 1], ['peek', 100], ['enter'], ['tick', 200], ['hide'], ['show'], ['show']],
  [['instant', true], ['enter'], ['leave'], ['enter'], ['tick', 0], ['leave'], ['instant', false]],
  [['enter'], ['leave'], ['tick', 1000], ['hold', true], ['peek'], ['tick', 5000], ['hold', false], ['tick', 300]],
];
for (const sc of SCEN) {
  const T = fakeTimers(); const log = [];
  const s = S.slider({ set: (v) => log.push(v), timers: T });
  const steps = [];
  for (const [op, a] of sc) { if (op === 'tick') T.tick(a); else s[op](a); steps.push([op, a ?? null, s.open, log.length]); }
  out.push({ fn: 'slider', sc, out: { steps, log } });
}

const spheres = [{ id: 's1', name: 'Работа' }, { id: 's2', name: 'Ёлки дом' }, { id: 's3', name: 'Пусто' }];
const listsBy = { s1: [{ id: 'a', title: 'Иконки' }, { id: 'b', title: 'Смета клиента' }], s2: [{ id: 'c', title: 'Покупки' }], s3: [] };
const noSph = [{ id: 'd', title: 'Учёба Blender' }, { id: 'e', title: 'Иконки 2' }];
for (const q of ['', '  ', 'икон', 'елки', 'работа смет', 'пусто', 'blender', 'нет', 'Смета']) out.push({ fn: 'filterSide', q, out: S.filterSide(q, spheres, (id) => listsBy[id], noSph) });

const cols = [{ id: 'in', name: 'Входящие' }, { id: 'doing', name: 'В работе', limit: 3 }, { id: 'done', name: 'Готово' }];
const mk = (n, col) => Array.from({ length: n }, (_, i) => ({ id: `${col}${i}`, title: i ? `Задача ${i}` : '', col }));
const BT = [
  [[], null], [mk(3, 'in').concat(mk(2, 'doing')), { task: { id: 'in1', title: 'Смета' }, why: 'срок сегодня' }],
  [mk(1, 'in').concat(mk(4, 'doing')), { task: { id: 'x', title: '' } }], [mk(2, 'in'), { task: { id: 'y', title: 'Точка.' }, why: 'важно.' }],
  [mk(5, 'in').concat(mk(3, 'doing')), null],
];
for (const [open, first] of BT) {
  out.push({ fn: 'boardTips', open, first, cols, out: S.boardTips({ open, cols, colOf: (t) => t.col, first }) });
  out.push({ fn: 'boardTips', open, first, cols: cols.slice(0, 2), out: S.boardTips({ open, cols: cols.slice(0, 2), colOf: (t) => t.col, first }) });
}
out.push({ fn: 'SETTINGS_TABS', out: S.SETTINGS_TABS }, { fn: 'SETTINGS_INDEX', out: S.SETTINGS_INDEX }, { fn: 'VIEW_TABS', out: S.VIEW_TABS });
for (const q of ['', 'тема', 'бот телеграм', 'ЁЛКА', 'обновления', 'дубли', 'xyz', 'по умолчанию']) out.push({ fn: 'searchSettings', q, out: S.searchSettings(q).map((r) => r.id) });
for (const [c, d] of [['look', 1], ['look', -1], ['keys', 1], ['nope', 1], ['sync', 2]]) out.push({ fn: 'stepTab', c, d, out: S.stepTab(c, d) });
for (const s of [null, [], ['board', 'today'], ['x', 'habits', 'habits', 'today'], 'строка']) out.push({ fn: 'tabOrder', s, out: S.tabOrder(s) });
const ord = ['today', 'calendar', 'board', 'habits'];
for (const [id, to] of [['board', 0], ['today', 3], ['today', 10], ['habits', -2], ['x', 1]]) out.push({ fn: 'moveTab', o: ord, id, to, out: S.moveTab(ord, id, to) });
for (const o of [ord, ['board', 'today', 'calendar', 'habits']]) out.push({ fn: 'tabsDefault', o, out: S.tabsDefault(o) });
for (const [p, l] of [['board', 'x'], ['last', 'habits'], ['last', 'nope'], ['today', 'board'], [null, null]]) out.push({ fn: 'startView', p, l, out: S.startView(p, l) });
write('shell.json', out);
console.log(out.length);
