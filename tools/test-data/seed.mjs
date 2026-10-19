#!/usr/bin/env node
// Спутник · тестовые данные в Google.
//
//   node tools/test-data/seed.mjs          создать песочницу
//   node tools/test-data/seed.mjs --clean  удалить всё, что создал скрипт
//
// Нужен ключ приложения: D:\Project\client_secret.json (OAuth client, тип Desktop app).
// Путь можно переопределить переменной SPUTNIK_CLIENT_SECRET.
// Без внешних зависимостей: Node 18+.

import { createServer } from 'node:http';
import { readFile, writeFile, rm } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { randomBytes, createHash } from 'node:crypto';
import { exec } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(HERE, '..', '..');
const SECRET = process.env.SPUTNIK_CLIENT_SECRET || resolve(REPO, '..', 'client_secret.json');
const TOKEN = join(HERE, '.token.json');
const STATE = join(HERE, '.state.json');
const SCOPES = [
  'https://www.googleapis.com/auth/tasks',
  'https://www.googleapis.com/auth/calendar',
  'https://www.googleapis.com/auth/drive.file',
];
const TZ = 'Europe/Moscow';
const PREFIX = 'Тест · ';

// ---------- вход в Google (OAuth для установленных приложений, PKCE) ----------

async function loadClient() {
  if (!existsSync(SECRET)) {
    console.error(`Не найден ключ приложения: ${SECRET}\nСкачайте JSON из Google Cloud → Credentials (Desktop app) и сохраните под этим именем.`);
    process.exit(1);
  }
  const raw = JSON.parse(await readFile(SECRET, 'utf8'));
  const c = raw.installed || raw.web;
  if (!c?.client_id) { console.error('В client_secret.json нет client_id. Нужен ключ типа Desktop app.'); process.exit(1); }
  return c;
}

function openBrowser(url) {
  const cmd = process.platform === 'win32' ? `start "" "${url}"` : process.platform === 'darwin' ? `open "${url}"` : `xdg-open "${url}"`;
  exec(cmd, () => {});
}

async function authorize(client) {
  if (existsSync(TOKEN)) {
    const t = JSON.parse(await readFile(TOKEN, 'utf8'));
    if (t.refresh_token) return refresh(client, t);
  }
  const verifier = randomBytes(32).toString('base64url');
  const challenge = createHash('sha256').update(verifier).digest('base64url');
  const state = randomBytes(12).toString('hex');

  const { code, redirect } = await new Promise((ok, fail) => {
    const srv = createServer((req, res) => {
      const u = new URL(req.url, 'http://127.0.0.1');
      if (u.pathname !== '/') { res.writeHead(404).end(); return; }
      const err = u.searchParams.get('error');
      const got = u.searchParams.get('code');
      res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
      res.end(err ? `<p>Вход отменён: ${err}. Окно можно закрыть.</p>` : '<p>Готово, Спутник получил доступ. Окно можно закрыть.</p>');
      srv.close();
      if (err) fail(new Error('Вход отменён: ' + err));
      else if (u.searchParams.get('state') !== state) fail(new Error('Ответ Google не совпал с запросом, попробуйте ещё раз.'));
      else ok({ code: got, redirect: `http://127.0.0.1:${srv.address().port}` });
    });
    srv.listen(0, '127.0.0.1', () => {
      const port = srv.address().port;
      const url = new URL('https://accounts.google.com/o/oauth2/v2/auth');
      url.search = new URLSearchParams({
        client_id: client.client_id,
        redirect_uri: `http://127.0.0.1:${port}`,
        response_type: 'code',
        scope: SCOPES.join(' '),
        code_challenge: challenge,
        code_challenge_method: 'S256',
        access_type: 'offline',
        prompt: 'consent',
        state,
      }).toString();
      console.log('Открываю браузер для входа в Google. Если не открылся, перейдите по ссылке:\n' + url + '\n');
      openBrowser(url.toString());
    });
  });

  const tok = await postForm('https://oauth2.googleapis.com/token', {
    code, client_id: client.client_id, client_secret: client.client_secret || '',
    redirect_uri: redirect, grant_type: 'authorization_code', code_verifier: verifier,
  });
  await writeFile(TOKEN, JSON.stringify(tok, null, 2));
  return tok.access_token;
}

async function refresh(client, t) {
  const tok = await postForm('https://oauth2.googleapis.com/token', {
    client_id: client.client_id, client_secret: client.client_secret || '',
    refresh_token: t.refresh_token, grant_type: 'refresh_token',
  });
  await writeFile(TOKEN, JSON.stringify({ ...t, ...tok }, null, 2));
  return tok.access_token;
}

async function postForm(url, body) {
  const r = await fetch(url, { method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams(body) });
  const j = await r.json();
  if (!r.ok) throw new Error(`Google отказал во входе: ${j.error_description || j.error || r.status}`);
  return j;
}

// ---------- запросы к API ----------

let ACCESS = '';
async function api(method, url, body) {
  const r = await fetch(url, {
    method,
    headers: { authorization: `Bearer ${ACCESS}`, ...(body ? { 'content-type': 'application/json' } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (r.status === 204) return null;
  const text = await r.text();
  const j = text ? JSON.parse(text) : null;
  if (!r.ok) throw new Error(`${method} ${url.split('?')[0]} → ${r.status}: ${j?.error?.message || text}`);
  return j;
}
const TASKS = 'https://tasks.googleapis.com/tasks/v1';
const CAL = 'https://www.googleapis.com/calendar/v3';
const DRIVE = 'https://www.googleapis.com/drive/v3';
const UPLOAD = 'https://www.googleapis.com/upload/drive/v3';

// ---------- даты ----------

const today = new Date();
today.setHours(0, 0, 0, 0);
const day = (n) => { const d = new Date(today); d.setDate(d.getDate() + n); return d; };
const ymd = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const due = (n) => `${ymd(day(n))}T00:00:00.000Z`; // в Google Tasks у срока есть только дата
const at = (n, hh, mm = 0) => `${ymd(day(n))}T${String(hh).padStart(2, '0')}:${String(mm).padStart(2, '0')}:00`;

// ---------- что создаём ----------

const LISTS = {
  work: { title: PREFIX + 'Работа', tasks: [
    { key: 'artstation', title: 'Сменить пароль ArtStation', notes: 'Новый вход из Стокгольма.', due: 0 },
    { key: 'refs', title: 'Референсы для таверны', due: 3 },
    { key: 'estimate', title: 'Смета по набору иконок', notes: 'Клиент ждёт до пятницы.', due: 4 },
    { key: 'tower', title: 'Башня · ретопология', due: 4, subtasks: [
      { title: 'Крыша и шпиль', done: true }, { title: 'Стены и окна', done: true },
      { title: 'Лестница' }, { title: 'Проверить нормали' },
    ] },
    { key: 'icons', title: 'Правки по иконкам для клиента', notes: 'Толще обводка, без градиента.', due: 0, subtasks: [
      { title: 'Обводка 2px', done: true }, { title: 'Убрать градиент', done: true },
      { title: 'Экспорт SVG' }, { title: 'Отправить клиенту' },
    ] },
    { key: 'review', title: 'Ревью lowpoly-башни', due: 1 },
    { key: 'blockout', title: 'Блокаут башни', done: true, due: -3 },
    { key: 'iconsv1', title: 'Набор иконок v1', done: true, due: -5 },
  ] },
  personal: { title: PREFIX + 'Личное', tasks: [
    { key: 'portfolio', title: 'Обновить портфолио', due: 6 },
    { key: 'dentist', title: 'Записаться к стоматологу' },
  ] },
  study: { title: PREFIX + 'Учёба', tasks: [
    { key: 'gn', title: 'Урок по Geometry Nodes, часть 3', due: -2 },
    { key: 'anatomy-book', title: 'Прочитать главу про кисти рук', due: 5 },
  ] },
  habits: { title: PREFIX + 'Привычки', tasks: [
    { key: 'h-sketch', title: 'Скетч 20 минут', due: 0 },
    { key: 'h-sculpt', title: 'Скульпт в Blender', due: 0 },
    { key: 'h-anatomy', title: 'Анатомия, 30 минут', due: 0 },
    { key: 'h-walk', title: 'Прогулка без телефона', due: 0 },
  ] },
};

const EVENTS = [
  { key: 'review', summary: 'Ревью lowpoly-башни', start: at(1, 16), end: at(1, 16, 45) },
  { key: 'icons', summary: 'Правки по иконкам', start: at(0, 18), end: at(0, 19) },
  { summary: 'Стрим про стилизацию лоуполи', start: at(3, 19), end: at(3, 20, 30) },
  { summary: 'Созвон с клиентом по иконкам', start: at(2, 11), end: at(2, 11, 30) },
];

// Слой Спутника: то, чего нет в Google. Ключи — задачи по key, после создания — по id.
function layer(ids) {
  const t = (key, extra) => ({ [ids[key]]: extra });
  const history = (pattern) => { // pattern(i) → true, если в день «i дней назад» сделано
    const out = [];
    for (let i = 84; i >= 1; i--) if (pattern(i)) out.push(ymd(day(-i)));
    return out;
  };
  return {
    version: 1,
    test: true,
    updatedAt: new Date().toISOString(),
    types: ['plain', 'work', 'asset', 'meeting', 'study', 'habit'],
    pipeline: ['Референсы', 'Блокаут', 'Скульпт', 'Ретопология', 'UV', 'Текстуры', 'Рендер'],
    projects: [
      { id: 'tower', name: 'Башня · lowpoly', type: 'asset' },
      { id: 'tavern', name: 'Таверна', type: 'asset' },
      { id: 'client-icons', name: 'Иконки для клиента', type: 'work' },
      { id: 'portfolio', name: 'Портфолио', type: 'plain' },
    ],
    tasks: {
      ...t('artstation', { type: 'work', status: 'inbox', priority: 'high', source: 'gmail' }),
      ...t('refs', { type: 'asset', project: 'tavern', status: 'inbox', stage: 0, tags: ['lowpoly'] }),
      ...t('estimate', { type: 'work', project: 'client-icons', status: 'inbox' }),
      ...t('tower', { type: 'asset', project: 'tower', status: 'doing', stage: 3, priority: 'high', tags: ['lowpoly', 'tavern-set'], estimateMin: 180, spentMin: 80 }),
      ...t('icons', { type: 'work', project: 'client-icons', status: 'doing', time: '18:00' }),
      ...t('review', { type: 'meeting', project: 'tower', status: 'review', time: '16:00', durationMin: 45 }),
      ...t('blockout', { type: 'asset', project: 'tower', status: 'done', stage: 1 }),
      ...t('iconsv1', { type: 'work', project: 'client-icons', status: 'done' }),
      ...t('portfolio', { type: 'plain', project: 'portfolio' }),
      ...t('gn', { type: 'study' }),
      ...t('anatomy-book', { type: 'study' }),
      ...t('h-sketch', { type: 'habit', schedule: [0, 1, 2, 3, 4, 5, 6], history: history((i) => i <= 6 || (i >= 20 && i <= 40) || (i !== 7 && i !== 19 && i !== 41 && (i * 7 + 3) % 10 < 6)) }),
      ...t('h-sculpt', { type: 'habit', schedule: [0, 1, 2, 3, 4, 5, 6], history: history((i) => i <= 12 || (i !== 13 && (i * 3 + 3) % 10 < 5)) }),
      ...t('h-anatomy', { type: 'habit', schedule: [0, 2, 4], history: history((i) => { const dow = (day(-i).getDay() + 6) % 7; return [0, 2, 4].includes(dow) && (i <= 12 || (i * 9 + 3) % 10 < 7); }) }),
      ...t('h-walk', { type: 'habit', schedule: [0, 1, 2, 3, 4, 5, 6], history: history((i) => i !== 1 && ((i >= 10 && i <= 18) || (i !== 9 && i !== 19 && (i + 3) % 10 < 5))) }),
    },
  };
}

// ---------- создание ----------

async function seed() {
  if (existsSync(STATE)) { console.error('Песочница уже создана. Сначала удалите её: node tools/test-data/seed.mjs --clean'); process.exit(1); }
  const st = { lists: [], calendar: null, folder: null, files: [] };
  const save = () => writeFile(STATE, JSON.stringify(st, null, 2));
  const ids = {};

  for (const list of Object.values(LISTS)) {
    const l = await api('POST', `${TASKS}/users/@me/lists`, { title: list.title });
    st.lists.push(l.id); await save();
    for (const task of [...list.tasks].reverse()) { // API ставит новую задачу наверх
      const body = { title: task.title, notes: task.notes, ...(task.due !== undefined ? { due: due(task.due) } : {}) };
      if (task.done) body.status = 'completed';
      const created = await api('POST', `${TASKS}/lists/${l.id}/tasks`, body);
      ids[task.key] = created.id;
      for (const sub of [...(task.subtasks || [])].reverse()) {
        await api('POST', `${TASKS}/lists/${l.id}/tasks?parent=${created.id}`, { title: sub.title, ...(sub.done ? { status: 'completed' } : {}) });
      }
    }
    console.log(`✓ Список «${list.title}»: ${list.tasks.length} задач`);
  }

  const cal = await api('POST', `${CAL}/calendars`, { summary: 'Спутник · тест', timeZone: TZ, description: 'Песочница Спутника. Удаляется командой seed.mjs --clean.' });
  st.calendar = cal.id; await save();
  for (const e of EVENTS) {
    await api('POST', `${CAL}/calendars/${encodeURIComponent(cal.id)}/events`, {
      summary: e.summary,
      start: { dateTime: e.start, timeZone: TZ },
      end: { dateTime: e.end, timeZone: TZ },
      extendedProperties: { private: { sputnikTest: '1', ...(e.key && ids[e.key] ? { sputnikTask: ids[e.key] } : {}) } },
    });
  }
  console.log(`✓ Календарь «Спутник · тест»: ${EVENTS.length} события`);

  const folder = await api('POST', `${DRIVE}/files`, { name: 'Спутник · тест', mimeType: 'application/vnd.google-apps.folder', appProperties: { sputnikTest: '1' } });
  st.folder = folder.id; await save();
  const boundary = 'sputnik' + randomBytes(6).toString('hex');
  const meta = { name: 'sputnik-layer.json', parents: [folder.id], appProperties: { sputnikTest: '1' } };
  const multipart = `--${boundary}\r\ncontent-type: application/json; charset=UTF-8\r\n\r\n${JSON.stringify(meta)}\r\n--${boundary}\r\ncontent-type: application/json\r\n\r\n${JSON.stringify(layer(ids), null, 2)}\r\n--${boundary}--`;
  const r = await fetch(`${UPLOAD}/files?uploadType=multipart`, { method: 'POST', headers: { authorization: `Bearer ${ACCESS}`, 'content-type': `multipart/related; boundary=${boundary}` }, body: multipart });
  if (!r.ok) throw new Error('Не удалось загрузить слой Спутника: ' + (await r.text()));
  st.files.push((await r.json()).id); await save();
  console.log('✓ Папка «Спутник · тест» на Drive со слоем Спутника (типы, этапы, проекты, история привычек)');

  console.log('\nГотово. Задачи видны в Google Tasks, события — в календаре «Спутник · тест».\nУдалить всё: node tools/test-data/seed.mjs --clean');
}

async function clean() {
  if (!existsSync(STATE)) { console.log('Песочницы нет, удалять нечего.'); return; }
  const st = JSON.parse(await readFile(STATE, 'utf8'));
  for (const id of st.lists) await api('DELETE', `${TASKS}/users/@me/lists/${id}`).catch((e) => console.warn('  пропуск:', e.message));
  console.log(`✓ Удалено списков задач: ${st.lists.length}`);
  if (st.calendar) { await api('DELETE', `${CAL}/calendars/${encodeURIComponent(st.calendar)}`).catch((e) => console.warn('  пропуск:', e.message)); console.log('✓ Календарь «Спутник · тест» удалён'); }
  if (st.folder) { await api('DELETE', `${DRIVE}/files/${st.folder}`).catch((e) => console.warn('  пропуск:', e.message)); console.log('✓ Папка «Спутник · тест» удалена'); }
  await rm(STATE);
  console.log('\nПесочница удалена.');
}

const client = await loadClient();
ACCESS = await authorize(client);
try {
  if (process.argv.includes('--clean')) await clean(); else await seed();
} catch (e) {
  console.error('\nОшибка: ' + e.message);
  if (existsSync(STATE)) console.error('Всё, что успело создаться, удалит: node tools/test-data/seed.mjs --clean');
  process.exit(1);
}
