// Утренняя сводка общего бота: задачи дня из снимка трекера + новости дня.
// Новости собирает GitHub Actions (.github/workflows/news.yml, tools/news/) и кладёт на GitHub Pages
// рядом со страницей data.json: { date, count, top: [{ title, url }], dota }. Бот только читает этот файл.
// Настройки человека — таблица brief (schema.sql): время (минуты от полуночи в его поясе), дни, пауза, когда слал.

import { agenda, esc, parts } from './logic.js';

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

/** Блок новостей: число, большое обновление Dota 2 и три главных со ссылками. Вчерашние — с пометкой. */
export function newsLines(data, ymd) {
  if (!data?.count) return '';
  const old = data.date && data.date !== ymd ? ` <i>· ${dayDiff(ymd, data.date) === 1 ? 'вчерашние' : 'позавчерашние'}</i>` : '';
  const lines = [`📰 <b>Новости · ${data.count}</b>${old}`];
  if (data.dota?.stage === 'big') lines.push(`✦ <a href="${esc(data.dota.url)}">Dota 2: ${esc(data.dota.title)}</a>`);
  for (const t of (data.top ?? []).slice(0, 3)) lines.push(`• <a href="${esc(t.url)}">${esc(t.title)}</a>`);
  return lines.join('\n');
}

/** Текст сводки и кнопка. news — data.json или null. */
export function briefMessage(state, news, tz, now) {
  const p = parts(new Date(now), tz);
  const fresh = news?.date && dayDiff(p.ymd, news.date) <= NEWS_OLD && dayDiff(p.ymd, news.date) >= 0 ? news : null;
  const stale = state?.at && now - state.at > 864e5 ? '\n<i>Спутник давно не синхронизировался — список может быть старым.</i>' : '';
  const text = [`🛰 <b>Спутник · утро</b> · ${p.d}.${String(p.m).padStart(2, '0')}`, agenda(state?.today, tz, now) + stale, newsLines(fresh, p.ymd)]
    .filter(Boolean).join('\n\n');
  return { text, markup: fresh?.count ? { inline_keyboard: [[{ text: 'Открыть новости', url: NEWS_URL }]] } : null };
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
