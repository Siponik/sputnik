import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/notes/index.dart';

const vault = {
  '3D/Техники/Запекание нормалей.md': '---\ntags: [baking]\naliases: [Нормали]\n---\n'
      'Порядок: см. [[UV без растяжений]], потом [[Умные маски Substance]].\n'
      'Ошибки — [[Справочник по кейджам]].\n![[было.png]]\n![[нет.png]]\n',
  '3D/Техники/UV без растяжений.md': 'Швы по краям. Дальше — [[Запекание нормалей#Порядок|запекание]].\n',
  '3D/Техники/Умные маски Substance.md': '# Маски\nГрязь по кривизне. #substance\n',
  '3D/Ассеты/Щит паладина.md': 'Нормали пекла по [[Запекание нормалей]] и ещё раз [[Запекание нормалей]].\n',
  'Учёба/Курс текстуры.md': 'Урок 6 — запекание нормалей, домашка: щит.\n',
  'Работа/Прайс.md': 'Ассеты под ключ. Запекание нормалей входит в цену.\n',
  'DND/Мира Тёрн.md': '---\ntype: НПС\nстатус: жива\ntags: [лор/нпс]\n---\nИнформатор. Живёт в [[Город Вельск]].\n',
  'DND/Город Вельск.md': 'Порт. Тут [[Мира Тёрн]] и [[Таверна]]. #лор\n',
  'Личное/Пусто.md': '',
};

NoteIndex ix() => NoteIndex.of(vault, files: ['Вложения/было.png']);

void main() {
  test('исходящие: пути без повторов, вставка картинки тоже, несуществующие отдельно', () {
    final i = ix();
    expect(i.linksTo('3D/Техники/Запекание нормалей.md'), [
      '3D/Техники/UV без растяжений.md',
      '3D/Техники/Умные маски Substance.md',
      'Вложения/было.png',
    ]);
    expect(i.missingFrom('3D/Техники/Запекание нормалей.md'), ['Справочник по кейджам']);
  });

  test('обратные ссылки с куском строки, одна на строку', () {
    final b = ix().backlinks('3D/Техники/Запекание нормалей.md');
    expect(b.map((x) => x.toJson()).toList(), [
      {'from': '3D/Ассеты/Щит паладина.md', 'line': 0, 'snippet': 'Нормали пекла по [[Запекание нормалей]] и ещё раз [[Запекание нормалей]].'},
      {'from': '3D/Техники/UV без растяжений.md', 'line': 0, 'snippet': 'Швы по краям. Дальше — [[Запекание нормалей#Порядок|запекание]].'},
    ]);
  });

  test('упоминания без ссылки: по названию и aliases, целым словом, ё = е', () {
    final m = ix().mentions('3D/Техники/Запекание нормалей.md');
    expect(m.map((x) => x.from), ['Работа/Прайс.md', 'Учёба/Курс текстуры.md']);
    expect(m.first.snippet, 'Ассеты под ключ. Запекание нормалей входит в цену.');
    // Уже связанная заметка не предлагается, внутри [[…]] — не упоминание.
    final mira = ix().mentions('DND/Мира Тёрн.md');
    expect(mira, isEmpty);
  });

  test('ещё не созданные заметки и кто на них ссылается; битая картинка — не заметка', () {
    expect(ix().missing(), {
      'Справочник по кейджам': ['3D/Техники/Запекание нормалей.md'],
      'Таверна': ['DND/Город Вельск.md'],
    });
  });

  test('новая заметка разрешает ссылки, которые раньше вели в пустоту', () {
    final i = ix()..update('DND/Таверна.md', 'Хозяин — Борн.');
    expect(i.missing().keys, ['Справочник по кейджам']);
    expect(i.backlinks('DND/Таверна.md').single.from, 'DND/Город Вельск.md');
    i.remove('DND/Таверна.md');
    expect(i.missing().keys, contains('Таверна'));
  });

  test('переименование: ссылки по старому имени перестают находить заметку', () {
    final i = ix()..rename('DND/Мира Тёрн.md', 'DND/НПС/Мира.md');
    expect(i.paths, contains('DND/НПС/Мира.md'));
    expect(i.missing().keys, contains('Мира Тёрн'));
  });

  test('число связей', () {
    final i = ix();
    expect(i.degree('3D/Техники/Запекание нормалей.md'), 3); // UV (в обе стороны), маски, щит
    expect(i.degree('Личное/Пусто.md'), 0);
  });

  test('поиск по началу слов, ё = е, название выше текста', () {
    final h = ix().search('запекан');
    expect(h.first.path, '3D/Техники/Запекание нормалей.md');
    expect(h.map((x) => x.path).toSet(), {
      '3D/Техники/Запекание нормалей.md',
      '3D/Техники/UV без растяжений.md',
      '3D/Ассеты/Щит паладина.md',
      'Учёба/Курс текстуры.md',
      'Работа/Прайс.md',
    });
    expect(ix().search('пекла').single.path, '3D/Ассеты/Щит паладина.md');
    expect(ix().search('терн').map((x) => x.path), ['DND/Мира Тёрн.md', 'DND/Город Вельск.md']); // название выше текста
    expect(ix().search('ЖИВА').single.path, 'DND/Мира Тёрн.md'); // по свойству
    expect(ix().search('лор').map((x) => x.path).toSet(), {'DND/Мира Тёрн.md', 'DND/Город Вельск.md'});
    expect(ix().search('кривизне маски').single.path, '3D/Техники/Умные маски Substance.md');
    expect(ix().search('запекание дракона'), isEmpty);
    expect(ix().search('  '), isEmpty);
  });

  test('кусок текста в поиске — строка с совпадением', () {
    final h = ix().search('домашка').single;
    expect(h.snippet, 'Урок 6 — запекание нормалей, домашка: щит.');
    expect(h.line, 0);
  });

  test('рёбра графа без направления и повторов; с вложениями и несозданными по запросу', () {
    final i = ix();
    final e = i.edges();
    // Запекание—UV (ссылки в обе стороны — одно ребро), Запекание—маски, Щит—Запекание, Мира—Вельск.
    expect(e.length, 4);
    expect(e, contains(const GraphEdge('3D/Техники/UV без растяжений.md', '3D/Техники/Запекание нормалей.md')));
    expect(i.edges(withFiles: true).length, 5);
    expect(i.edges(withMissing: true).any((x) => x.b == '?Таверна' || x.a == '?Таверна'), isTrue);
  });

  test('соседи для локального графа', () {
    final i = ix();
    expect(i.neighbours('3D/Техники/Умные маски Substance.md'), {
      '3D/Техники/Умные маски Substance.md',
      '3D/Техники/Запекание нормалей.md',
    });
    expect(i.neighbours('3D/Техники/Умные маски Substance.md', depth: 2).length, 4);
  });

  test('теги со счётом и выборка по тегу с вложенными', () {
    final i = ix();
    expect(i.tags(), [('baking', 1), ('substance', 1), ('лор', 1), ('лор/нпс', 1)]);
    expect(i.withTag('лор'), ['DND/Город Вельск.md', 'DND/Мира Тёрн.md']);
  });

  test('snippetAround режет длинную строку вокруг совпадения', () {
    final long = '${'а' * 100} слово ${'б' * 100}';
    final s = snippetAround(long, 101, max: 30);
    expect(s.startsWith('…'), isTrue);
    expect(s.endsWith('…'), isTrue);
    expect(s.contains('слово'), isTrue);
    expect(snippetAround('  коротко  ', 0), 'коротко');
  });
}
