// «Что нового» для релиза (tools/ci/notes.mjs): раздел из описания PR, иначе названия коммитов — без «Merge pull request…».
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { sectionItems, subjectItem, releaseNotes, prNumber, lastTag } from '../../tools/ci/notes.mjs';

test('пункты раздела «Что нового» из описания PR', () => {
  const body = [
    '<!-- claude-projects-attribution -->',
    '## Что нового',
    '- Превью в «Создать» больше не вылезает за рамку.',
    '* Стикер открывается кликом по названию',
    '<!-- коротко, для пользователя -->',
    '## Как проверено',
    '- npm test',
  ].join('\n');
  assert.deepEqual(sectionItems(body), ['Превью в «Создать» больше не вылезает за рамку.', 'Стикер открывается кликом по названию']);
  assert.deepEqual(sectionItems('просто текст'), []);
  // раздел без следующего заголовка кончается на первой строке не-списка
  const loose = '## Что нового\n- Бот лучше защищён.\n\n**Общий бот — защита:**\n- `/link`: не больше 10 кодов';
  assert.deepEqual(sectionItems(loose), ['Бот лучше защищён.']);
  assert.deepEqual(sectionItems(null), []);
});

test('служебные коммиты пропускаются, хвост «(#42)» и «Трекер:» убираются', () => {
  assert.equal(subjectItem('Merge pull request #44 from Siponik/claude/x'), null);
  assert.equal(subjectItem('Revert "что-то"'), null);
  assert.equal(subjectItem('Стикеры: окно задачи — только по клику (#42)'), 'Стикеры: окно задачи — только по клику');
  assert.equal(subjectItem('Трекер: общий ключ Google'), 'общий ключ Google');
});

test('заметка: раздел PR главнее коммитов, свежие сверху, без повторов', () => {
  const notes = releaseNotes([
    { body: '', subjects: ['Старое исправление', 'Merge branch main'] },
    { body: '## Что нового\n- Новое окно «Создать».', subjects: ['wip', 'ещё wip'] },
    { subjects: ['Старое исправление.', 'Свежая правка'] },
  ]);
  assert.equal(notes, '- Старое исправление.\n- Свежая правка\n- Новое окно «Создать».');
  assert.ok(!notes.includes('Merge'));
});

test('пусто — общая фраза, много — «и ещё N»', () => {
  assert.equal(releaseNotes([]), '- Небольшие исправления и улучшения.');
  assert.equal(releaseNotes([{ subjects: ['Merge pull request #1 from a/b'] }]), '- Небольшие исправления и улучшения.');
  const many = releaseNotes([{ subjects: ['a', 'b', 'c', 'd'] }], 2);
  assert.equal(many, '- a\n- b\n- И ещё 2 — подробности на странице релиза.');
});

test('номер PR и последний тег', () => {
  assert.equal(prNumber('Merge pull request #44 from Siponik/claude/x'), 44);
  assert.equal(prNumber('Стикеры: клик (#42)'), 42);
  assert.equal(prNumber('Просто коммит'), null);
  assert.equal(lastTag(['tracker-0.6.7', 'tracker-0.6.69', 'tracker-0.5.99', 'v1']), 'tracker-0.6.69');
  assert.equal(lastTag([]), null);
});
