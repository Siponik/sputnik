// Золотые данные для accent, authcheck, dropdown, meta, spheres. Запуск: node tools/golden/small2.mjs
import { writeFileSync, mkdirSync } from 'node:fs';
import * as A from '../../tracker/src/lib/accent.js';
import * as C from '../../tracker/src/lib/authcheck.js';
import * as D from '../../tracker/src/lib/dropdown.js';
import * as M from '../../tracker/src/lib/meta.js';
import * as S from '../../tracker/src/lib/spheres.js';

const OUT = new URL('../../rust/core/tests/golden/', import.meta.url);
mkdirSync(OUT, { recursive: true });
const write = (name, data) => writeFileSync(new URL(name, OUT), '[\n' + data.map((x) => JSON.stringify(x)).join(',\n') + '\n]\n');

const a = [];
const COLS = ['#D9774F', '#000000', '#FFFFFF', '#123456', '#FF0000', '#7F7F7F', '#1C1B19', '#A8B85A', '#0000FF'];
for (const x of COLS) { a.push({ fn: 'luminance', x, out: A.luminance(x) }); for (const y of COLS.slice(0, 4)) { a.push({ fn: 'contrast', x, y, out: A.contrast(x, y) }); a.push({ fn: 'mix', x, y, t: 0.13, out: A.mix(x, y, 0.13) }); } }
for (const x of COLS) for (const bg of ['#1C1B19', '#FFFFFF']) for (const min of [3, 4.5, 7]) a.push({ fn: 'fit', x, bg, min, out: A.fit(x, bg, min) });
const VS = ['clay', 'mint', 'sky', '#123456', '123456', '#abcdef', ' #FfAa00 ', '#12345', 'zzz', '', null, undefined, 5];
for (const v of VS) { a.push({ fn: 'accentOf', v: v ?? null, out: A.accentOf(v) }); a.push({ fn: 'accentCss', v: v ?? null, out: A.accentCss(v) }); }
for (const x of COLS) for (const th of ['dark', 'light']) a.push({ fn: 'vars', x, th, out: A.vars(x, th) });
a.push({ fn: 'ACCENTS', out: A.ACCENTS });
write('accent.json', a);

const c = [];
const SEC = ['', '   ', 'не json', '[1]', 'null', '5', '{"web":{"client_id":"x"}}', '{"type":"service_account"}', '{"installed":5}', '{"other":1}',
  '{"installed":{"client_id":"x.apps.googleusercontent.com"}}', '﻿{"installed":{"client_id":" x.apps.googleusercontent.com "}}',
  '{"installed":{"client_id":"a b.apps.googleusercontent.com"}}', '{"installed":{"client_id":""}}', '{"installed":{"client_id":"abc"}}',
  '{"installed":{"client_id":"x.apps.googleusercontent.com"},"web":{}}'];
for (const t of SEC) c.push({ fn: 'checkSecretText', t, size: null, out: C.checkSecretText(t) });
c.push({ fn: 'checkSecretText', t: '{}', size: 70000, out: C.checkSecretText('{}', 70000) });
c.push({ fn: 'checkSecretText', t: null, size: null, out: C.checkSecretText(null) });
const ERR = ['', null, 'Error: Вход прерван', 'Error: Войдите в Google заново: Google не дал доступ — Задачи, Календарь.', 'Google не дал Спутнику все доступы',
  'insufficient authentication scopes', 'Error: access_denied', 'invalid_client', 'HTTP 401', 'Вход не завершён за 5 минут, попробуйте ещё раз', 'Нет связи'];
for (const e of ERR) { c.push({ fn: 'loginHint', e, out: C.loginHint(e) }); c.push({ fn: 'isStopped', e, out: C.isStopped(e) }); c.push({ fn: 'isScopeLack', e, out: C.isScopeLack(e) }); }
for (const cal of [null, {}, { primary: true }, { id: 'ru.russian#holiday@group.v.calendar.google.com' }, { id: 'x@group' }]) c.push({ fn: 'calDefaultOn', cal, out: C.calDefaultOn(cal) });
write('authcheck.json', c);

const d = [];
const OPTS = [{ id: 'a', label: 'Ёлка' }, { id: 'b', label: 'Работа над сценой', short: 'Работа' }, { id: 'c', label: 'В работе', disabled: true },
  { id: 'd', label: 'Готово' }, { id: 'e', label: 'ещё работа' }, { id: 'f', label: 'Архив', disabled: true }];
for (const q of ['', ' ', 'ел', 'РАБ', 'раб сц', 'нет', 'е']) { d.push({ fn: 'filterOpts', q, out: D.filterOpts(OPTS, q).map((o) => o.id) }); for (const o of OPTS) d.push({ fn: 'marks', label: o.label, q, out: D.marks(o.label, q) }); }
d.push({ fn: 'marks', label: null, q: 'x', out: D.marks(null, 'x') });
for (const key of ['ArrowDown', 'ArrowUp', 'Home', 'End']) for (const cur of [-1, 0, 1, 3, 4, 5]) d.push({ fn: 'moveActive', opts: OPTS, cur, key, out: D.moveActive(OPTS, cur, key) });
d.push({ fn: 'moveActive', opts: [{ id: 'x', disabled: true }], cur: 0, key: 'ArrowDown', out: D.moveActive([{ id: 'x', disabled: true }], 0, 'ArrowDown') });
d.push({ fn: 'moveActive', opts: [], cur: -1, key: 'Home', out: D.moveActive([], -1, 'Home') });
for (const ch of ['р', 'Р', 'е', 'ё', 'в', 'x', ' ', 'г']) for (const cur of [-1, 0, 1, 4]) d.push({ fn: 'jumpTo', opts: OPTS, cur, ch, out: D.jumpTo(OPTS, cur, ch) });
for (const [values, id] of [[[], 'b'], [['d'], 'a'], [['a', 'd'], 'a'], [null, 'z'], [['e', 'a'], 'b']]) d.push({ fn: 'toggleIn', values, id, opts: OPTS, out: D.toggleIn(values, id, OPTS) });
for (const [value, multi] of [['b', false], ['zz', false], [['a'], true], [['a', 'b'], true], [['a', 'b', 'd', 'e'], true], [[], true], [null, true]]) d.push({ fn: 'buttonText', value, multi, out: D.buttonText(OPTS, value, multi) });
const view = { w: 1200, h: 800 };
for (const btn of [{ left: 100, top: 100, right: 300, bottom: 130, width: 200 }, { left: 1100, top: 700, right: 1180, bottom: 730, width: 80 }, { left: 0, top: 400, right: 50, bottom: 430, width: 50 }])
  for (const [h, w] of [[200, 150], [600, 400], [100, 2000]]) for (const opt of [undefined, { gap: 2, max: 500, pad: 4 }])
    d.push({ fn: 'placeMenu', btn, h, w, view, opt: opt ?? null, out: D.placeMenu(btn, h, w, view, opt) });
write('dropdown.json', d);

const m = [];
for (const id of ['work', 'creative', 'zzz', null]) m.push({ fn: 'typeLabel', id, out: M.typeLabel(id) });
for (const n of [1, 2, 3, 4, 0, null]) { m.push({ fn: 'priorityOf', n, out: M.priorityOf(n) }); m.push({ fn: 'priorityRank', n, out: M.priorityRank(n) }); }
const today = '2026-10-21';
const items = [{ task: { id: 'a', due: '2026-10-25T00:00:00.000Z', position: '002' } }, { task: { id: 'b', position: '001' } }, { task: { id: 'c', due: '2026-10-19T00:00:00.000Z', position: '005' } },
  { task: { id: 'd', due: '2026-10-22T00:00:00.000Z', position: '003' } }, { task: { id: 'e', due: '2026-10-22T00:00:00.000Z', position: '000' } }];
for (const lay of [{}, { a: { priority: 1 } }, { b: { priority: 1 }, c: { priority: 3 } }, { d: { priority: 2 }, e: { priority: 3 } }, null])
  m.push({ fn: 'pickNext', items, lay, today, out: M.pickNext(items, lay, today)?.task.id ?? null });
m.push({ fn: 'pickNext', items: [], lay: {}, today, out: M.pickNext([], {}, today) });
const human = (due) => 'пт, ' + due.slice(8, 10) + '.' + due.slice(5, 7);
for (const t of items.map((x) => x.task)) for (const lay of [{}, { [t.id]: { priority: 1 } }, { [t.id]: { priority: 3 } }, { [t.id]: { priority: 2 } }])
  m.push({ fn: 'nextReason', task: t, lay, today, out: M.nextReason(t, lay, today, human) });
m.push({ fn: 'TYPES', out: M.TYPES }, { fn: 'PRIORITIES', out: M.PRIORITIES });
write('meta.json', m);

const s = [];
const lay = { spheres: { w: { name: 'Работа', color: 'work', icon: 'case', order: 1 }, h: { name: 'Дом', color: 'zzz', icon: 'nope', order: 1 }, x: { name: 'Старое', removed: true }, e: { name: 'Ёж' }, a: { name: 'Арбуз' }, n: null },
  lists: { L1: { sphere: 'w' }, L2: { sphere: 'x' }, L3: { sphere: 'h' }, L4: {}, L6: { sphere: 'missing' } } };
for (const l of [lay, {}, null, { spheres: {} }]) s.push({ fn: 'spheresFrom', lay: l, out: S.spheresFrom(l) });
for (const id of ['L1', 'L2', 'L3', 'L4', 'L5', 'L6']) s.push({ fn: 'sphereOf', id, lay, out: S.sphereOf(id, lay) });
for (const sp of [null, {}, { color: 'gold', icon: 'cube' }, { color: 'bad', icon: 'bad' }]) { s.push({ fn: 'sphereColor', sp, out: S.sphereColor(sp) }); s.push({ fn: 'iconPath', sp, out: S.iconPath(sp) }); }
const lists = [{ id: 'L1', title: 'Офис' }, { id: 'L2', title: 'Старый' }, { id: 'L3', title: 'Кухня' }, { id: 'L4', title: 'Разное' }];
for (const ls of [lists, [lists[0]], [lists[3]], []]) s.push({ fn: 'listChoices', lists: ls, lay, out: S.listChoices(ls, lay) });
write('spheres.json', s);
console.log(a.length, c.length, d.length, m.length, s.length);
