import test from 'node:test';
import assert from 'node:assert/strict';
import { checkSecretText, isStopped, isScopeLack, loginHint, calDefaultOn, SECRET_MAX } from '../src/lib/authcheck.js';

const good = JSON.stringify({ installed: { client_id: '123-abc.apps.googleusercontent.com', client_secret: 'x', redirect_uris: ['http://localhost'] } });

test('client_secret.json: подходит только Desktop app', () => {
  assert.equal(checkSecretText(good), '');
  assert.equal(checkSecretText('﻿' + good), '');
  assert.match(checkSecretText(''), /пустой/);
  assert.match(checkSecretText('{ не json'), /не JSON/);
  assert.match(checkSecretText('[1,2]'), /не похоже/);
  assert.match(checkSecretText('null'), /не похоже/);
  assert.match(checkSecretText(JSON.stringify({ web: { client_id: 'a.apps.googleusercontent.com' } })), /Веб-приложение/);
  assert.match(checkSecretText(JSON.stringify({ type: 'service_account', private_key: '…' })), /сервисного/);
  assert.match(checkSecretText(JSON.stringify({ installed: { client_id: '' } })), /client_id/);
  assert.match(checkSecretText(JSON.stringify({ installed: { client_id: 'hello' } })), /client_id/);
  assert.match(checkSecretText(JSON.stringify({ installed: 'строка' })), /installed/);
  assert.match(checkSecretText(good, SECRET_MAX + 1), /большой/);
});

test('ошибки входа — понятным текстом', () => {
  assert.ok(isStopped('Вход прерван'));
  assert.equal(loginHint('Вход прерван'), '');
  const lack = 'Войдите в Google заново: Google не дал доступ — Задачи, Календарь. На странице входа отметь все галочки.';
  assert.ok(isScopeLack(lack));
  assert.match(loginHint(lack), /Задачи, Календарь/);
  assert.ok(isScopeLack('Google ответил 403: Request had insufficient authentication scopes.'));
  assert.ok(isScopeLack('Войдите в Google заново: Google не дал Спутнику все доступы. …'));
  assert.ok(!isScopeLack('Войдите в Google заново (invalid_grant)'));
  assert.match(loginHint('Вход отменён: access_denied'), /тестовые пользователи/);
  assert.match(loginHint('Google ответил 401: invalid_client'), /ключ/);
  assert.equal(loginHint('Что-то другое'), 'Что-то другое');
});

test('первый запуск: включены только основной календарь и праздники', () => {
  assert.equal(calDefaultOn({ id: 'me@gmail.com', primary: true }), true);
  assert.equal(calDefaultOn({ id: 'uk.ukrainian#holiday@group.v.calendar.google.com' }), true);
  assert.equal(calDefaultOn({ id: 'classroom123@group.calendar.google.com', selected: true }), false);
  assert.equal(calDefaultOn({ id: 'addressbook#contacts@group.v.calendar.google.com' }), false);
});
