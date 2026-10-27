// Общий Telegram-бот Спутника на Cloudflare Workers. Логика — logic.js, хранилище — store.js (D1).
// Секреты воркера: BOT_TOKEN (токен от @BotFather), TG_SECRET (проверка, что вебхук зовёт Telegram),
// OWNER_CHAT и OWNER_HOOK — чат владельца и адрес его личного бота на Apps Script (reminders/Bot.gs, doPost):
// бот у них общий, и сообщения владельца уходят туда, как раньше.
// Выкладка и настройка — bot/README.md.

import { onUpdate, link, putState, tick, sha256, MAX_STATE } from './logic.js';
import { d1Store } from './store.js';
import { briefTick, NEWS_URL } from './brief.js';

const CORS = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'GET, POST, PUT, OPTIONS', 'Access-Control-Allow-Headers': 'Authorization, Content-Type' };
// Секрет, переданный через PowerShell, может прийти с BOM и переводом строки — чистим.
const clean = (s) => String(s ?? '').replace(/^\uFEFF/, '').trim();
// data.json сборки новостей (tools/news/) — с кешем Cloudflare на 5 минут, чтобы не дёргать Pages каждую минуту.
const news = async () => {
  const r = await fetch(NEWS_URL + 'data.json', { cf: { cacheTtl: 300, cacheEverything: true } });
  return r.ok ? r.json() : null;
};
const json = (body, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json; charset=utf-8', ...CORS } });

function telegram(env) {
  return async (method, body) => {
    const r = await fetch(`https://api.telegram.org/bot${clean(env.BOT_TOKEN)}/${method}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
    if (r.ok) return r.json();
    const text = await r.text();
    // Telegram не разобрал разметку (например, «<» в названии) — тот же текст без тегов.
    if (r.status === 400 && /can't parse entities/i.test(text) && body.text) {
      const plain = body.text.replace(/<[^>]+>/g, '').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&');
      const { parse_mode, ...rest } = body;
      return telegram(env)(method, { ...rest, text: plain });
    }
    throw new Error(`Telegram ${r.status}: ${text.slice(0, 200)}`);
  };
}

export default {
  async fetch(req, env, ctx) {
    const url = new URL(req.url);
    if (req.method === 'OPTIONS') return new Response(null, { headers: CORS });
    const store = d1Store(env.DB);
    const tg = telegram(env);
    try {
      if (url.pathname === '/ping') return json({ ok: true, bot: env.BOT_NAME ?? '' });
      if (url.pathname === '/tg' && req.method === 'POST') {
        if (req.headers.get('X-Telegram-Bot-Api-Secret-Token') !== clean(env.TG_SECRET)) return new Response('нет', { status: 403 });
        const u = await req.json();
        const chat = String(u.message?.chat?.id ?? u.callback_query?.message?.chat?.id ?? u.callback_query?.from?.id ?? '');
        if (env.OWNER_CHAT && env.OWNER_HOOK && chat === String(env.OWNER_CHAT)) {
          // Apps Script отвечает несколько секунд — Telegram не ждёт, пересылаем в фоне.
          ctx.waitUntil(fetch(env.OWNER_HOOK, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(u) }).catch((e) => console.error('Личный бот: ' + e)));
          return new Response('ok');
        }
        await onUpdate(u, { store, tg, news });
        return new Response('ok');
      }
      if (url.pathname === '/link' && req.method === 'POST') {
        const r = await link(await req.json(), { store, tg, ip: req.headers.get('CF-Connecting-IP') ?? '' });
        return json(r.body, r.status);
      }
      // Дальше — только трекер с ключом, который он получил при привязке.
      const key = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
      const user = key.length >= 32 ? await store.userByKey(await sha256(key)) : null;
      if (!user) return json({ error: 'Бот не подключён', unlinked: true }, 401);
      if (url.pathname === '/state' && req.method === 'PUT') {
        const text = await req.text();
        if (text.length > MAX_STATE) return json({ error: 'Слишком большой список' }, 413);
        const r = await putState(user.chat, JSON.parse(text), { store });
        return json(r.body, r.status);
      }
      if (url.pathname === '/inbox' && req.method === 'GET') return json({ items: await store.inbox(user.chat), muted: !!user.muted });
      if (url.pathname === '/ack' && req.method === 'POST') { await store.ack(user.chat, ((await req.json()).ids ?? []).map(Number)); return json({ ok: true }); }
      if (url.pathname === '/test' && req.method === 'POST') { await tg('sendMessage', { chat_id: user.chat, text: 'Спутник: проверка связи — напоминания доходят ✓' }); return json({ ok: true }); }
      if (url.pathname === '/unlink' && req.method === 'POST') { await store.unlink(user.chat); return json({ ok: true }); }
      return json({ error: 'нет такого адреса' }, 404);
    } catch (e) {
      console.error(e);
      return json({ error: String(e?.message ?? e) }, 500);
    }
  },
  async scheduled(_ev, env, ctx) {
    const store = d1Store(env.DB), tg = telegram(env);
    ctx.waitUntil(tick({ store, tg }));
    ctx.waitUntil(briefTick({ store, tg, news }).catch((e) => console.error('Сводка: ' + e)));
  },
};
