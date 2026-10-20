// Демо-данные — те же задачи, что на макетах design/screens/Kanban.dc.html и Conveyor.dc.html,
// чтобы скриншот трекера можно было положить рядом с design/screens/ref/*.png.
const day = (d) => { const x = new Date(); x.setHours(0, 0, 0, 0); x.setDate(x.getDate() + d); return x; };
const due = (d) => { const x = day(d); return `${x.getFullYear()}-${String(x.getMonth() + 1).padStart(2, '0')}-${String(x.getDate()).padStart(2, '0')}T00:00:00.000Z`; };
const ymd = (d) => due(d).slice(0, 10);
const ago = (d) => Date.now() - d * 864e5;
const iso = (d) => new Date(ago(d)).toISOString();

export const seedLists = () => [
  { id: 'Lwork', title: 'Иконки для клиента' },
  { id: 'L3d', title: '3D-проекты' },
  { id: 'Lme', title: 'Личное' },
  { id: 'Lhab', title: 'Привычки' },
];

let k = 0;
const T = (title, o = {}) => ({ id: o.id ?? 't' + ++k, title, status: o.done ? 'completed' : 'needsAction', updated: iso(0),
  ...(o.notes ? { notes: o.notes } : {}), ...(o.due != null ? { due: due(o.due) } : {}),
  ...(o.done ? { completed: iso(o.done) } : {}), ...(o.parent ? { parent: o.parent } : {}) });
const subs = (parent, items) => items.map(([title, done]) => T(title, { parent, done: done ? 1 : 0 }));

export function seedTasks() {
  return {
    Lwork: [
      T('Сменить пароль ArtStation', { id: 'w1', notes: 'Новый вход из Стокгольма в пятницу', due: 0 }),
      T('Референсы для набора «Зимние»', { id: 'w2', due: 3 }),
      T('Смета по набору иконок', { id: 'w3', notes: 'Клиент ждёт до пятницы', due: 3 }),
      T('Иконки v2: толще обводка, без градиента', { id: 'w4', due: 0 }),
      ...subs('w4', [['Сетка 24 px', 1], ['Обводка 2 px', 1], ['Убрать градиенты', 1], ['Экспорт SVG', 0], ['Проверить на тёмном', 0]]),
      T('Анимация загрузки для приложения клиента', { id: 'w5', notes: 'Лоадер в стиле бренда, 2 варианта', due: 7 }),
      ...subs('w5', [['Раскадровка', 1], ['Вариант A', 0], ['Вариант B', 0], ['Lottie-экспорт', 0]]),
      T('Ревью набора «Погода»', { id: 'w6', due: -1 }),
      T('Набор иконок v1', { id: 'w7', done: 1, due: -6 }),
      T('Логотип для бота', { id: 'w8', done: 2, due: -4 }),
      T('Обложка для Behance', { id: 'w9', done: 2 }),
    ],
    L3d: [
      T('Башня lowpoly', { id: 'a1', notes: 'Лимит 3k треугольников. Окна — отдельным мешем, арки без лишних петель.', due: 3 }),
      ...subs('a1', [['Основной объём', 1], ['Окна и арки', 1], ['Проверить нормали', 0], ['Сетка на деформациях', 0]]),
      T('Пропсы для башни', { id: 'a2', notes: 'бочки, факелы', due: 10 }),
      T('Сундук с золотом', { id: 'a3', notes: 'пропс', due: -1 }),
      T('Енот-космонавт · 3D', { id: 'a4', notes: 'маскот Спутника' }),
    ],
    Lme: [
      T('Записаться к стоматологу', { id: 'p1', due: 2 }),
      T('Купить подарок маме', { id: 'p2', due: 5 }),
    ],
    Lhab: [T('Скетч 15 минут', { id: 'h1' }), T('Зарядка', { id: 'h2' })],
  };
}

export function seedLayer() {
  const t = Date.now();
  const L = (o) => ({ ...o, t });
  return {
    version: 1,
    lists: { Lwork: L({ template: 'work' }), L3d: L({ template: 'asset3d', view: 'pipe' }), Lme: L({ template: 'personal' }), Lhab: L({ template: 'habits' }) },
    tasks: {
      w1: L({ priority: 1, type: 'work' }),
      w2: L({ priority: 3 }),
      w3: L({ priority: 2, remind: { kind: 'before', days: 1, time: '10:00' } }),
      w4: L({ priority: 1, status: 'doing', slot: { s: '18:00', e: '19:00' }, remind: { kind: 'at', at: `${ymd(0)}T17:00`, hour1: true } }),
      w5: L({ priority: 2, status: 'doing' }),
      w6: L({ priority: 2, status: 'review' }),
      a1: L({ priority: 1, status: 'retopo', project: 'Башня', remind: { kind: 'before', days: 1, time: '10:00' },
        stageAt: { refs: ago(10), blockout: ago(9.5), sculpt: ago(8.5), retopo: ago(3) } }),
      a2: L({ priority: 2, status: 'blockout', project: 'Башня', stageAt: { refs: ago(9), blockout: ago(6) } }),
      a3: L({ priority: 2, status: 'textures', project: 'Таверна', stageAt: { textures: ago(2) } }),
      a4: L({ priority: 3, status: 'sculpt', project: 'Личное', stageAt: { sculpt: ago(9) } }),
    },
    habits: {}, log: {}, cals: {}, templates: {}, templatesEdit: {}, spheres: {},
    settings: { setup: L({ done: true }) },
  };
}
