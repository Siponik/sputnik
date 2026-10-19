#!/usr/bin/env node
// Спутник · прочитать задачи из Google Tasks (только чтение).
//
//   node tools/tasks/list.mjs                 — все списки с числом открытых задач
//   node tools/tasks/list.mjs "разработка"    — задачи списков, в названии которых есть это слово
//   node tools/tasks/list.mjs "разработка" --done   — вместе с выполненными
//
// Вход — тот же, что у add.mjs и tools/test-data/seed.mjs (client_secret.json и сохранённый токен).
// Если входа ещё нет, сначала запусти add.mjs — он откроет браузер.

import { readFile, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(HERE, '..', '..');
const SECRET = process.env.SPUTNIK_CLIENT_SECRET
  || [resolve(REPO, 'client_secret.json'), resolve(REPO, '..', 'client_secret.json')].find((p) => existsSync(p));
const SEED_TOKEN = resolve(REPO, 'tools', 'test-data', '.token.json');
const TOKEN = existsSync(SEED_TOKEN) ? SEED_TOKEN : join(HERE, '.token.json');
const TASKS = 'https://tasks.googleapis.com/tasks/v1';

async function access() {
  if (!SECRET || !existsSync(TOKEN)) throw new Error('Нет входа в Google: сначала запусти node tools/tasks/add.mjs');
  const raw = JSON.parse(await readFile(SECRET, 'utf8'));
  const c = raw.installed || raw.web;
  const t = JSON.parse(await readFile(TOKEN, 'utf8'));
  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ client_id: c.client_id, client_secret: c.client_secret || '', refresh_token: t.refresh_token, grant_type: 'refresh_token' }),
  });
  const j = await r.json();
  if (!r.ok) throw new Error('Вход устарел — запусти node tools/tasks/add.mjs, он войдёт заново');
  await writeFile(TOKEN, JSON.stringify({ ...t, ...j }, null, 2));
  return j.access_token;
}

async function all(token, url) {
  const out = [];
  let page = '';
  do {
    const r = await fetch(url + (url.includes('?') ? '&' : '?') + 'maxResults=100' + (page ? '&pageToken=' + page : ''), { headers: { authorization: `Bearer ${token}` } });
    const j = await r.json();
    if (!r.ok) throw new Error(`${r.status}: ${j?.error?.message}`);
    out.push(...(j.items || []));
    page = j.nextPageToken || '';
  } while (page);
  return out;
}

const [filter = '', ...flags] = process.argv.slice(2);
const withDone = flags.includes('--done');
const token = await access();
const lists = await all(token, `${TASKS}/users/@me/lists`);

if (!filter) {
  for (const l of lists) {
    const open = (await all(token, `${TASKS}/lists/${l.id}/tasks?showCompleted=false`)).filter((t) => !t.parent).length;
    console.log(`${l.title} — открытых: ${open}`);
  }
} else {
  for (const l of lists.filter((x) => x.title.toLowerCase().includes(filter.toLowerCase()))) {
    const items = await all(token, `${TASKS}/lists/${l.id}/tasks?showCompleted=${withDone}&showHidden=${withDone}`);
    const byPos = (a, b) => (a.position || '').localeCompare(b.position || '');
    console.log(`\n=== ${l.title} (${items.filter((t) => !t.parent).length}) ===`);
    for (const t of items.filter((x) => !x.parent).sort(byPos)) {
      const due = t.due ? ` [срок ${t.due.slice(0, 10)}]` : '';
      console.log(`- ${t.status === 'completed' ? '✓ ' : ''}${t.title}${due}  (обновлена ${t.updated.slice(0, 10)})`);
      if (t.notes) console.log(t.notes.split('\n').map((s) => '    ' + s).join('\n'));
      for (const s of items.filter((x) => x.parent === t.id).sort(byPos)) console.log(`    · ${s.status === 'completed' ? '✓ ' : ''}${s.title}`);
    }
  }
}
