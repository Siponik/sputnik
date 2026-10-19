#!/usr/bin/env node
// Спутник · списки и задачи в Google Tasks по плану из plan.json.
//
//   node tools/tasks/add.mjs
//
// Повторный запуск безопасен: существующие списки и задачи с тем же названием не дублируются.
// Вход в Google — как в tools/test-data/seed.mjs (тот же client_secret.json и, если есть, тот же токен).
// Без внешних зависимостей: Node 18+.

import { createServer } from 'node:http';
import { readFile, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { randomBytes, createHash } from 'node:crypto';
import { exec } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(HERE, '..', '..');
const SECRET = process.env.SPUTNIK_CLIENT_SECRET
  || [resolve(REPO, 'client_secret.json'), resolve(REPO, '..', 'client_secret.json')].find((p) => existsSync(p))
  || resolve(REPO, 'client_secret.json');
const SEED_TOKEN = resolve(REPO, 'tools', 'test-data', '.token.json');
const TOKEN = existsSync(SEED_TOKEN) ? SEED_TOKEN : join(HERE, '.token.json');
const SCOPES = ['https://www.googleapis.com/auth/tasks'];
const TASKS = 'https://tasks.googleapis.com/tasks/v1';

async function loadClient() {
  if (!existsSync(SECRET)) { console.error(`Не найден ключ приложения: ${SECRET}`); process.exit(1); }
  const raw = JSON.parse(await readFile(SECRET, 'utf8'));
  const c = raw.installed || raw.web;
  if (!c?.client_id) { console.error('В client_secret.json нет client_id. Нужен ключ типа Desktop app.'); process.exit(1); }
  return c;
}

async function postForm(url, body) {
  const r = await fetch(url, { method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams(body) });
  const j = await r.json();
  if (!r.ok) throw new Error(`Google отказал во входе: ${j.error_description || j.error || r.status}`);
  return j;
}

async function authorize(client) {
  if (existsSync(TOKEN)) {
    const t = JSON.parse(await readFile(TOKEN, 'utf8'));
    if (t.refresh_token) {
      try {
        const tok = await postForm('https://oauth2.googleapis.com/token', {
          client_id: client.client_id, client_secret: client.client_secret || '',
          refresh_token: t.refresh_token, grant_type: 'refresh_token',
        });
        await writeFile(TOKEN, JSON.stringify({ ...t, ...tok }, null, 2));
        return tok.access_token;
      } catch { console.log('Старый вход устарел, войдём заново.'); }
    }
  }
  const verifier = randomBytes(32).toString('base64url');
  const challenge = createHash('sha256').update(verifier).digest('base64url');
  const state = randomBytes(12).toString('hex');
  const { code, redirect } = await new Promise((ok, fail) => {
    let port = 0;
    const srv = createServer((req, res) => {
      const u = new URL(req.url, 'http://127.0.0.1');
      if (u.pathname !== '/') { res.writeHead(404).end(); return; }
      const err = u.searchParams.get('error');
      res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
      res.end(err ? `<p>Вход отменён: ${err}. Окно можно закрыть.</p>` : '<p>Готово, Спутник получил доступ. Окно можно закрыть.</p>');
      srv.close();
      if (err) fail(new Error('Вход отменён: ' + err));
      else if (u.searchParams.get('state') !== state) fail(new Error('Ответ Google не совпал с запросом, попробуйте ещё раз.'));
      else ok({ code: u.searchParams.get('code'), redirect: `http://127.0.0.1:${port}` });
    });
    srv.listen(0, '127.0.0.1', () => {
      port = srv.address().port;
      const url = new URL('https://accounts.google.com/o/oauth2/v2/auth');
      url.search = new URLSearchParams({
        client_id: client.client_id, redirect_uri: `http://127.0.0.1:${port}`, response_type: 'code',
        scope: SCOPES.join(' '), code_challenge: challenge, code_challenge_method: 'S256',
        access_type: 'offline', prompt: 'consent', state,
      }).toString();
      console.log('Открываю браузер для входа в Google. Если не открылся, перейдите по ссылке:\n' + url + '\n');
      const cmd = process.platform === 'win32' ? `start "" "${url}"` : `xdg-open "${url}"`;
      exec(cmd, () => {});
    });
  });
  const tok = await postForm('https://oauth2.googleapis.com/token', {
    code, client_id: client.client_id, client_secret: client.client_secret || '',
    redirect_uri: redirect, grant_type: 'authorization_code', code_verifier: verifier,
  });
  await writeFile(TOKEN, JSON.stringify(tok, null, 2));
  return tok.access_token;
}

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

async function all(url) {
  const out = [];
  let page = '';
  do {
    const j = await api('GET', url + (url.includes('?') ? '&' : '?') + 'maxResults=100' + (page ? '&pageToken=' + page : ''));
    out.push(...(j.items || []));
    page = j.nextPageToken || '';
  } while (page);
  return out;
}

async function main() {
  const plan = JSON.parse(await readFile(join(HERE, 'plan.json'), 'utf8'));
  ACCESS = await authorize(await loadClient());
  const lists = await all(`${TASKS}/users/@me/lists`);
  for (const l of plan.lists) {
    let list = lists.find((x) => x.title === l.title);
    if (list) console.log(`Список «${l.title}» уже есть.`);
    else { list = await api('POST', `${TASKS}/users/@me/lists`, { title: l.title }); console.log(`Создан список «${l.title}».`); }
    const have = await all(`${TASKS}/lists/${list.id}/tasks?showCompleted=true&showHidden=true`);
    for (const t of [...(l.tasks || [])].reverse()) {
      if (have.some((x) => x.title === t.title)) { console.log(`  · уже есть: ${t.title}`); continue; }
      await api('POST', `${TASKS}/lists/${list.id}/tasks`, { title: t.title, notes: t.notes || undefined, due: t.due || undefined });
      console.log(`  + ${t.title}`);
    }
  }
  console.log('\nГотово. Проверь Google Tasks (в Календаре справа или в приложении «Задачи»).');
}

main().catch((e) => { console.error('\nОшибка: ' + e.message); process.exit(1); });
