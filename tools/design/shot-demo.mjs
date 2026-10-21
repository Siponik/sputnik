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
//   Версия 0.6.0 (docs/release-0.6.0.md):
//   shots/shell.png, shell-свёрнуто.png, shell-наведение.png ↔ design/screens/ref/shell-обычный/свёрнуто/наведение.png
//   shots/shell-состояние.png, shell-обновление.png, shell-нет-связи.png ↔ ref/shell-состояние/обновление/нет связи.png
//   shots/settings-вид.png, settings-напоминания.png, settings-клавиши.png ↔ ref/settings-*.png
//   shots/today.png ↔ ref/today-0.6.png (строка с «Понял:», привычки, входящие — today-низ.png)
//   shots/header-1180.png, header-1920.png — шапка в одну строку на узком и широком окне
//   shots/calendar-week*.png — неделя календаря на плотной неделе («Тест · нагрузка»), своего макета нет
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
const list = (p, name) => p.locator('aside').getByText(name, { exact: true }).first().click();

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
  // Календарь, неделя: плотная неделя из списка «Тест · нагрузка» (весь день с «+ ещё», сетка, обзор недели).
  await tab(p, 'Календарь');
  await shot(p, 'calendar-week' + sfx);
  const more = p.locator('.ad-more').first();
  if (await more.count()) { await more.click(); await shot(p, 'calendar-week-allday' + sfx); await p.locator('.ad-fold').click(); }
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
  // 0.6: «Сегодня» — умная строка, привычки «таблетками», входящие от Claude
  await p.waitForTimeout(300);
  await p.locator('.qa input').fill('скетч таверны 17:00');
  await shot(p, 'today' + sfx);
  await p.locator('.qa input').fill('');
  await p.locator('.inbox').scrollIntoViewIfNeeded();
  await shot(p, 'today-низ' + sfx);
  // 0.6: «Состояние», настройки
  await p.locator('.hd-stat').click();
  await shot(p, 'shell-состояние' + sfx);
  await p.keyboard.press('Escape');
  for (const [tabName, name] of [['Вид', 'вид'], ['Напоминания', 'напоминания'], ['Клавиши', 'клавиши']]) {
    if (!(await p.locator('.stg-win').count())) await p.keyboard.press('Control+Comma');
    await p.locator('.stg-win nav button', { hasText: tabName }).first().click();
    await shot(p, 'settings-' + name + sfx);
  }
  await p.keyboard.press('Escape');
  // 0.6: левая колонка — закреплена, свёрнута (Ctrl+B), выезд при наведении
  await tab(p, 'Доска');
  await p.waitForTimeout(400);
  await list(p, 'Иконки для клиента');
  await shot(p, 'shell' + sfx);
  await p.keyboard.press('Control+KeyB');
  await shot(p, 'shell-свёрнуто' + sfx);
  await p.locator('aside.sd.rail').hover();
  await p.waitForTimeout(400);
  await shot(p, 'shell-наведение' + sfx);
  await p.mouse.move(900, 500);
  await p.keyboard.press('Control+KeyB');
  await p.close();
}
// 0.6: вышла новая версия (подменённый check(), ?upd=) и «Нет связи»
{
  const p = await b.newPage({ viewport: { width: 1440, height: 900 }, colorScheme: 'dark' });
  p.on('pageerror', (e) => errors.push(e.message));
  await p.goto(URL + '?upd=0.6.4'); await p.waitForTimeout(2500);
  await p.locator('.hd-upd').click();
  await shot(p, 'shell-обновление');
  await p.keyboard.press('Escape');
  await p.evaluate(() => { window.__demo = { offline: true }; });
  await p.keyboard.press('KeyR');
  await p.waitForTimeout(1500);
  await shot(p, 'shell-нет-связи');
  await p.close();
}
// 0.6: шапка в одну строку на 1180 и 1920 px
for (const w of [1180, 1920]) {
  const p = await b.newPage({ viewport: { width: w, height: 300 }, colorScheme: 'dark' });
  p.on('pageerror', (e) => errors.push(e.message));
  await p.goto(URL); await p.waitForTimeout(1200);
  const h = await p.locator('.sp-hd').evaluate((el) => el.getBoundingClientRect().height);
  const over = await p.locator('.sp-hd').evaluate((el) => el.scrollWidth > el.clientWidth);
  if (h > 60 || over) errors.push(`шапка при ${w} px: высота ${h}, вылезает: ${over}`);
  await p.screenshot({ path: `${out}/header-${w}.png`, clip: { x: 0, y: 0, width: w, height: 56 } }); console.log('   header-' + w);
  await p.close();
}
// Большой экран, как у пользователя (1920×1080): неделя целиком.
{
  const p = await b.newPage({ viewport: { width: 1920, height: 1040 }, colorScheme: 'dark' });
  p.on('pageerror', (e) => errors.push(e.message));
  await p.goto(URL); await p.waitForTimeout(1200);
  await tab(p, 'Календарь');
  await shot(p, 'calendar-week-1920');
  await p.close();
}
await b.close();
if (errors.length) { console.log('\nОшибки на странице:'); for (const e of [...new Set(errors)]) console.log(' -', e); }
console.log('\nГотово:', out);
