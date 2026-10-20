// Вебхук бота ждёт ту же блокировку, что и tick(), и отпускает её (reminders/Bot.gs → doPost).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

function setup(canLock) {
  const log = [];
  const props = { TELEGRAM_BOT_TOKEN: 'x', TELEGRAM_CHAT_ID: '1' };
  const ctx = vm.createContext({
    console, JSON, Date,
    Utilities: { computeDigest: () => [1, 2, 3], DigestAlgorithm: {}, Charset: {}, formatDate: () => '2026-10-21' },
    PropertiesService: { getScriptProperties: () => ({ getProperty: (k) => props[k] ?? null, setProperty: (k, v) => { props[k] = v; }, deleteProperty: () => {} }) },
    LockService: { getScriptLock: () => ({ tryLock: (ms) => { log.push('lock ' + ms); return canLock; }, releaseLock: () => log.push('release') }) },
    HtmlService: { createHtmlOutput: (s) => s },
    CacheService: { getScriptCache: () => ({ get: () => null, put: () => {} }) },
    UrlFetchApp: { fetch: (url) => { log.push(url.split('/').pop()); return { getResponseCode: () => 200, getContentText: () => '{"ok":true}' }; } },
  });
  for (const f of ['Code.gs', 'Bot.gs', 'BotTasks.gs']) vm.runInContext(readFileSync(new URL(`../../reminders/${f}`, import.meta.url), 'utf8'), ctx, { filename: f });
  const key = ctx.hookKey_();
  const post = (k = key) => ctx.doPost({ parameter: { k }, postData: { contents: JSON.stringify({ update_id: 7, message: { chat: { id: 1 }, text: '/help' } }) } });
  return { log, post };
}

test('ответ под блокировкой, блокировка отпускается', () => {
  const { log, post } = setup(true);
  assert.equal(post(), 'ok');
  assert.ok(log.includes('sendMessage'));
  assert.deepEqual([log[0], log.at(-1)], ['lock 20000', 'release']);
});

test('не дождались блокировки — всё равно отвечаем и ничего не отпускаем', () => {
  const { log, post } = setup(false);
  post();
  assert.ok(log.includes('sendMessage'));
  assert.ok(!log.includes('release'));
});

test('чужой ключ — ни блокировки, ни ответа', () => {
  const { log, post } = setup(true);
  post('wrong');
  assert.deepEqual(log, []);
});
