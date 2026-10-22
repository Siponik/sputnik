// Общий бот Спутника — логика без Cloudflare: команды, привязка, напоминания.
// Хранилище (store) и Telegram (tg) передаются снаружи: в воркере — D1 и fetch (store.js, index.js),
// в тестах — память (tracker/tests/shared-bot.test.js).
//
// Ключей Google здесь нет. Трекер сам присылает список напоминаний и задачи на неделю (PUT /state)
// и забирает то, что человек написал боту (GET /inbox) — задачи в Google создаёт уже трекер.

export const CODE_TTL = 15 * 60e3; // код привязки живёт 15 минут
export const LATE_LIMIT = 12 * 3600e3; // опоздавшее больше чем на 12 ч не шлём
export const KEEP_SENT = 3 * 864e5;
export const SNOOZE_MIN = 60;
export const LINK_TRIES = 10; // неверных кодов с одного адреса за час — потом ждать
export const MAX_STATE = 256 * 1024; // байт в PUT /state
const MONTHS = ['янв.', 'февр.', 'мар.', 'апр.', 'мая', 'июн.', 'июл.', 'авг.', 'сент.', 'окт.', 'нояб.', 'дек.'];
const DOW = ['вс', 'пн', 'вт', 'ср', 'чт', 'пт', 'сб'];

export const HELP = [
  '🛰 <b>Спутник</b>',
  'Пиши сюда задачи обычным текстом — «купить корм завтра 18:00» — они появятся в Спутнике.',
  '',
  '/today — задачи на сегодня',
  '/week — на неделю',
  '/off — не присылать напоминания, /on — снова присылать',
  '/unlink — отключить этот чат от Спутника',
].join('\n');

export const esc = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

/** Части даты в часовом поясе человека: { y, m, d, hh, mm, dow, ymd }. */
export function parts(date, tz) {
  const f = new Intl.DateTimeFormat('en-CA', { timeZone: tz || 'Europe/Moscow', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', weekday: 'short', hourCycle: 'h23' });
  const p = Object.fromEntries(f.formatToParts(date).map((x) => [x.type, x.value]));
  const dow = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].indexOf(p.weekday);
  return { y: +p.year, m: +p.month, d: +p.day, hh: +p.hour, mm: p.minute, dow, ymd: `${p.year}-${p.month}-${p.day}` };
}
const dayText = (ymd) => { const [, m, d] = ymd.split('-').map(Number); return `${d} ${MONTHS[m - 1]}`; };

/** Текст напоминания — как у личного бота (reminders/Code.gs, format_). */
export function format(item, tz) {
  if (item.kind === 'birthday') return `🎂 <b>${esc(item.title)}</b>\nДень рождения ${dayText(item.due)}${item.lead ? ` · <i>${esc(item.lead.toLowerCase())}</i>` : ''}`;
  if (item.kind === 'event') {
    const when = item.start ? (() => { const p = parts(new Date(item.start), tz); return `${dayText(p.ymd)}, ${p.hh}:${p.mm}`; })() : `${dayText(item.due)}, весь день`;
    return [`📅 <b>${esc(item.title)}</b>`, when, ...(item.note ? [esc(item.note)] : [])].join('\n');
  }
  if (item.kind === 'habit') { const p = parts(new Date(item.fireAt), tz); return `⏰ <b>${esc(item.title)}</b>\nПривычка · ${p.hh}:${p.mm}`; }
  const lines = [`${item.kind === 'milestone' || item.kind === 'test' ? '' : '🔔 '}<b>${esc(item.title)}</b>`];
  if (item.due) lines.push(`Срок: ${dayText(item.due)}`);
  if (item.note) lines.push(esc(item.note));
  if (item.list) lines.push(`<i>${esc(item.list)}</i>`);
  return lines.join('\n');
}

/** Задачи дня из снимка трекера: today = [{ title, due: 'ГГГГ-ММ-ДД', time?: 'ЧЧ:ММ', list? }]. */
export function agenda(today, tz, now, days = 1) {
  const p0 = parts(new Date(now), tz);
  const out = [];
  for (let i = 0; i < days; i++) {
    const p = parts(new Date(now + i * 864e5), tz);
    const items = (today ?? []).filter((t) => t.due === p.ymd || (i === 0 && t.due && t.due < p0.ymd))
      .sort((a, b) => (a.due < p0.ymd ? -1 : 0) - (b.due < p0.ymd ? -1 : 0) || (a.time ?? '99').localeCompare(b.time ?? '99'));
    if (days === 1 || items.length) {
      if (days > 1) out.push(`<b>${DOW[p.dow]}, ${dayText(p.ymd)}</b>`);
      for (const t of items) out.push(`• ${t.time ? `${t.time} ` : ''}${esc(t.title)}${t.due < p0.ymd ? ' <i>(просрочено)</i>' : ''}`);
    }
  }
  if (!out.length) return days === 1 ? 'На сегодня задач нет 🌙' : 'На неделю задач нет 🌙';
  return (days === 1 ? '<b>Сегодня</b>\n' : '') + out.join('\n');
}

export const newCode = (rand = Math.random) => String(Math.floor(100000 + rand() * 900000));

export async function sha256(text) {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

/** Ближайшее время, когда у человека что-то сработает (для выборки в cron). null — нечего ждать. */
export function nextAt(state, sentKeys, now) {
  let best = null;
  for (const it of [...(state.items ?? []), ...(state.snoozed ?? [])]) {
    const at = Date.parse(it.fireAt);
    if (!at || sentKeys.has(it.key) || now - at > LATE_LIMIT) continue;
    if (best === null || at < best) best = at;
  }
  return best;
}

// ---------- сообщения из Telegram ----------

export async function onUpdate(u, { store, tg, now = Date.now(), rand = Math.random }) {
  if (u.callback_query) return onButton(u.callback_query, { store, tg, now });
  const msg = u.message;
  if (!msg?.chat || msg.chat.type !== 'private') return;
  const chat = String(msg.chat.id);
  const text = String(msg.text ?? '').trim();
  const say = (t, markup) => tg('sendMessage', { chat_id: chat, text: t, parse_mode: 'HTML', disable_web_page_preview: true, ...(markup ? { reply_markup: markup } : {}) });
  const user = await store.user(chat);
  const cmd = (text.match(/^\/(\w+)/)?.[1] ?? '').toLowerCase();

  if (cmd === 'start' || (!user && !cmd && text)) {
    if (user && cmd === 'start') return say('Этот чат уже подключён к Спутнику ✓\n\n' + HELP);
    const code = newCode(rand);
    await store.putCode(code, chat, msg.from?.first_name ?? '', now + CODE_TTL);
    return say(`Привет! Я бот Спутника 🛰\n\nКод для подключения: <b>${code}</b>\nВведи его в Спутнике: «Настройки» → «Telegram». Код действует 15 минут.`);
  }
  if (cmd === 'help') return say(HELP);
  if (!user) return say('Сначала подключи Спутник: отправь /start и введи код в приложении.');
  if (cmd === 'today' || cmd === 'week') {
    const st = await store.state(chat);
    const head = st?.at && now - st.at > 864e5 ? '\n\n<i>Спутник давно не синхронизировался — список может быть старым.</i>' : '';
    return say(agenda(st?.today, user.tz, now, cmd === 'week' ? 7 : 1) + head);
  }
  if (cmd === 'off') { await store.setMuted(chat, true); return say('Напоминания на паузе. Включить — /on'); }
  if (cmd === 'on') { await store.setMuted(chat, false); return say('Напоминания снова включены ✓'); }
  if (cmd === 'unlink' || cmd === 'stop') { await store.unlink(chat); return say('Чат отключён от Спутника. Подключить снова — /start'); }
  if (cmd) return say('Не знаю такой команды.\n\n' + HELP);
  if (!text) return;
  await store.addInbox(chat, { type: 'add', text: text.slice(0, 1000), at: now });
  return say('📥 Записал. Задача появится в Спутнике при следующей синхронизации — когда он открыт, это пара минут.');
}

async function onButton(q, { store, tg, now }) {
  const chat = String(q.message?.chat?.id ?? q.from?.id ?? '');
  const [act, id] = String(q.data ?? '').split(':');
  const sent = id ? await store.sentById(chat, +id) : null;
  const answer = (text) => tg('answerCallbackQuery', { callback_query_id: q.id, text });
  if (!sent) return answer('Это напоминание уже не найти');
  const item = sent.item;
  if (act === 'd' && item.taskId) {
    await store.addInbox(chat, { type: 'done', taskId: item.taskId, listId: item.listId, title: item.title, at: now });
    await tg('editMessageReplyMarkup', { chat_id: chat, message_id: q.message?.message_id, reply_markup: { inline_keyboard: [] } }).catch(() => {});
    return answer('✓ Отмечу в Спутнике');
  }
  if (act === 'z') {
    const at = new Date(now + SNOOZE_MIN * 60e3);
    await store.addSnooze(chat, { ...item, key: `snooze|${id}|${at.getTime()}`, fireAt: at.toISOString() });
    const p = parts(at, (await store.user(chat))?.tz);
    return answer(`Напомню в ${p.hh}:${p.mm}`);
  }
  return answer('');
}

// ---------- запросы трекера ----------

/** Трекер ввёл код: связываем чат с ключом этого человека. */
export async function link({ code, key, tz }, { store, tg, now = Date.now(), ip = '' }) {
  if (!/^\d{6}$/.test(String(code ?? '')) || String(key ?? '').length < 32) return { status: 400, body: { error: 'Нужен код из 6 цифр' } };
  // Перебор кодов: с одного адреса — не больше LINK_TRIES неверных за час.
  if ((await store.tries(ip, now - 3600e3)) >= LINK_TRIES) return { status: 429, body: { error: 'Слишком много попыток — подожди час' } };
  const c = await store.takeCode(String(code));
  if (!c || c.exp < now) { await store.addTry(ip, now); return { status: 404, body: { error: 'Код не подошёл или устарел — отправь боту /start ещё раз' } }; }
  await store.link(c.chat, await sha256(key), tz || 'Europe/Moscow', c.name);
  await tg('sendMessage', { chat_id: c.chat, text: '✓ Спутник подключён. Сюда будут приходить напоминания, а задачи можно писать мне текстом.\n\n' + HELP, parse_mode: 'HTML' }).catch(() => {});
  return { status: 200, body: { ok: true, name: c.name } };
}

/** Трекер прислал напоминания и задачи на неделю. */
export async function putState(chat, body, { store, now = Date.now() }) {
  const items = Array.isArray(body?.items) ? body.items.slice(0, 500) : [];
  const today = Array.isArray(body?.today) ? body.today.slice(0, 300) : [];
  const prev = (await store.state(chat)) ?? {};
  const state = { items, today, snoozed: (prev.snoozed ?? []).filter((x) => now - Date.parse(x.fireAt) <= LATE_LIMIT), at: now };
  await store.putState(chat, state, body?.tz, nextAt(state, await store.sentKeys(chat), now));
  return { status: 200, body: { ok: true } };
}

/** Раз в минуту: шлём, что пришло время. */
export async function tick({ store, tg, now = Date.now() }) {
  let n = 0;
  for (const u of await store.due(now)) {
    const st = (await store.state(u.chat)) ?? {};
    const sentKeys = await store.sentKeys(u.chat);
    for (const it of [...(st.items ?? []), ...(st.snoozed ?? [])]) {
      const at = Date.parse(it.fireAt);
      if (!at || at > now || sentKeys.has(it.key)) continue;
      if (now - at <= LATE_LIMIT) {
        const id = await store.markSent(u.chat, it, now);
        const row = [];
        if (it.taskId && it.listId && it.kind !== 'milestone' && it.kind !== 'habit') row.push({ text: '✓ Готово', callback_data: `d:${id}` });
        if (it.kind !== 'milestone' && it.kind !== 'test') row.push({ text: '⏰ Через час', callback_data: `z:${id}` });
        try {
          await tg('sendMessage', { chat_id: u.chat, text: format(it, u.tz), parse_mode: 'HTML', disable_web_page_preview: true, ...(row.length ? { reply_markup: { inline_keyboard: [row] } } : {}) });
          n++;
        } catch (e) {
          // Человек заблокировал бота — дальше не шлём, пока снова не напишет /on.
          if (/403/.test(String(e))) { await store.setMuted(u.chat, true); break; }
          await store.unmarkSent(u.chat, id); // попробуем через минуту
          continue;
        }
      } else await store.markSent(u.chat, it, now);
      sentKeys.add(it.key);
    }
    await store.setNext(u.chat, nextAt(st, sentKeys, now));
  }
  await store.purge(now - KEEP_SENT);
  return n;
}
