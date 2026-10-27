// Новости без Claude (tools/news): разбор лент, окно по датам, повторы, правило Dota 2, проверка ответа ИИ, страница.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseFeed, parseSteam, fresh, unseen, fallbackPick, applyLlm, dotaSignificant, dotaStage, shortDate, ymd } from '../../tools/news/core.mjs';
import { page } from '../../tools/news/render.mjs';
import { SECTIONS } from '../../tools/news/feeds.mjs';

const RSS = `<?xml version="1.0"?><rss><channel><title>X</title>
<item><title><![CDATA[Blender 5.1 &amp; friends]]></title><link>https://ex.com/a?utm=1</link><pubDate>Thu, 22 Oct 2026 10:00:00 +0000</pubDate><description>&lt;p&gt;New &lt;b&gt;tools&lt;/b&gt;&lt;/p&gt;</description></item>
<item><title>No date</title><link>https://ex.com/b</link></item>
<item><title>Http only</title><link>http://ex.com/c</link><pubDate>Thu, 22 Oct 2026 10:00:00 +0000</pubDate></item>
</channel></rss>`;

const ATOM = `<feed><entry><title>Atom one</title><link rel="alternate" href="https://ex.com/atom"/><updated>2026-10-21T08:00:00Z</updated><summary>Sum</summary></entry></feed>`;

test('RSS и Atom: заголовок, ссылка, дата, текст без тегов; без даты и не https — мимо', () => {
  const r = parseFeed(RSS, 'Src', 'cg');
  assert.equal(r.length, 1);
  assert.equal(r[0].title, 'Blender 5.1 & friends');
  assert.equal(r[0].url, 'https://ex.com/a?utm=1');
  assert.equal(r[0].text, 'New tools');
  assert.equal(r[0].at, Date.parse('2026-10-22T10:00:00Z'));
  const a = parseFeed(ATOM, 'A', 'hype');
  assert.equal(a[0].url, 'https://ex.com/atom');
  assert.equal(a[0].sec, 'hype');
});

test('Steam: пункты в «Обновления игр», BB-код вычищен', () => {
  const r = parseSteam({ appnews: { newsitems: [{ title: 'Patch 7.42', url: 'https://store.steampowered.com/news/1', date: 1792700000, contents: '[b]Big[/b] changes' }] } }, { name: 'Dota 2', dota: true });
  assert.equal(r[0].sec, 'updates');
  assert.equal(r[0].text, 'Big changes');
  assert.ok(r[0].dota);
});

test('окно: три дня, хайп — двое суток; повторы по ссылке без хвоста', () => {
  const now = Date.parse('2026-10-23T02:30:00Z');
  const items = [
    { sec: 'cg', at: now - 2.5 * 864e5, url: 'https://a.com/1' },
    { sec: 'cg', at: now - 3.5 * 864e5, url: 'https://a.com/2' },
    { sec: 'hype', at: now - 2.5 * 864e5, url: 'https://a.com/3' },
  ];
  assert.deepEqual(fresh(items, now).map((i) => i.url), ['https://a.com/1']);
  const u = unseen([{ url: 'https://a.com/1?x=1' }, { url: 'https://a.com/4/' }, { url: 'https://a.com/4' }], ['https://a.com/1']);
  assert.deepEqual(u.map((i) => i.url), ['https://a.com/4/']);
});

test('Dota 2: номерной патч, сундук и персона — да; хотфикс, буквенный без крупного и турнир — нет', () => {
  const s = (title, text = '') => dotaSignificant({ title, text });
  assert.ok(s('Gameplay Patch 7.42'));
  assert.ok(s('The Crownfall Treasure II is here'));
  assert.ok(s('New Persona for Invoker'));
  assert.ok(!s('Gameplay Patch 7.41e', 'balance changes'));
  assert.ok(s('Gameplay Patch 7.41e and new hero Kez'));
  assert.ok(!s('Hotfix for 7.42'));
  assert.ok(!s('Riyadh Masters Major'));
  assert.ok(!s('Dota 2 Client Update'));
});

test('Dota 2: затухание — после прошлой сборки большой блок, до 3 дней звезда, потом ничего', () => {
  const now = Date.parse('2026-10-23T02:30:00Z'), prev = now - 864e5;
  assert.equal(dotaStage({ at: now - 3600e3 }, prev, now), 'big');
  assert.equal(dotaStage({ at: now - 2 * 864e5 }, prev, now), 'star');
  assert.equal(dotaStage({ at: now - 4 * 864e5 }, prev, now), null);
  assert.equal(dotaStage(undefined, prev, now), null);
});

test('без ИИ: свежие сверху, не больше max и не всё из одного источника', () => {
  const items = Array.from({ length: 12 }, (_, k) => ({ sec: 'cg', src: k < 9 ? 'A' : 'B', at: 1000 + k, title: 't' + k, url: 'https://x/' + k }));
  const r = fallbackPick(items, SECTIONS);
  assert.ok(r.cg.length <= 8);
  assert.equal(r.cg[0].title, 't11');
  assert.ok(r.cg.filter((i) => i.src === 'A').length <= 4);
  assert.equal(fallbackPick([{ sec: 'industry', src: 'A', at: 1, title: 'Турнир по CS', url: 'https://x' }], SECTIONS).industry.length, 0);
});

test('ответ ИИ: чужие id, повторы и лишние разделы отброшены, текст берётся из ответа', () => {
  const cands = [{ id: 'c0', sec: 'cg', title: 'Orig', url: 'https://x/0', at: 1, src: 'S' }, { id: 'c1', sec: 'hype', title: 'O1', url: 'https://x/1', at: 1, src: 'S' }];
  const r = applyLlm({ headline: 'Главное', items: [
    { id: 'c0', sec: 'cg', title: 'Новый <b>Blender</b>', text: 'Суть.' },
    { id: 'c0', sec: 'cg', title: 'Повтор' },
    { id: 'c9', sec: 'cg', title: 'Выдумка' },
    { id: 'c1', sec: 'nope', title: 'В свой раздел', text: '' },
  ] }, cands, SECTIONS);
  assert.equal(r.headline, 'Главное');
  assert.deepEqual(r.sections.cg.map((i) => [i.title, i.url]), [['Новый Blender', 'https://x/0']]);
  assert.equal(r.sections.hype[0].title, 'В свой раздел');
});

test('даты по Москве', () => {
  assert.equal(shortDate(Date.parse('2026-10-22T22:30:00Z')), 'пт, 23 окт.');
  assert.equal(ymd(Date.parse('2026-10-22T22:30:00Z')), '2026-10-23');
});

test('страница: экранирование, звезда Dota первой в обновлениях, пустые разделы скрыты', () => {
  const now = Date.parse('2026-10-23T02:30:00Z');
  const html = page({
    now, headline: 'A <script>', viaAi: true,
    sections: SECTIONS.map((s) => ({ ...s, items: s.id === 'updates' ? [{ title: 'Other', url: 'https://u/1', at: now, src: 'S' }] : [] })),
    dota: { stage: 'star', item: { title: 'Patch 7.42', url: 'https://d/1', at: now - 2 * 864e5, src: 'Dota 2 · Steam' }, extra: {} },
  });
  assert.ok(html.includes('A &lt;script&gt;'));
  assert.ok(html.indexOf('Patch 7.42') < html.indexOf('Other'));
  assert.ok(html.includes('row star'));
  assert.ok(!html.includes('CG и 3D'));
  assert.ok(html.includes('Новости <span class="n">· 2</span>'));
  const big = page({ now, headline: 'x', sections: SECTIONS.map((s) => ({ ...s, items: [] })), dota: { stage: 'big', item: { title: 'Patch 7.42', url: 'https://d/1', at: now, src: 'Steam' }, extra: { points: ['a', 'b'] } } });
  assert.ok(big.includes('БОЛЬШОЕ ОБНОВЛЕНИЕ'));
  assert.ok(big.includes('class="tw"'));
});
