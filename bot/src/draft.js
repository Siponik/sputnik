// Черновик задачи в Telegram: догадка по сообщению (своему или пересланному), карточка с кнопками, правка полей.
// Здесь нет ни Telegram, ни Google: на вход — сообщение и контекст { today, lists, def, learned },
// на выход — черновик (обычный объект) и карточка { text, markup }. Хранят черновики и создают задачи сами боты.
//
// Черновик: { id, title, notes, day, time, list, why, prio, rem, from, fkey, cnt, mode, made, extra, at }
//   day 'ГГГГ-ММ-ДД' | null, time 'ЧЧ:ММ' | null, list — id списка, prio 1..3 | null,
//   rem — минут до начала (0 — в момент), 'off' — без напоминания, null — как обычно;
//   from — от кого переслано, fkey — ключ отправителя (запоминаем его список), cnt — сколько сообщений собрано,
//   mode — что открыто на карточке: '' | 'when' | 'list' | 'prio' | 'rem' | 'title'.

const MONTHS = ['янв.', 'февр.', 'мар.', 'апр.', 'мая', 'июн.', 'июл.', 'авг.', 'сент.', 'окт.', 'нояб.', 'дек.'];
const MONTH_IDX = { янв: 0, фев: 1, мар: 2, апр: 3, мая: 4, май: 4, июн: 5, июл: 6, авг: 7, сен: 8, окт: 9, ноя: 10, дек: 11 };
const DOW = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
const WEEKDAY_RE = [/^понедельник/, /^вторник/, /^сред/, /^четверг/, /^пятниц/, /^суббот/, /^воскресень/];
const PRIO = { 1: '!!! высокий', 2: '!! средний', 3: '! низкий' };
export const TITLE_MAX = 80;
export const NOTE_MAX = 3000;
export const MERGE_MS = 4000; // пересланные подряд (в пределах 4 с) — в один черновик
export const DRAFT_TTL = 864e5; // черновик живёт сутки
const REMS = [[null, 'Как обычно'], [0, 'В момент начала'], [15, 'За 15 мин'], [60, 'За час'], [1440, 'За день'], ['off', 'Без напоминания']];
const TIMES = ['10:00', '13:00', '15:00', '19:00'];

export const esc = (s) => String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

// ---------- даты: строки ГГГГ-ММ-ДД, считаем в UTC ----------

function ymdDate(s) { const p = s.split('-').map(Number); return new Date(Date.UTC(p[0], p[1] - 1, p[2])); }
export function ymdAdd(s, n) { const d = ymdDate(s); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10); }
export function ymdDow(s) { return (ymdDate(s).getUTCDay() + 6) % 7; } // пн = 0
function ymdMake(y, m, d) {
  const x = new Date(Date.UTC(y, m, d));
  return x.getUTCMonth() === m && x.getUTCDate() === d ? x.toISOString().slice(0, 10) : null;
}
function nearest(base, m, d) {
  const y = +base.slice(0, 4);
  const a = ymdMake(y, m, d);
  return a && a < base ? ymdMake(y + 1, m, d) : a;
}
const hm = (h, m) => String(+h).padStart(2, '0') + ':' + m;

/** «сегодня», «завтра», «пт, 31 окт.» */
export function dayLabel(day, today) {
  if (day === today) return 'сегодня';
  if (day === ymdAdd(today, 1)) return 'завтра';
  if (day === ymdAdd(today, -1)) return 'вчера';
  const p = day.split('-').map(Number);
  return DOW[ymdDow(day)] + ', ' + p[2] + ' ' + MONTHS[p[1] - 1] + (p[0] !== +today.slice(0, 4) ? ' ' + p[0] : '');
}

/**
 * Срок и время словами — как parseWhen_ в BotTasks.gs и when.js трекера, плюс то, что пишут в переписке:
 * «до пятницы», «к среде», «до 25 октября», «к 15:00», «на следующей неделе», «до конца недели», «вечером».
 * Возвращает { day, time, rest } — rest без найденных слов.
 */
export function when(text, base) {
  let t = ' ' + String(text || '').replace(/\s+/g, ' ') + ' ';
  let day = null, time = null, allDay = false, part = null;
  const take = (re, fn) => { const m = t.match(re); if (m) { fn(m); t = t.replace(m[0], ' '); return true; } return false; };
  const pre = '(?:(?:до|к|ко|на|в|во|не позже|не позднее)\\s+)?';

  take(/\s(весь день)(?=\s)/i, () => (allDay = true));
  take(new RegExp('\\s' + pre + '([01]?\\d|2[0-3]):([0-5]\\d)(?=\\s|[,.!?;)])', 'i'), (m) => (time = hm(m[1], m[2])))
    || take(/\s(?:в|к)\s([6-9]|0[6-9]|1\d|2[0-3])\.([0-5][05])(?=\s|[,!?;)])/i, (m) => (time = hm(m[1], m[2])))
    || take(/\s(?:в|к)\s([01]?\d|2[0-3])(?:\s?ч(?:ас(?:а|ов)?)?\.?)?(?=\s|[,!?;)])(?!\s*(?:янв|фев|мар|апр|ма[яй]|июн|июл|авг|сен|окт|ноя|дек|числ))/i, (m) => (time = hm(m[1], '00')));
  take(/\s(?:до\s+|к\s+)?(утром|утра|днём|днем|вечером|вечера|к вечеру)(?=\s|[,.!?;)])/i, (m) => (part = m[1].toLowerCase()));

  take(new RegExp('\\s' + pre + '(послезавтра)(?=\\s|[,.!?;)])', 'i'), () => (day = ymdAdd(base, 2)))
    || take(new RegExp('\\s' + pre + '(завтра|завтрашнего дня|завтрашнему дню)(?=\\s|[,.!?;)])', 'i'), () => (day = ymdAdd(base, 1)))
    || take(new RegExp('\\s' + pre + '(сегодня|сегодняшнего дня)(?=\\s|[,.!?;)])', 'i'), () => (day = base))
    || take(/\sчерез\s(\d{1,3}|неделю|день|пару дней)\s?(дн[еяй]+|день|недел[июь]+)?(?=\s|[,.!?;)])/i, (m) => {
      const n = m[1] === 'неделю' ? 7 : m[1] === 'день' ? 1 : m[1] === 'пару дней' ? 2 : Number(m[1]) * (/недел/i.test(m[2] || '') ? 7 : 1);
      day = ymdAdd(base, n);
    })
    || take(new RegExp('\\s' + pre + '(\\d{1,2})\\s(янв|фев|мар|апр|мая|май|июн|июл|авг|сен|окт|ноя|дек)[а-я]*\\.?(?=\\s|[,!?;)])', 'i'), (m) => {
      day = nearest(base, MONTH_IDX[m[2].toLowerCase().slice(0, 3)], +m[1]);
    })
    || take(new RegExp('\\s' + pre + '(\\d{1,2})\\.(\\d{1,2})(?:\\.(\\d{2,4}))?(?=\\s|[,!?;)])', 'i'), (m) => {
      if (m[3]) day = ymdMake(+(m[3].length === 2 ? '20' + m[3] : m[3]), +m[2] - 1, +m[1]);
      else day = nearest(base, +m[2] - 1, +m[1]);
    })
    || take(/\s(?:(?:до|к)\s+)?конц[ау]\s+недели(?=\s|[,.!?;)])/i, () => {
      const dw = ymdDow(base);
      day = dw <= 4 ? ymdAdd(base, 4 - dw) : base;
    })
    || take(/\s(?:на|в)\s+(?:выходны[хе]|выходных)(?=\s|[,.!?;)])/i, () => {
      const dw = ymdDow(base);
      day = dw >= 5 ? base : ymdAdd(base, 5 - dw);
    })
    || take(/\s(?:на\s+)?следующей\s+неделе(?=\s|[,.!?;)])/i, () => (day = ymdAdd(base, 7 - ymdDow(base))))
    || take(new RegExp('\\s' + pre + '(понедельник[ау]?|вторник[ау]?|сред[аыуе]|четверг[ау]?|пятниц[аыуе]|суббот[аыуе]|воскресень[еяю]|пн|вт|ср|чт|пт|сб|вс)(?=\\s|[,.!?;)])', 'i'), (m) => {
      const w = m[1].toLowerCase();
      let i = WEEKDAY_RE.findIndex((re) => re.test(w));
      if (i < 0) i = DOW.indexOf(w);
      day = ymdAdd(base, ((i - ymdDow(base) + 7) % 7) || 7);
    });

  if (!time && part) time = /^утр/.test(part) ? '10:00' : /^дн/.test(part) ? '15:00' : '19:00';
  if (part && !day && time && !allDay) day = base; // «вечером» без дня — сегодня
  if (allDay) time = null;
  return { day: day, time: time, rest: t.replace(/\s+/g, ' ').trim() };
}

// ---------- от кого и что пришло ----------

/** Кто автор пересланного: { name, key, link } или null, если сообщение не пересланное. */
export function senderOf(m) {
  const o = m && m.forward_origin;
  if (o) {
    if (o.type === 'user' && o.sender_user) {
      const u = o.sender_user;
      return { name: [u.first_name, u.last_name].filter(Boolean).join(' ') || u.username || 'кто-то', key: 'u' + u.id, link: '' };
    }
    if (o.type === 'hidden_user') return { name: o.sender_user_name || 'кто-то', key: 'n' + (o.sender_user_name || ''), link: '' };
    const c = o.chat || o.sender_chat;
    if (c) {
      const link = c.username && o.message_id ? 'https://t.me/' + c.username + '/' + o.message_id : '';
      return { name: c.title || c.username || 'канал', key: 'c' + c.id, link: link };
    }
    return { name: 'кто-то', key: '', link: '' };
  }
  // Старые поля Telegram (до Bot API 7.0) — на всякий случай.
  if (m && m.forward_from) return { name: [m.forward_from.first_name, m.forward_from.last_name].filter(Boolean).join(' '), key: 'u' + m.forward_from.id, link: '' };
  if (m && m.forward_sender_name) return { name: m.forward_sender_name, key: 'n' + m.forward_sender_name, link: '' };
  if (m && m.forward_from_chat) {
    const c = m.forward_from_chat;
    return { name: c.title || 'канал', key: 'c' + c.id, link: c.username && m.forward_from_message_id ? 'https://t.me/' + c.username + '/' + m.forward_from_message_id : '' };
  }
  return null;
}

/** Текст сообщения: сам текст или подпись к фото/файлу, плюс адреса ссылок, спрятанных под словами. */
export function textOf(m) {
  const text = String((m && (m.text || m.caption)) || '');
  const ents = (m && (m.entities || m.caption_entities)) || [];
  const urls = ents.filter((e) => e.type === 'text_link' && e.url && text.indexOf(e.url) < 0).map((e) => e.url);
  return urls.length ? text + '\n' + urls.join('\n') : text;
}

/** Что во вложении — для названия, когда текста нет. */
function attachWord(m) {
  if (!m) return '';
  if (m.photo) return 'фото';
  if (m.video || m.video_note) return 'видео';
  if (m.voice || m.audio) return 'голосовое';
  if (m.document) return 'файл «' + (m.document.file_name || 'без имени') + '»';
  if (m.sticker) return 'стикер';
  if (m.location || m.venue) return 'место';
  if (m.contact) return 'контакт';
  return '';
}

// Вежливые начала и обращения: «Привет! Можешь, пожалуйста, прислать…» → «Прислать…»
const GREET = /^(привет(ик)?|здравствуй(те)?|добрый\s+(день|вечер)|доброе\s+утро|доброго\s+(дня|времени\s+суток)|хай|хей|hi|hello|салют|слушай(те)?|смотри(те)?|кстати|короче|так|итак|ок(ей)?|ну|а|и|да|алло|ещё|еще|также|плюс)(?=[\s,!.:)]|$)[\s,!.:)]*/i;
const ASK = /^(ты\s+|вы\s+)?(можешь|можете|сможешь|сможете|не\s+мог(ла|ли)?\s+бы|мог(ла|ли)?\s+бы|не\s+забудь(те)?|прошу|просьба|пожалуйста|плиз|плз|нужно\s+будет|нужно|надо\s+будет|надо|необходимо|давай(те)?|срочно)(\s+(ты|вы|пожалуйста|плиз))*[\s,]+/i;

/** Название из текста: первая смысловая фраза без приветствий, «можешь…», даты, @списка и !!! — до TITLE_MAX знаков. */
export function titleFrom(text) {
  let s = String(text || '').replace(/https?:\/\/\S+/g, ' ').replace(/[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}]/gu, ' ');
  // Первая непустая строка, в ней — первое предложение (если оно не совсем короткое).
  const line = s.split('\n').map((x) => x.trim()).find((x) => x.replace(GREET, '').trim().length > 2) || '';
  s = line;
  for (let i = 0; i < 4; i++) { const n = s.replace(GREET, ''); if (n === s) break; s = n; }
  const parts = s.split(/(?<=[.!?…])\s+/);
  if (parts.length > 1 && parts[0].replace(/[.!?…]+$/, '').length >= 12) s = parts[0];
  for (let i = 0; i < 3; i++) { const n = s.replace(ASK, ''); if (n === s) break; s = n; }
  s = s.replace(/[,\s]*(пожалуйста|плиз|плз)[,\s]*/gi, ' ').replace(/\s+/g, ' ').trim();
  s = s.replace(/(\s(срок(ом)?|дедлайн|до|к|ко|на|в|во|не позже|не позднее))+$/i, '');
  s = s.replace(/^[,.:;!?\-–—\s]+/, '').replace(/[\s,:;\-–—]+$/, '').replace(/[?!.…]+$/, '').trim();
  if (s.length > TITLE_MAX) {
    const cut = s.slice(0, TITLE_MAX);
    s = (cut.lastIndexOf(' ') > 40 ? cut.slice(0, cut.lastIndexOf(' ')) : cut).replace(/[\s,.:;\-–—]+$/, '') + '…';
  }
  return s ? s[0].toUpperCase() + s.slice(1) : '';
}

/** «срочно», «asap», «!!!» → 1; «!!» → 2; «!» отдельным словом → 3. */
export function prioFrom(text) {
  const t = ' ' + String(text || '') + ' ';
  const m = t.match(/\s(!{1,3})(?=\s)/);
  if (m) return 4 - m[1].length;
  if (/(^|[^а-яё])(срочн|горит|asap|как можно скорее|очень важно|в первую очередь)/i.test(t)) return 1;
  if (/(^|[^а-яё])(важно|приоритет)/i.test(t)) return 2;
  return null;
}

const norm = (s) => String(s || '').toLowerCase().replace(/ё/g, 'е').replace(/[\s\-_·.«»"']+/g, '');
const stem = (w) => norm(w).slice(0, 5);

/** «@раб» → «Работа»: точное совпадение, начало названия, часть названия. */
export function findList(lists, word) {
  const w = norm(word);
  if (!w) return null;
  return lists.find((l) => norm(l.title) === w) || lists.find((l) => norm(l.title).indexOf(w) === 0)
    || lists.find((l) => norm(l.title).indexOf(w) >= 0) || null;
}

/**
 * Куда положить: @список → запомненный для этого отправителя → выученное слово → слово из названия списка → основной.
 * ctx.learned = { [ключ отправителя]: listId }, ctx.words = { [первые 5 букв слова]: listId }.
 */
export function guessList(text, fkey, from, ctx) {
  const lists = ctx.lists || [];
  const has = (id) => lists.some((l) => l.id === id);
  const at = String(text || '').match(/(^|\s)@([^\s@]+)/);
  if (at) { const l = findList(lists, at[2]); if (l) return { list: l.id, why: '' }; }
  if (fkey && ctx.learned && has(ctx.learned[fkey])) return { list: ctx.learned[fkey], why: 'как в прошлый раз от ' + from };
  const words = (String(text || '').toLowerCase().match(/[a-zа-яё0-9]{4,}/g) || []).slice(0, 60);
  for (const w of words) {
    const id = ctx.words && ctx.words[stem(w)];
    if (has(id)) return { list: id, why: 'по слову «' + w + '»' };
  }
  for (const w of words) {
    if (w.length < 5) continue;
    const l = lists.find((x) => (x.title.toLowerCase().match(/[a-zа-яё0-9]{4,}/g) || []).some((tw) => stem(tw) === stem(w)));
    if (l) return { list: l.id, why: 'по слову «' + w + '»' };
  }
  const def = has(ctx.def) ? ctx.def : lists[0] && lists[0].id;
  return { list: def || null, why: '' };
}

/**
 * Догадка по сообщению Telegram. ctx: { today: 'ГГГГ-ММ-ДД', lists: [{ id, title }], def, learned, words }.
 * У своего текста заметка — со второй строки (как раньше), у пересланного — весь текст, «от кого» и ссылка.
 */
export function guess(m, ctx) {
  const who = senderOf(m);
  const full = textOf(m).trim();
  const own = !who;
  const nl = full.indexOf('\n');
  const head = own && nl >= 0 ? full.slice(0, nl) : full;
  const w = when(own ? head : full.replace(/https?:\/\/\S+/g, ' '), ctx.today);
  // Из названия убираем то, что разобрали: дату, @список, !!!.
  const clean = (s) => when(s, ctx.today).rest.replace(/(^|\s)@[^\s@]+/g, ' ').replace(/(^|\s)!{1,3}(?=\s|$)/g, ' ');
  let title = titleFrom(clean(head));
  const att = attachWord(m);
  if (!title) title = att ? (att[0].toUpperCase() + att.slice(1)) + (who ? ' от ' + who.name : '') : '';
  const url = full.match(/https?:\/\/([^\/\s]+)\S*/);
  if (!title && url) title = 'Посмотреть ссылку ' + url[1].replace(/^www\./, '');
  if (!title && full && who) title = titleFrom(full); // своё «завтра 18:00» без слов — не задача
  const notes = own ? (nl >= 0 ? full.slice(nl + 1).trim() : '') : noteFor(full, who, att);
  const g = guessList(full, who && who.key, who && who.name, ctx);
  return {
    title: title.slice(0, 250),
    notes: notes.slice(0, NOTE_MAX),
    day: w.day,
    time: w.time,
    list: g.list,
    why: g.why,
    prio: prioFrom(own ? head : full),
    rem: null,
    from: who ? who.name : '',
    fkey: who ? who.key : '',
    cnt: 1,
    mode: '',
  };
}

function noteFor(text, who, att) {
  const tail = [];
  if (who) tail.push('— переслано от ' + who.name + (who.link ? ': ' + who.link : ''));
  if (att && !text) tail.push('(' + att + ' — в Telegram)');
  return [text, tail.join('\n')].filter(Boolean).join('\n\n');
}

/** Ещё одно пересланное в тот же черновик: текст — в заметку, название — из первого. */
export function merge(d, m, ctx) {
  const g = guess(m, ctx);
  return Object.assign({}, d, {
    notes: (d.notes + '\n\n' + g.notes).slice(0, NOTE_MAX),
    day: d.day || g.day,
    time: d.time || g.time,
    prio: d.prio || g.prio,
    cnt: (d.cnt || 1) + 1,
    parts: (d.parts || [{ title: d.title, notes: d.notes }]).concat([{ title: g.title, notes: g.notes }]).slice(0, 10),
  });
}

/** Черновик из нескольких пересланных → отдельные задачи с теми же сроком, списком и приоритетом. */
export function split(d) {
  return (d.parts || [{ title: d.title, notes: d.notes }]).map((p) => Object.assign({}, d, { title: p.title, notes: p.notes, cnt: 1, parts: null }));
}

/**
 * Текст, присланный при открытом черновике: правка, а не новая задача?
 * Режим «название» — весь текст становится названием. Иначе правка — если в тексте только срок/время, @список, !!! или «без срока».
 * Возвращает новый черновик или null.
 */
export function editByText(d, text, ctx) {
  const s = String(text || '').trim();
  if (!s) return null;
  if (d.mode === 'title') return Object.assign({}, d, { title: titleFrom(s) || s.slice(0, TITLE_MAX), mode: '' });
  const out = Object.assign({}, d, { mode: '' });
  let rest = ' ' + s + ' ';
  let hit = false;
  if (/\sбез\s+срока\s/i.test(rest)) { out.day = null; out.time = null; rest = rest.replace(/\sбез\s+срока\s/i, ' '); hit = true; }
  if (/\sбез\s+времени\s/i.test(rest)) { out.time = null; rest = rest.replace(/\sбез\s+времени\s/i, ' '); hit = true; }
  const at = rest.match(/\s@([^\s@]+)(?=\s)/);
  if (at) {
    const l = findList(ctx.lists || [], at[1]);
    if (!l) return null;
    out.list = l.id; out.why = ''; out.listSet = true; rest = rest.replace(at[0], ' '); hit = true;
  }
  const p = rest.match(/\s(!{1,3})(?=\s)/);
  if (p) { out.prio = 4 - p[1].length; rest = rest.replace(p[0], ' '); hit = true; }
  const w = when(rest, ctx.today);
  if (w.day || w.time) {
    if (w.day) out.day = w.day;
    if (w.time) { out.time = w.time; if (!out.day) out.day = w.day || ctx.today; }
    rest = w.rest; hit = true;
  }
  return hit && !rest.trim() ? out : null;
}

// ---------- карточка ----------

const btn = (text, id, op) => ({ text: text, callback_data: 'g' + id + '|' + op });
function listTitle(ctx, id) { const l = (ctx.lists || []).find((x) => x.id === id); return l ? l.title : 'основной список'; }
export function remText(rem) { const r = REMS.find((x) => x[0] === rem); return r ? r[1] : 'за ' + rem + ' мин'; }

/** Строка «когда»: «пт, 31 окт. · 15:00» или «без срока». */
export function whenText(d, today) {
  return d.day ? dayLabel(d.day, today) + (d.time ? ' · ' + d.time : '') : 'без срока';
}

/** Сообщение с черновиком: { text, markup }. Вид зависит от d.mode — открыт выбор срока, списка, приоритета… */
export function card(d, ctx) {
  // made: 'done' — задача уже создана (правки идут сразу в неё), 'sent' — ждёт трекер, 'final' — трекер забрал, кнопок нет.
  const head = d.made === 'done' ? '✅ <b>Создано</b>' : d.made === 'sent' ? '📥 <b>Записал</b> · появится в Спутнике, когда он синхронизируется'
    : d.made === 'final' ? '✅ <b>В Спутнике</b>'
    : d.from ? '📝 <b>Черновик</b> · от ' + esc(d.from) + (d.cnt > 1 ? ' · ' + d.cnt + ' сообщ.' : '') : '📝 <b>Черновик</b>';
  const lines = [head, '', '<b>' + esc(d.title || 'Без названия') + '</b>', '📅 ' + whenText(d, ctx.today) + (d.extra ? ' · ' + esc(d.extra) : ''),
    '📋 ' + esc(listTitle(ctx, d.list)) + (d.why ? ' <i>· ' + esc(d.why) + '</i>' : '')];
  if (d.prio) lines.push('❗ ' + PRIO[d.prio].replace(/^\S+ /, ''));
  if (d.rem !== null && d.rem !== undefined) lines.push('🔔 ' + remText(d.rem).toLowerCase());
  if (d.notes) {
    const n = d.notes.replace(/\s+/g, ' ').trim();
    lines.push('🗒 <i>' + esc(n.length > 140 ? n.slice(0, 140) + '…' : n) + '</i>');
  }
  const id = d.id;
  const back = [btn('← Назад', id, 'b')];
  let kb;
  if (d.mode === 'when') {
    lines.push('', 'Когда? Или напиши словами: <i>в четверг 18:30</i>');
    const t = ctx.today;
    const days = [];
    for (let i = 2; i <= 6; i++) days.push(btn(DOW[ymdDow(ymdAdd(t, i))] + ' ' + +ymdAdd(t, i).slice(8), id, 'D' + ymdAdd(t, i)));
    const mark = (s, on) => (on ? '• ' : '') + s;
    kb = [
      [btn(mark('Сегодня', d.day === t), id, 'D' + t), btn(mark('Завтра', d.day === ymdAdd(t, 1)), id, 'D' + ymdAdd(t, 1)), btn('Через неделю', id, 'D' + ymdAdd(t, 7))],
      days,
      [btn(mark('Без времени', !d.time), id, 'H-')].concat(TIMES.map((x) => btn(mark(x, d.time === x), id, 'H' + x))),
      [btn(mark('Без срока', !d.day), id, 'D-')].concat(back),
    ];
  } else if (d.mode === 'list') {
    lines.push('', 'В какой список?');
    kb = [];
    (ctx.lists || []).slice(0, 24).forEach((l, i) => {
      if (i % 2 === 0) kb.push([]);
      kb[kb.length - 1].push(btn((l.id === d.list ? '• ' : '') + l.title, id, 'L' + i));
    });
    kb.push(back);
  } else if (d.mode === 'prio') {
    kb = [[1, 2, 3].map((p) => btn((d.prio === p ? '• ' : '') + PRIO[p], id, 'P' + p)), [btn((d.prio ? '' : '• ') + 'Без приоритета', id, 'P0')].concat(back)];
  } else if (d.mode === 'rem') {
    kb = [];
    REMS.forEach((r, i) => {
      if (i % 3 === 0) kb.push([]);
      kb[kb.length - 1].push(btn((d.rem === r[0] || (d.rem === undefined && r[0] === null) ? '• ' : '') + r[1], id, 'R' + (r[0] === null ? 'd' : r[0])));
    });
    kb.push(back);
  } else if (d.mode === 'title') {
    lines.push('', '✏ Пришли новое название сообщением.');
    kb = [back];
  } else if (d.made === 'final') {
    kb = [];
  } else if (d.made) {
    kb = [
      [btn('📅 Срок', id, 'w'), btn('📋 Список', id, 'l'), btn('❗ Приоритет', id, 'p')],
      [btn('✏ Название', id, 't'), btn('🔔 Напомнить', id, 'r'), btn('↩ Отменить', id, 'x')],
    ];
  } else {
    kb = [
      [btn('✅ Создать', id, 'ok')],
      [btn('📅 Срок', id, 'w'), btn('📋 Список', id, 'l'), btn('❗ Приоритет', id, 'p')],
      [btn('✏ Название', id, 't'), btn('🔔 Напомнить', id, 'r'), btn('✕ Отмена', id, 'x')],
    ];
    if (d.cnt > 1) kb.splice(1, 0, [btn('✂ Разделить на ' + d.cnt + ' задач' + (d.cnt < 5 ? 'и' : ''), id, 's')]);
  }
  return { text: lines.join('\n'), markup: { inline_keyboard: kb } };
}

/** Строка итога после создания: «✅ Название · пт, 31 окт. · 15:00 · Работа» */
export function doneText(d, ctx, prefix) {
  const bits = [whenText(d, ctx.today)];
  if (d.prio) bits.push(PRIO[d.prio].split(' ')[0]);
  return (prefix || '✅') + ' <b>' + esc(d.title) + '</b>\n' + bits.join(' · ') + ' · <i>' + esc(listTitle(ctx, d.list)) + '</i>';
}

/** Разбор нажатия «g<id>|<op>»: { id, op } или null. */
export function parseData(data) {
  const m = /^g([a-z0-9]+)\|(.+)$/.exec(String(data || ''));
  return m ? { id: m[1], op: m[2] } : null;
}

/**
 * Нажали кнопку на карточке. Возвращает { d, act }: d — новый черновик (показать заново),
 * act — что сделать боту: 'create' | 'cancel' | 'split' | '' (только перерисовать).
 */
export function press(d, op, ctx) {
  const set = (patch) => ({ d: Object.assign({}, d, { mode: '' }, patch), act: '' });
  if (op === 'ok') return { d: d, act: 'create' };
  if (op === 'x') return { d: d, act: 'cancel' };
  if (op === 's') return { d: d, act: 'split' };
  if (op === 'b') return set({});
  if (op === 'w' || op === 'l' || op === 'p' || op === 'r' || op === 't') {
    return { d: Object.assign({}, d, { mode: { w: 'when', l: 'list', p: 'prio', r: 'rem', t: 'title' }[op] }), act: '' };
  }
  const k = op[0], v = op.slice(1);
  if (k === 'D') return { d: Object.assign({}, d, v === '-' ? { day: null, time: null, mode: '' } : { day: v, mode: d.time ? '' : 'when' }), act: '' };
  if (k === 'H') return set(v === '-' ? { time: null } : { time: v, day: d.day || ctx.today });
  if (k === 'L') { const l = (ctx.lists || [])[+v]; return l ? set({ list: l.id, why: '', listSet: true }) : set({}); }
  if (k === 'P') return set({ prio: +v || null });
  if (k === 'R') return set({ rem: v === 'd' ? null : v === 'off' ? 'off' : +v });
  return set({});
}

/** Короткий id черновика: время в base36 + случайный хвост. */
export function newId(now, rand) { return (Math.floor(now / 1000) % 1e7).toString(36) + Math.floor((rand || Math.random)() * 1296).toString(36); }
