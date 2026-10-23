// Номер версии сборки (tools/ci/version.mjs): новый минор начинается с x.y.0, дальше x.y.1, x.y.2…
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { nextVersion, nextBeta, msiVersion } from '../../tools/ci/version.mjs';

test('первый релиз минора — x.y.0, старые миноры не в счёт', () => {
  assert.equal(nextVersion('0.6.0', []), '0.6.0');
  assert.equal(nextVersion('0.6.0', ['tracker-0.5.61', 'tracker-0.5.62']), '0.6.0');
  assert.equal(nextVersion('0.7.0', ['tracker-0.6.0', 'tracker-0.6.3']), '0.7.0');
});

test('следующие — по порядку после наибольшего', () => {
  assert.equal(nextVersion('0.6.0', ['tracker-0.6.0']), '0.6.1');
  assert.equal(nextVersion('0.6.0', ['tracker-0.6.1', 'tracker-0.6.0', 'tracker-0.6.10 ']), '0.6.11');
  assert.equal(nextVersion('0.6.0', ['tracker-0.6.2-test', 'tracker-0.60.4', 'v0.6.5']), '0.6.0');
});

test('непонятная версия — ошибка', () => {
  assert.throws(() => nextVersion('0.6', []));
});

test('бета — следующий номер с «-beta.N», счёт заново на каждый номер', () => {
  assert.equal(nextBeta('0.7.0', []), '0.7.0-beta.1');
  assert.equal(nextBeta('0.7.0', ['tracker-0.7.0', 'tracker-0.7.1-beta.1', 'tracker-0.7.1-beta.2', 'tracker-beta']), '0.7.1-beta.3');
  assert.equal(nextBeta('0.7.0', ['tracker-0.7.0', 'tracker-0.7.1-beta.4', 'tracker-0.7.1']), '0.7.2-beta.1');
  // бета не сдвигает номер обычного релиза
  assert.equal(nextVersion('0.7.0', ['tracker-0.7.0', 'tracker-0.7.1-beta.4']), '0.7.1');
});

test('версия .msi — только числа', () => {
  assert.equal(msiVersion('0.7.3-beta.2'), '0.7.3.2');
  assert.equal(msiVersion('0.7.3'), '0.7.3');
  assert.throws(() => msiVersion('0.7.3-rc1'));
});
