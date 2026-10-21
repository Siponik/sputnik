// «Сегодня» 0.6: чипы «Понял:» и задача из умной строки (src/lib/today.js).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { understood, taskFrom } from '../src/lib/today.js';
import { parseLine } from '../src/lib/route.js';

const TODAY = new Date(2026, 9, 21); // среда
const T = '2026-10-21';
const p = (s) => parseLine(s, { today: TODAY });

test('без даты — «сегодня», со временем — «сегодня · 17:00»', () => {
  assert.deepEqual(understood(p('скетч таверны'), T), [{ kind: 'when', text: 'сегодня' }]);
  assert.deepEqual(understood(p('скетч таверны 17:00'), T), [{ kind: 'when', text: 'сегодня · 17:00' }]);
});

test('другой день, приоритет, повтор и тип', () => {
  const c = understood(p('смета завтра 15:00 !!! каждую неделю #work'), T);
  assert.equal(c[0].text, 'завтра, 22 октября · 15:00');
  assert.deepEqual(c.slice(1).map((x) => x.kind), ['prio', 'repeat', 'type']);
  assert.equal(c[1].text, '!!! высокий');
  assert.equal(c[3].text, '#work');
});

test('пустая строка — ничего не понято', () => {
  assert.deepEqual(understood(p(''), T), []);
  assert.deepEqual(understood(p('завтра'), T), []);
});

test('задача из строки: срок сегодня, час по умолчанию, поля слоя', () => {
  const t = taskFrom(p('скетч таверны 17:00 !! #asset'), T, 'L3d');
  assert.deepEqual(t, { title: 'Скетч таверны', listId: 'L3d', due: T, slot: { s: '17:00', e: '18:00' }, layer: { type: 'creative', priority: 2 } });
  assert.equal(taskFrom(p('созвон 23:30'), T, 'L').slot.e, '23:59');
  assert.equal(taskFrom(p('созвон в пятницу'), T, 'L').due, '2026-10-23');
  assert.deepEqual(taskFrom(p('правки #client'), T, 'L').layer, { type: 'work', tags: ['client'] });
});

test('тема стикеров и проект — только если выбран угаданный список', () => {
  const r = { listId: 'Lhome', topic: 'buy', project: null };
  assert.equal(taskFrom(p('купить лампу'), T, 'Lhome', r).layer.topic, 'buy');
  assert.equal(taskFrom(p('купить лампу'), T, 'Lwork', r).layer.topic, undefined);
  assert.equal(taskFrom(p('башня uv'), T, 'L3d', { listId: 'L3d', project: 'Башня' }).layer.project, 'Башня');
});
