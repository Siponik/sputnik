import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/data/notes/notes_sync.dart';
import 'package:sputnik_app/state/notes_state.dart';

import '../data/notes/notes_sync_test.dart' show MemStore;

void main() {
  late Directory tmp, vault;
  late NotesState st;
  late MemStore drive;

  void put(String rel, String text) {
    final f = File('${vault.path}/$rel');
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(text);
  }

  String? read(String rel) {
    final f = File('${vault.path}/$rel');
    return f.existsSync() ? f.readAsStringSync() : null;
  }

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('nstate');
    vault = Directory('${tmp.path}/vault')..createSync();
    put('DND/Мира Тёрн.md', 'НПС');
    put('DND/Город Вельск.md', 'Тут [[Мира Тёрн]].');
    put('Шаблоны/НПС.md', '---\ntype: НПС\n---\n# {{title}}\nСоздано {{date}}\n');
    drive = MemStore();
    st = NotesState(DirNotesFiles(Directory('${tmp.path}/cfg')), remote: () => drive)..saveDelay = const Duration(milliseconds: 10);
    await st.open(vault.path, watch: false);
  });

  tearDown(() async {
    await st.flush();
    st.dispose();
    tmp.deleteSync(recursive: true);
  });

  test('открытие папки: индекс и настройки запоминаются', () async {
    expect(st.index.length, 3);
    st.openNote('DND/Мира Тёрн.md');
    await st.flush();
    final again = NotesState(DirNotesFiles(Directory('${tmp.path}/cfg')));
    await again.load();
    expect(again.config.folder, vault.path);
    expect(again.config.tabs, ['DND/Мира Тёрн.md']);
    expect(again.config.recent, ['DND/Мира Тёрн.md']);
    again.dispose();
  });

  test('нет папки — понятная ошибка', () async {
    await st.open('${tmp.path}/нет', watch: false);
    expect(st.error, contains('недоступна'));
    expect(st.hasFolder, isFalse);
  });

  test('правка: индекс сразу, файл — с задержкой', () async {
    st.edit('DND/Мира Тёрн.md', 'Информатор #лор');
    expect(st.index.withTag('лор'), ['DND/Мира Тёрн.md']);
    expect(read('DND/Мира Тёрн.md'), 'НПС');
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(read('DND/Мира Тёрн.md'), 'Информатор #лор');
  });

  test('файл изменили снаружи — правка не затирает, выбор «оставить обе»', () async {
    put('DND/Мира Тёрн.md', 'правка из Obsidian');
    st.edit('DND/Мира Тёрн.md', 'моя правка');
    expect(await st.save('DND/Мира Тёрн.md'), isFalse);
    expect(st.conflicts.keys, ['DND/Мира Тёрн.md']);
    expect(read('DND/Мира Тёрн.md'), 'правка из Obsidian');
    await st.resolve('DND/Мира Тёрн.md', keep: 'both');
    expect(read('DND/Мира Тёрн (с другого компьютера).md'), 'моя правка');
  });

  test('новая заметка из шаблона', () async {
    final p = await st.create('DND', 'Борн', template: 'Шаблоны/НПС.md');
    expect(p, 'DND/Борн.md');
    expect(read(p!), startsWith('---\ntype: НПС\n---\n# Борн\nСоздано 20'));
    expect(st.active, p);
  });

  test('переименование обновляет ссылки и вкладки', () async {
    st.openNote('DND/Мира Тёрн.md');
    expect(st.renameTouches('DND/Мира Тёрн.md'), 1);
    await st.rename('DND/Мира Тёрн.md', 'DND/НПС/Мира.md');
    expect(read('DND/Город Вельск.md'), 'Тут [[Мира]].');
    expect(st.config.tabs, ['DND/НПС/Мира.md']);
    expect(st.index.backlinks('DND/НПС/Мира.md').single.from, 'DND/Город Вельск.md');
  });

  test('удаление — в .trash, вкладка закрывается', () async {
    st.openNote('DND/Мира Тёрн.md');
    await st.trash('DND/Мира Тёрн.md');
    expect(read('.trash/DND/Мира Тёрн.md'), 'НПС');
    expect(st.config.tabs, isEmpty);
  });

  test('чек-лист и свойство меняются в тексте', () async {
    put('a.md', '- [ ] сделать');
    await st.open(vault.path, watch: false);
    st.toggleTask('a.md', 0, true);
    expect(st.textOf('a.md'), '- [x] сделать');
    st.setProp('a.md', 'статус', 'готово');
    expect(st.textOf('a.md'), '---\nстатус: готово\n---\n- [x] сделать');
  });

  test('синхронизация отправляет всё и пишет строку состояния', () async {
    st.edit('DND/Мира Тёрн.md', 'несохранённое');
    final r = await st.syncNow();
    expect(r!.sent, 3);
    expect(drive.text('DND/Мира Тёрн.md'), 'несохранённое');
    expect(st.syncStatus, 'Знания: всё отправлено');
  });

  test('сверка упала не из-за связи — строка с причиной, следующая удачная её убирает', () async {
    var broken = true;
    final s2 = NotesState(DirNotesFiles(Directory('${tmp.path}/cfg2')), remote: () => broken ? _Broken() : drive);
    await s2.open(vault.path, watch: false);
    await s2.syncNow();
    expect(s2.syncStatus, startsWith('Знания: не сверилось — '));
    broken = false;
    await s2.syncNow();
    expect(s2.syncStatus, 'Знания: всё отправлено');
    await s2.flush();
    s2.dispose();
  });

  test('забыть папку: файлы на месте, раздел снова «первый запуск»', () async {
    await st.forget();
    expect(st.hasFolder, isFalse);
    expect(st.config.folder, isNull);
    expect(File('${vault.path}/DND/Мира Тёрн.md').existsSync(), isTrue);
  });
}

class _Broken extends MemStore {
  @override
  Future<Map<String, RemoteFile>> list() async => throw StateError('нет входа в Google');
}
