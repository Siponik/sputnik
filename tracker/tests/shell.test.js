// Шапка 0.6: «Состояние», обновления, совет енота, выезд колонки, поиск в настройках (src/lib/shell.js).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import * as shell from '../src/lib/shell.js';

const at = new Date(2026, 9, 21, 13, 52);
const ok = { sync: { busy: false, err: '', at }, cloud: { state: 'ok', at }, upd: { found: null } };

test('три точки: всё хорошо — бирюзовые, подпись — время', () => {
  const s = shell.statusDots(ok);
  assert.deepEqual(s.dots.map((d) => d.c), ['', '', '']);
  assert.equal(s.label, '13:52');
});

test('точки: нет связи — красная первая и «Нет связи»; вход — золотая вторая; версия — золотая третья', () => {
  const off = shell.statusDots({ ...ok, sync: { err: 'error sending request', at }, offline: true });
  assert.equal(off.dots[0].c, 'e');
  assert.equal(off.label, 'Нет связи');
  const login = shell.statusDots({ ...ok, cloud: { state: 'login' } });
  assert.equal(login.dots[1].c, 'w');
  assert.equal(login.label, 'Нужен вход');
  const upd = shell.statusDots({ ...ok, upd: { found: { version: '0.6.4' } } });
  assert.equal(upd.dots[2].c, 'w');
  assert.equal(upd.label, '13:52');
});

test('точка пульсирует во время обмена', () => {
  const s = shell.statusDots({ ...ok, sync: { busy: true, at }, cloud: { state: 'busy' } });
  assert.equal(s.dots[0].busy, true);
  assert.equal(s.dots[1].busy, true);
  assert.equal(s.dots[2].busy, false);
});

test('строки «Состояния»', () => {
  assert.equal(shell.googleLine(ok.sync).text, 'обновлено в 13:52 · раз в 2 минуты');
  assert.equal(shell.googleLine({ err: 'boom' }).cls, 'e');
  assert.equal(shell.cloudLine({ state: 'login' }).cls, 'w');
  assert.equal(shell.versionLine({ found: { version: '0.6.4' } }).text, 'вышла 0.6.4 · меньше минуты');
  assert.equal(shell.versionLine({ checkedAt: at }).text, 'последняя версия · проверено в 13:52');
  assert.equal(shell.remindLine({ at, n: 6 }).text, 'файл обновлён 13:52 · 6 впереди');
  assert.equal(shell.remindLine(null).cls, '');
});

test('«что нового» — первые 3 пункта списка из заметки релиза', () => {
  assert.deepEqual(shell.notesOf('Спутник 0.6\n- раз\n* два\n• три\n- четыре'), ['раз', 'два', 'три']);
  assert.deepEqual(shell.notesOf('просто строка'), ['просто строка']);
  assert.deepEqual(shell.notesOf(''), []);
});

test('чип обновления: пропущенная версия и «Вечером» его прячут', () => {
  const f = { version: '0.6.4' };
  const now = at.getTime();
  assert.equal(shell.showUpdChip(null), false);
  assert.equal(shell.showUpdChip(f, {}, now), true);
  assert.equal(shell.showUpdChip(f, { skip: '0.6.4' }, now), false);
  assert.equal(shell.showUpdChip({ version: '0.6.5' }, { skip: '0.6.4' }, now), true);
  assert.equal(shell.showUpdChip(f, { remindAt: shell.eveningAt(at) }, now), false);
  assert.equal(shell.showUpdChip(f, { remindAt: shell.eveningAt(at) }, new Date(2026, 9, 21, 20, 1).getTime()), true);
});

test('«Вечером» — в 20:00 сегодня, а после 20:00 — завтра', () => {
  assert.equal(new Date(shell.eveningAt(at)).getDate(), 21);
  assert.equal(new Date(shell.eveningAt(at)).getHours(), 20);
  assert.equal(new Date(shell.eveningAt(new Date(2026, 9, 21, 21))).getDate(), 22);
});

// ---------- колонка доски ----------

function fakeTimers() {
  let now = 0, id = 0;
  const q = new Map();
  return {
    setTimeout: (fn, ms) => { q.set(++id, { fn, at: now + ms }); return id; },
    clearTimeout: (i) => q.delete(i),
    tick(ms) {
      now += ms;
      for (const [i, t] of [...q].sort((a, b) => a[1].at - b[1].at)) if (t.at <= now) { q.delete(i); t.fn(); }
    },
  };
}

test('колонка выезжает через 150 мс наведения и уезжает через 300 мс после ухода', () => {
  const tm = fakeTimers();
  const log = [];
  const s = shell.slider({ set: (v) => log.push(v), timers: tm });
  s.enter(); tm.tick(140); assert.equal(s.open, false);
  tm.tick(20); assert.equal(s.open, true);
  s.leave(); tm.tick(290); assert.equal(s.open, true);
  tm.tick(20); assert.equal(s.open, false);
  assert.deepEqual(log, [true, false]);
});

test('мышь вернулась раньше 300 мс — колонка остаётся; быстрый проход мимо — не выезжает', () => {
  const tm = fakeTimers();
  const s = shell.slider({ timers: tm });
  s.enter(); tm.tick(200); s.leave(); tm.tick(200); s.enter(); tm.tick(500);
  assert.equal(s.open, true);
  s.leave(); tm.tick(100); assert.equal(s.open, true);
  const s2 = shell.slider({ timers: tm });
  s2.enter(); tm.tick(100); s2.leave(); tm.tick(500);
  assert.equal(s2.open, false);
});

test('пока открыт фильтр или меню — не уезжает; отпустили — уезжает через 300 мс', () => {
  const tm = fakeTimers();
  const s = shell.slider({ timers: tm });
  s.show(); s.hold(true); s.leave(); tm.tick(1000);
  assert.equal(s.open, true);
  s.hold(false); tm.tick(299); assert.equal(s.open, true);
  tm.tick(2); assert.equal(s.open, false);
});

test('анимации выключены — выезд и уход мгновенные; Esc — убрать сразу', () => {
  const tm = fakeTimers();
  const s = shell.slider({ timers: tm });
  s.instant(true);
  s.enter(); assert.equal(s.open, true);
  s.leave(); assert.equal(s.open, false);
  s.show(); s.hold(true); s.hide(); assert.equal(s.open, false);
});

test('фильтр «Список…»: по спискам и сферам, ё = е, первый — для Enter', () => {
  const sp = [{ id: 'w', name: 'Работа' }, { id: 'p', name: 'Личное' }];
  const L = { w: [{ id: 'a', title: 'Иконки для клиента' }, { id: 'b', title: 'Заказы' }], p: [{ id: 'c', title: 'Дела по дому' }] };
  const listsOf = (id) => L[id];
  const none = [{ id: 'd', title: 'Ёлка' }];
  const all = shell.filterSide('', sp, listsOf, none);
  assert.equal(all.spheres.length, 2);
  const r = shell.filterSide('зак', sp, listsOf, none);
  assert.deepEqual(r.spheres.map((x) => x.lists.map((l) => l.id)), [['b']]);
  assert.equal(r.first.id, 'b');
  assert.deepEqual(shell.filterSide('работа', sp, listsOf, none).spheres[0].lists.map((l) => l.id), ['a', 'b']);
  assert.equal(shell.filterSide('елка', sp, listsOf, none).first.id, 'd');
  assert.equal(shell.filterSide('нет такого', sp, listsOf, none).first, null);
});

test('советы енота: с чего начать, лимит колонки, разбор входящих; пустая доска — один совет', () => {
  const cols = [{ id: 'inbox', name: 'Входящие' }, { id: 'doing', name: 'В работе', limit: 3 }, { id: 'review', name: 'На ревью' }, { id: 'done', name: 'Готово' }];
  const t = (id, col) => ({ id, title: id, col });
  const open = [t('a', 'inbox'), t('b', 'inbox'), t('c', 'inbox'), t('d', 'doing'), t('e', 'doing')];
  const tips = shell.boardTips({ open, cols, colOf: (x) => x.col, first: { task: open[0], why: 'просрочено с вчера' } });
  assert.deepEqual(tips.map((x) => x.id), ['first', 'limit', 'inbox']);
  assert.equal(tips[0].text, 'Начни с «a» — просрочено с вчера. Остальное подождёт.');
  assert.equal(tips[1].text, '«В работе» уже 2 из 3 — закончи одну, прежде чем брать новую.');
  assert.deepEqual([tips[1].kind, tips[1].ref, tips[1].act], ['col', 'doing', 'К «В работе»']);
  const empty = shell.boardTips({ open: [], cols, colOf: () => 'inbox', first: null });
  assert.equal(empty.length, 1);
  assert.equal(empty[0].kind, 'new');
});

test('[ ] выдвигают колонку на время: мышь не на ней — уезжает сама', () => {
  const tm = fakeTimers();
  const s = shell.slider({ timers: tm });
  s.peek(1500); assert.equal(s.open, true);
  tm.tick(1400); s.peek(1500); tm.tick(1400); assert.equal(s.open, true);
  tm.tick(200); assert.equal(s.open, false);
  s.enter(); tm.tick(200); s.peek(1500); tm.tick(5000); assert.equal(s.open, true);
});

// ---------- Настройки ----------

test('найти настройку: по заголовку, пояснению и словам для поиска; ё = е', () => {
  assert.deepEqual(shell.searchSettings('тема').map((r) => r.id), ['theme']);
  assert.deepEqual(shell.searchSettings('тёмная').map((r) => r.id), ['theme']);
  assert.equal(shell.searchSettings('ночью')[0].tab, 'upd');
  assert.deepEqual(shell.searchSettings('резервн').map((r) => r.id), ['backup']);
  assert.deepEqual(shell.searchSettings('  '), []);
  assert.deepEqual(shell.searchSettings('нет такой настройки'), []);
  assert.ok(shell.searchSettings('телеграм').some((r) => r.id === 'bot'));
});

test('каждая строка поиска — на существующей вкладке', () => {
  const tabs = new Set(shell.SETTINGS_TABS.map((t) => t.id));
  for (const r of shell.SETTINGS_INDEX) assert.ok(tabs.has(r.tab), r.id);
});

test('↑ ↓ по вкладкам — по кругу', () => {
  assert.equal(shell.stepTab('look', 1), 'show');
  assert.equal(shell.stepTab('look', -1), 'keys');
  assert.equal(shell.stepTab('keys', 1), 'look');
});

test('открывать при запуске: Сегодня / Доска / где остановился', () => {
  assert.equal(shell.startView(undefined, 'board'), 'today');
  assert.equal(shell.startView('board', 'habits'), 'board');
  assert.equal(shell.startView('last', 'habits'), 'habits');
  assert.equal(shell.startView('last', 'templates'), 'today');
});

test('свой бот (Apps Script): только у владельца, у кого скрипт ведёт «Входящие»', () => {
  assert.deepEqual(shell.ownBot({}, null), { show: false, on: false });
  assert.deepEqual(shell.ownBot({}, { processed: [] }), { show: true, on: true });
  assert.deepEqual(shell.ownBot({ ownBot: { v: false } }, { processed: [] }), { show: true, on: false });
  assert.deepEqual(shell.ownBot({ ownBot: { v: true } }, null), { show: true, on: true });
  assert.equal(shell.remindLine({ shared: true, linked: true }).cls, 'ok');
  assert.equal(shell.remindLine({ shared: true, linked: false }).cls, 'w');
  assert.equal(shell.remindLine({ shared: true, linked: true, err: 'нет связи' }).text, 'нет связи');
  assert.ok(shell.searchSettings('отключить').some((r) => r.id === 'rhour'));
});
