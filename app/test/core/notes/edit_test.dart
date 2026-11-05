import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/notes/edit.dart';
import 'package:sputnik_app/core/notes/index.dart';
import 'package:sputnik_app/core/notes/parse.dart';

void main() {
  group('setFrontProp', () {
    const base = '---\ntype: НПС\ntags:\n  - лор\n  - нпс\n# комментарий\nстатус: жива\n---\nТекст: не трогать.\n';

    test('меняет только свою строку', () {
      expect(setFrontProp(base, 'статус', 'погибла'),
          '---\ntype: НПС\ntags:\n  - лор\n  - нпс\n# комментарий\nстатус: погибла\n---\nТекст: не трогать.\n');
    });

    test('блочный список заменяется одной строкой, остальное как было', () {
      expect(setFrontProp(base, 'tags', ['лор', 'фракция']),
          '---\ntype: НПС\ntags: [лор, фракция]\n# комментарий\nстатус: жива\n---\nТекст: не трогать.\n');
    });

    test('новое свойство — последней строкой шапки; null убирает', () {
      expect(setFrontProp(base, 'где', 'Город Вельск'), contains('статус: жива\nгде: Город Вельск\n---\n'));
      expect(setFrontProp(base, 'type', null), '---\ntags:\n  - лор\n  - нпс\n# комментарий\nстатус: жива\n---\nТекст: не трогать.\n');
      expect(setFrontProp(base, 'нет', null), base);
    });

    test('нет шапки — создаётся; пустая шапка — заполняется; BOM сохраняется', () {
      expect(setFrontProp('Текст', 'type', 'идея'), '---\ntype: идея\n---\nТекст');
      expect(setFrontProp('---\n---\nТекст', 'type', 'идея'), '---\ntype: идея\n---\nТекст');
      expect(setFrontProp('\uFEFFТекст', 'a', 1), '\uFEFF---\na: 1\n---\nТекст');
    });

    test('переводы строк Windows сохраняются', () {
      const t = '---\r\na: 1\r\nb: 2\r\n---\r\nТекст\r\n';
      expect(setFrontProp(t, 'a', 5), '---\r\na: 5\r\nb: 2\r\n---\r\nТекст\r\n');
      expect(setFrontProp(t, 'c', 'x'), '---\r\na: 1\r\nb: 2\r\nc: x\r\n---\r\nТекст\r\n');
    });

    test('результат снова читается как YAML с тем же значением', () {
      for (final v in ['да', 'true', '12', 'a: b', '#тег', ' пробел', 'кавычка "x"', '', 'обычный текст', 'C:\\путь']) {
        final d = parseNote('a.md', setFrontProp('Текст', 'k', v));
        expect(d.frontError, isFalse, reason: v);
        expect(d.props['k'], v, reason: v);
      }
      final d = parseNote('a.md', setFrontProp('x', 'k', ['a, b', 'в', 3, true]));
      expect(d.props['k'], ['a, b', 'в', 3, true]);
    });
  });

  test('yamlScalar: простые слова без кавычек', () {
    expect(yamlScalar('Город Вельск'), 'Город Вельск');
    expect(yamlScalar('yes'), '"yes"');
    expect(yamlScalar(3.5), '3.5');
  });

  test('setTaskDone меняет только отметку', () {
    const t = 'a\n  - [ ] Перепечь щит\n- [x] Готово\n';
    expect(setTaskDone(t, 1, true), 'a\n  - [x] Перепечь щит\n- [x] Готово\n');
    expect(setTaskDone(t, 2, false), 'a\n  - [ ] Перепечь щит\n- [ ] Готово\n');
    expect(setTaskDone(t, 0, true), t);
    expect(setTaskDone(t, 99, true), t);
  });

  group('переименование со ссылками', () {
    const notes = {
      'DND/Мира Тёрн.md': 'НПС.',
      'DND/Город Вельск.md': 'Тут [[Мира Тёрн]], [[мира тёрн#Связи|Мира]] и ![[Мира Тёрн#^итог]].\n',
      '3D/Прочее.md': 'См. [досье](../DND/Мира%20Тёрн.md#Связи) и [[Другое]].',
      'Учёба/Мира.md': 'Другая заметка с похожим именем.',
    };

    test('все формы ссылок переписываются, подписи и разделы остаются', () {
      final ix = NoteIndex.of(notes);
      final refs = ix.referencing('DND/Мира Тёрн.md');
      expect(refs.keys.toSet(), {'DND/Город Вельск.md', '3D/Прочее.md'});
      const to = 'DND/НПС/Мира.md';
      final all = [...notes.keys.where((p) => p != 'DND/Мира Тёрн.md'), to];
      final (a, na) = rewriteLinks('DND/Город Вельск.md', notes['DND/Город Вельск.md']!, refs['DND/Город Вельск.md']!, to, all);
      // Имя «Мира» уже есть в Учёбе — ссылка пишется путём.
      expect(a, 'Тут [[DND/НПС/Мира]], [[DND/НПС/Мира#Связи|Мира]] и ![[DND/НПС/Мира#^итог]].\n');
      expect(na, 3);
      final (b, nb) = rewriteLinks('3D/Прочее.md', notes['3D/Прочее.md']!, refs['3D/Прочее.md']!, to, all);
      expect(b, 'См. [досье](../DND/НПС/Мира.md#Связи) и [[Другое]].');
      expect(nb, 1);
    });

    test('единственное имя — короткая ссылка', () {
      expect(wikiTargetFor('DND/Мира Тёрн 2.md', notes.keys), 'Мира Тёрн 2');
      expect(wikiTargetFor('Вложения/карта.png', ['a.md']), 'карта.png');
    });

    test('relativePath', () {
      expect(relativePath('3D/Техники/a.md', '3D/Ассеты/Щит паладина.md'), '../Ассеты/Щит%20паладина.md');
      expect(relativePath('a.md', 'DND/b.md'), 'DND/b.md');
      expect(relativePath('DND/x.md', 'DND/y.md'), 'y.md');
    });
  });

  test('freeName и safeFileName', () {
    expect(freeName('DND/Таверна.md', ['DND/таверна.md', 'DND/Таверна 2.md']), 'DND/Таверна 3.md');
    expect(freeName('DND/Новая.md', ['DND/Таверна.md']), 'DND/Новая.md');
    expect(safeFileName('Идея: таверна / на сваях?'), 'Идея таверна на сваях');
    expect(safeFileName('  ...  '), 'Без названия');
    expect(safeFileName('CON'), 'CON _');
  });
}
