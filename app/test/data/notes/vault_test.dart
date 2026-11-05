import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/data/notes/vault.dart';
import 'package:watcher/watcher.dart';

void main() {
  late Directory dir;
  late NoteVault v;

  void put(String rel, String text) {
    final f = File('${dir.path}/$rel');
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(text);
  }

  String read(String rel) => File('${dir.path}/$rel').readAsStringSync();

  setUp(() {
    dir = Directory.systemTemp.createTempSync('vault');
    put('3D/Щит.md', 'Щит [[Кант]]');
    put('DND/Мира Тёрн.md', '---\ntype: НПС\n---\nИнформатор');
    put('Вложения/карта.png', 'PNG');
    put('.obsidian/workspace.json', '{}');
    put('.trash/старое.md', 'удалено');
    put('3D/desktop.ini', 'x');
    v = NoteVault(dir);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('scan: заметки с текстом, прочие файлы, служебное пропущено', () async {
    final s = await v.scan();
    expect(s.notes, {'3D/Щит.md': 'Щит [[Кант]]', 'DND/Мира Тёрн.md': '---\ntype: НПС\n---\nИнформатор'});
    expect(s.files, ['Вложения/карта.png']);
    expect(v.stamps['3D/Щит.md']!.hash, hashBytes(File('${dir.path}/3D/Щит.md').readAsBytesSync()));
  });

  test('нет папки — пусто, без ошибки', () async {
    final s = await NoteVault(Directory('${dir.path}/нет')).scan();
    expect(s.notes, isEmpty);
  });

  test('запись: через временный файл, без лишних записей, создаёт папки', () async {
    await v.scan();
    await v.write('3D/Щит.md', 'Новый текст');
    expect(read('3D/Щит.md'), 'Новый текст');
    await v.write('Новое/Папка/Идея.md', 'идея');
    expect(read('Новое/Папка/Идея.md'), 'идея');
    expect(dir.listSync(recursive: true).where((e) => e.path.endsWith('.sputnik-tmp')), isEmpty);
    final before = File('${dir.path}/3D/Щит.md').statSync().modified;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await v.write('3D/Щит.md', 'Новый текст'); // тот же текст — файл не трогаем
    expect(File('${dir.path}/3D/Щит.md').statSync().modified, before);
  });

  test('изменили снаружи — запись не затирает, а с force — пишет', () async {
    await v.scan();
    put('3D/Щит.md', 'правка из другой программы');
    expect(await v.changedOutside('3D/Щит.md'), isTrue);
    await expectLater(v.write('3D/Щит.md', 'моя правка'), throwsA(isA<VaultConflict>()));
    expect(read('3D/Щит.md'), 'правка из другой программы');
    await v.write('3D/Щит.md', 'моя правка', force: true);
    expect(read('3D/Щит.md'), 'моя правка');
  });

  test('refresh: своя запись — не изменение, чужая — изменение, удаление и новый файл', () async {
    await v.scan();
    await v.write('3D/Щит.md', 'моё');
    expect(await v.refresh('3D/Щит.md'), isNull);
    put('3D/Щит.md', 'чужое');
    final c = await v.refresh('3D/Щит.md');
    expect(c!.kind, VaultChangeKind.changed);
    expect(c.text, 'чужое');
    put('DND/Новая.md', 'н');
    expect((await v.refresh('DND/Новая.md'))!.kind, VaultChangeKind.added);
    File('${dir.path}/DND/Новая.md').deleteSync();
    expect((await v.refresh('DND/Новая.md'))!.kind, VaultChangeKind.removed);
    expect(await v.refresh('.obsidian/workspace.json'), isNull);
  });

  test('create и addFile не затирают: «Имя 2»', () async {
    await v.scan();
    expect(await v.create('3D/Щит.md', 'другой'), '3D/Щит 2.md');
    expect(read('3D/Щит.md'), 'Щит [[Кант]]');
    expect(await v.addFile('Вложения/карта.png', [1, 2]), 'Вложения/карта 2.png');
  });

  test('rename: занято — ошибка; смена регистра работает', () async {
    await v.scan();
    await expectLater(v.rename('3D/Щит.md', 'DND/Мира Тёрн.md'), throwsA(isA<FileSystemException>()));
    await v.rename('3D/Щит.md', '3D/Ассеты/Щит паладина.md');
    expect(read('3D/Ассеты/Щит паладина.md'), 'Щит [[Кант]]');
    expect(v.stamps.containsKey('3D/Ассеты/Щит паладина.md'), isTrue);
    await v.rename('3D/Ассеты/Щит паладина.md', '3D/Ассеты/щит паладина.md');
    expect((await v.scan()).notes.keys, contains('3D/Ассеты/щит паладина.md'));
  });

  test('trash: в .trash с теми же папками, повтор — «Имя 2»', () async {
    await v.scan();
    expect(await v.trash('3D/Щит.md'), '.trash/3D/Щит.md');
    put('3D/Щит.md', 'ещё один');
    await v.scan();
    expect(await v.trash('3D/Щит.md'), '.trash/3D/Щит 2.md');
    expect((await v.scan()).notes.keys, isNot(contains('3D/Щит.md')));
  });

  test('отпечатки в JSON и обратно', () async {
    await v.scan();
    final back = NoteVault.parseStamps(v.stampsJson());
    expect(back['3D/Щит.md']!.hash, v.stamps['3D/Щит.md']!.hash);
    expect(back['Вложения/карта.png']!.size, 3);
  });

  test('watch: склеивает сигналы, свои записи не приходят', () async {
    await v.scan();
    final w = PollingDirectoryWatcher(dir.path, pollingDelay: const Duration(milliseconds: 50));
    final got = <String>[];
    final sub = v.watch(watcher: w, debounce: const Duration(milliseconds: 100)).listen((c) => got.add(c.toString()));
    await w.ready;
    await v.write('3D/Щит.md', 'моё');
    put('DND/Мира Тёрн.md', 'чужая правка');
    put('DND/Мира Тёрн.md', 'чужая правка 2');
    put('.obsidian/x.json', '{}');
    final until = DateTime.now().add(const Duration(seconds: 5));
    while (got.isEmpty && DateTime.now().isBefore(until)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await sub.cancel();
    expect(got, ['changed DND/Мира Тёрн.md']);
  });
}
