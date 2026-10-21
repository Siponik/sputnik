// Вид «Стикеры»: раскладка по срокам, порядок, перенос срока, наклон (src/lib/stickers.js).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { visibleLanes, bucket, weekEnd, whenDue, newDue, dueLabel, order, lanes, tilt, parseSticker, jarCount, todaySub, DEFAULT_TOPICS } from '../src/lib/stickers.js';

const T = '2026-10-21'; // среда
const SUN = '2026-10-25';
const due = (s) => (s ? `${s}T00:00:00.000Z` : undefined);
const task = (id, d, extra = {}) => ({ id, title: id, status: 'needsAction', ...(d ? { due: due(d) } : {}), ...extra });

test('конец недели — воскресенье; в воскресенье — следующее', () => {
  assert.equal(weekEnd(T), SUN);
  assert.equal(weekEnd('2026-10-19'), SUN); // понедельник
  assert.equal(weekEnd(SUN), '2026-11-01');
});

test('по срокам: сегодня с просроченным, неделя до воскресенья, остальное — когда-нибудь', () => {
  assert.equal(bucket('2026-10-20', T), 'today');
  assert.equal(bucket(T, T), 'today');
  assert.equal(bucket('2026-10-22', T), 'week');
  assert.equal(bucket(SUN, T), 'week');
  assert.equal(bucket('2026-10-26', T), 'later');
  assert.equal(bucket('', T), 'later');
  assert.equal(bucket('2026-10-26', SUN), 'week'); // в воскресенье «на неделе» — следующая неделя
});

test('перенос в колонку меняет срок', () => {
  assert.equal(whenDue('today', '2026-10-24', T), T);
  assert.equal(whenDue('today', '2026-10-19', T), T);
  assert.equal(whenDue('later', T, T), null);
  assert.equal(whenDue('week', '2026-10-24', T), '2026-10-24'); // уже на этой неделе — не трогаем
  assert.equal(whenDue('week', null, T), '2026-10-22'); // иначе завтра
  assert.equal(whenDue('week', '2026-11-10', T), '2026-10-22');
  assert.equal(whenDue('week', null, SUN), '2026-11-01'); // в воскресенье — следующее воскресенье
  assert.equal(newDue('today', T), T);
  assert.equal(newDue('week', T), '2026-10-22');
  assert.equal(newDue('later', T), null);
});

test('подпись срока', () => {
  assert.deepEqual(dueLabel('2026-10-20', T), { text: 'просрочено · вчера', cls: 'late' });
  assert.equal(dueLabel('2026-10-18', T).text, 'просрочено · 18 окт.');
  assert.deepEqual(dueLabel(T, T, { s: '19:00', e: '20:00' }), { text: 'сегодня, 19:00', cls: 'soon' });
  assert.equal(dueLabel(T, T, null, true).text, '');
  assert.equal(dueLabel('2026-10-22', T).text, 'завтра');
  assert.equal(dueLabel('2026-10-24', T).text, 'сб');
  assert.equal(dueLabel('2026-11-02', T).text, '2 нояб.');
  assert.equal(dueLabel('', T).text, '');
  assert.equal(todaySub(T), 'ср, 21 октября · и просроченное');
});

test('порядок: закреплённые → просроченные → ближайший срок → свой порядок', () => {
  const items = [task('a'), task('b', '2026-10-24'), task('c', '2026-10-19'), task('d', '2026-10-22'), task('e')];
  const lay = { e: { pin: true }, a: { ord: 0 } };
  assert.deepEqual(order(items, lay, T, 'due').map((t) => t.id), ['e', 'c', 'd', 'b', 'a']);
  // «Закреплённые сверху» — дальше только свой порядок, без ord — по порядку Google
  const pos = items.map((t, i) => ({ ...t, position: String(i) }));
  assert.deepEqual(order(pos, { e: { pin: true }, d: { ord: 0 }, b: { ord: 1 } }, T, 'pin').map((t) => t.id), ['e', 'd', 'b', 'a', 'c']);
});

test('раскладка по темам: «Разное» только если есть дела без темы', () => {
  const tasks = [task('x'), task('y')];
  const by = lanes(tasks, { topics: DEFAULT_TOPICS, layTasks: { x: { topic: 'buy' }, y: { topic: 'buy' } }, today: T });
  assert.deepEqual(by.map((l) => l.name), ['Документы', 'Покупки', 'Звонки', 'Здоровье', 'Дом']);
  assert.equal(by[1].items.length, 2);
  const misc = lanes(tasks, { topics: DEFAULT_TOPICS, layTasks: { x: { topic: 'gone' } }, today: T });
  assert.equal(misc.at(-1).name, 'Разное');
  assert.equal(misc.at(-1).items.length, 2);
});

test('раскладка по срокам: три колонки', () => {
  const tasks = [task('a', '2026-10-19'), task('b', T), task('c', '2026-10-23'), task('d'), task('e', '2026-12-01')];
  const by = lanes(tasks, { group: 'when', today: T });
  assert.deepEqual(by.map((l) => l.items.map((t) => t.id)), [['a', 'b'], ['c'], ['e', 'd']]);
  assert.equal(by[0].sub, 'ср, 21 октября · и просроченное');
});

test('наклон постоянный и в пределах ±1,5°', () => {
  assert.equal(tilt('abc'), tilt('abc'));
  const all = Array.from({ length: 200 }, (_, i) => tilt('id' + i));
  assert.ok(all.every((x) => x >= -1.5 && x <= 1.5));
  assert.ok(new Set(all).size > 10);
});

test('текст нового стикера: #тема, когда, приоритет, повтор', () => {
  const p = parseSticker('купить батарейки #покуп в пятницу 17:00 !!!', DEFAULT_TOPICS, new Date(2026, 9, 21));
  assert.equal(p.title, 'Купить батарейки');
  assert.equal(p.topic, 'buy');
  assert.equal(p.day, '2026-10-23');
  assert.equal(p.time, '17:00');
  assert.equal(p.priority, 1);
  assert.equal(parseSticker('#ДОМ полить цветы каждую неделю').topic, 'home');
  assert.deepEqual(parseSticker('полить цветы каждую неделю').repeat, { every: 'week' });
  assert.equal(parseSticker('#нетакой тема').title, '#нетакой тема'); // незнакомая тема остаётся в тексте
});

test('баночка: сделано за 7 дней', () => {
  const now = Date.parse('2026-10-21T12:00:00Z');
  const done = (d) => ({ status: 'completed', completed: new Date(now - d * 864e5).toISOString() });
  assert.equal(jarCount([done(1), done(6.5), done(8), { status: 'needsAction' }, { ...done(1), parent: 'p' }], now), 2);
});

test('пустые темы прячутся, по срокам — всегда три колонки', () => {
  const L = (id, n) => ({ id, items: Array.from({ length: n }, (_, i) => ({ id: id + i })) });
  const all = [L('docs', 0), L('buy', 2), L('calls', 0), L('', 1)];
  let v = visibleLanes(all, { group: 'topic' });
  assert.deepEqual(v.shown.map((l) => l.id), ['buy', '']);
  assert.deepEqual(v.hidden.map((l) => l.id), ['docs', 'calls']);
  v = visibleLanes(all, { group: 'topic', keep: 'calls' }); // пишут новый стикер в пустую тему
  assert.deepEqual(v.shown.map((l) => l.id), ['buy', 'calls', '']);
  v = visibleLanes([L('docs', 0), L('buy', 0)], { group: 'topic' }); // пусто везде — все
  assert.equal(v.shown.length, 2);
  assert.equal(v.hidden.length, 0);
  v = visibleLanes([L('today', 0), L('week', 0), L('later', 1)], { group: 'when' });
  assert.equal(v.shown.length, 3);
});

test('«Разное» (id пустой) не считается колонкой, куда пишут новый стикер, пока не начали', () => {
  const L = (id, n) => ({ id, items: Array.from({ length: n }, (_, i) => ({ id: id + i })) });
  const all = [L('docs', 0), L('', 1)];
  assert.deepEqual(visibleLanes(all, { group: 'topic', keep: null }).shown.map((l) => l.id), ['']);
  assert.deepEqual(visibleLanes(all, { group: 'topic', keep: 'docs' }).shown.map((l) => l.id), ['docs', '']);
});
