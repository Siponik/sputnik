import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/notes/graph.dart';
import 'package:sputnik_app/core/notes/index.dart';

void main() {
  final ix = NoteIndex.of({
    '3D/Запекание.md': '---\ntags: [baking]\n---\n# Порядок\n- [ ] Пеку по [[UV]] и [[Кейдж]], картинка ![[рис.png]]',
    '3D/UV.md': 'Швы по [[Запекание]].',
    'DND/Мира.md': '#лор Живёт в [[Вельск]]',
    'DND/Вельск.md': '',
    'Одиночка.md': '',
  }, files: ['3D/рис.png']);

  List<String> ids(GraphData g) => g.nodes.map((n) => n.id).toList();

  test('весь граф: заметки, связи, число связей', () {
    final g = buildGraph(ix, const GraphFilter());
    expect(ids(g), ['3D/UV.md', '3D/Запекание.md', 'DND/Вельск.md', 'DND/Мира.md', 'Одиночка.md']);
    expect(g.links.length, 2); // Запекание—UV (в обе стороны — одна), Мира—Вельск
    expect(g.nodes[g.indexOf('3D/Запекание.md')].degree, 1);
    expect(g.nodes.first.group, '3D');
  });

  test('показывать: теги, вложения, несозданные; без одиночек', () {
    final g = buildGraph(ix, const GraphFilter(tags: true, files: true, missing: true, orphans: false));
    expect(ids(g), containsAll(['#baking', '#лор', '3D/рис.png', '?Кейдж']));
    expect(ids(g), isNot(contains('Одиночка.md')));
    expect(g.nodes[g.indexOf('?Кейдж')].kind, GraphKind.missing);
    expect(g.nodes[g.indexOf('3D/Запекание.md')].degree, 4);
  });

  test('скрытая группа и локальный граф', () {
    expect(ids(buildGraph(ix, const GraphFilter(hidden: {'DND'}))), ['3D/UV.md', '3D/Запекание.md', 'Одиночка.md']);
    // Без папки 3D пропадают и её несозданные ссылки.
    expect(ids(buildGraph(ix, const GraphFilter(hidden: {'3D'}, missing: true))), ['DND/Вельск.md', 'DND/Мира.md', 'Одиночка.md']);
    final local = buildGraph(ix, const GraphFilter(focus: 'DND/Мира.md', tags: true));
    expect(ids(local), ['#лор', 'DND/Вельск.md', 'DND/Мира.md']);
    // Одиночка в фокусе не пропадает и при «без связей».
    expect(ids(buildGraph(ix, const GraphFilter(focus: 'Одиночка.md', orphans: false))), ['Одиночка.md']);
  });

  test('раскрытие по масштабу и удалению от центра', () {
    expect(openness(1, 0), 0);
    expect(openness(zoomNames * 1.2, 0), 1);
    expect(openness(zoomNodes * 1.2, 0), 2);
    expect(openness(zoomNodes * 1.2, 1), 1); // у края — только шапка
    final mid = openness(zoomNames, 0);
    expect(mid > 0 && mid < 1, isTrue);
    expect(dotRadius(0) < dotRadius(9), isTrue);
  });

  test('первые строки: без шапки, решёток, ссылок и картинок', () {
    expect(previewLines(ix.text('3D/Запекание.md')!), ['Порядок', 'Пеку по UV и Кейдж, картинка']);
    expect(previewLines('![[a.png]]\n\nСсылка [[A|на а]]', n: 1), ['Ссылка на а']);
    expect(previewLines('a' * 80, width: 10).single, 'aaaaaaaaa…');
  });

  test('камера: приближение вокруг курсора и вписывание', () {
    final c = GraphCamera();
    c.zoomAt(2, 100, 50);
    final (sx, sy) = c.toScreen(100, 50);
    expect((sx, sy), (100.0, 50.0)); // точка под курсором стоит на месте
    expect(c.k, 2);
    c.fit(-100, -50, 100, 50, 480, 280, pad: 40, maxK: 4);
    expect(c.k, 2); // по ширине 400/200 = 2, по высоте 200/100 = 2
    expect(c.toScreen(0, 0), (240.0, 140.0));
    c.zoomAt(100, 0, 0);
    expect(c.k, 8);
  });
}
