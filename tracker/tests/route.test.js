// Окно «Создать» v2: умная строка и авто-определение списка (src/lib/route.js).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseLine, route, learn, findList, projectsOf, sameWord } from '../src/lib/route.js';

const TODAY = new Date(2026, 9, 21); // среда
const NOW = TODAY.getTime();
const T = (id, title, extra = {}) => ({ id, title, status: 'needsAction', ...extra });

// Как демо (src/demo/data.js): канбан работы, конвейер 3D, стикеры по дому, список учёбы.
const lists = [
  { id: 'Lwork', title: 'Иконки для клиента' },
  { id: 'L3d', title: '3D-проекты' },
  { id: 'Lhome', title: 'Дела по дому' },
  { id: 'Lstudy', title: 'Курс Blender' },
];
const layer = {
  lists: {
    Lwork: { template: 'work' },
    L3d: { template: 'asset3d', view: 'pipe' },
    Lhome: { template: 'personal', view: 'stickers' },
    Lstudy: { template: 'study' },
  },
  tasks: { a1: { project: 'Башня' }, a2: { project: 'Башня' }, a3: { project: 'Таверна' } },
  settings: {},
};
const tasks = {
  Lwork: [T('w1', 'Смета по набору иконок'), T('w2', 'Референсы для набора «Зимние»'), T('w3', 'Ревью набора «Погода»')],
  L3d: [T('a1', 'Башня lowpoly'), T('a2', 'Пропсы для башни'), T('a3', 'Сундук с золотом')],
  Lhome: [T('h1', 'Лампочки в коридор'), T('h2', 'Позвонить бабушке')],
  Lstudy: [T('s1', 'Урок 3: материалы')],
};
const ctx = (extra = {}) => ({ lists, layer, tasks, now: NOW, ...extra });
const top = (text, extra) => route(text, ctx(extra))[0];

test('умная строка: дата, время, приоритет и куски для подсветки', () => {
  const p = parseLine('смета для клиента по иконкам завтра 15:00 !!', { today: TODAY });
  assert.equal(p.title, 'Смета для клиента по иконкам');
  assert.equal(p.day, '2026-10-22');
  assert.equal(p.time, '15:00');
  assert.equal(p.priority, 2);
  assert.deepEqual(p.marks.map((m) => [m.kind, 'смета для клиента по иконкам завтра 15:00 !!'.slice(m.from, m.to)]),
    [['when', 'завтра 15:00'], ['prio', '!!']]);
});

test('умная строка: «в субботу», @список и #тема; убранный крестиком кусок остаётся текстом', () => {
  const raw = 'купить лампочки в коридор в субботу';
  const p = parseLine(raw, { today: TODAY });
  assert.equal(p.title, 'Купить лампочки в коридор');
  assert.equal(p.day, '2026-10-24');
  assert.deepEqual(p.marks.map((m) => raw.slice(m.from, m.to)), ['в субботу']);
  const q = parseLine('позвонить маме @дом #звонки', { today: TODAY });
  assert.equal(q.at, 'дом');
  assert.equal(q.tag, 'звонки');
  assert.equal(q.title, 'Позвонить маме');
  const off = parseLine(raw, { today: TODAY, off: { when: true } });
  assert.equal(off.day, null);
  assert.equal(off.title, 'Купить лампочки в коридор в субботу');
  assert.deepEqual(off.marks, []);
});

test('умная строка: повтор словами', () => {
  const p = parseLine('полить цветы каждую неделю', { today: TODAY });
  assert.deepEqual(p.repeat, { every: 'week' });
  assert.equal(p.title, 'Полить цветы');
});

test('@список — сразу выбор, как в боте', () => {
  assert.equal(findList(lists, '3d').id, 'L3d');
  assert.equal(findList(lists, 'дел').id, 'Lhome');
  const r = top('что-нибудь @курс');
  assert.equal(r.listId, 'Lstudy');
  assert.equal(r.why, 'указано @курс');
});

test('#тип ведёт в список с подходящим шаблоном', () => {
  const r = top('новая штука #asset');
  assert.equal(r.listId, 'L3d');
  assert.equal(r.why, 'указано #asset');
  assert.equal(top('что-то #study').listId, 'Lstudy');
});

test('словарь по шаблонам: lowpoly → 3D, урок → учёба, купить → стикеры с темой «Покупки»', () => {
  const a = top('сундук с золотом lowpoly для таверны');
  assert.equal(a.listId, 'L3d');
  assert.equal(a.why, 'по слову «lowpoly»');
  assert.equal(top('урок про ноды').listId, 'Lstudy');
  const b = top('купить лампочки в коридор');
  assert.equal(b.listId, 'Lhome');
  assert.equal(b.why, 'по слову «купить»');
  assert.equal(b.topic, 'buy');
  assert.equal(b.topicWhy, 'по слову «купить»');
});

test('темы стикеров: словарь темы и имя темы', () => {
  assert.equal(top('записаться к стоматологу').topic, 'health');
  assert.equal(top('продлить полис').topic, 'docs');
  assert.equal(top('позвонить в сервис').topic, 'call');
  assert.equal(top('что-то по дому').topic, 'home'); // имя темы «Дом»
});

test('похожесть на задачи доски: много общих слов — «похоже на задачи этой доски»', () => {
  const r = top('смета для клиента по иконкам');
  assert.equal(r.listId, 'Lwork');
  assert.equal(r.why, 'похоже на задачи этой доски');
  assert.equal(top('референсы зимние').listId, 'Lwork');
});

test('проект Конвейера по слову названия', () => {
  const r = top('сундук с золотом lowpoly для таверны');
  assert.equal(r.project, 'Таверна');
  assert.equal(r.projectWord, 'таверны');
  assert.deepEqual(projectsOf(tasks.L3d, layer.tasks), ['Башня', 'Таверна']);
  assert.equal(top('окна для башни').project, 'Башня');
});

test('текущая доска: без совпадений — она, с бейджем «текущая доска»; небольшой бонус при равенстве', () => {
  const r = top('разобраться с этим', { current: 'Lstudy' });
  assert.equal(r.listId, 'Lstudy');
  assert.equal(r.why, 'текущая доска');
  assert.equal(top('разобраться с этим').why, 'по умолчанию');
  // явные слова сильнее текущей доски
  assert.equal(top('купить лампочки', { current: 'Lwork' }).listId, 'Lhome');
});

test('выученные слова: ручной выбор запоминается и перевешивает словарь', () => {
  const learned = learn({}, 'Купить бумагу для принтера', 'Lwork');
  assert.deepEqual(Object.keys(learned), ['купит', 'бумаг']);
  assert.equal(learned['бумаг'].n, 1);
  const lay = { ...layer, settings: { route: { ...learned, t: 1 } } };
  const r = route('бумагу в офис', { ...ctx(), layer: lay })[0];
  assert.equal(r.listId, 'Lwork');
  assert.equal(r.why, 'запомнил «бумагу»');
  // повтор того же выбора — n растёт; другой список — заново с 1
  assert.equal(learn(learned, 'бумага', 'Lwork')['бумаг'].n, 2);
  assert.equal(learn(learned, 'бумага', 'Lhome')['бумаг'].n, 1);
  // с темой
  const lt = learn({}, 'батарейки', 'Lhome', 'home');
  assert.equal(route('батарейки ААА', { ...ctx(), layer: { ...layer, settings: { route: lt } } })[0].topic, 'home');
});

test('порядок кандидатов: лучший первым, остальные за ним', () => {
  const r = route('купить лампочки', ctx());
  assert.equal(r.length, lists.length);
  assert.ok(r[0].score >= r[1].score);
});

test('формы одного слова', () => {
  assert.ok(sameWord('иконкам', 'иконок'));
  assert.ok(sameWord('таверны', 'таверна'));
  assert.ok(!sameWord('клад', 'клиент'));
});
