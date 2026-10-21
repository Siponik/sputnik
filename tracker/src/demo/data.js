// Демо-данные — те же задачи, что на макетах design/screens/Kanban.dc.html, Conveyor.dc.html и Stickers.dc.html,
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
  { id: 'Lhome', title: 'Дела по дому' },
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
    // «Дела по дому» = Stickers.dc.html (вид «Стикеры»), макет снят в среду — сроки относительно сегодня.
    Lhome: [
      T('Продлить полис ОСАГО', { id: 'h01', due: -1 }),
      T('Поменять резину', { id: 'h02', notes: 'шиномонтаж у дома, записаться', due: 12 }),
      T('Забрать посылку с Озона', { id: 'h03', notes: 'код 4417', due: 0 }),
      T('Подарок маме', { id: 'h04', notes: 'сертификат в спа или плед', due: 3 }),
      T('Лампочки в коридор', { id: 'h05', due: 4 }),
      T('Позвонить бабушке', { id: 'h06', due: 0 }),
      T('Вернуть книгу Саше', { id: 'h07', due: 1 }),
      T('Записаться к стоматологу', { id: 'h08', due: 2 }),
      T('Записаться в зал', { id: 'h09' }),
      T('Оплатить интернет', { id: 'h10', due: 0 }),
      T('Почистить ноутбук от пыли', { id: 'h11' }),
      T('Разобрать фото с поездки', { id: 'h12' }),
      T('Фильтр в кофемашине', { id: 'h13' }),
      // сделано за неделю — «баночка»
      T('Вынести коробки', { id: 'h20', done: 1 }), T('Купить корм коту', { id: 'h21', done: 1 }), T('Счётчики воды', { id: 'h22', done: 2 }),
      T('Забрать химчистку', { id: 'h23', done: 3 }), T('Позвонить в ЖЭК', { id: 'h24', done: 4 }), T('Заказать воду', { id: 'h25', done: 6 }),
    ],
    Lhab: [T('Скетч 15 минут', { id: 'h1' }), T('Зарядка', { id: 'h2' })],
  };
}

export function seedLayer() {
  const t = Date.now();
  const L = (o) => ({ ...o, t });
  return {
    version: 1,
    lists: { Lwork: L({ template: 'work', sphere: 'sWork' }), L3d: L({ template: 'asset3d', view: 'pipe', sphere: 'sArt' }), Lme: L({ template: 'personal' }), Lhab: L({ template: 'habits' }),
      Lhome: L({ template: 'personal', view: 'stickers', sphere: 'sMe', topics: [
        { id: 'docs', name: 'Документы', color: 'clay' }, { id: 'buy', name: 'Покупки', color: 'gold' },
        { id: 'call', name: 'Звонки', color: 'work' }, { id: 'health', name: 'Здоровье', color: 'study' },
        { id: 'home', name: 'Дом', color: 'personal' }] }) },
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
      h01: L({ topic: 'docs', pin: true, remind: { kind: 'lead', min: 60 } }), h02: L({ topic: 'docs' }),
      h03: L({ topic: 'buy', pin: true, slot: { s: '20:00', e: '21:00' } }), h04: L({ topic: 'buy' }), h05: L({ topic: 'buy' }),
      h06: L({ topic: 'call', slot: { s: '19:00', e: '19:30' } }), h07: L({ topic: 'call' }),
      h08: L({ topic: 'health', remind: { kind: 'lead', min: 60 } }), h09: L({ topic: 'health' }),
      h10: L({ topic: 'home', pin: true, repeat: { every: 'month' } }), h11: L({ topic: 'home' }), h12: L({ topic: 'home' }),
      h13: L({ topic: 'home', repeat: { every: 'month' } }),
    },
    habits: {}, log: {}, cals: {}, templates: {}, templatesEdit: {},
    // Сферы — как на макетах «Создать» (Create.dc.html): Работа · Творчество · Личное.
    spheres: { sWork: L({ name: 'Работа', color: 'work', icon: 'case', order: 0 }), sArt: L({ name: 'Творчество', color: 'clay', icon: 'brush', order: 0.5 }),
      sMe: L({ name: 'Личное', color: 'personal', icon: 'home', order: 1 }) },
    settings: { setup: L({ done: true }) },
  };
}
