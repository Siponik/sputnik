import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/notes/view.dart';

void main() {
  const notes = [
    '00 Входящие/Идея.md',
    '3D/Техники/Запекание нормалей.md',
    '3D/Техники/UV без растяжений.md',
    '3D/Ассеты/Щит.md',
    '3D/Пайплайн.md',
    'Корень.md',
  ];

  test('дерево: закрытые папки со счётчиком, папки выше заметок', () {
    final t = folderTree(notes, {});
    expect(t.map((r) => r.toString()), ['▸ 00 Входящие 1', '▸ 3D 4', 'Корень']);
  });

  test('дерево: открытая папка и подпапка, «ещё N»', () {
    final t = folderTree(notes, {'3D', '3D/Техники'}, cap: 1);
    expect(t.map((r) => r.toString()), [
      '▸ 00 Входящие 1',
      '▾ 3D 4',
      '  ▸ Ассеты 1',
      '  ▾ Техники 2',
      '    UV без растяжений',
      '    ещё 1',
      '  Пайплайн',
      'Корень',
    ]);
    expect(t[5].path, '…more:3D/Техники');
    final all = folderTree(notes, {'3D', '3D/Техники', '…all:3D/Техники'}, cap: 1);
    expect(all.where((r) => r.depth == 2).length, 2);
  });

  test('имя папки из пути Windows и Linux', () {
    expect(dirName(r'C:\Users\я\Знания\'), 'Знания');
    expect(dirName('/home/я/Obsidian-Vault'), 'Obsidian-Vault');
  });

  test('слова без шапки и скобок ссылок', () {
    expect(wordCount('---\ntype: НПС\n---\nМира живёт в [[Город Вельск|Вельске]].'), 4);
    expect(wordCount(''), 0);
  });

  test('куски текста покрывают всё и находят ссылки, заголовки, теги', () {
    const text = '---\na: 1\n---\n# Заголовок [[Есть]]\nТекст [[Нет]] и #тег.\n';
    final ps = pieces('x.md', text, (l) => l.target == 'Есть' ? 'Есть.md' : null);
    expect(ps.first.start, 0);
    expect(ps.last.end, text.length);
    for (var i = 1; i < ps.length; i++) {
      expect(ps[i].start, ps[i - 1].end);
    }
    String of(SpanKind k) => ps.where((p) => p.kind == k).map((p) => text.substring(p.start, p.end)).join('|');
    expect(of(SpanKind.front), '---\na: 1\n---\n');
    expect(of(SpanKind.link), '[[Есть]]');
    expect(ps.firstWhere((p) => p.kind == SpanKind.link).to, 'Есть.md');
    expect(of(SpanKind.missing), '[[Нет]]');
    expect(of(SpanKind.heading), '# Заголовок ');
    expect(of(SpanKind.tag), '#тег');
  });

  test('подсветка запроса: начало слов, ё = е, самое длинное совпадение', () {
    expect(matchRanges('Запекание нормалей и запёк', 'запек'), [(0, 5), (21, 26)]);
    expect(matchRanges('Курс: текстуры', 'тек кур'), [(0, 3), (6, 9)]);
    expect(matchRanges('Перепечь щит', 'печь'), isEmpty); // середина слова не считается
    expect(matchRanges('что угодно', '  '), isEmpty);
  });

  test('задача подходит, если все слова запроса начинают её слова', () {
    expect(matchesAll('Перепечь щит с новым кейджем', 'щит кейдж'), isTrue);
    expect(matchesAll('Перепечь щит', 'щит кейдж'), isFalse);
    expect(matchesAll('Ёлка', 'елк'), isTrue);
    expect(matchesAll('что-то', ''), isFalse);
  });
}
