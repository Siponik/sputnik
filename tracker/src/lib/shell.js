// Шапка 0.6, «Состояние», обновления, левая колонка и настройки — чистая логика (тесты: tests/shell.test.js).
// Спецификация — docs/design-v2.md, раздел «Шапка, левая колонка доски, «Состояние», обновления и настройки».

export const hm = (d) => (d ? new Date(d).toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' }) : '');

/**
 * Три точки «Состояния»: Google, между компьютерами, версия. Цвет: '' — всё хорошо (бирюзовая), 'w' — нужно действие
 * (золотая), 'e' — ошибка (красная); busy — идёт обмен (точка пульсирует).
 * sync = { busy, err, at }, offline — нет связи; cloud = { state: idle|busy|ok|login|err }; upd = { found, err }.
 */
export function statusDots({ sync, offline = false, cloud, upd }) {
  const g = { c: sync.err ? 'e' : '', busy: !!sync.busy };
  const l = { c: cloud.state === 'login' ? 'w' : cloud.state === 'err' ? 'e' : '', busy: cloud.state === 'busy' };
  const v = { c: upd.found ? 'w' : upd.err ? 'e' : '', busy: !!upd.busy };
  let label = hm(sync.at);
  if (offline) label = 'Нет связи';
  else if (cloud.state === 'login') label = 'Нужен вход';
  else if (sync.err) label = 'Ошибка';
  return { dots: [g, l, v], label };
}

/** Подпись строки «Google Задачи и Календарь» в «Состоянии». */
export function googleLine(sync, offline = false) {
  if (sync.busy) return { text: 'обновляю…', cls: '' };
  if (offline) return { text: 'нет связи — повторю через минуту', cls: 'e' };
  if (sync.err) return { text: sync.err, cls: 'e' };
  if (!sync.at) return { text: 'ещё не обновлялось', cls: '' };
  return { text: `обновлено в ${hm(sync.at)} · раз в 2 минуты`, cls: 'ok' };
}

/** Подпись строки «Между компьютерами». */
export function cloudLine(cloud) {
  if (cloud.state === 'login') return { text: 'нужно разрешить скрытую папку на Drive', cls: 'w' };
  if (cloud.state === 'err') return { text: cloud.err || 'не удалось синхронизировать', cls: 'e' };
  if (cloud.state === 'busy') return { text: 'синхронизирую…', cls: '' };
  if (cloud.state === 'ok' && cloud.at) return { text: `синхронизировано в ${hm(cloud.at)}`, cls: 'ok' };
  return { text: 'ещё не синхронизировано', cls: '' };
}

/** Подпись строки «Спутник <версия>». upd = { found, err, busy, progress, checkedAt }. */
export function versionLine(upd) {
  if (upd.busy) return { text: `ставлю ${upd.found?.version ?? ''} · ${Math.round((upd.progress || 0) * 100)}%`, cls: 'w' };
  if (upd.found) return { text: `вышла ${upd.found.version} · меньше минуты`, cls: 'c' };
  if (upd.err) return { text: upd.err, cls: 'e' };
  if (upd.checkedAt) return { text: `последняя версия · проверено в ${hm(upd.checkedAt)}`, cls: 'ok' };
  return { text: 'обновления проверяются сами', cls: '' };
}

/** Подпись строки «Напоминания в Telegram». rem = { at, n, err } — файл для своего бота;
 *  { shared: true, linked, err } — свой бот выключен, напоминания идут только через общий. */
export function remindLine(rem) {
  if (rem?.shared) {
    if (rem.err) return { text: rem.err, cls: 'e' };
    return rem.linked ? { text: 'через общий бот', cls: 'ok' } : { text: 'бот не подключён — Настройки → Напоминания', cls: 'w' };
  }
  if (rem?.err) return { text: rem.err, cls: 'e' };
  if (!rem?.at) return { text: 'файл ещё не обновлялся', cls: '' };
  return { text: `файл обновлён ${hm(rem.at)} · ${rem.n} впереди`, cls: 'ok' };
}

/**
 * Свой бот на Google Apps Script (reminders/Code.gs) есть только у владельца: у него скрипт ведёт «Входящие от Claude»
 * и пишет событие «Спутник · статус» (inbox — его содержимое). У остальных пользователей — только общий бот.
 * settings.ownBot = { v } — выбор вручную. show — показывать строку в настройках, on — писать файл напоминаний на Drive.
 */
export function ownBot(settings, inbox) {
  const v = settings?.ownBot?.v;
  const found = !!inbox;
  return { show: found || v === true, on: typeof v === 'boolean' ? v : found };
}

/** Бета-сборка: «0.7.3-beta.2» (ветка beta, .github/workflows/tracker-build.yml). */
export const isBeta = (v) => /-beta\.\d+$/.test(String(v ?? ''));

/**
 * Строка «Бета-версии» в Настройки → Обновления — только у владельца (у кого есть свой бот, см. ownBot), а ещё если
 * бета уже включена или стоит — чтобы её можно было выключить. settings.update.beta — проверять бета-канал.
 */
export const betaShow = (own, version, pref = {}) => !!own?.show || pref.beta === true || isBeta(version);

/** «Что нового»: первые n пунктов списка из заметки релиза (строки «- …», «* …», «• …»; иначе — строки как есть). */
export function notesOf(text, n = 3) {
  const lines = String(text ?? '').split(/\r?\n/).map((s) => s.trim()).filter(Boolean);
  const items = lines.filter((s) => /^[-*•✦]\s+/.test(s)).map((s) => s.replace(/^[-*•✦]\s+/, ''));
  return (items.length ? items : lines).slice(0, n);
}

/**
 * Показывать ли чип обновления в шапке: есть версия, она не пропущена и «Вечером» ещё не наступило.
 * pref = settings.update = { skip: '0.6.3', remindAt: <мс> }.
 */
export function showUpdChip(found, pref = {}, now = Date.now()) {
  if (!found) return false;
  if (pref.skip && pref.skip === found.version) return false;
  if (pref.remindAt && now < pref.remindAt) return false;
  return true;
}

/** «Вечером» — сегодня в 20:00, а если уже позже — завтра в 20:00. */
export function eveningAt(now = new Date()) {
  const d = new Date(now);
  d.setHours(20, 0, 0, 0);
  if (d <= now) d.setDate(d.getDate() + 1);
  return d.getTime();
}

/** Ночная установка: включена и сейчас 3:00–3:59. */
export const nightNow = (pref = {}, now = new Date()) => !!pref.night && now.getHours() === 3;

// ---------- левая колонка доски ----------

/**
 * Выезд откреплённой колонки: наведение — через inMs выезжает, уход — через outMs уезжает (вернулся раньше — остаётся).
 * Пока hold(true) (открыт фильтр, меню списка, тащим карточку) — не уезжает. set(open) — сообщить экрану.
 * timers — для тестов (по умолчанию обычные setTimeout/clearTimeout).
 */
export function slider({ inMs = 150, outMs = 300, set, timers = globalThis } = {}) {
  let open = false, inside = false, held = false, t = null;
  const clear = () => { if (t) timers.clearTimeout(t); t = null; };
  const go = (v) => { clear(); if (open !== v) { open = v; set?.(v); } };
  const later = (v, ms) => { clear(); if (!ms) go(v); else t = timers.setTimeout(() => go(v), ms); };
  return {
    get open() { return open; },
    enter() { inside = true; if (open) clear(); else later(true, inMs); },
    leave() { inside = false; if (!open) clear(); else if (!held) later(false, outMs); },
    hold(v) { held = !!v; if (held) clear(); else if (open && !inside) later(false, outMs); },
    show() { go(true); },
    /** Выдвинуть на время (клавиши [ ]): мышь не на колонке — уедет через ms. */
    peek(ms = 1500) { go(true); if (!inside && !held) later(false, ms); },
    hide() { held = false; go(false); },
    /** Анимации выключены — выезд мгновенный. */
    instant(v) { if (v) { inMs = 0; outMs = 0; } },
  };
}

/** Фильтр «Список…»: сферы и списки, где есть все слова запроса (ё = е). Сфера подходит — показываем все её списки. */
export function filterSide(query, spheres, listsOf, noSphere) {
  const norm = (s) => String(s ?? '').toLowerCase().replace(/ё/g, 'е');
  const words = norm(query).split(/\s+/).filter(Boolean);
  const hit = (s) => words.every((w) => norm(s).includes(w));
  if (!words.length) return { spheres: spheres.map((sp) => ({ sp, lists: listsOf(sp.id) })), noSphere, first: null };
  const out = [];
  for (const sp of spheres) {
    const all = listsOf(sp.id);
    const lists = hit(sp.name) ? all : all.filter((l) => hit(l.title));
    if (lists.length || hit(sp.name)) out.push({ sp, lists });
  }
  const rest = noSphere.filter((l) => hit(l.title));
  const first = out.flatMap((x) => x.lists)[0] ?? rest[0] ?? null;
  return { spheres: out, noSphere: rest, first, firstSphere: !first ? out[0]?.sp ?? null : null };
}

/**
 * Советы енота для доски: 2–3 штуки, { id, text, act, kind, ref }. kind — что делает ссылка:
 * 'task' (открыть задачу ref), 'col' (прокрутить к колонке ref), 'new' (новая задача).
 * open — открытые задачи доски (без подзадач); cols — колонки шаблона; colOf(task) — колонка; first — с чего начать
 * ({ task, why } или null).
 */
export function boardTips({ open, cols, colOf, first }) {
  const tips = [];
  if (!open.length) return [{ id: 'empty', text: 'Всё разобрано. Новые задачи — кнопкой «+ Добавить задачу» в колонке или «Создать».', act: 'Новая задача', kind: 'new' }];
  if (first) {
    const head = `Начни с «${first.task.title || 'Без названия'}»${first.why ? ` — ${first.why}` : ''}`;
    tips.push({ id: 'first', text: `${head}${head.endsWith('.') ? '' : '.'} Остальное подождёт.`, act: 'Открыть', kind: 'task', ref: first.task.id });
  }
  const n = (c) => open.filter((t) => colOf(t) === c.id).length;
  const lim = cols.find((c) => c.limit && n(c) >= c.limit - 1);
  if (lim) {
    const k = n(lim);
    tips.push({ id: 'limit', kind: 'col', ref: lim.id, act: `К «${lim.name}»`,
      text: k > lim.limit ? `В «${lim.name}» ${k} из ${lim.limit} — больше лимита. Закончи что-нибудь, прежде чем брать новое.`
        : `«${lim.name}» уже ${k} из ${lim.limit} — закончи одну, прежде чем брать новую.` });
  }
  const inbox = cols[0];
  const ni = inbox ? n(inbox) : 0;
  if (inbox && ni >= 3 && cols.length > 2) {
    tips.push({ id: 'inbox', kind: 'col', ref: inbox.id, act: `К «${inbox.name}»`, text: `Во «${inbox.name}» ${ni} — разбери: что в работу, что на потом.` });
  }
  return tips.slice(0, 3);
}

// ---------- Настройки: вкладки и поиск «Найти настройку» ----------

export const SETTINGS_TABS = [
  { id: 'look', name: 'Вид' },
  { id: 'show', name: 'Что показывать' },
  { id: 'rem', name: 'Напоминания' },
  { id: 'sync', name: 'Синхронизация' },
  { id: 'upd', name: 'Обновления' },
  { id: 'keys', name: 'Клавиши' },
];

/** Строки настроек для поиска: заголовок и пояснение (то, что видно на экране), плюс слова, которыми их ищут. */
export const SETTINGS_INDEX = [
  { tab: 'look', id: 'theme', title: 'Тема', hint: 'Тёмная — основная. «Как в Windows» переключается вместе с системой.', also: 'светлая цвет оформление' },
  { tab: 'look', id: 'accent', title: 'Акцент', hint: 'Цвет кнопок, выделения и подсветки', also: 'акцентный цвет оформление глина палитра' },
  { tab: 'look', id: 'motion', title: 'Анимации', hint: '«Минимум» — только мягкое появление. «Выкл» — всё сразу.', also: 'движение' },
  { tab: 'look', id: 'tabs', title: 'Порядок вкладок', hint: 'Сегодня, Календарь, Доска, Привычки — в каком порядке стоят в шапке. Клавиши 1–4 идут так же.', also: 'меню шапка разделы переставить порядок верхнее' },
  { tab: 'look', id: 'start', title: 'Открывать при запуске', hint: 'Какой раздел показывать первым', also: 'старт' },
  { tab: 'look', id: 'tips', title: 'Енот-советчик', hint: 'Советы внизу колонки доски', also: 'совет подсказки' },
  { tab: 'show', id: 'lists', title: 'Списки задач', hint: 'Какие списки видны на доске, в «Сегодня» и в календаре', also: 'скрыть показывать' },
  { tab: 'show', id: 'cals', title: 'Календари', hint: 'Какие календари Google показывать', also: 'скрыть показывать дни рождения праздники' },
  { tab: 'rem', id: 'tgbot', title: 'Telegram', hint: 'Общий бот: напоминания и задачи текстом', also: 'телеграм бот подключить код' },
  { tab: 'rem', id: 'bot', title: 'Свой бот (Apps Script)', hint: 'Только у владельца: файл напоминаний, проверка связи, выключить', also: 'телеграм бот проверить apps script выключить' },
  { tab: 'rem', id: 'rtask', title: 'Задачи — по умолчанию', hint: 'Напоминание, которое ставится новой задаче со сроком' },
  { tab: 'rem', id: 'revent', title: 'События', hint: 'Напоминание о событии по умолчанию' },
  { tab: 'rem', id: 'rbday', title: 'Дни рождения', hint: 'Напоминание о дне рождения по умолчанию' },
  { tab: 'rem', id: 'rhour', title: 'Задачи без времени', hint: 'Во сколько напоминать, если у задачи только дата, или не напоминать', also: 'выключить отключить уведомление' },
  { tab: 'rem', id: 'notify', title: 'Уведомления Windows', hint: 'Вехи привычек; основное — в боте' },
  { tab: 'sync', id: 'acct', title: 'Google-аккаунт', hint: 'Задачи, календарь, скрытая папка', also: 'выйти войти почта' },
  { tab: 'sync', id: 'google', title: 'Google Задачи и Календарь', hint: 'Обновляется само раз в 2 минуты', also: 'обновить синхронизация' },
  { tab: 'sync', id: 'cloud', title: 'Между компьютерами', hint: 'Слой Спутника в скрытой папке на Drive', also: 'синхронизация второй компьютер' },
  { tab: 'sync', id: 'dupes', title: 'Дубли задач', hint: 'Одинаковые задачи в одном списке', also: 'дубли копии повторы двойные' },
  { tab: 'sync', id: 'backup', title: 'Резервные копии', hint: 'Каждый день, хранятся 14', also: 'бэкап копия папка' },
  { tab: 'upd', id: 'ver', title: 'Версия Спутника', hint: 'Обновить или проверить обновления', also: 'обновление' },
  { tab: 'upd', id: 'auto', title: 'Проверять самому', hint: 'Через 30 секунд после запуска и раз в 6 часов', also: 'обновления автоматически' },
  { tab: 'upd', id: 'night', title: 'Ставить ночью', hint: 'Если компьютер включён — обновится в 3:00 без вопросов', also: 'обновления' },
  { tab: 'upd', id: 'all', title: 'Все версии', hint: 'Список изменений на GitHub', also: 'релизы' },
  { tab: 'keys', id: 'keys', title: 'Клавиши', hint: 'Горячие клавиши — работают и в русской раскладке', also: 'сочетания хоткеи' },
];

const norm = (s) => String(s ?? '').toLowerCase().replace(/ё/g, 'е');
/** Найти настройку: все слова запроса — в заголовке, пояснении или словах для поиска. Порядок — как на экране. */
export function searchSettings(query, index = SETTINGS_INDEX) {
  const words = norm(query).split(/\s+/).filter(Boolean);
  if (!words.length) return [];
  return index.filter((r) => { const t = norm(`${r.title} ${r.hint ?? ''} ${r.also ?? ''}`); return words.every((w) => t.includes(w)); });
}

/** ↑ ↓ по вкладкам настроек. */
export function stepTab(cur, dir, tabs = SETTINGS_TABS) {
  const i = tabs.findIndex((t) => t.id === cur);
  return tabs[(i + dir + tabs.length) % tabs.length].id;
}

// ---------- Порядок вкладок в шапке ----------

/** Вкладки шапки в исходном порядке. Свой порядок — settings.tabs.v (массив id), синхронизируется со слоем. */
export const VIEW_TABS = [
  { id: 'today', name: 'Сегодня' },
  { id: 'calendar', name: 'Календарь' },
  { id: 'board', name: 'Доска' },
  { id: 'habits', name: 'Привычки' },
];

/** Порядок вкладок из настройки: неизвестные и повторы отбрасываются, забытые (новые разделы) — в конец. */
export function tabOrder(saved, tabs = VIEW_TABS) {
  const ids = tabs.map((t) => t.id);
  const out = (Array.isArray(saved) ? saved : []).filter((id, i, a) => ids.includes(id) && a.indexOf(id) === i);
  return [...out, ...ids.filter((id) => !out.includes(id))];
}

/** Переставить вкладку id на место to (0…n−1). */
export function moveTab(order, id, to) {
  const rest = order.filter((x) => x !== id);
  if (rest.length === order.length) return order.slice();
  const i = Math.max(0, Math.min(rest.length, to));
  return [...rest.slice(0, i), id, ...rest.slice(i)];
}

/** Порядок совпадает с исходным — настройку можно не хранить. */
export const tabsDefault = (order, tabs = VIEW_TABS) => order.join() === tabs.map((t) => t.id).join();

/** С какого раздела открыться: settings.start = today | board | last; last — где остановился (если раздел ещё есть). */
export function startView(pref, last, views = ['today', 'calendar', 'board', 'habits']) {
  if (pref === 'board') return 'board';
  if (pref === 'last' && views.includes(last)) return last;
  return 'today';
}
