// Страница «Спутник · Новости» в виде «Система G» (docs/design-g.md): холст с точками, разделы — ноды с цветной шапкой
// моно-капсом «01 · …», Onest + JetBrains Mono, акцент #F0A04B. Тёмная тема основная. Всё экранируется.
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
  const body = shown.map((s, k) => `<div class="sec h-${esc(s.id)}">
  <h2><span>${String(k + 1).padStart(2, '0')} · ${esc(s.title.toUpperCase())}</span><span class="n">${s.items.length}</span></h2>
  <ol class="box">${s.items.map((i) => row(i, i.star)).join('\n')}</ol>
</div>`).join('\n');
  const calm = n ? '' : '<p class="calm">Свежих новостей по твоим темам за последние дни не нашлось.</p>';
  return `<!doctype html>
<html lang="ru"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>Спутник · Новости</title>
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Onest:wght@200;400;500;600&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
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
:root{--ground:#191A1E;--bg:#1C1D21;--node:#25262B;--hover:#2C2D33;--line:#3A3B42;--line-soft:#303137;--ink:#E2E3E8;--muted:#9A9CA6;--dim:#7A7C86;--accent:#F0A04B;--accent-ink:#FFD29C;--dot:rgba(255,255,255,.07);
--h-cg:#5E3F92;--h-industry:#2F4F86;--h-releases:#2E6B3E;--h-updates:#8A5320;--h-hype:#7A6620;
--font-sans:Onest,"Segoe UI",system-ui,sans-serif;--font-mono:"JetBrains Mono","Cascadia Mono",ui-monospace,Consolas,monospace;color-scheme:dark}
@media (prefers-color-scheme:light){:root:not([data-theme="dark"]){--ground:#F3F3F5;--bg:#FAFAFB;--node:#FFFFFF;--hover:#F0F0F3;--line:#D9DAE0;--line-soft:#E6E7EB;--ink:#1F2024;--muted:#5E606A;--dim:#7A7C86;--accent:#B5651A;--accent-ink:#8A4A10;--dot:rgba(0,0,0,.08);color-scheme:light}}
:root[data-theme="light"]{--ground:#F3F3F5;--bg:#FAFAFB;--node:#FFFFFF;--hover:#F0F0F3;--line:#D9DAE0;--line-soft:#E6E7EB;--ink:#1F2024;--muted:#5E606A;--dim:#7A7C86;--accent:#B5651A;--accent-ink:#8A4A10;--dot:rgba(0,0,0,.08);color-scheme:light}
*{box-sizing:border-box}html,body{margin:0;color:var(--ink);font-family:var(--font-sans)}a{color:inherit}
body{background:radial-gradient(var(--dot) 1px,transparent 1px) 0 0/24px 24px,var(--ground)}
.in{max-width:880px;margin:0 auto;padding-left:max(32px,env(safe-area-inset-left,0px));padding-right:max(32px,env(safe-area-inset-right,0px))}
.tabs{background:var(--bg);border-bottom:1px solid var(--line)}.tabs .in{display:flex;align-items:flex-end;gap:28px;padding-block:16px 0}
.brand{display:flex;align-items:center;gap:8px;padding-bottom:10px;margin-right:8px;font:600 14px/20px var(--font-sans)}.brand svg{width:18px;height:18px}
.brand .arc{fill:none;stroke:var(--accent);stroke-width:46;stroke-linecap:round}.brand .core{fill:var(--ink)}.brand .sat{fill:var(--accent);stroke:var(--bg);stroke-width:22}
.tab{padding:0 0 10px;font:500 12px/20px var(--font-mono);letter-spacing:.08em;text-transform:uppercase;border-bottom:2px solid var(--accent)}.tab .n{color:var(--dim);font-weight:400}
.tw{color:var(--accent);display:inline-block;animation:tw 1.6s ease-in-out infinite}
.hero{border-bottom:1px solid var(--line-soft)}.hero .in{padding-block:32px 28px}
.date{margin:0 0 10px;font:500 12px/18px var(--font-mono);letter-spacing:.06em;text-transform:uppercase;color:var(--muted)}.date b{font-weight:500;color:var(--accent)}
h1{margin:0;font-weight:400;font-size:34px;line-height:42px;letter-spacing:-.01em;text-wrap:balance;max-width:680px}
.body .in{padding-block:32px 48px;display:flex;flex-direction:column;gap:28px}
.sec{border-radius:8px;background:var(--node);border:1px solid var(--line);overflow:hidden;animation:up .4s cubic-bezier(.2,.7,.2,1) both}
.sec:nth-child(2){animation-delay:.05s}.sec:nth-child(3){animation-delay:.1s}.sec:nth-child(4){animation-delay:.15s}.sec:nth-child(5){animation-delay:.2s}
h2{margin:0;display:flex;justify-content:space-between;align-items:center;padding:8px 16px;background:var(--hc,#3D3E45);color:#fff;font:500 12px/18px var(--font-mono);letter-spacing:.08em}
h2 .n{font-weight:400;opacity:.75}
.h-cg{--hc:var(--h-cg)}.h-industry{--hc:var(--h-industry)}.h-releases{--hc:var(--h-releases)}.h-updates{--hc:var(--h-updates)}.h-hype{--hc:var(--h-hype)}
.box{list-style:none;margin:0;padding:0;counter-reset:n}
.row{counter-increment:n;display:grid;grid-template-columns:28px minmax(0,1fr);gap:0 10px;padding:14px 16px;transition:background .15s}.row+.row{border-top:1px solid var(--line-soft)}.row:hover{background:var(--hover)}
.row::before{content:counter(n,decimal-leading-zero);font:400 12px/22px var(--font-mono);color:var(--dim)}.row.star::before{content:"✦";color:var(--accent);font-size:15px}
.row>div{min-width:0}.src{display:block;margin-bottom:2px;font:400 11px/16px var(--font-mono);letter-spacing:.04em;color:var(--muted)}
.row .t{font:600 15px/22px var(--font-sans);color:var(--ink);text-decoration:none}.row .t:hover{text-decoration:underline;text-decoration-color:var(--dim);text-underline-offset:3px}
.row .t:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
.row p{margin:3px 0 0;font-size:14px;line-height:21px;color:var(--muted);max-width:68ch}
.calm{margin:0;padding:14px 16px;border:1px dashed var(--line);border-radius:8px;font-size:14px;color:var(--muted)}
.foot{margin:0;font:11px/16px var(--font-mono);letter-spacing:.04em;color:var(--dim)}
@keyframes up{from{opacity:0;transform:translateY(8px)}}
@property --a{syntax:"<angle>";inherits:false;initial-value:0deg}
.dota{position:relative;overflow:hidden;padding:28px 28px 24px;border-radius:12px;color:#FFE9CC;
background:radial-gradient(120% 140% at 20% 0%,#4a2a12,#25262B 60%,#1C1D21) padding-box,conic-gradient(from var(--a),#9A5A22,#F0A04B,#FFD29C,#F0A04B,#9A5A22) border-box;
border:2px solid transparent;box-shadow:0 0 36px rgba(240,160,75,.25);animation:spin 6s linear infinite}
.dota::after{content:"";position:absolute;inset:0;background:linear-gradient(105deg,transparent 40%,rgba(255,233,176,.14) 50%,transparent 60%);transform:translateX(-100%);animation:shine 4.5s ease-in-out infinite;pointer-events:none}
.spark{position:absolute;width:14px;height:14px;animation:tw 2.2s ease-in-out infinite}.spark svg{width:100%;height:100%;fill:#FFE9B0;filter:drop-shadow(0 0 4px #F4C66B)}
.dota-k{margin:0 0 8px;font:500 12px/16px var(--font-mono);letter-spacing:.08em;color:#F0A04B}
.dota-h{display:block;margin:0 0 10px;font:500 38px/44px var(--font-sans);background:linear-gradient(90deg,#F0A04B,#FFD29C,#F0A04B,#FFD29C);background-size:200% auto;-webkit-background-clip:text;background-clip:text;color:transparent;animation:flow 5s linear infinite}
.dota-p{margin:0 0 12px;font-size:15px;line-height:22px;color:#F3DFC2;max-width:62ch}
.dota-l{margin:0 0 16px;padding:0;list-style:none;display:grid;grid-template-columns:1fr 1fr;gap:6px 20px}.dota-l li{font-size:14px;line-height:20px;color:#F3DFC2}.dota-l li::before{content:"✦ ";color:#F4C66B}
.dota-a{margin:0;display:flex;align-items:center;gap:14px;flex-wrap:wrap}.dota-a a{display:inline-block;padding:9px 16px;border-radius:6px;background:#F0A04B;color:#1C1D21;font:600 14px/20px var(--font-sans);text-decoration:none}
.dota-a span{font-size:13px;color:#D9B98F}
@keyframes spin{to{--a:360deg}}@keyframes shine{0%,60%{transform:translateX(-100%)}100%{transform:translateX(100%)}}@keyframes tw{0%,100%{opacity:.35;transform:scale(.8)}50%{opacity:1;transform:scale(1.1)}}@keyframes flow{to{background-position:200% center}}
@media (prefers-reduced-motion:reduce){.dota,.dota::after,.spark,.dota-h,.tw,.sec{animation:none}}
@media (max-width:640px){.in{padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px))}h1{font-size:28px;line-height:35px}.row{padding:12px 14px;grid-template-columns:22px minmax(0,1fr)}.dota{padding:22px 18px}.dota-h{font-size:28px;line-height:34px}.dota-l{grid-template-columns:1fr}}
`;
