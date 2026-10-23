// Сборка страницы новостей: node tools/news/build.mjs <папка вывода> [прошлый data.json]
// Пишет <папка>/index.html и <папка>/data.json (дата, число пунктов, тройка главных — для бота; seen — от повторов).
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { FEEDS, STEAM_GAMES, SECTIONS, steamUrl } from './feeds.mjs';
import { parseFeed, parseSteam, fresh, unseen, fallbackPick, applyLlm, dotaSignificant, dotaStage, shortDate, ymd, plain } from './core.mjs';
import { prompt, retell } from './llm.mjs';
import { page } from './render.mjs';

const out = process.argv[2] || 'site/news';
const prevPath = process.argv[3];
const now = Date.now();
const UA = { 'user-agent': 'Mozilla/5.0 (SputnikNews; +https://github.com/Siponik/sputnik)' };

async function get(url, kind) {
  const r = await fetch(url, { headers: UA, signal: AbortSignal.timeout(20e3), redirect: 'follow' });
  if (!r.ok) throw new Error(r.status);
  return kind === 'json' ? r.json() : r.text();
}

let prev = {};
if (prevPath) try { prev = JSON.parse(await readFile(prevPath, 'utf8')); } catch { /* первой сборки ещё не было */ }

const failed = [];
const lists = await Promise.all([
  ...FEEDS.map((f) => get(f.url).then((x) => parseFeed(x, f.name, f.sec)).catch((e) => (failed.push(f.name + ' ' + e.message), []))),
  ...STEAM_GAMES.map((g) => get(steamUrl(g.app).replace('maxlength=400', g.dota ? 'maxlength=1500' : 'maxlength=400'), 'json').then((x) => parseSteam(x, g)).catch((e) => (failed.push(g.name + ' ' + e.message), []))),
]);
const all = lists.flat();

// Dota 2: самое свежее значимое за 3 дня.
const dotaItem = all.filter((i) => i.dota && dotaSignificant(i)).sort((a, b) => b.at - a.at)[0];
const stage = dotaStage(dotaItem, prev.builtAt, now);
const dota = stage ? { stage, item: dotaItem, extra: {} } : null;

const seen = prev.seen || [];
let pool = unseen(fresh(all.filter((i) => !(i.dota && i === dotaItem)), now), seen);
// Обычные объявления Dota без большого обновления — в «Обновления игр» как остальные; хотфиксы ИИ отсеет.
pool.sort((a, b) => b.at - a.at);
const perSec = Object.fromEntries(SECTIONS.map((s) => [s.id, 0]));
// У GitHub Models на бесплатном уровне запрос до ~8 тыс. токенов — кандидатов меньше и текст короче; у Gemini — с запасом.
const big = !!process.env.GEMINI_API_KEY;
const PER_SEC = big ? 30 : 10, TEXT = big ? 300 : 110;
pool = pool.filter((i) => (perSec[i.sec] = (perSec[i.sec] || 0) + 1) <= PER_SEC);
pool.forEach((c, k) => { c.id = 'c' + k; c.date = shortDate(c.at); });
const cands = pool.map((c) => ({ ...c, text: plain(c.text, TEXT) }));

let picked = null, headline = '', viaAi = false;
try {
  let text = prompt(cands, SECTIONS, dota && dota.stage === 'big' ? dota.item.title : '');
  if (dota && dota.stage === 'big') {
    text += `\n\nЕщё добавь в ответ поле "dota": {"title":"заголовок до 6 слов, например «Патч 7.42»","text":"одно-два предложения сути","points":["3–5 главных изменений, коротко"]} по этому объявлению Dota 2:\n${JSON.stringify({ title: dota.item.title, text: plain(dota.item.text, big ? 1500 : 600) })}`;
  }
  const ans = await retell(text);
  if (ans) {
    const r = applyLlm(ans, pool, SECTIONS);
    const count = Object.values(r.sections).reduce((a, x) => a + x.length, 0);
    if (count >= 5) {
      picked = r.sections; headline = r.headline; viaAi = true;
      if (dota && ans.dota) dota.extra = { title: plain(ans.dota.title, 60) || dota.item.title, text: plain(ans.dota.text, 300), points: (ans.dota.points || []).map((p) => plain(p, 120)).filter(Boolean).slice(0, 5) };
    } else console.warn('ИИ вернул слишком мало пунктов:', count);
  }
} catch (e) {
  console.warn('ИИ не ответил, отбор без ИИ:', e.message);
}
if (!picked) picked = fallbackPick(pool, SECTIONS);
if (dota && !dota.extra.text) dota.extra = { text: plain(dota.item.text, 260) };

const sections = SECTIONS.map((s) => ({ ...s, items: picked[s.id] || [] }));
const flat = sections.flatMap((s) => s.items);
if (!headline) headline = dota && dota.stage === 'big' ? 'В Dota 2 вышло большое обновление' : flat.length ? 'Свежее из CG и игр за последние дни' : '';

await mkdir(out, { recursive: true });
await writeFile(out + '/index.html', page({ now, sections, headline, dota, viaAi }));
const count = flat.length + (dota && dota.stage === 'big' ? 1 : 0) + (dota && dota.stage === 'star' && !flat.some((i) => i.url === dota.item.url) ? 1 : 0);
const data = {
  date: ymd(now),
  builtAt: now,
  count,
  headline,
  viaAi,
  dota: dota ? { stage: dota.stage, title: dota.extra.title || dota.item.title, url: dota.item.url } : null,
  top: ['cg', 'industry', 'updates'].map((id) => (picked[id] || [])[0]).filter(Boolean).map((i) => ({ title: i.title, url: i.url })),
  failed,
  seen: [...flat.map((i) => i.url), ...(dota ? [dota.item.url] : []), ...seen].slice(0, 400),
};
await writeFile(out + '/data.json', JSON.stringify(data, null, 1));
console.log(`Новостей: ${count} (${viaAi ? 'с ИИ' : 'без ИИ'}), источников не открылось: ${failed.length}${failed.length ? ' — ' + failed.join('; ') : ''}`);
