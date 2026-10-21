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
