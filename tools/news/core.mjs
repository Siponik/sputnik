// Чистая логика новостей: разбор RSS и Steam, отбор по дате, повторы, правило Dota 2, запасной отбор без ИИ.
// Тест — tracker/tests/news.test.js.

const ENT = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ', laquo: '«', raquo: '»', mdash: '—', ndash: '–', hellip: '…' };

export function decode(s) {
  return String(s || '')
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1')
    .replace(/&#x([0-9a-f]+);/gi, (_, h) => String.fromCodePoint(parseInt(h, 16)))
    .replace(/&#(\d+);/g, (_, d) => String.fromCodePoint(+d))
    .replace(/&([a-z]+);/gi, (m, n) => ENT[n.toLowerCase()] ?? m);
}

/** Текст без тегов, с одиночными пробелами. */
export function plain(s, max = 0) {
  let t = decode(decode(s)).replace(/<[^>]*>/g, ' ').replace(/\[\/?[a-z0-9*]+[^\]]*\]/gi, ' ').replace(/\s+/g, ' ').trim();
  if (max && t.length > max) t = t.slice(0, max - 1).replace(/\s+\S*$/, '') + '…';
  return t;
}

function tag(block, names) {
  for (const n of names) {
    const m = block.match(new RegExp(`<${n}(?:\\s[^>]*)?>([\\s\\S]*?)</${n}>`, 'i'));
    if (m && m[1].trim()) return m[1];
  }
  return '';
}

function linkOf(block) {
  const atom = block.match(/<link\b[^>]*rel=["']alternate["'][^>]*>/i) || block.match(/<link\b[^>]*href=["'][^"']+["'][^>]*\/?>/i);
  if (atom) {
    const h = atom[0].match(/href=["']([^"']+)["']/i);
    if (h) return decode(h[1]).trim();
  }
  return plain(tag(block, ['link', 'guid']));
}

/** RSS 2.0 и Atom → [{ title, url, at (мс), text }]. Пункты без ссылки или даты отбрасываются. */
export function parseFeed(xml, source, sec) {
  const out = [];
  const blocks = String(xml || '').match(/<(item|entry)\b[\s\S]*?<\/\1>/gi) || [];
  for (const b of blocks) {
    const title = plain(tag(b, ['title']), 200);
    const url = linkOf(b);
    const at = Date.parse(plain(tag(b, ['pubDate', 'published', 'updated', 'dc:date'])));
    if (!title || !/^https:\/\//.test(url) || !Number.isFinite(at)) continue;
    out.push({ title, url, at, text: plain(tag(b, ['description', 'summary', 'content:encoded', 'content']), 300), src: source, sec });
  }
  return out;
}

/** Ответ Steam GetNewsForApp → пункты раздела «Обновления игр». */
export function parseSteam(json, game) {
  const items = (json && json.appnews && json.appnews.newsitems) || [];
  return items
    .filter((n) => n.title && /^https:\/\//.test(n.url || ''))
    .map((n) => ({ title: plain(n.title, 200), url: n.url, at: n.date * 1000, text: plain(n.contents, 300), src: game.name + ' · Steam', sec: 'updates', game: game.name, dota: !!game.dota }));
}

// ── Dota 2: что считается большим обновлением ──
const DOTA_BIG = /(\b7\.\d{2}\b(?![a-z])|treasure|trove|chest|battle ?pass|compendium|arcana|persona|new hero|новый герой|сундук|аркан|персона)/i;
const DOTA_SMALL = /(hotfix|client update|bug ?fix|tournament|league|esports|majors?\b|riyadh|international\b(?! update))/i;

export function dotaSignificant(item) {
  const t = item.title + ' ' + (item.text || '').slice(0, 120);
  if (DOTA_SMALL.test(item.title)) return false;
  if (/\b7\.\d{2}[a-z]\b/i.test(item.title)) return /new hero|новый герой|arcana|persona|treasure|trove/i.test(t); // буквенный патч — только с крупным
  return DOTA_BIG.test(t);
}

/**
 * Затухание: 'big' — вышло после прошлой сборки (огромный блок), 'star' — дни 2–3 (строка со звездой в «Обновлениях игр»),
 * null — старше 3 дней или нет значимого.
 */
export function dotaStage(item, prevBuiltAt, now) {
  if (!item) return null;
  if (prevBuiltAt && item.at > prevBuiltAt) return 'big';
  if (!prevBuiltAt && now - item.at < 864e5) return 'big';
  return now - item.at <= 3 * 864e5 ? 'star' : null;
}

/** Окно по разделам: хайп — двое суток, остальное — трое. */
export function fresh(items, now) {
  return items.filter((i) => i.at <= now + 36e5 && now - i.at <= (i.sec === 'hype' ? 2 : 3) * 864e5);
}

const norm = (u) => u.replace(/[?#].*$/, '').replace(/\/$/, '').toLowerCase();

/** Убрать то, что уже было в прошлых сводках, и дубли одной ссылки. */
export function unseen(items, seen) {
  const s = new Set((seen || []).map(norm));
  const out = [];
  for (const i of items) {
    const k = norm(i.url);
    if (s.has(k)) continue;
    s.add(k);
    out.push(i);
  }
  return out;
}

const SKIP = /(esports|киберспорт|турнир|tournament|\bmajor\b|деньги|скидк|распродаж|deal of the day|sale\b|промокод|гороскоп)/i;

/** Запасной отбор без ИИ: по разделам самые свежие, не больше max, не больше двух подряд из одного источника. */
export function fallbackPick(items, sections) {
  const res = {};
  for (const s of sections) {
    const pool = items.filter((i) => i.sec === s.id && !SKIP.test(i.title)).sort((a, b) => b.at - a.at);
    const bySrc = {};
    const cap = Math.max(2, Math.ceil(s.max / 2));
    res[s.id] = [];
    for (const i of pool) {
      if (res[s.id].length >= s.max) break;
      if ((bySrc[i.src] = (bySrc[i.src] || 0) + 1) > cap) continue;
      res[s.id].push({ ...i });
    }
  }
  return res;
}

/** Проверить ответ ИИ: только пункты из списка кандидатов, разделы из списка, тексты обрезаны. */
export function applyLlm(answer, cands, sections) {
  const byId = new Map(cands.map((c) => [c.id, c]));
  const ids = new Set(sections.map((s) => s.id));
  const res = Object.fromEntries(sections.map((s) => [s.id, []]));
  const used = new Set();
  for (const a of (answer && answer.items) || []) {
    const c = byId.get(String(a.id));
    const sec = ids.has(a.sec) ? a.sec : c && c.sec;
    if (!c || used.has(c.id) || !res[sec]) continue;
    const max = sections.find((s) => s.id === sec).max;
    if (res[sec].length >= max) continue;
    used.add(c.id);
    res[sec].push({ ...c, title: plain(a.title, 120) || c.title, text: plain(a.text, 320) || c.text });
  }
  return { sections: res, headline: plain(answer && answer.headline, 160) };
}

const MONTHS = ['янв.', 'февр.', 'марта', 'апр.', 'мая', 'июня', 'июля', 'авг.', 'сент.', 'окт.', 'нояб.', 'дек.'];
const DAYS = ['вс', 'пн', 'вт', 'ср', 'чт', 'пт', 'сб'];
const MSK = 3 * 36e5;

/** «чт, 22 окт.» по Москве. */
export function shortDate(ms) {
  const d = new Date(ms + MSK);
  return `${DAYS[d.getUTCDay()]}, ${d.getUTCDate()} ${MONTHS[d.getUTCMonth()]}`;
}

/** «2026-10-23» по Москве. */
export function ymd(ms) {
  return new Date(ms + MSK).toISOString().slice(0, 10);
}
