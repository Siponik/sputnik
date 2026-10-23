// Страница «Спутник · Новости» в дизайне утренней сводки v2 (тёмная тема основная). Всё экранируется.
import { shortDate } from './core.mjs';

export const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

const WD = ['Воскресенье', 'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота'];
const MON = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];

function dayLine(ms) {
  const d = new Date(ms + 3 * 36e5);
  return `<b>${WD[d.getUTCDay()]}</b> · ${d.getUTCDate()} ${MON[d.getUTCMonth()]} ${d.getUTCFullYear()}`;
}

const STAR = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 0C13 8 16 11 24 12 16 13 13 16 12 24 11 16 8 13 0 12 8 11 11 8 12 0Z"/></svg>';

function row(i, star) {
  const when = shortDate(i.at);
  return `<li class="row${star ? ' star' : ''}"><div>
  <span class="src">${esc(i.src)} · <time>${esc(when)}</time></span>
  <a class="t" href="${esc(i.url)}" target="_blank" rel="noopener">${esc(i.title)}</a>
  ${i.text ? `<p>${esc(i.text)}</p>` : ''}
</div></li>`;
}

function dotaBlock(d) {
  const stars = [[6, 14], [18, 70], [44, 8], [70, 82], [88, 20], [94, 64], [30, 90]]
    .map(([x, y], k) => `<span class="spark" style="left:${x}%;top:${y}%;animation-delay:${(k * 0.37).toFixed(2)}s">${STAR}</span>`).join('');
  const points = (d.points || []).slice(0, 5).map((p) => `<li>${esc(p)}</li>`).join('');
  return `<section class="dota" aria-label="Большое обновление Dota 2">${stars}
  <p class="dota-k">✦ DOTA 2 · БОЛЬШОЕ ОБНОВЛЕНИЕ · ${esc(shortDate(d.at))}</p>
  <h2 class="dota-h">${esc(d.title)}</h2>
  ${d.text ? `<p class="dota-p">${esc(d.text)}</p>` : ''}
  ${points ? `<ul class="dota-l">${points}</ul>` : ''}
  <p class="dota-a"><a href="${esc(d.url)}" target="_blank" rel="noopener">Открыть патчноут</a><span>${esc(d.src)}</span></p>
</section>`;
}

/**
 * page({ now, sections: [{ id, title, items }], headline, dota: { stage, item } , viaAi })
 * stage 'big' — огромный блок первым; 'star' — строка со звездой первой в «Обновлениях игр».
 */
export function page({ now, sections, headline, dota, viaAi }) {
  const secs = sections.map((s) => ({ ...s, items: s.items.slice() }));
  if (dota && dota.stage === 'star') {
    const up = secs.find((s) => s.id === 'updates');
    if (up) up.items = [{ ...dota.item, star: true }, ...up.items.filter((i) => i.url !== dota.item.url)];
  }
  const shown = secs.filter((s) => s.items.length);
  const n = shown.reduce((a, s) => a + s.items.length, 0) + (dota && dota.stage === 'big' ? 1 : 0);
  const body = shown.map((s) => `<div class="sec">
  <h2>${esc(s.title)} <span class="n">${s.items.length}</span></h2>
  <ol class="box">${s.items.map((i) => row(i, i.star)).join('\n')}</ol>
</div>`).join('\n');
  const calm = n ? '' : '<p class="calm">Свежих новостей по твоим темам за последние дни не нашлось.</p>';
  return `<!doctype html>
<html lang="ru"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>Спутник · Новости</title>
<style>${CSS}</style></head>
<body>
<nav class="tabs"><div class="in">
  <span class="brand"><svg viewBox="0 0 512 512" aria-hidden="true"><path class="arc" d="M370.9 159.6 A150 150 0 1 0 370.9 352.4"/><circle class="core" cx="256" cy="256" r="62"/><circle class="sat" cx="370.9" cy="159.6" r="42"/></svg>Спутник</span>
  <span class="tab" aria-current="page">Новости <span class="n">· ${n}</span>${dota && dota.stage === 'big' ? ' <span class="tw">✦</span>' : ''}</span>
</div></nav>
<header class="hero"><div class="in">
  <p class="date">${dayLine(now)}</p>
  <h1>${esc(headline || 'Что нового в CG и играх')}</h1>
</div></header>
<main class="body"><div class="in">
${dota && dota.stage === 'big' ? dotaBlock({ ...dota.item, ...dota.extra }) : ''}
${body}${calm}
<p class="foot">Собрано ${esc(new Date(now + 3 * 36e5).toISOString().slice(11, 16))} МСК из RSS-лент${viaAi ? ', пересказ — ИИ' : ''}.</p>
</div></main>
</body></html>
`;
}

const CSS = `
:root{--bg:#1C1B19;--wash:#22211E;--raised:#282723;--hairline:#34332E;--edge:#3A3934;--ink:#ECEAE3;--ink-soft:#A8A69D;--ink-faint:#7C7B72;--clay:#D9774F;--gold:#E0A04A;--gold-soft:#3A2E1A;--glow:rgba(217,119,79,.10);
--font-display:"Iowan Old Style","Palatino Linotype",Palatino,Georgia,serif;--font-sans:-apple-system,"Segoe UI",system-ui,sans-serif;--font-mono:"Cascadia Mono",ui-monospace,Consolas,monospace;color-scheme:dark}
@media (prefers-color-scheme:light){:root:not([data-theme="dark"]){--bg:#FCFCFB;--wash:#F5F4F0;--raised:#FFFFFF;--hairline:#E4E3DC;--edge:#E1E1DF;--ink:#2E2C27;--ink-soft:#6B6A63;--ink-faint:#8A897F;--clay:#AD4F2C;--gold:#8F5A00;--gold-soft:#FBF1DF;--glow:rgba(173,79,44,.07);color-scheme:light}}
:root[data-theme="light"]{--bg:#FCFCFB;--wash:#F5F4F0;--raised:#FFFFFF;--hairline:#E4E3DC;--edge:#E1E1DF;--ink:#2E2C27;--ink-soft:#6B6A63;--ink-faint:#8A897F;--clay:#AD4F2C;--gold:#8F5A00;--gold-soft:#FBF1DF;--glow:rgba(173,79,44,.07);color-scheme:light}
*{box-sizing:border-box}html,body{margin:0;background:var(--bg);color:var(--ink);font-family:var(--font-sans)}a{color:inherit}
.in{max-width:880px;margin:0 auto;padding-left:max(32px,env(safe-area-inset-left,0px));padding-right:max(32px,env(safe-area-inset-right,0px))}
.tabs{background:var(--wash);border-bottom:1px solid var(--edge)}.tabs .in{display:flex;align-items:flex-end;gap:28px;padding-block:18px 0}
.brand{display:flex;align-items:center;gap:8px;padding-bottom:10px;margin-right:8px;font:600 14px/20px var(--font-sans)}.brand svg{width:18px;height:18px}
.brand .arc{fill:none;stroke:var(--clay);stroke-width:46;stroke-linecap:round}.brand .core{fill:var(--ink)}.brand .sat{fill:var(--ink);stroke:var(--wash);stroke-width:22}
.tab{padding:0 0 10px;font:500 14px/20px var(--font-sans);border-bottom:2px solid var(--ink)}.tab .n{color:var(--ink-faint);font-weight:400}
.tw{color:var(--clay);display:inline-block;animation:tw 1.6s ease-in-out infinite}
.hero{background:radial-gradient(80% 140% at 100% 0%,var(--glow),transparent 60%),var(--wash);border-bottom:1px solid var(--edge)}.hero .in{padding-block:32px 28px}
.date{margin:0 0 10px;font:500 13px/18px var(--font-sans);color:var(--ink-soft)}.date b{font-weight:600;color:var(--ink)}
h1{margin:0;font-family:var(--font-display);font-weight:600;font-size:34px;line-height:42px;text-wrap:balance;max-width:680px}
.body .in{padding-block:36px 48px;display:flex;flex-direction:column;gap:36px}
.sec{display:flex;flex-direction:column;gap:12px}h2{margin:0;display:flex;align-items:baseline;gap:8px;font:600 16px/22px var(--font-sans)}h2 .n{font:400 13px var(--font-mono);color:var(--ink-faint)}
.box{list-style:none;margin:0;padding:0;border-radius:8px;background:var(--raised);border:1px solid var(--edge);counter-reset:n}
.row{counter-increment:n;display:grid;grid-template-columns:28px minmax(0,1fr);gap:0 10px;padding:14px 16px}.row+.row{border-top:1px solid var(--hairline)}
.row::before{content:counter(n);font:400 13px/22px var(--font-mono);color:var(--ink-faint)}.row.star::before{content:"✦";color:#E0A04A;font-size:15px}
.row>div{min-width:0}.src{display:block;margin-bottom:2px;font:500 12px/16px var(--font-sans);color:var(--ink-soft)}
.row .t{font:600 15px/22px var(--font-sans);color:var(--ink);text-decoration:none}.row .t:hover{text-decoration:underline;text-decoration-color:var(--ink-faint);text-underline-offset:3px}
.row .t:focus-visible{outline:2px solid var(--clay);outline-offset:2px}
.row p{margin:3px 0 0;font-size:14px;line-height:21px;color:var(--ink-soft);max-width:68ch}
.calm{margin:0;padding:14px 16px;border:1px dashed var(--edge);border-radius:12px;font-size:14px;color:var(--ink-soft)}
.foot{margin:0;font:12px/16px var(--font-mono);color:var(--ink-faint)}
@property --a{syntax:"<angle>";inherits:false;initial-value:0deg}
.dota{position:relative;overflow:hidden;padding:28px 28px 24px;border-radius:16px;color:#FFF3DC;
background:radial-gradient(120% 140% at 20% 0%,#5a1d10,#2a0e08 55%,#140806) padding-box,conic-gradient(from var(--a),#E0703E,#F4C66B,#FFE9B0,#F4C66B,#E0703E) border-box;
border:2px solid transparent;box-shadow:0 0 36px rgba(224,112,62,.35);animation:spin 6s linear infinite}
.dota::after{content:"";position:absolute;inset:0;background:linear-gradient(105deg,transparent 40%,rgba(255,233,176,.14) 50%,transparent 60%);transform:translateX(-100%);animation:shine 4.5s ease-in-out infinite;pointer-events:none}
.spark{position:absolute;width:14px;height:14px;animation:tw 2.2s ease-in-out infinite}.spark svg{width:100%;height:100%;fill:#FFE9B0;filter:drop-shadow(0 0 4px #F4C66B)}
.dota-k{margin:0 0 8px;font:700 12px/16px var(--font-sans);letter-spacing:.08em;color:#F4C66B}
.dota-h{display:block;margin:0 0 10px;font:600 38px/44px var(--font-display);background:linear-gradient(90deg,#F4C66B,#FFE9B0,#E0703E,#F4C66B);background-size:200% auto;-webkit-background-clip:text;background-clip:text;color:transparent;animation:flow 5s linear infinite}
.dota-p{margin:0 0 12px;font-size:15px;line-height:22px;color:#F3DFC2;max-width:62ch}
.dota-l{margin:0 0 16px;padding:0;list-style:none;display:grid;grid-template-columns:1fr 1fr;gap:6px 20px}.dota-l li{font-size:14px;line-height:20px;color:#F3DFC2}.dota-l li::before{content:"✦ ";color:#F4C66B}
.dota-a{margin:0;display:flex;align-items:center;gap:14px;flex-wrap:wrap}.dota-a a{display:inline-block;padding:9px 16px;border-radius:8px;background:linear-gradient(90deg,#F4C66B,#E0703E);color:#2a0e08;font:600 14px/20px var(--font-sans);text-decoration:none}
.dota-a span{font-size:13px;color:#D9B98F}
@keyframes spin{to{--a:360deg}}@keyframes shine{0%,60%{transform:translateX(-100%)}100%{transform:translateX(100%)}}@keyframes tw{0%,100%{opacity:.35;transform:scale(.8)}50%{opacity:1;transform:scale(1.1)}}@keyframes flow{to{background-position:200% center}}
@media (prefers-reduced-motion:reduce){.dota,.dota::after,.spark,.dota-h,.tw{animation:none}}
@media (max-width:640px){.in{padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px))}h1{font-size:28px;line-height:35px}.row{padding:12px 14px;grid-template-columns:22px minmax(0,1fr)}.dota{padding:22px 18px}.dota-h{font-size:28px;line-height:34px}.dota-l{grid-template-columns:1fr}}
`;
