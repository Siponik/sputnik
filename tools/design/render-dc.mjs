// Рисует макет с холста (design/screens/*.dc.html) в PNG — чтобы сравнить с тем, что получилось в трекере.
// Макеты — шаблоны: {{дырки}}, <sc-for>, <sc-if>, логика в классе Component (renderVals()).
// Здесь — маленький исполнитель этих шаблонов прямо в браузере Playwright.
//
//   node tools/design/render-dc.mjs design/screens/Kanban.dc.html out.png
//   node tools/design/render-dc.mjs design/screens/Kanban.dc.html out.png "demo=меню" "theme=light"
//   node tools/design/render-dc.mjs design/screens/Conveyor.dc.html out.png --click ".cv-row .name"
//
// Нужен playwright: npm i -D playwright && npx playwright install chromium (один раз, из папки tracker).
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { createRequire } from 'node:module';

const args = process.argv.slice(2);
const file = resolve(args[0]);
const out = resolve(args[1] ?? 'dc.png');
const props = {};
const clicks = [];
for (let i = 2; i < args.length; i++) {
  if (args[i] === '--click') clicks.push(args[++i]);
  else if (args[i].includes('=')) { const [k, v] = args[i].split('='); props[k] = v; }
}

const src = readFileSync(file, 'utf8');
const tpl = src.match(/<x-dc>([\s\S]*)<\/x-dc>/)[1];
const helmet = (tpl.match(/<helmet>([\s\S]*?)<\/helmet>/) ?? [, ''])[1];
const body = tpl.replace(/<helmet>[\s\S]*?<\/helmet>/, '');
const script = src.match(/<script[^>]*data-dc-script[^>]*?(?:data-props='([^']*)')?[^>]*>([\s\S]*?)<\/script>/);
const meta = script[1] ? JSON.parse(script[1]) : {};
for (const [k, d] of Object.entries(meta)) if (!(k in props) && d && 'default' in d) props[k] = d.default;
const size = meta.$preview ?? { width: 1440, height: 900 };
// Общие классы sp-* (шапка, кнопки) — те же, что в трекере; на холсте они приходят из bundle.css дизайн-системы.
const ds = ['tokens.css', 'components.css'].map((f) => { try { return readFileSync(resolve('tracker/src/styles', f), 'utf8'); } catch { return ''; } }).join('\n');

const html = `<!doctype html><html lang="ru"><head><meta charset="utf-8"><style>${ds}</style>${helmet}</head><body><div id="root"></div>
<template id="tpl">${body}</template>
<script>
class DCLogic { constructor(p) { this.props = p || {}; this.state = this.state || {}; } setState(x) { Object.assign(this.state, typeof x === 'function' ? x(this.state) : x); window.__draw(); } }
${script[2]}
const comp = new Component(${JSON.stringify(props)});
const get = (scope, path) => path.split('.').reduce((o, k) => (o == null ? undefined : o[k]), scope);
const HOLE = /\\{\\{\\s*([\\w.]+)\\s*\\}\\}/g;
const one = (s) => { const m = /^\\s*\\{\\{\\s*([\\w.]+)\\s*\\}\\}\\s*$/.exec(s); return m && m[1]; };
const fill = (s, scope) => s.replace(HOLE, (_, p) => { const v = get(scope, p); return v == null || v === false ? '' : v === true ? 'true' : String(v); });
function walk(node, scope, into) {
  for (const n of node.childNodes) {
    if (n.nodeType === 3) { into.appendChild(document.createTextNode(fill(n.textContent, scope))); continue; }
    if (n.nodeType !== 1) continue;
    const tag = n.tagName.toLowerCase();
    if (tag === 'sc-for') {
      const list = get(scope, one(n.getAttribute('list'))) || [];
      const as = n.getAttribute('as');
      list.forEach((item, i) => walk(n, { ...scope, [as]: item, [as + 'Index']: i }, into));
      continue;
    }
    if (tag === 'sc-if') { if (get(scope, one(n.getAttribute('value')))) walk(n, scope, into); continue; }
    const el = document.createElementNS(n.namespaceURI, n.tagName.includes(':') ? n.tagName : (n.namespaceURI.includes('svg') ? n.localName : tag));
    for (const a of n.attributes) {
      const p = one(a.value);
      if (/^on[A-Z]/.test(a.name) || /^on[a-z]/.test(a.name) && p) {
        const fn = p && get(scope, p);
        if (typeof fn === 'function') el.addEventListener(a.name.slice(2).toLowerCase(), (e) => { fn(e); window.__draw(); });
        continue;
      }
      el.setAttribute(a.name, fill(a.value, scope));
    }
    walk(n.content ?? n, scope, el);
    into.appendChild(el);
  }
}
window.__draw = () => { const root = document.getElementById('root'); root.textContent = ''; walk(document.getElementById('tpl').content, comp.renderVals(), root); };
window.__draw();
</script></body></html>`;

const require = createRequire(resolve('tracker/package.json'));
let chromium;
try { ({ chromium } = require('playwright')); } catch { ({ chromium } = await import('playwright')); }
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: size.width, height: size.height } });
p.on('pageerror', (e) => console.error('Ошибка в макете:', e.message));
await p.setContent(html);
for (const c of clicks) { await p.click(c); await p.waitForTimeout(150); }
await p.waitForTimeout(300);
await p.screenshot({ path: out, fullPage: true });
await b.close();
console.log('Готово:', out);
