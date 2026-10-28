// Окно «Создать» v2 — помощники (src/lib/create.js).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { dative, nextBirthday, ageAt, years, freeCheck, colCount, topOrd, stageChecklist, shortDay, dueShort, whenChip, initials, suggestKind, kindHint, dayChunk } from '../src/lib/create.js';

const T = '2026-10-21'; // среда

test('подписи дат', () => {
  assert.equal(shortDay('2026-10-24'), 'сб, 24 окт.');
  assert.equal(dueShort('2026-10-22', T, { s: '15:00', e: '16:00' }), 'завтра, 15:00');
  assert.equal(dueShort('2026-10-24', T), 'сб');
  assert.equal(dueShort('2026-11-05', T), '5 нояб.');
  assert.equal(whenChip(null, T), 'later');
  assert.equal(whenChip('2026-10-24', T), 'week');
  assert.equal(whenChip('2026-11-24', T), 'date');
});

test('дательный падеж имени для «Подарок …»', () => {
  assert.equal(dative('Аня'), 'Ане');
  assert.equal(dative('Маша'), 'Маше');
  assert.equal(dative('Мария'), 'Марии');
  assert.equal(dative('Иван'), 'Ивану');
  assert.equal(dative('Андрей'), 'Андрею');
  assert.equal(dative('Игорь'), 'Игорю');
  assert.equal(dative('Анна Петровна'), 'Анна Петровна');
});

test('ближайший день рождения и возраст', () => {
  assert.equal(nextBirthday('2026-03-12', T), '2027-03-12');
  assert.equal(nextBirthday('1996-12-01', T), '2026-12-01');
  assert.equal(nextBirthday('2026-10-21', T), '2026-10-21');
  assert.equal(ageAt('1997', '2026-03-12', T), 30);
  assert.equal(ageAt('', '2026-03-12', T), null);
  assert.equal(years(30), '30 лет');
  assert.equal(years(21), '21 год');
  assert.equal(years(22), '22 года');
  assert.equal(years(12), '12 лет');
});

test('событие: пересечение и «свободно до»', () => {
  const ev = (s, e, summary) => ({ summary, start: { dateTime: `${T}T${s}:00` }, end: { dateTime: `${T}T${e}:00` } });
  const day = [ev('12:00', '13:00', 'Обед'), ev('17:00', '18:00', 'Спорт')];
  assert.deepEqual(freeCheck(day, T, { s: '14:00', e: '14:45' }), { until: '17:00' });
  assert.deepEqual(freeCheck(day, T, { s: '12:30', e: '13:30' }), { clash: 'Обед' });
  assert.deepEqual(freeCheck(day, T, { s: '19:00', e: '20:00' }), { free: true });
  assert.equal(freeCheck(day, T, null), null);
});

test('колонки: лимит и порядок «сверху»', () => {
  const tasks = [{ id: 'a', status: 'needsAction' }, { id: 'b', status: 'needsAction' }, { id: 'c', status: 'needsAction' }, { id: 'd', status: 'completed' }];
  const lay = { a: { status: 'doing', ord: 2 }, b: { status: 'doing' }, d: { status: 'doing' } };
  assert.equal(colCount(tasks, lay, 'doing', 'inbox'), 2);
  assert.equal(colCount(tasks, lay, 'inbox', 'inbox'), 1);
  assert.equal(topOrd(tasks, lay, 'doing', 'inbox'), -1);
  assert.equal(topOrd(tasks, { a: { status: 'doing', ord: -3 } }, 'doing', 'inbox'), -4);
});

test('чек-лист этапов берётся из последнего ассета с подзадачами этапов', () => {
  const tasks = [
    { id: 'a1', title: 'Башня', updated: '2026-10-20' },
    { id: 's1', title: 'Нормали', parent: 'a1', position: '2' },
    { id: 's2', title: 'Сетка', parent: 'a1', position: '1' },
    { id: 'a2', title: 'Сундук', updated: '2026-10-21' },
    { id: 's3', title: 'Без этапа', parent: 'a2' },
  ];
  const lay = { s1: { stage: 'retopo' }, s2: { stage: 'blockout' } };
  assert.deepEqual(stageChecklist(tasks, lay), [{ title: 'Сетка', stage: 'blockout' }, { title: 'Нормали', stage: 'retopo' }]);
  assert.deepEqual(stageChecklist([], {}), []);
  assert.equal(initials('Сундук с золотом'), 'СУ');
});

test('подсказка вида: встреча, привычка, день рождения', () => {
  const ev = suggestKind('Созвон с Олей завтра в 15:00', { day: '2026-10-22', time: '15:00' });
  assert.equal(ev.kind, 'event');
  assert.equal(ev.why, 'у неё есть время и с кем-то');
  assert.equal(suggestKind('Обсудить смету с клиентом 14:00', { time: '14:00' }).kind, 'event');
  assert.equal(suggestKind('к врачу в пятницу', { day: '2026-10-23' }).kind, 'event');
  assert.equal(suggestKind('Встреча по проекту', {}).why, 'её не отмечают сделанной');
  // просто дело со временем — не встреча; «с утра» — не человек
  assert.equal(suggestKind('купить лампочки 17:00', { time: '17:00' }), null);
  assert.equal(suggestKind('позвонить маме', {}), null);
  assert.equal(suggestKind('с утра отправить смету 10:00', { time: '10:00' }), null);
  // «встречать» — не встреча
  assert.equal(suggestKind('встречать гостей', {}), null);

  assert.deepEqual(suggestKind('Пить воду 8 стаканов каждый день', {}), { kind: 'habit', what: 'привычку', why: 'повторяется каждый день' });
  assert.equal(suggestKind('зарядка по будням', {}).why, 'повторяется по будням');
  assert.equal(suggestKind('Бег 3 раза в неделю', {}).why, 'повторяется 3 раза в неделю');
  assert.equal(suggestKind('медитация', { repeat: { every: 'day' } }).kind, 'habit');
  assert.equal(suggestKind('отчёт', { repeat: { every: 'week' } }), null); // повтор раз в неделю — обычная задача

  assert.equal(suggestKind('др Ани 12 марта', { day: '2027-03-12' }).kind, 'birthday');
  assert.equal(suggestKind('День рождения мамы 5 мая', { day: '2027-05-05' }).kind, 'birthday');
  assert.equal(suggestKind('подарок на день рождения', {}), null); // без даты — дело
  assert.equal(suggestKind('драйвер обновить', { day: '2027-05-05' }), null); // «др» — только отдельным словом
});

test('подсказка вида молчит, когда вид уже подходит', () => {
  const p = { day: '2026-10-22', time: '15:00' };
  assert.equal(kindHint('Созвон с Олей завтра 15:00', p, 'task').kind, 'event');
  assert.equal(kindHint('Созвон с Олей завтра 15:00', p, 'event'), null);
  assert.equal(kindHint('планёрка каждый день', {}, 'event'), null); // повторяющееся событие — нормально
  assert.equal(kindHint('планёрка каждый день', {}, 'task').kind, 'habit');
  assert.equal(kindHint('встреча с Аней', {}, 'birthday'), null);
});

test('превью события: кусок сетки дня', () => {
  const T2 = '2026-10-22';
  const ev = (s, e, summary) => ({ summary, start: { dateTime: `${T2}T${s}:00` }, end: { dateTime: `${T2}T${e}:00` } });
  const c = dayChunk([ev('17:00', '17:30', 'Спорт'), ev('08:00', '09:00', 'Утро')], T2, { s: '15:00', e: '16:00' }, 'Созвон');
  assert.deepEqual(c.hours, [14, 15, 16, 17, 18]);
  assert.deepEqual(c.items, [{ top: 3, h: 0.5, title: 'Спорт', mine: false }, { top: 1, h: 1, title: 'Созвон', mine: true }]);
  assert.deepEqual(dayChunk([], T2, null).hours, [9, 10, 11, 12, 13]);
  assert.deepEqual(dayChunk([], T2, { s: '23:00', e: '23:30' }, 'x').hours, [19, 20, 21, 22, 23]);
});
