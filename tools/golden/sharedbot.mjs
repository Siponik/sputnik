// Золотые данные для sharedbot (только чистые функции). «Сейчас» — 2026-10-21 14:00.
// Запуск: TZ=Europe/Moscow node tools/golden/sharedbot.mjs
import { writeFileSync, mkdirSync } from 'node:fs';

const NOW = new Date(2026, 9, 21, 14, 0).getTime();
const RealDate = Date;
class FakeDate extends RealDate {
  constructor(...a) { if (a.length) super(...a); else super(NOW); }
  static now() { return NOW; }
}
FakeDate.parse = RealDate.parse;
globalThis.Date = FakeDate;
const B = await import('../../tracker/src/lib/sharedbot.js');

const OUT = new URL('../../rust/core/tests/golden/', import.meta.url);
mkdirSync(OUT, { recursive: true });
const write = (name, data) => writeFileSync(new URL(name, OUT), '[\n' + data.map((x) => JSON.stringify(x)).join(',\n') + '\n]\n');
const out = [];
const lists = [{ id: 'Lwork', title: 'Иконки для клиента' }, { id: 'L3d', title: '3D-проекты' }, { id: 'Lhome', title: 'Дела по дому' }, { id: 'Lx', title: '' }];
const layer = {
  lists: { Lwork: { template: 'work' }, L3d: { template: 'asset3d', view: 'pipe' }, Lhome: { template: 'personal', view: 'stickers' } },
  tasks: { a1: { project: 'Башня', slot: { s: '10:00' } }, w1: { slot: { s: '09:30' } }, w2: { slot: {} } },
  settings: { route: { 'смета': { list: 'Lwork', n: 2 }, 'башн': { list: 'L3d' }, 'чужо': { list: 'nope', n: 9 }, 'плохо': 'x', 'купит': { list: 'Lhome', n: 5 } } },
};
const T = (id, title, due, extra = {}) => ({ id, title, status: 'needsAction', ...(due ? { due: `${due}T00:00:00.000Z` } : {}), ...extra });
const tasks = {
  Lwork: [T('w1', 'Смета по набору иконок', '2026-10-21'), T('w2', '', '2026-10-28'), T('w3', 'Поздно', '2026-10-29'), T('w4', 'Сделано', '2026-10-21', { status: 'completed' }),
    T('w5', 'Подзадача', '2026-10-21', { parent: 'w1' }), T('w6', 'Без срока'), T('w7', 'Просрочено', '2026-10-01'), T('w8', 'Удалено', '2026-10-22', { deleted: true })],
  L3d: [T('a1', 'Башня lowpoly', '2026-10-21'), T('a2', 'Пропсы для башни', '2026-10-21')],
  Lhome: [T('h1', 'Лампочки', '2026-10-25')],
};
for (const now of [NOW, new Date(2026, 11, 28, 9).getTime()]) out.push({ fn: 'snapshot', now, out: B.snapshot(lists, tasks, layer.tasks, new Date(now)) });
out.push({ fn: 'snapshotNoLay', now: NOW, out: B.snapshot(lists, tasks, undefined, new Date(NOW)) });
out.push({ fn: 'guessCtx', out: B.guessCtx(lists, layer) });
out.push({ fn: 'guessCtx0', out: B.guessCtx([], null) });
const TEXTS = ['смета для клиента завтра 15:00 !!', 'купить хлеб\nзаметка\nвторая строка', 'башня lowpoly #asset каждую неделю', '', '  ', 'что-то @дому', 'позвонить в пятницу', '!!!', 'Тест\n'];
for (const s of TEXTS) out.push({ fn: 'fromText', s, out: B.fromText(s, { lists, layer, tasks }) });
out.push({ fn: 'fromTextNoLists', s: 'купить', out: B.fromText('купить', { lists: [], layer, tasks }) });
const DRAFTS = [
  { title: 'Смета', listId: 'Lwork', due: '2026-10-23', time: '15:00', prio: 1, rem: 15, notes: 'з', src: 'смета для клиента в пятницу 15:00 !!' },
  { title: 'Купить хлеб', due: 'нет', time: '25:00', rem: 'off', src: 'купить хлеб #personal каждый день' },
  { title: 'Башня', listId: 'nope', prio: 5, rem: -1 },
  { title: '', listId: 'Lwork' },
  { title: 'x'.repeat(300), listId: 'Lhome', notes: 'n'.repeat(5000), due: '2026-10-30', time: '23:30', rem: 1.5 },
  { title: 'Пропсы для башни', src: 'пропсы для башни !!!', due: '2026-10-22' },
  { title: 'Ничего', due: '2026-10-22', time: '10:00' },
  { title: 5, listId: 'Lwork', rem: 0 },
];
for (const x of DRAFTS) out.push({ fn: 'fromDraft', x, out: B.fromDraft(x, { lists, layer, tasks }) });
out.push({ fn: 'fromDraftNoLists', x: DRAFTS[1], out: B.fromDraft(DRAFTS[1], { lists: [], layer, tasks }) });
out.push({ fn: 'consts', out: [B.BOT_URL, B.BOT_NAME, B.BOT_LINK] });
write('sharedbot.json', out);
console.log(out.length);
