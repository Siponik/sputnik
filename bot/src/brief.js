// Утренняя сводка общего бота: задачи дня из снимка трекера + новости дня.
// Новости собирает GitHub Actions (.github/workflows/news.yml, tools/news/) и кладёт на GitHub Pages
// рядом со страницей data.json: { date, count, top: [{ title, url, sec }], dota: { stage, title, url, at, points } }. Бот только читает этот файл.
// Настройки человека — таблица brief (schema.sql): время (минуты от полуночи в его поясе), дни, пауза, когда слал.

import { esc, parts } from './logic.js';

export const NEWS_URL = 'https://siponik.github.io/sputnik/news/';
export const BRIEF_AT = 8 * 60; // 08:00 по времени человека
export const NEWS_WAIT = 60; // свежих новостей нет — ждём до часа после времени сводки
export const WINDOW = 180; // позже чем через 3 часа после времени сводки уже не шлём
const NEWS_OLD = 2; // новости старше двух дней не показываем

const hhmm = (m) => `${Math.floor(m / 60)}:${String(m % 60).padStart(2, '0')}`;
const daysText = (p) => (p.days === 'work' ? 'по будням' : 'каждый день');
const prefsOf = (u) => ({ at: u?.at ?? BRIEF_AT, days: u?.days === 'work' ? 'work' : 'all', off: !!u?.off, sent: u?.sent ?? '' });

/** Разница в днях между двумя датами «ГГГГ-ММ-ДД». */
const dayDiff = (a, b) => Math.round((Date.parse(a) - Date.parse(b)) / 864e5);

// Вид сводки — «Система G» (docs/design-g.md): шапки разделов моно-капсом с номером «01 · …», время и счётчики
// моноширинным, содержимое разделов — в цитате-ноде, Dota 2 — отдельной нодой со звездой.
const WD = ['ВС', 'ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ'];
const MON = ['ЯНВАРЯ', 'ФЕВРАЛЯ', 'МАРТА', 'АПРЕЛЯ', 'МАЯ', 'ИЮНЯ', 'ИЮЛЯ', 'АВГУСТА', 'СЕНТЯБРЯ', 'ОКТЯБРЯ', 'НОЯБРЯ', 'ДЕКАБРЯ'];
const SEC = { cg: 'CG   ', industry: 'ИГРЫ ', updates: 'ПАТЧИ', releases: 'ВЫХОД', hype: 'ХАЙП ' };
const head = (n, title, count, extra = '') => `<b>${n} · ${title}</b>${count != null ? ` <code>${count}</code>` : ''}${extra}`;
const MAX_TASKS = 8;

/** Задачи дня: просроченные сверху, дальше по времени. */
export function tasksBlock(today, tz, now) {
  const ymd = parts(new Date(now), tz).ymd;
  const items = (today ?? []).filter((t) => t.due === ymd || (t.due && t.due < ymd))
    .sort((a, b) => (a.due < ymd ? -1 : 0) - (b.due < ymd ? -1 : 0) || (a.time ?? '99').localeCompare(b.time ?? '99'));
  if (!items.length) return `${head('01', 'СЕГОДНЯ', 0)}\n<blockquote>Задач на сегодня нет — свободный день 🌙</blockquote>`;
  const rows = items.slice(0, MAX_TASKS).map((t) => {
    const late = t.due < ymd;
    return `<code>${late ? '  !  ' : t.time ? t.time.padStart(5) : '  ·  '}</code>  ${esc(t.title)}${late ? ' <i>· просрочено</i>' : ''}`;
  });
  if (items.length > MAX_TASKS) rows.push(`<i>и ещё ${items.length - MAX_TASKS} — /today</i>`);
  return `${head('01', 'СЕГОДНЯ', items.length)}\n<blockquote>${rows.join('\n')}</blockquote>`;
}

/** Нода Dota 2: большое обновление первые двое суток (stage 'big'). */
export function dotaLines(dota) {
  if (dota?.stage !== 'big' || !dota.url) return '';
  const pts = (dota.points ?? []).slice(0, 3).map((p) => `— ${esc(p)}`);
  return [`✦ <b>DOTA 2 · БОЛЬШОЕ ОБНОВЛЕНИЕ</b>`, `<blockquote><b>${esc(dota.title)}</b>${pts.length ? '\n' + pts.join('\n') : ''}\n<a href="${esc(dota.url)}">Открыть патчноут →</a></blockquote>`].join('\n');
}

/** Блок новостей: число и три главных со ссылками; вчерашние — с пометкой. Dota «со звездой» — строкой. */
export function newsLines(data, ymd) {
  if (!data?.count) return '';
  const old = data.date && data.date !== ymd ? ` <i>· ${dayDiff(ymd, data.date) === 1 ? 'вчерашние' : 'позавчерашние'}</i>` : '';
  const rows = [];
  if (data.dota?.stage === 'star' && data.dota.url) rows.push(`<code>DOTA ✦</code> <a href="${esc(data.dota.url)}">${esc(data.dota.title)}</a>`);
  for (const t of (data.top ?? []).slice(0, 3)) rows.push(`<code>${SEC[t.sec] ?? '  •  '}</code> <a href="${esc(t.url)}">${esc(t.title)}</a>`);
  return `${head('02', 'НОВОСТИ', data.count, old)}${rows.length ? `\n<blockquote>${rows.join('\n')}</blockquote>` : ''}`;
}

/** Текст сводки и кнопки. news — data.json или null. */
export function briefMessage(state, news, tz, now) {
  const p = parts(new Date(now), tz);
  const fresh = news?.date && dayDiff(p.ymd, news.date) <= NEWS_OLD && dayDiff(p.ymd, news.date) >= 0 ? news : null;
  const stale = state?.at && now - state.at > 864e5 ? '<i>Спутник давно не синхронизировался — список может быть старым.</i>' : '';
  const text = [
    `🛰 <b>СПУТНИК · УТРО</b>\n<code>${WD[p.dow]} · ${p.d} ${MON[p.m - 1]}</code>`,
    tasksBlock(state?.today, tz, now) + (stale ? '\n' + stale : ''),
    dotaLines(fresh?.dota),
    newsLines(fresh, p.ymd),
  ].filter(Boolean).join('\n\n');
  const row = [];
  if (fresh?.count) row.push({ text: '📰 Все новости', url: NEWS_URL });
  if (fresh?.dota?.stage === 'big' && fresh.dota.url) row.push({ text: '✦ Патчноут', url: fresh.dota.url });
  return { text, markup: row.length ? { inline_keyboard: [row] } : null };
}

/** Пора ли слать сводку: 'send' — да, 'wait' — подождать свежих новостей, null — не сегодня или уже отправлена. */
export function briefDue(prefs, tz, now, newsDate) {
  if (prefs.off) return null;
  const p = parts(new Date(now), tz);
  if (prefs.days === 'work' && (p.dow === 0 || p.dow === 6)) return null;
  if (prefs.sent === p.ymd) return null;
  const min = p.hh * 60 + +p.mm;
  if (min < prefs.at || min > prefs.at + WINDOW) return null;
  if (newsDate !== p.ymd && min < prefs.at + NEWS_WAIT) return 'wait';
  return 'send';
}

/** Раз в минуту из cron: кому пора — шлём. news() — data.json (читается один раз за запуск, только если кому-то пора). */
export async function briefTick({ store, tg, news, now = Date.now() }) {
  let data, n = 0;
  const getNews = async () => (data === undefined ? (data = await news().catch(() => null)) : data);
  for (const u of await store.briefUsers()) {
    if (u.muted) continue;
    const prefs = prefsOf(u);
    // Не время — даже не читаем новости.
    if (!briefDue(prefs, u.tz, now, parts(new Date(now), u.tz).ymd)) continue;
    const nw = await getNews();
    if (briefDue(prefs, u.tz, now, nw?.date) !== 'send') continue;
    const ymd = parts(new Date(now), u.tz).ymd;
    await store.setBrief(u.chat, { sent: ymd });
    const { text, markup } = briefMessage(await store.state(u.chat), nw, u.tz, now);
    try {
      await tg('sendMessage', { chat_id: u.chat, text, parse_mode: 'HTML', disable_web_page_preview: true, ...(markup ? { reply_markup: markup } : {}) });
      n++;
    } catch (e) {
      if (/403/.test(String(e))) await store.setMuted(u.chat, true);
      else await store.setBrief(u.chat, { sent: prefs.sent }); // попробуем через минуту
    }
  }
  return n;
}

/** Команда /brief: без слов — сводка сейчас; «7:30» — время; «будни» / «все» — дни; «выкл» / «вкл» — пауза. */
export async function briefCommand(chat, arg, { store, tg, news, now = Date.now() }) {
  const user = await store.user(chat);
  const prefs = prefsOf(await store.brief(chat));
  const say = (text, markup) => tg('sendMessage', { chat_id: chat, text, parse_mode: 'HTML', disable_web_page_preview: true, ...(markup ? { reply_markup: markup } : {}) });
  const a = String(arg ?? '').trim().toLowerCase();
  const status = (p) => (p.off ? `⏸ Утренняя сводка выключена. Включить — /brief вкл` : `🕗 Сводка приходит ${daysText(p)} в ${hhmm(p.at)}.`);
  if (!a || /^(сейчас|now)$/.test(a)) {
    const { text, markup } = briefMessage(await store.state(chat), await news().catch(() => null), user?.tz, now);
    return say(text, markup);
  }
  const t = a.match(/^(\d{1,2})(?:[:.](\d{2}))?$/);
  if (t && +t[1] < 24 && +(t[2] ?? 0) < 60) {
    const p = { ...prefs, at: +t[1] * 60 + +(t[2] ?? 0), off: false };
    await store.setBrief(chat, { at: p.at, off: 0 });
    return say('✅ ' + status(p));
  }
  if (/^(все|всё|каждый|ежедн|all|every)/.test(a)) { await store.setBrief(chat, { days: 'all' }); return say('✅ ' + status({ ...prefs, days: 'all' })); }
  if (/^(будн|раб|work)/.test(a)) { await store.setBrief(chat, { days: 'work' }); return say('✅ ' + status({ ...prefs, days: 'work' })); }
  if (/^(выкл|off|стоп|нет)/.test(a)) { await store.setBrief(chat, { off: 1 }); return say(status({ ...prefs, off: true })); }
  if (/^(вкл|on|да)/.test(a)) { await store.setBrief(chat, { off: 0 }); return say('✅ ' + status({ ...prefs, off: false })); }
  return say(status(prefs) + '\n\n/brief — сводка сейчас\n/brief 7:30 — время\n/brief будни · /brief все — дни\n/brief выкл · /brief вкл — пауза');
}
