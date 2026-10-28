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
  { id: 'Lload', title: 'Тест · нагрузка' },
];

// «Тест · нагрузка» — плотная неделя (как тестовая сфера пользователя, ~80 задач): проверка вёрстки календаря.
// Сроки — по дням текущей недели (пн = mon), часть со временем (слой ниже), часть выполнена или просрочена.
const mon = -((new Date().getDay() + 6) % 7);
const LOAD = [
  ['Попс', 0, 1], ['Доработка окна создания', 0, 1], ['Просроченный отчёт по багам', 0], ['Тест Спутника: ревью', 0],
  ['Фиксы', 1, 1], ['Переделать енота: голова в шлеме', 1, 1], ['Пропсы для таверны', 1], ['Стикерпак для Telegram', 1], ['Меч рыцаря', 1],
  ['Разобрать почту за неделю', 2], ['Обложка для подкаста', 2], ['Продлить страховку', 2], ['Купить молоко и хлеб', 2], ['Витамины', 2],
  ['Полить цветы', 2], ['Английский: 20 минут', 2], ['Ответить продюсеру по срокам', 2], ['Иконки интерфейса, пак 2', 2], ['Бочка с элем', 2],
  ['Анатомия для художников', 2], ['Отправить Клоду ноты', 2], ['Скетч персонажа', 2], ['Счёт за свет', 2],
  ['Ревью сцены от М.', 3], ['Скамья лоуполи', 3], ['Созвон с арт-директором', 3], ['Рендер витрины', 3], ['Ретопология сапога', 3],
  ['Подготовить бриф', 4], ['Еженедельный отчёт', 4], ['Набор пропсов «Кузня»', 4], ['Записаться к стоматологу', 4], ['Текстуры сундука', 4],
  ['Концепт локации', 5], ['Таверна · вывеска', 5], ['Новый стилус для планшета', 5], ['Уборка мастерской', 5],
  ['Онбординг нового клиента', 6], ['Фонарь на столбе', 6], ['План на следующую неделю', 6], ['Бэкап проектов', 6],
];
const SLOTS = { 'Тест Спутника: ревью': ['16:00', '17:00'], 'Ответить продюсеру по срокам': ['11:00', '11:30'], 'Иконки интерфейса, пак 2': ['14:00', '17:00'],
  'Бочка с элем': ['18:00', '20:00'], 'Анатомия для художников': ['20:00', '21:00'], 'Отправить Клоду ноты': ['23:00', '23:45'],
  'Созвон с арт-директором': ['15:00', '16:00'], 'Рендер витрины': ['10:00', '13:00'], 'Еженедельный отчёт': ['09:00', '10:00'], 'Уборка мастерской': ['12:00', '14:00'] };

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
      // «Входящие от Claude» (status ниже): Claude положил в «Личное», «Сегодня» угадывает, куда им на самом деле.
      T('Отправить смету по набору иконок', { id: 'c1', notes: 'Клиент просит смету до пятницы · письмо от вчера', due: 2 }),
      T('Посмотреть стрим про стилизацию лоуполи', { id: 'c2', notes: 'Приглашение на завтра, 19:00 · 80 Level', due: 1 }),
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
    Lhab: [T('Скетч 15 минут', { id: 'h1' }), T('Зарядка', { id: 'h2' }), T('Вода', { id: 'h3' }), T('Чтение', { id: 'h4' }),
      T('Без телефона после 23:00', { id: 'h5' }), T('Английский 15 мин', { id: 'h6' })],
    Lload: LOAD.map(([title, d, done], i) => T(title, { id: 'z' + i, due: mon + d, ...(done ? { done: 1 } : {}) })),
  };
}

// Привычки как на макете «Привычки: карточки» (Habits.dc.html): серии, срыв, количество, «3 раза в неделю».
function demoHabits(L) {
  const habits = {
    h1: L({ icon: 'pencil', color: 'gold', part: 'evening', time: '21:00', end: '22:00', createdAt: ymd(-60) }),
    h2: L({ icon: 'gym', color: 'clay', part: 'morning', time: '07:30', end: '08:15', createdAt: ymd(-40) }),
    h3: L({ icon: 'cup', color: 'work', part: 'morning', goal: { n: 8, unit: 'стаканов' }, createdAt: ymd(-50) }),
    h4: L({ icon: 'book', color: 'personal', part: 'evening', time: '22:30', createdAt: ymd(-45) }),
    h5: L({ icon: 'moon', color: 'done', part: 'evening', time: '23:00', createdAt: ymd(-30) }),
    h6: L({ icon: 'lang', color: 'study', part: 'any', perWeek: 3, createdAt: ymd(-35) }),
  };
  const log = {};
  const put = (id, d, v) => { log[`${id}|${ymd(d)}`] = L(v); };
  for (let d = -34; d <= -1; d++) put('h1', d, { done: true });
  for (let d = -20; d <= 0; d++) if (d !== -12) put('h2', d, { done: true });
  for (let d = -21; d <= -1; d++) put('h3', d, d === -5 ? { n: 5, done: false } : { n: 8, done: true });
  put('h3', 0, { n: 5, done: false });
  for (let d = -16; d <= -4; d++) if (d !== -14) put('h4', d, { done: true });
  for (let d = -10; d <= -1; d++) if (d !== -3 && d !== -4) put('h5', d, { done: true });
  for (const d of [-1, -3, -6, -8, -10, -13, -15, -17, -20, -22, -24]) put('h6', d, { done: true });
  return { habits, log };
}

export function seedLayer() {
  const t = Date.now();
  const L = (o) => ({ ...o, t });
  return {
    version: 1,
    lists: { Lwork: L({ template: 'work', sphere: 'sWork' }), L3d: L({ template: 'asset3d', view: 'pipe', sphere: 'sArt' }), Lme: L({ template: 'personal' }), Lhab: L({ template: 'habits' }), Lload: L({ template: 'work', sphere: 'sTest' }),
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
      ...Object.fromEntries(LOAD.map(([title], i) => [title, i]).filter(([title]) => SLOTS[title])
        .map(([title, i]) => ['z' + i, L({ slot: { s: SLOTS[title][0], e: SLOTS[title][1] } })])),
    },
    ...demoHabits(L), cals: {}, templates: {}, templatesEdit: {},
    // Сферы — как на макетах «Создать» (Create.dc.html): Работа · Творчество · Личное.
    spheres: { sWork: L({ name: 'Работа', color: 'work', icon: 'case', order: 0 }), sArt: L({ name: 'Творчество', color: 'clay', icon: 'brush', order: 0.5 }),
      sMe: L({ name: 'Личное', color: 'personal', icon: 'home', order: 1 }), sTest: L({ name: 'Тест', color: 'study', icon: 'star', order: 2 }) },
    settings: { setup: L({ done: true }) },
  };
}

/** Статус «Входящих от Claude» (событие «Спутник · статус» в очереди): две задачи ждут «Принять / Отклонить». */
export const seedInbox = () => ({ processed: { demo1: { ok: true, from: 'из утренней сводки', at: iso(0),
  created: [{ op: 'task.create', taskId: 'c1' }, { op: 'task.create', taskId: 'c2' }] } } });

// Общие сферы (docs/design-v2.md, «Общие сферы»; макеты design/screens/Share*.dc.html): календари сфер с записями,
// как их пишет lib/shared.js. Ты — владелец «Таверны» (с Аней и Максом, Вика ещё не приняла приглашение) и участник «Семьи» у Оли.
import { make, toEvent, MARK, SPHERE_KEY, memberKey } from '../lib/sharedcore.js';
export const DEMO_ME = 'siponik@gmail.com';
const ANYA = 'anya@gmail.com', MAX = 'max@gmail.com', VIKA = 'vika@gmail.com', OLYA = 'olya@gmail.com';
const key = (p, n) => p + String(n).padStart(16, '0');
export function seedShared() {
  const t = Date.now() - 36e5;
  const R = (k, f) => make(k, f, t);
  const member = (email, name, order, joined = true, seen = undefined) => R(memberKey(email), { email, name, order, joined, ...(seen ? { seen } : {}) });
  const task = (n, list, title, f = {}) => R(key('t', n), { list, title, notes: '', status: 'needsAction', pos: String(100 + n).padStart(20, '0'), ...f });
  const LA = key('l', 1), LT = key('l', 2), LB = key('l', 3);
  const tavern = [
    R(SPHERE_KEY, { name: 'Таверна', color: 'clay', icon: 'cube', owner: DEMO_ME }),
    member(DEMO_ME, 'Сипоник', 0), member(ANYA, 'Аня', 1, true, t), member(MAX, 'Макс', 2), member(VIKA, 'Вика', 3, false),
    R(LA, { title: 'Ассеты таверны', created: 1, $template: 'asset3d', $view: 'pipe' }),
    R(LT, { title: 'Задачи команды', created: 2, $template: 'work' }),
    task(1, LA, 'Стойка бармена', { due: due(0), $status: 'sculpt', $project: 'Таверна', $who: DEMO_ME, $priority: 1,
      $stageWho: { refs: ANYA, blockout: DEMO_ME, sculpt: DEMO_ME, retopo: DEMO_ME, uv: MAX, textures: ANYA, render: ANYA },
      $stageAt: { refs: ago(8), blockout: ago(6), sculpt: ago(3) } }),
    task(2, LA, 'Сундук с золотом', { due: due(-1), $status: 'uv', $project: 'Таверна', $who: MAX, $stageWho: { refs: ANYA, blockout: ANYA, sculpt: DEMO_ME, retopo: DEMO_ME, textures: ANYA }, $stageAt: { uv: ago(2) } }),
    task(3, LA, 'Вывеска таверны', { $status: 'refs', $project: 'Таверна' }),
    task(4, LA, 'Лестница на 2 этаж', { due: due(8), $status: 'retopo', $project: 'Таверна', $who: DEMO_ME, $stageWho: { refs: ANYA, blockout: MAX, sculpt: MAX, uv: MAX }, $stageAt: { retopo: ago(1) } }),
    task(5, LA, 'Пропсы: бочки и ящики', { due: due(1), $status: 'refs', $project: 'Таверна', $who: ANYA }),
    task(6, LA, 'Стол и стулья', { status: 'completed', completed: new Date(ago(4)).toISOString(), $project: 'Таверна', $who: MAX }),
    task(7, LT, 'Собрать референсы по свету', { due: due(2), $who: ANYA }),
    task(8, LT, 'Созвон по сцене', { due: due(0), $status: 'doing', $slot: { s: '16:00', e: '16:30' }, $who: DEMO_ME }),
    task(9, LT, 'Обновить ТЗ на мебель', { $status: 'review', $who: MAX }),
    task(10, LT, 'Список звуков для таверны', {}),
  ];
  const family = [
    R(SPHERE_KEY, { name: 'Семья', color: 'study', icon: 'star', owner: OLYA }),
    member(OLYA, 'Оля', 0), member(DEMO_ME, 'Сипоник', 1),
    R(LB, { title: 'Покупки', created: 1, $template: 'personal', $view: 'stickers',
      $topics: [{ id: 'food', name: 'Еда', color: 'personal' }, { id: 'home', name: 'Дом', color: 'gold' }] }),
    task(11, LB, 'Молоко и хлеб', { due: due(0), $topic: 'food', $who: DEMO_ME }),
    task(12, LB, 'Подарок маме', { due: due(5), $topic: 'home', $who: OLYA }),
    task(13, LB, 'Батарейки для пульта', { $topic: 'home' }),
    task(14, LB, 'Сыр к ужину', { $topic: 'food', $who: OLYA }),
  ];
  // Приглашение: Аня позвала, я ещё не принял — плашка «Аня зовёт тебя в сферу» на «Сегодня» и доске.
  const LC = key('l', 4);
  const cafe = [
    R(SPHERE_KEY, { name: 'Кафе «Ёж»', color: 'personal', icon: 'heart', owner: ANYA }),
    member(ANYA, 'Аня', 0), member(MAX, 'Макс', 1), member(DEMO_ME, 'Сипоник', 2, false),
    R(LC, { title: 'Меню и вывески', created: 1, $template: 'work' }),
    task(21, LC, 'Логотип кафе', { $who: ANYA }), task(22, LC, 'Меню на доске', {}), task(23, LC, 'Табличка «открыто»', { $who: MAX }),
  ];
  const cal = (id, summary, role, recs) => ({ id, summary, role, description: `${MARK} v1 — служебный календарь общей сферы Спутника.`, recs: recs.map(toEvent) });
  return [cal('tavern@group.calendar.google.com', 'Спутник · сфера Таверна', 'owner', tavern),
    cal('family@group.calendar.google.com', 'Спутник · сфера Семья', 'writer', family),
    cal('cafe@group.calendar.google.com', 'Спутник · сфера Кафе', 'writer', cafe)];
}
