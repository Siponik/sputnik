import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/notes/index.dart';
import 'package:sputnik_app/core/notes/parse.dart';
import 'package:sputnik_app/core/notes/tasks.dart';

void main() {
  test('пункты чек-листа: только открытые, без разметки ссылок, отправленные помечены', () {
    const text = '# Щит\n- [ ] Перепечь [[Запекание нормалей|нормали]]\n- [x] Развёртка\n- [ ]   \n  - [ ] Ёлка [[Кейдж]]\n';
    final d = parseNote('3D/Щит.md', text);
    final ts = openTodos(d, {todoKey('3D/Щит.md', 'Ёлка Кейдж')});
    expect(ts.map((t) => t.toString()), ['1:Перепечь нормали', '4:Ёлка Кейдж ✓']);
    expect(taskNotesFrom('3D/Щит.md'), 'Из заметки «Щит» · 3D/Щит.md');
  });

  test('заметки про задачу: название, ссылка, целое слово; ё = е', () {
    final ix = NoteIndex.of({
      'Кейдж.md': 'про кейдж',
      'Б.md': 'Нужен [[Кейдж]] побольше',
      'А.md': 'делаю КЕЙДЖ сегодня',
      'В.md': 'кейджи не трогаю',
      'Ёж.md': 'просто ёж',
    });
    expect(notesAbout(ix, 'кейдж'), ['Кейдж.md', 'А.md', 'Б.md']);
    expect(notesAbout(ix, 'Еж'), ['Ёж.md']);
    expect(notesAbout(ix, 'ке'), isEmpty);
    expect(notesAbout(ix, 'к'), isEmpty);
  });

  test('окно задачи: заметка-источник первой, потом найденные', () {
    final ix = NoteIndex.of({'DND/Сессия 3.md': '- [ ] Карта', 'Карта.md': 'карта мира', 'А.md': 'рисую карта'});
    final n = taskNotesFrom('DND/Сессия 3.md');
    expect(noteFromTaskNotes('что-то\n$n'), 'DND/Сессия 3.md');
    expect(noteFromTaskNotes('просто текст'), isNull);
    expect(notesForTask(ix, 'Карта', n), ['DND/Сессия 3.md', 'Карта.md', 'А.md']);
    expect(notesForTask(ix, 'Карта', ''), ['Карта.md', 'DND/Сессия 3.md', 'А.md']); // пункт чек-листа «Карта» — тоже про неё
  });
}
