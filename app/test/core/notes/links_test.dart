import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/notes/index.dart';
import 'package:sputnik_app/core/notes/local_graph.dart';

void main() {
  test('«Связать»: первое упоминание целым словом становится ссылкой', () {
    const t = 'Шапка\nПеку щит, см. запекание нормалей и [[Запекание нормалей]].\n';
    expect(linkMention(t, 1, ['Запекание нормалей'], 'Запекание нормалей'),
        'Шапка\nПеку щит, см. [[Запекание нормалей|запекание нормалей]] и [[Запекание нормалей]].\n');
  });

  test('«Связать»: буква в букву — без подписи, ё = е, внутри ссылки не трогаем', () {
    expect(linkMention('про Мира Тёрн тут', 0, ['Мира Тёрн'], 'Мира Тёрн'), 'про [[Мира Тёрн]] тут');
    expect(linkMention('про мира терн', 0, ['Мира Тёрн'], 'Мира Тёрн'), 'про [[Мира Тёрн|мира терн]]');
    expect(linkMention('[[Мира Тёрн]] и всё', 0, ['Мира Тёрн'], 'Мира Тёрн'), isNull);
    expect(linkMention('Мирабель', 0, ['Мира'], 'Мира'), isNull);
  });

  test('«Связать»: по псевдониму — ссылка на заметку с подписью', () {
    expect(linkMention('звали Тёрн', 0, ['Мира Тёрн', 'Тёрн'], 'Мира Тёрн'), 'звали [[Мира Тёрн|Тёрн]]');
  });

  test('локальный граф: заметка в центре, соседи на глубину, обрезка по max', () {
    final ix = NoteIndex.of({
      'А.md': '[[Б]] [[В]]',
      'Б.md': '[[Г]]',
      'В.md': '',
      'Г.md': '[[Д]]',
      'Д.md': '',
      'Е.md': '',
    });
    final g1 = localGraph(ix, 'А.md');
    expect(g1.nodes.map((n) => n.id).toSet(), {'А.md', 'Б.md', 'В.md'});
    expect(g1.nodes.first.x, 0);
    expect(g1.links.length, 2);
    final g2 = localGraph(ix, 'А.md', depth: 2);
    expect(g2.depth['Г.md'], 2);
    expect(g2.depth.containsKey('Д.md'), isFalse);
    expect(localGraph(ix, 'А.md', depth: 3, max: 3).nodes.length, 3);
    for (final n in g2.nodes) {
      expect(n.x.isFinite && n.y.isFinite, isTrue);
    }
  });
}
