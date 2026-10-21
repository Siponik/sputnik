// Скриншоты трекера в демо-режиме — чтобы сравнить с макетами (design/screens/ref/*.png).
// Сначала в другом окне: cd tracker; npm run demo   (откроется http://localhost:1421)
// Потом:                 cd tracker; npm run shot    → картинки в tracker/shots/ (папка в .gitignore)
//
// Сравнивай попарно:
//   shots/kanban.png        ↔ design/screens/ref/kanban-обычный.png
//   shots/kanban-menu.png   ↔ design/screens/ref/kanban-меню.png
//   shots/conveyor.png      ↔ design/screens/ref/conveyor.png   (первая строка раскрыта)
//   shots/stickers.png      ↔ design/screens/ref/stickers-по-темам.png
//   shots/stickers-when.png ↔ design/screens/ref/stickers-по-срокам.png
//   shots/stickers-light.png ↔ design/screens/ref/stickers-светлая.png
//   shots/create-личное.png  ↔ design/screens/ref/create-личное.png   (окно «Создать», стикеры)
//   shots/create-работа.png  ↔ design/screens/ref/create-работа.png   (канбан)
//   shots/create-3D.png      ↔ design/screens/ref/create-3D.png       (конвейер)
//   shots/create-куда.png, create-событие.png, create-др.png ↔ design/screens/ref/create-список-событие-др.png
//   shots/*-light.png       — то же в светлой теме
import { mkdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(resolve('package.json'));
const { chromium } = require('playwright');
const URL = process.env.DEMO_URL ?? 'http://localhost:1421/';
const out = resolve('shots');
mkdirSync(out, { recursive: true });

const b = await chromium.launch();
const errors = [];
async function page(theme) {
  const p = await b.newPage({ viewport: { width: 1440, height: 900 }, colorScheme: theme });
  p.on('pageerror', (e) => errors.push(e.message));
  p.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  await p.goto(URL);
  await p.waitForTimeout(1200);
  return p;
}
const shot = async (p, name) => { await p.waitForTimeout(500); await p.screenshot({ path: `${out}/${name}.png` }); console.log('  ', name); };
const tab = (p, name) => p.getByRole('button', { name, exact: false }).or(p.getByRole('tab', { name })).first().click();
const list = (p, name) => p.locator('aside, nav, .side').getByText(name, { exact: true }).first().click();

for (const theme of ['dark', 'light']) {
  const sfx = theme === 'light' ? '-light' : '';
  const p = await page(theme);
  if (theme === 'light') await p.evaluate(() => document.documentElement.setAttribute('data-theme', 'light'));
  await tab(p, 'Доска');
  await list(p, 'Иконки для клиента');
  await shot(p, 'kanban' + sfx);
  // наведение на карточку — кнопки → 📅 ⋯
  await p.locator('.kc').nth(4).hover();
  await shot(p, 'kanban-hover' + sfx);
  // меню задачи — правый клик
  await p.locator('.kc').nth(4).click({ button: 'right' });
  await shot(p, 'kanban-menu' + sfx);
  await p.keyboard.press('Escape');
  await list(p, '3D-проекты');
  await shot(p, 'conveyor-closed' + sfx);
  await p.getByText('Башня lowpoly', { exact: true }).first().click();
  await shot(p, 'conveyor' + sfx);
  await list(p, 'Дела по дому');
  await shot(p, 'stickers' + sfx);
  if (await p.locator('.stk').count()) {
    // «Сделано» — штамп на стикере «Позвонить бабушке» (до улёта в баночку 2 с)
    await p.locator('.stk', { hasText: 'Позвонить бабушке' }).locator('.ck').click();
    await p.waitForTimeout(300);
    await p.screenshot({ path: `${out}/stickers-done${sfx}.png` }); console.log('   stickers-done' + sfx);
    await p.waitForTimeout(2600);
    await p.keyboard.press('KeyG');
    await shot(p, 'stickers-when' + sfx);
    await p.keyboard.press('KeyG');
  }
  // Окно «Создать» v2: три случая, как Create.dc.html (demo = личное / работа / 3D), и CreateMore.dc.html.
  await tab(p, 'Сегодня');
  const create = async (line, name, extra) => {
    await p.waitForTimeout(300); // прежнее окно успело закрыться
    await p.locator('button[title^="Новая задача"]').first().click();
    await p.locator('.cr-input').fill(line);
    await p.waitForTimeout(250);
    if (extra) await extra();
    await shot(p, name + sfx);
  };
  await create('купить лампочки в коридор в субботу', 'create-личное');
  await p.keyboard.press('Alt+KeyL');
  await shot(p, 'create-куда' + sfx);
  await p.keyboard.press('Escape');
  await p.keyboard.press('Escape');
  await create('смета для клиента по иконкам завтра 15:00 !!', 'create-работа', async () => {
    await p.locator('.cr-subin').fill('Собрать список иконок'); await p.keyboard.press('Enter');
    await p.locator('.cr-subin').fill('Посчитать часы'); await p.keyboard.press('Enter');
  });
  await p.keyboard.press('Escape');
  await create('сундук с золотом lowpoly для таверны', 'create-3D', async () => {
    await p.locator('.cr-c.p2').click();
  });
  await p.keyboard.press('Escape');
  await create('Созвон с клиентом по иконкам завтра 14:00', 'create-событие', async () => {
    await p.keyboard.press('Alt+Digit2');
    await p.locator('.cr-c', { hasText: '45 мин' }).click();
  });
  await p.keyboard.press('Escape');
  await create('Аня 12 марта', 'create-др', async () => {
    await p.keyboard.press('Alt+Digit3');
    await p.locator('.cr-fld').fill('1997');
  });
  await p.keyboard.press('Escape');
  await p.close();
}
await b.close();
if (errors.length) { console.log('\nОшибки на странице:'); for (const e of [...new Set(errors)]) console.log(' -', e); }
console.log('\nГотово:', out);
