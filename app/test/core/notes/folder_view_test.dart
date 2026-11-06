import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/notes/folder_view.dart';
import 'package:sputnik_app/core/notes/index.dart';
import 'package:sputnik_app/core/notes/parse.dart';

void main() {
  final ix = NoteIndex.of({
    'DND/НПС/Мира Тёрн.md': '---\nтип: НПС\nгде: "[[Город Вельск]]"\nфракция: Пепельные\nстатус: жива\nуровень: 5\ntags: [информатор]\n---\nТекст',
    'DND/НПС/Борн.md': '---\nтип: НПС\nгде: Таверна\nстатус: жив\nуровень: 12\ntags: [гном]\n---\n',
    'DND/Город Вельск.md': '---\nтип: Место\n---\n![[вельск.png]] ![[карта.jpg]] ![[план.pdf]]',
    'DND/Без шапки.md': 'просто текст',
    '3D/Щит.md': '---\nтип: Ассет\n---\n',
  }, files: ['DND/вельск.png', 'DND/карта.jpg', 'DND/план.pdf']);
  List<NoteDoc> docs(List<String> ps) => [for (final p in ps) ix.doc(p)!];

  test('заметки папки с подпапками, по названию', () {
    expect(notesIn(ix.paths, 'DND'), ['DND/Без шапки.md', 'DND/НПС/Борн.md', 'DND/Город Вельск.md', 'DND/НПС/Мира Тёрн.md']);
    expect(notesIn(ix.paths, '').length, 5);
    expect(notesIn(ix.paths, 'DND/НПС').length, 2);
  });

  test('колонки: тип первым, потом по частоте; теги не колонка', () {
    expect(propColumns(docs(notesIn(ix.paths, 'DND'))), ['тип', 'где', 'статус', 'уровень', 'фракция']);
  });

  test('ячейка: ссылка без скобок, список через запятую', () {
    expect(cellText(ix.doc('DND/НПС/Мира Тёрн.md')!.props['где']), 'Город Вельск');
    expect(cellText(['a', '[[b|Бэ]]', null]), 'a, Бэ');
    expect(cellText(true), 'да');
    expect(cellText(null), '');
  });

  test('условия: значение, пусто, тег; варианты значений', () {
    final all = docs(notesIn(ix.paths, 'DND'));
    expect(all.where((d) => matchConds(d, const [PropCond('тип', 'нпс')])).length, 2);
    expect(all.where((d) => matchConds(d, const [PropCond('тип', 'НПС'), PropCond('фракция', '')])).map((d) => d.title), ['Борн']);
    expect(all.where((d) => matchConds(d, const [PropCond('#', 'гном')])).map((d) => d.title), ['Борн']);
    expect(valuesOf(all, 'тип'), ['НПС', 'Место']);
  });

  test('сортировка: числа как числа, пустые внизу в обе стороны', () {
    final all = docs(notesIn(ix.paths, 'DND'));
    expect(sortDocs(all, 'уровень').map((d) => d.title).take(2), ['Мира Тёрн', 'Борн']);
    expect(sortDocs(all, 'уровень', asc: false).map((d) => d.title).take(2), ['Борн', 'Мира Тёрн']);
    expect(sortDocs(all, 'уровень', asc: false).last.title, isNot(anyOf('Борн', 'Мира Тёрн')));
    expect(sortDocs(all, '').first.title, 'Без шапки');
    expect(sortDocs(all, '~links', asc: false, numbers: {'DND/Без шапки.md': 9}).first.title, 'Без шапки');
    expect(sortDocs(all, '#').first.title, 'Борн'); // «гном» раньше «информатор», без тегов — внизу
  });

  test('картинки заметки для обложки', () {
    final d = ix.doc('DND/Город Вельск.md')!;
    final to = {for (final r in ix.outgoing(d.path)) r.link.start: r.to};
    expect(imagesOf(d, (l) => to[l.start]), ['DND/вельск.png', 'DND/карта.jpg']);
  });

  test('новая строка с условиями — шапка заметки', () {
    expect(frontFromConds(const [PropCond('тип', 'НПС'), PropCond('#', 'гном'), PropCond('где', '')]), '---\nтип: НПС\ntags: [гном]\n---\n');
    expect(frontFromConds(const []), '');
  });
}
