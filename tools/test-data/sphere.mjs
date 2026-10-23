#!/usr/bin/env node
// Спутник · тестовая сфера «Тест» в рабочем аккаунте: по списку на каждый вид доски и много наглядных задач.
//
//   node tools/test-data/sphere.mjs          создать
//   node tools/test-data/sphere.mjs --clean  удалить всё, что создал скрипт
//
// Берёт вход трекера (token.json и client_secret.json в %APPDATA%\com.siponik.sputnik), отдельного входа не нужно.
// Задачи создаёт прямо в Google Tasks, а поля Спутника (сфера, вид и шаблон списка, колонки, приоритеты, темы, время…)
// дописывает в копию слоя на Google Drive (appDataFolder) — трекер подхватит их при ближайшей синхронизации,
// закрывать его не нужно. Если синхронизация слоя не включена, пишет в layer.json (тогда трекер надо закрыть).
// Без внешних зависимостей: Node 18+.

import { readFile, writeFile, copyFile, rm } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { createInterface } from 'node:readline/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { homedir } from 'node:os';

const HERE = dirname(fileURLToPath(import.meta.url));
const APP = process.env.SPUTNIK_APP_DIR || join(process.env.APPDATA || join(homedir(), '.config'), 'com.siponik.sputnik');
const STATE = join(HERE, '.sphere-state.json');
const SPHERE = 'test-sphere';
const LAYER_FILE = 'sputnik-layer.json';

// ---------- вход ----------

async function access() {
  const need = (f) => { if (!existsSync(join(APP, f))) { console.error(`Не найден ${join(APP, f)}.\nСначала войди в Google в самом трекере.`); process.exit(1); } };
  need('token.json'); need('client_secret.json');
  const tok = JSON.parse(await readFile(join(APP, 'token.json'), 'utf8'));
  const raw = JSON.parse(await readFile(join(APP, 'client_secret.json'), 'utf8'));
  const c = raw.installed || raw.web;
  if (!tok.refresh_token) { console.error('В token.json нет refresh_token — войди в Google в трекере заново.'); process.exit(1); }
  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ client_id: c.client_id, client_secret: c.client_secret || '', refresh_token: tok.refresh_token, grant_type: 'refresh_token' }),
  });
  const j = await r.json();
  if (!r.ok) throw new Error(`Google отказал во входе: ${j.error_description || j.error || r.status}`);
  return j.access_token; // token.json трекера не трогаем
}

let ACCESS = '';
async function api(method, url, body, raw = false) {
  const r = await fetch(url, {
    method,
    headers: { authorization: `Bearer ${ACCESS}`, ...(body !== undefined ? { 'content-type': 'application/json' } : {}) },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  if (r.status === 204) return null;
  const text = await r.text();
  if (!r.ok) { const e = new Error(`${method} ${url.split('?')[0]} → ${r.status}: ${text.slice(0, 300)}`); e.status = r.status; throw e; }
  return raw ? text : text ? JSON.parse(text) : null;
}
const TASKS = 'https://tasks.googleapis.com/tasks/v1';
const DRIVE = 'https://www.googleapis.com/drive/v3';
const UPLOAD = 'https://www.googleapis.com/upload/drive/v3';

// ---------- даты ----------

const today = new Date();
today.setHours(0, 0, 0, 0);
const day = (n) => { const d = new Date(today); d.setDate(d.getDate() + n); return d; };
const ymd = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const due = (n) => `${ymd(day(n))}T00:00:00.000Z`;
const ago = (days) => Date.now() - days * 864e5;
const nextDow = (dow) => { const d = today.getDay(); return ((dow - d + 7) % 7) || 7; }; // через сколько дней ближайший день недели
const FRI = nextDow(5);

// ---------- что создаём ----------
// Поле L — запись слоя задачи (status — колонка/этап, priority 1–3, type, slot, repeat, remind, spent, pin, topic, client, money…).
// subs — подзадачи: { title, done?, L? }.

const H = { kind: 'lead', min: 60 }, M15 = { kind: 'lead', min: 15 }, D1 = { kind: 'lead', min: 1440 };

const LISTS = [
  { key: 'kanban', title: 'Тест · Канбан', layer: { template: 'work', view: 'kanban' }, tasks: [
    { title: 'Ответить продюсеру по срокам', due: 0, L: { status: 'inbox', priority: 1, type: 'work', slot: { s: '11:00', e: '11:30' }, remind: M15 } },
    { title: 'Разобрать почту за неделю', due: 0, L: { status: 'inbox', priority: 3, type: 'work' } },
    { title: 'Подготовить бриф для аутсорса', notes: 'Стиль — lowpoly, палитра из референсов.\nБюджет до 40 тыс.', due: 2, L: { status: 'inbox', priority: 2, type: 'work' } },
    { title: 'Созвон с арт-директором', due: 1, L: { status: 'inbox', type: 'work', slot: { s: '15:00', e: '16:00' }, remind: H } },
    { title: 'Идеи для нового пета', L: { status: 'inbox', type: 'creative' } },
    { title: 'Еженедельный отчёт', due: FRI, L: { status: 'inbox', priority: 2, type: 'work', repeat: { every: 'week' }, remind: D1 } },
    { title: 'Просроченный отчёт по багам', due: -2, L: { status: 'inbox', priority: 1, type: 'work' } },
    { title: 'Концепт локации «Пристань»', due: 3, L: { status: 'doing', priority: 1, type: 'creative', spent: 135 }, subs: [
      { title: 'Мудборд', done: true }, { title: 'Три скетча композиции', done: true }, { title: 'Цветовые этюды' }, { title: 'Показать на ревью' },
    ] },
    { title: 'Иконки интерфейса, пак 2', due: 0, L: { status: 'doing', priority: 2, type: 'creative', slot: { s: '14:00', e: '17:00' }, spent: 50 } },
    { title: 'Онбординг нового джуна', notes: 'Доступы, гайд по пайплайну, первая задача.', due: 4, L: { status: 'doing', type: 'work' } },
    { title: 'Ревью сцены от Миши', due: 1, L: { status: 'review', priority: 2, type: 'work' } },
    { title: 'Пропсы для таверны', due: -1, L: { status: 'review', type: 'creative', spent: 240 } },
    { title: 'Настроить экспорт в Unity', done: true, L: { type: 'work' } },
    { title: 'Палитра проекта', done: true, L: { type: 'creative' } },
    { title: 'Старый бэклог (давно сделано)', done: true, doneDaysAgo: 6, L: { type: 'work' } },
  ] },
  { key: 'orders', title: 'Тест · Заказы', layer: { template: 'client', view: 'kanban' }, tasks: [
    { title: 'Логотип для кофейни', due: 5, L: { status: 'request', client: 'Кофейня «Зерно»', money: '15 000 ₽', type: 'work' } },
    { title: 'Персонаж для мобильной игры', notes: 'Нужен в трёх позах, стилизация как у Supercell.', due: 9, L: { status: 'estimate', priority: 1, client: 'Studio North', money: '120 000 ₽', type: 'creative' } },
    { title: 'Набор пропсов «Кухня»', due: 2, L: { status: 'doing', priority: 2, client: 'Indie Forge', money: '45 000 ₽', type: 'creative', spent: 300 }, subs: [
      { title: 'Кастрюли и сковородки', done: true }, { title: 'Стол и табуреты' }, { title: 'Текстуры' },
    ] },
    { title: 'Обложка для подкаста', due: 0, L: { status: 'revise', priority: 1, client: 'Подкаст «Полигон»', money: '8 000 ₽', type: 'creative', remind: H } },
    { title: 'Стикерпак для Telegram', due: -1, L: { status: 'delivered', client: 'Маша К.', money: '6 000 ₽', type: 'creative' } },
    { title: 'Иллюстрация к статье', done: true, L: { client: 'Блог «Рендер»', money: '10 000 ₽', type: 'creative' } },
  ] },
  { key: 'pipe', title: 'Тест · Конвейер', layer: { template: 'asset3d', view: 'pipe' }, tasks: [
    { title: 'Сундук пирата', due: 6, L: { status: 'refs', type: 'creative', stageAt: { refs: ago(1) } }, subs: [
      { title: 'Собрать референсы на Pinterest', done: true, L: { stage: 'refs' } }, { title: 'Выбрать стиль ковки', L: { stage: 'refs' } },
    ] },
    { title: 'Фонарь на столбе', due: 4, L: { status: 'blockout', priority: 2, type: 'creative', stageAt: { refs: ago(5), blockout: ago(2) }, spent: 70 } },
    { title: 'Голова орка', notes: 'Хайполи для портфолио, потом запечь на лоуполи.', due: 10, L: { status: 'sculpt', priority: 1, type: 'creative', stageAt: { refs: ago(12), blockout: ago(9), sculpt: ago(4) }, spent: 610 }, subs: [
      { title: 'Формы черепа', done: true, L: { stage: 'sculpt' } }, { title: 'Клыки и уши', done: true, L: { stage: 'sculpt' } },
      { title: 'Морщины и поры', L: { stage: 'sculpt' } }, { title: 'Проверить силуэт', L: { stage: 'sculpt' } },
    ] },
    { title: 'Бочка с элем', due: 0, L: { status: 'retopo', priority: 2, type: 'creative', stageAt: { refs: ago(8), blockout: ago(6), sculpt: ago(4), retopo: ago(1) }, slot: { s: '18:00', e: '20:00' } } },
    { title: 'Меч рыцаря', due: -1, L: { status: 'uv', priority: 1, type: 'creative', stageAt: { refs: ago(15), blockout: ago(13), sculpt: ago(11), retopo: ago(8), uv: ago(6) }, spent: 420 }, subs: [
      { title: 'Развернуть клинок', done: true, L: { stage: 'uv' } }, { title: 'Гарда и рукоять', L: { stage: 'uv' } }, { title: 'Упаковать острова', L: { stage: 'uv' } },
    ] },
    { title: 'Таверна · вывеска', due: 3, L: { status: 'textures', type: 'creative', stageAt: { refs: ago(14), blockout: ago(12), sculpt: ago(10), retopo: ago(8), uv: ago(5), textures: ago(2) }, spent: 380 } },
    { title: 'Скамья лоуполи', due: 1, L: { status: 'render', type: 'creative', stageAt: { refs: ago(9), blockout: ago(8), retopo: ago(6), uv: ago(5), textures: ago(3), render: ago(0) }, spent: 260 } },
    { title: 'Кружка', done: true, L: { type: 'creative', spent: 180 } },
  ] },
  { key: 'stickers', title: 'Тест · Стикеры', layer: { template: 'personal', view: 'stickers', group: 'topic' }, tasks: [
    { title: 'Продлить страховку', due: 0, L: { topic: 'docs', pin: true, priority: 1, remind: H } },
    { title: 'Заполнить декларацию', due: 8, L: { topic: 'docs' } },
    { title: 'Сделать копию паспорта', L: { topic: 'docs' } },
    { title: 'Купить молоко и хлеб', due: 0, L: { topic: 'buy' } },
    { title: 'Новый стилус для планшета', notes: 'Wacom Pro Pen 3, сравнить цены.', due: 3, L: { topic: 'buy', priority: 2 } },
    { title: 'Подарок маме', due: 5, L: { topic: 'buy', pin: true } },
    { title: 'Позвонить в сервис по ноутбуку', due: 1, L: { topic: 'call', slot: { s: '10:00', e: '10:15' }, remind: M15 } },
    { title: 'Позвонить бабушке', L: { topic: 'call', repeat: { every: 'week' } } },
    { title: 'Записаться к стоматологу', due: 2, L: { topic: 'health', priority: 1 } },
    { title: 'Витамины', due: 0, L: { topic: 'health', repeat: { every: 'day' } } },
    { title: 'Полить цветы', due: 0, L: { topic: 'home', repeat: { every: 'weekdays' } } },
    { title: 'Поменять лампочку в коридоре', L: { topic: 'home' } },
    { title: 'Разобрать балкон', due: 12, L: { topic: 'home' } },
    { title: 'Вернуть книгу другу', L: {} },
    { title: 'Оплатить интернет', done: true, L: { topic: 'docs' } },
    { title: 'Вынести коробки', done: true, L: { topic: 'home' } },
  ] },
  { key: 'list', title: 'Тест · Список', layer: { template: 'study', view: 'list' }, tasks: [
    { title: 'Курс по Substance Painter', due: 7, L: { status: 'doing', priority: 1, type: 'study', spent: 200 }, subs: [
      { title: 'Урок 1 · Интерфейс', done: true }, { title: 'Урок 2 · Маски', done: true }, { title: 'Урок 3 · Генераторы', done: true },
      { title: 'Урок 4 · Смарт-материалы' }, { title: 'Урок 5 · Экспорт' },
    ] },
    { title: 'Анатомия для художников', due: 0, L: { status: 'doing', type: 'study', slot: { s: '20:00', e: '21:00' }, repeat: { every: 'weekdays' } }, subs: [
      { title: 'Торс', done: true }, { title: 'Руки' }, { title: 'Ноги' }, { title: 'Голова' },
    ] },
    { title: 'Geometry Nodes с нуля', due: 14, L: { status: 'inbox', priority: 2, type: 'study' }, subs: [
      { title: 'Введение' }, { title: 'Скаттер' }, { title: 'Процедурный забор' },
    ] },
    { title: 'Книга «Цвет и свет», Гурни', L: { status: 'inbox', type: 'study' } },
    { title: 'Английский: 20 минут', due: 0, L: { status: 'doing', priority: 3, type: 'study', repeat: { every: 'day' } } },
    { title: 'Блендер: горячие клавиши', done: true, L: { type: 'study' } },
  ] },
];

// ---------- слой на Drive (appDataFolder) или локально ----------

async function findLayerFile() {
  const q = encodeURIComponent(`name='${LAYER_FILE}' and trashed=false`);
  const r = await api('GET', `${DRIVE}/files?spaces=appDataFolder&q=${q}&fields=files(id,modifiedTime)&orderBy=modifiedTime desc&pageSize=10`);
  return r?.files?.[0]?.id ?? null;
}

// patch — { раздел: { ключ: запись } }; запись дописывается поверх старой с новым t, как touch в трекере.
function apply(lay, patch, t) {
  for (const [s, recs] of Object.entries(patch)) {
    lay[s] ??= {};
    for (const [k, v] of Object.entries(recs)) lay[s][k] = v.gone ? { gone: true, t } : { ...(lay[s][k]?.gone ? {} : lay[s][k] ?? {}), ...v, t };
  }
  return lay;
}

async function writeLayer(patch) {
  const t = Date.now();
  try {
    const id = await findLayerFile();
    const cur = id ? JSON.parse(await api('GET', `${DRIVE}/files/${id}?alt=media`, undefined, true)) : { version: 1 };
    const next = apply(cur, patch, t);
    let fid = id;
    if (!fid) fid = (await api('POST', `${DRIVE}/files?fields=id`, { name: LAYER_FILE, parents: ['appDataFolder'], mimeType: 'application/json' })).id;
    await api('PATCH', `${UPLOAD}/files/${fid}?uploadType=media`, next);
    console.log('✓ Поля Спутника записаны в облачную копию слоя — трекер подхватит их за 1–2 минуты');
    return;
  } catch (e) {
    if (e.status !== 403 && e.status !== 401) throw e;
    console.log('\nСинхронизация слоя через Google Drive у трекера ещё не включена — запишу поля в layer.json на этом компьютере.');
  }
  const file = join(APP, 'layer.json');
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  await rl.question('Закрой трекер Спутник полностью (и в трее), потом нажми Enter… ');
  rl.close();
  const cur = existsSync(file) ? JSON.parse(await readFile(file, 'utf8')) : { version: 1 };
  if (existsSync(file)) await copyFile(file, join(APP, `layer.before-test-${ymd(today)}.json`));
  await writeFile(file, JSON.stringify(apply(cur, patch, t), null, 2));
  console.log('✓ Поля Спутника записаны в layer.json (копия прежнего — layer.before-test-…json рядом). Можно открывать трекер.');
}

// ---------- создание ----------

async function seed() {
  if (existsSync(STATE)) { console.error('Тестовая сфера уже создана. Удалить её: node tools/test-data/sphere.mjs --clean'); process.exit(1); }
  const st = { lists: [], tasks: [] };
  const save = () => writeFile(STATE, JSON.stringify(st, null, 2));
  const patch = { spheres: { [SPHERE]: { name: 'Тест', color: 'gold', icon: 'star', order: 99, removed: false } }, lists: {}, tasks: {} };
  let n = 0;

  for (const list of LISTS) {
    const l = await api('POST', `${TASKS}/users/@me/lists`, { title: list.title });
    st.lists.push(l.id); await save();
    patch.lists[l.id] = { ...list.layer, sphere: SPHERE };
    for (const task of [...list.tasks].reverse()) { // Google ставит новую задачу наверх
      const body = { title: task.title, ...(task.notes ? { notes: task.notes } : {}), ...(task.due !== undefined ? { due: due(task.due) } : {}) };
      if (task.done) { body.status = 'completed'; if (task.doneDaysAgo) body.completed = new Date(ago(task.doneDaysAgo)).toISOString(); }
      const created = await api('POST', `${TASKS}/lists/${l.id}/tasks`, body);
      st.tasks.push(created.id); n++;
      if (task.L && Object.keys(task.L).length) patch.tasks[created.id] = task.L;
      for (const sub of [...(task.subs || [])].reverse()) {
        const s = await api('POST', `${TASKS}/lists/${l.id}/tasks?parent=${created.id}`, { title: sub.title, ...(sub.done ? { status: 'completed' } : {}) });
        st.tasks.push(s.id); n++;
        if (sub.L) patch.tasks[s.id] = sub.L;
      }
    }
    await save();
    console.log(`✓ «${list.title}»: ${list.tasks.length} задач`);
  }

  await writeLayer(patch);
  console.log(`\nГотово: сфера «Тест», ${LISTS.length} списков, ${n} задач вместе с подзадачами.\nУдалить всё: node tools/test-data/sphere.mjs --clean`);
}

async function clean() {
  if (!existsSync(STATE)) { console.log('Тестовой сферы нет, удалять нечего.'); return; }
  const st = JSON.parse(await readFile(STATE, 'utf8'));
  for (const id of st.lists) await api('DELETE', `${TASKS}/users/@me/lists/${id}`).catch((e) => console.warn('  пропуск:', e.message));
  console.log(`✓ Удалено списков: ${st.lists.length}`);
  const gone = (ids) => Object.fromEntries(ids.map((id) => [id, { gone: true }]));
  await writeLayer({ spheres: { [SPHERE]: { removed: true } }, lists: gone(st.lists), tasks: gone(st.tasks) });
  await rm(STATE);
  console.log('\nТестовая сфера удалена.');
}

try {
  ACCESS = await access();
  if (process.argv.includes('--clean')) await clean(); else await seed();
} catch (e) {
  console.error('\nОшибка: ' + e.message);
  if (existsSync(STATE)) console.error('Всё, что успело создаться, удалит: node tools/test-data/sphere.mjs --clean');
  process.exit(1);
}
