// Золотые данные для route. Запуск: TZ=Europe/Moscow node tools/golden/route.mjs
import { writeFileSync, mkdirSync } from 'node:fs';
import * as R from '../../tracker/src/lib/route.js';

const OUT = new URL('../../app/test/golden/', import.meta.url);
mkdirSync(OUT, { recursive: true });
const write = (name, data) => writeFileSync(new URL(name, OUT), '[\n' + data.map((x) => JSON.stringify(x)).join(',\n') + '\n]\n');
const out = [];
const TODAY = new Date(2026, 9, 21);
const NOW = TODAY.getTime();
const T = (id, title, extra = {}) => ({ id, title, status: 'needsAction', ...extra });
const lists = [
  { id: 'Lwork', title: 'Иконки для клиента' }, { id: 'L3d', title: '3D-проекты' },
  { id: 'Lhome', title: 'Дела по дому' }, { id: 'Lstudy', title: 'Курс Blender' },
];
const layer = {
  lists: { Lwork: { template: 'work' }, L3d: { template: 'asset3d', view: 'pipe' }, Lhome: { template: 'personal', view: 'stickers' }, Lstudy: { template: 'study' } },
  tasks: { a1: { project: 'Башня' }, a2: { project: 'Башня' }, a3: { project: 'Таверна' }, a4: { project: 'Таверна' } },
  settings: {},
};
const tasks = {
  Lwork: [T('w1', 'Смета по набору иконок'), T('w2', 'Референсы для набора «Зимние»'), T('w3', 'Ревью набора «Погода»'),
    T('w4', 'Старое сделанное письмо', { status: 'completed', completed: '2026-08-01T00:00:00Z' }), T('w5', 'Свежий отчёт', { status: 'completed', completed: '2026-10-20T00:00:00Z' }), T('w6', 'Подзадача иконок', { parent: 'w1' })],
  L3d: [T('a1', 'Башня lowpoly'), T('a2', 'Пропсы для башни'), T('a3', 'Сундук с золотом'), T('a4', 'Таверна'), T('a5', 'Без проекта', { parent: 'a1' })],
  Lhome: [T('h1', 'Лампочки в коридор'), T('h2', 'Позвонить бабушке')],
  Lstudy: [T('s1', 'Урок 3: материалы')],
};
const learned = { ...layer, settings: { route: { 'разоб': { list: 'Lstudy', n: 3 }, 'батар': { list: 'Lhome', topic: 'buy', n: 1 }, 'плохо': 'x', 'смета': { list: 'L3d', n: 9 } } } };

for (const w of ['Ёлка в лесу, для всех!', 'uv развёртка', '', null, 'чтобы надо 3D-проекты']) out.push({ fn: 'words', s: w, out: R.words(w) });
for (const w of ['Ёлочка', 'аб', 'ИКОНКАМ']) out.push({ fn: 'stem', s: w, out: R.stem(w) });
for (const [a, b] of [['иконкам', 'иконок'], ['кот', 'кот'], ['ко', 'ко'], ['коты', 'кит'], ['дом', 'дома'], ['abc', 'abd']]) out.push({ fn: 'sameWord', a, b, out: R.sameWord(a, b) });

const LINES = ['смета для клиента по иконкам завтра 15:00 !!', 'позвонить маме @дом #звонки', 'полить цветы каждую неделю', 'купить хлеб', '',
  '  ', 'отчёт в пятницу 17:00 !!!', 'отчёт ! важный', '!!!! много', '@раб #work задача', 'задача @a @b', 'по будням зарядка в 7:30', 'ежедневно 9:00 пить воду',
  'Встреча 21.10 в 10', 'встреча послезавтра', 'сделать #тип#два', 'Завтра завтра', 'через 2 дня созвон', 'созвон !', '#asset башня', 'каждый месяц оплатить счёт 25 числа'];
const OFFS = [{}, { when: true }, { prio: true, at: true }, { tag: true, repeat: true }];
for (const s of LINES) for (const off of OFFS) out.push({ fn: 'parseLine', s, off, out: R.parseLine(s, { today: TODAY, off }) });

out.push({ fn: 'projectsOf', t: tasks.L3d, lay: layer.tasks, out: R.projectsOf(tasks.L3d, layer.tasks) });
out.push({ fn: 'projectsOf', t: [], lay: null, out: R.projectsOf([], null) });
for (const w of ['раб', 'дела по дому', 'ДОМУ', '3d', '3dпро', '', '-', 'blender', 'xyz']) out.push({ fn: 'findList', w, out: R.findList(lists, w) });
out.push({ fn: 'viewOf', id: 'Lhome', out: R.viewOf('Lhome', layer) });
out.push({ fn: 'viewOf', id: 'Lwork', out: R.viewOf('Lwork', layer) });

const TEXTS = ['что-нибудь @курс', 'новая штука #asset', 'что-то #study', 'что-то #работа', 'что-то #неизвестно', 'сундук с золотом lowpoly для таверны', 'урок про ноды',
  'купить лампочки в коридор', 'записаться к стоматологу', 'продлить полис', 'позвонить в сервис', 'что-то по дому', 'смета для клиента по иконкам', 'референсы зимние',
  'окна для башни', 'разобраться с этим', 'купить лампочки', 'батарейки ААА', 'бумагу в офис', 'свежий отчёт письмо', 'сходить в зал', 'uv для пропсов', 'набор иконок погода зимние', ''];
for (const text of TEXTS) for (const [lay, current] of [[layer, null], [layer, 'Lstudy'], [learned, 'Lwork'], [learned, null]])
  out.push({ fn: 'route', text, learned: lay === learned, current, out: R.route(text, { lists, layer: lay, tasks, current, now: NOW }) });
out.push({ fn: 'route', text: 'x', empty: true, out: R.route('x', { lists: [], layer, tasks }) });

for (const [cur, title, list, topic] of [[{}, 'Сундук с золотом lowpoly', 'L3d', null], [learned.settings.route, 'Разобраться и смета', 'Lstudy', 'buy'],
  [learned.settings.route, 'Смета', 'L3d', null], [null, 'а б', 'X', null], [{ 'плохо': 'x' }, 'плохой день', 'Y', 't']])
  out.push({ fn: 'learn', cur, title, list, topic, out: R.learn(cur ?? undefined, title, list, topic) });
write('route.json', out);
console.log(out.length);
