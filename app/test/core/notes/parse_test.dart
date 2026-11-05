import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/notes/parse.dart';

void main() {
  group('шапка YAML', () {
    test('свойства, теги и aliases', () {
      const text = '---\ntype: техника\ntags: [baking, "#substance"]\naliases:\n  - Нормали\n  - Baking\n---\n# Запекание\n';
      final d = parseNote('3D/Техники/Запекание нормалей.md', text);
      expect(d.props['type'], 'техника');
      expect(d.tags, ['baking', 'substance']);
      expect(d.aliases, ['Нормали', 'Baking']);
      expect(d.frontError, isFalse);
      expect(d.title, 'Запекание нормалей');
      expect(d.body(text), '# Запекание\n');
      expect(d.bodyLine, 7);
    });

    test('теги строкой через запятую и пробел, aliases строкой — только по запятым', () {
      final d = parseNote('a.md', '---\ntags: лор, нпс фракция\naliases: Мира, Мира Тёрн\n---\n');
      expect(d.tags, ['лор', 'нпс', 'фракция']);
      expect(d.aliases, ['Мира', 'Мира Тёрн']);
    });

    test('title из шапки главнее имени файла', () {
      expect(parseNote('x/2026-11-05.md', '---\ntitle: Таверна на сваях\n---\n').title, 'Таверна на сваях');
    });

    test('нет шапки — пустые свойства, текст с начала', () {
      final d = parseNote('a.md', 'Просто текст\n---\nне шапка\n');
      expect(d.props, isEmpty);
      expect(d.frontRaw, isNull);
      expect(d.bodyStart, 0);
    });

    test('испорченная шапка — предупреждение, свойства пусты', () {
      final d = parseNote('a.md', '---\ntype: [не закрыто\n---\nтекст #тег\n');
      expect(d.frontError, isTrue);
      expect(d.props, isEmpty);
      expect(d.tags, ['тег']);
    });

    test('незакрытая шапка — это не шапка', () {
      final d = parseNote('a.md', '---\ntype: x\nтекст');
      expect(d.frontRaw, isNull);
      expect(d.props, isEmpty);
    });

    test('BOM и переводы строк Windows', () {
      const text = '﻿---\r\ntype: идея\r\n---\r\nСтрока [[Щит]]\r\n';
      final d = parseNote('a.md', text);
      expect(d.props['type'], 'идея');
      expect(d.links.single.target, 'Щит');
      expect(d.links.single.line, 3);
      expect(text.substring(d.links.single.start, d.links.single.end), '[[Щит]]');
    });

    test('вложенные свойства — обычные Map и List', () {
      final d = parseNote('a.md', '---\nnpc:\n  имя: Мира\n  связи: [Борн, Ильва]\n---\n');
      expect(d.props['npc'], {'имя': 'Мира', 'связи': ['Борн', 'Ильва']});
    });
  });

  group('ссылки', () {
    test('все формы [[…]]', () {
      final d = parseNote('a.md', 'См. [[Щит паладина]], [[UV#Швы|про швы]], [[Сессия 12#^итог]] и ![[карта.png]].\n');
      final l = d.links;
      expect(l.map((x) => x.target), ['Щит паладина', 'UV', 'Сессия 12', 'карта.png']);
      expect(l[1].heading, 'Швы');
      expect(l[1].alias, 'про швы');
      expect(l[1].label, 'про швы');
      expect(l[2].block, 'итог');
      expect(l[3].embed, isTrue);
    });

    test('ссылка на раздел своей заметки', () {
      final l = parseNote('a.md', '[[#Порядок]]').links.single;
      expect(l.target, '');
      expect(l.heading, 'Порядок');
      expect(l.label, 'Порядок');
    });

    test('экранированная черта в таблице', () {
      final l = parseNote('a.md', '| [[Мира Тёрн\\|Мира]] | жива |').links.single;
      expect(l.target, 'Мира Тёрн');
      expect(l.alias, 'Мира');
    });

    test('Markdown-ссылки: на .md — связь, на сайт — нет, картинка — вставка', () {
      final d = parseNote('a.md', '[щит](../3D/Щит%20паладина.md) [сайт](https://example.com/a.md) ![](Вложения/a.png) [pdf](doc.pdf)');
      expect(d.links.length, 2);
      expect(d.links[0].target, '../3D/Щит паладина.md');
      expect(d.links[0].markdown, isTrue);
      expect(d.links[0].alias, 'щит');
      expect(d.links[1].embed, isTrue);
      expect(d.links[1].target, 'Вложения/a.png');
    });

    test('в коде ссылки и теги не считаются', () {
      const text = 'Текст `[[не ссылка]] #нетег`\n```\n[[тоже нет]] #нет\n```\n    [[отступ — код]]\n[[да]] #да\n';
      final d = parseNote('a.md', text);
      expect(d.links.map((x) => x.target), ['да']);
      expect(d.tags, ['да']);
    });

    test('пустые скобки — не ссылка', () {
      expect(parseNote('a.md', '[[ ]] [[|подпись]]').links, isEmpty);
    });

    test('номер строки и смещения считаются от начала файла', () {
      const text = '---\na: 1\n---\nпервая\nвторая [[Цель]]\n';
      final l = parseNote('a.md', text).links.single;
      expect(l.line, 4);
      expect(text.substring(l.start, l.end), '[[Цель]]');
    });
  });

  group('теги', () {
    test('русские, вложенные, без повторов; цифры, заголовки и якоря — не теги', () {
      final d = parseNote('a.md', '# Заголовок\n#лор/фракции и #Лор, #3d-модель, #123, цвет&#35; a#b (#скобки)\n');
      expect(d.tags, ['лор/фракции', 'Лор', '3d-модель', 'скобки']);
    });

    test('повтор тега из шапки в тексте не дублируется', () {
      expect(parseNote('a.md', '---\ntags: [Лор]\n---\n#лор #нпс').tags, ['Лор', 'нпс']);
    });

    test('cleanTag', () {
      expect(cleanTag('#баг'), 'баг');
      expect(cleanTag(' 42 '), isNull);
      expect(cleanTag('два слова'), isNull);
      expect(cleanTag(null), isNull);
    });
  });

  group('чек-листы и заголовки', () {
    test('задачи с отметкой и отступом, нумерованные тоже', () {
      final d = parseNote('a.md', '- [ ] Перепечь щит\n  - [x] Сравнить\n1. [ ] Первое\n* [X] Звёздочка\n- [] не задача\n');
      expect(d.tasks.map((t) => t.toJson()).toList(), [
        {'line': 0, 'done': false, 'text': 'Перепечь щит'},
        {'line': 1, 'done': true, 'text': 'Сравнить', 'indent': 2},
        {'line': 2, 'done': false, 'text': 'Первое'},
        {'line': 3, 'done': true, 'text': 'Звёздочка'},
      ]);
    });

    test('заголовки ATX, хвостовые # убираются, в коде — нет', () {
      final d = parseNote('a.md', '# Один\n## Два ##\n```\n# не заголовок\n```\n#тег\n');
      expect(d.headings.map((h) => [h.level, h.text]).toList(), [
        [1, 'Один'],
        [2, 'Два'],
      ]);
    });
  });

  group('resolveLink', () {
    const paths = [
      '3D/Техники/Запекание нормалей.md',
      '3D/Ассеты/Щит паладина.md',
      'DND/Щит паладина.md',
      'DND/НПС/Мира Тёрн.md',
      'Вложения/карта.png',
      'Корень.md',
      'v1.2.md',
    ];

    test('по имени без регистра и без .md', () {
      expect(resolveLink('запекание нормалей', 'Корень.md', paths), '3D/Техники/Запекание нормалей.md');
      expect(resolveLink('Корень.md', 'x.md', paths), 'Корень.md');
      expect(resolveLink('v1.2', 'x.md', paths), 'v1.2.md');
    });

    test('одинаковые имена — сначала своя папка, потом короче путь', () {
      expect(resolveLink('Щит паладина', '3D/Ассеты/Другое.md', paths), '3D/Ассеты/Щит паладина.md');
      expect(resolveLink('Щит паладина', 'Корень.md', paths), 'DND/Щит паладина.md');
    });

    test('путь с папкой — полный или по концу', () {
      expect(resolveLink('3D/Ассеты/Щит паладина', 'Корень.md', paths), '3D/Ассеты/Щит паладина.md');
      expect(resolveLink('Ассеты/Щит паладина', 'Корень.md', paths), '3D/Ассеты/Щит паладина.md');
      expect(resolveLink('НПС/Мира Тёрн.md', 'Корень.md', paths), 'DND/НПС/Мира Тёрн.md');
    });

    test('относительный путь Markdown-ссылки', () {
      expect(resolveLink('../Ассеты/Щит паладина.md', '3D/Техники/Запекание нормалей.md', paths), '3D/Ассеты/Щит паладина.md');
      expect(resolveLink('./Нет.md', '3D/a.md', paths), isNull);
    });

    test('вложение по имени файла', () {
      expect(resolveLink('карта.png', 'DND/x.md', paths), 'Вложения/карта.png');
    });

    test('по aliases, если файла с таким именем нет', () {
      expect(resolveLink('Мира', 'x.md', paths, aliases: {'DND/НПС/Мира Тёрн.md': ['Мира']}), 'DND/НПС/Мира Тёрн.md');
    });

    test('ё и е — разные, как в Obsidian; несуществующая — null', () {
      expect(resolveLink('Мира Терн', 'x.md', paths), isNull);
      expect(resolveLink('Справочник по кейджам', 'x.md', paths), isNull);
    });

    test('пустая цель — своя заметка', () {
      expect(resolveLink('', 'DND/x.md', paths), 'DND/x.md');
    });
  });

  test('percentDecode', () {
    expect(percentDecode('Щит%20паладина.md'), 'Щит паладина.md');
    expect(percentDecode('%D0%A9%D0%B8%D1%82'), 'Щит');
    expect(percentDecode('100%'), '100%');
    expect(percentDecode('%FF'), '%FF');
  });

  test('baseName и folderOf', () {
    expect(baseName('3D/Техники/Запекание.md'), 'Запекание');
    expect(baseName('карта.png'), 'карта.png');
    expect(folderOf('3D/Техники/Запекание.md'), '3D/Техники');
    expect(folderOf('Корень.md'), '');
  });
}
