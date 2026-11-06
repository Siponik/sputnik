import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/data/notes/drive_store.dart';
import 'package:sputnik_app/data/notes/notes_sync.dart';
import 'package:sputnik_app/data/notes/vault.dart';

/// Drive в памяти.
class MemStore implements RemoteStore {
  final Map<String, (String, List<int>, int)> files = {}; // путь → (id, байты, время)
  final trashed = <String>[];
  var n = 0;
  bool down = false;
  bool full = false;

  @override
  Future<Map<String, RemoteFile>> list() async {
    if (down) throw const SocketException('нет сети');
    return {for (final e in files.entries) e.key: RemoteFile(e.value.$1, e.key, md5Of(e.value.$2), e.value.$3)};
  }

  @override
  Future<List<int>> download(RemoteFile f) async => files[f.path]!.$2;

  @override
  Future<RemoteFile> upload(String path, List<int> bytes, {RemoteFile? existing}) async {
    if (full) throw DriveFull();
    final id = existing?.id ?? 'id${n++}';
    files[path] = (id, List.of(bytes), DateTime.now().millisecondsSinceEpoch);
    return RemoteFile(id, path, md5Of(bytes), 0);
  }

  @override
  Future<void> trash(RemoteFile f) async {
    files.remove(f.path);
    trashed.add(f.path);
  }

  String text(String p) => utf8.decode(files[p]!.$2);
}

class Pc {
  final Directory dir;
  final NoteVault vault;
  final Map<String, BaseEntry> base = {};
  Pc(this.dir) : vault = NoteVault(dir);
  void put(String rel, String text) {
    final f = File('${dir.path}/$rel');
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(text);
  }

  String? read(String rel) {
    final f = File('${dir.path}/$rel');
    return f.existsSync() ? f.readAsStringSync() : null;
  }

  Future<dynamic> sync(MemStore s) async {
    final r = await NotesSync(vault, s).run(base);
    // База переживает перезапуск: через JSON.
    final back = baseFromJson(baseToJson(base));
    base
      ..clear()
      ..addAll(back);
    return r;
  }
}

void main() {
  late Directory tmp;
  late Pc a, b;
  late MemStore drive;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('nsync');
    a = Pc(Directory('${tmp.path}/a')..createSync());
    b = Pc(Directory('${tmp.path}/b')..createSync());
    drive = MemStore();
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('первый компьютер отправляет всё, второй скачивает в пустую папку', () async {
    a.put('3D/Щит.md', 'щит');
    a.put('Вложения/карта.png', 'PNG');
    a.put('.obsidian/x.json', '{}');
    final r1 = await a.sync(drive);
    expect(r1.sent, 2);
    expect(drive.files.keys.toSet(), {'3D/Щит.md', 'Вложения/карта.png'});
    final r2 = await b.sync(drive);
    expect(r2.got, 2);
    expect(b.read('3D/Щит.md'), 'щит');
    expect((await a.sync(drive)).sent, 0); // второй раз отправлять нечего
  });

  test('правка на одном компьютере доходит до другого', () async {
    a.put('a.md', 'v1');
    await a.sync(drive);
    await b.sync(drive);
    b.put('a.md', 'v2 с b');
    expect((await b.sync(drive)).sent, 1);
    expect((await a.sync(drive)).got, 1);
    expect(a.read('a.md'), 'v2 с b');
  });

  test('правка на обоих — обе копии, ничего не теряется', () async {
    a.put('a.md', 'v1');
    await a.sync(drive);
    await b.sync(drive);
    a.put('a.md', 'правка A');
    b.put('a.md', 'правка B');
    await a.sync(drive);
    final r = await b.sync(drive);
    expect(r.conflicts, ['a.md']);
    expect(b.read('a.md'), 'правка B');
    expect(b.read('a (с другого компьютера).md'), 'правка A');
    await a.sync(drive);
    expect(a.read('a.md'), 'правка B');
    expect(a.read('a (с другого компьютера).md'), 'правка A');
  });

  test('удаление доходит до другого компьютера — в корзину, не насовсем', () async {
    a.put('a.md', 'x');
    await a.sync(drive);
    await b.sync(drive);
    File('${b.dir.path}/a.md').deleteSync();
    await b.sync(drive);
    expect(drive.trashed, ['a.md']);
    await a.sync(drive);
    expect(a.read('a.md'), isNull);
    expect(a.read('.trash/a.md'), 'x');
  });

  test('нет связи — ничего не теряется, отправится потом', () async {
    a.put('a.md', 'x');
    drive.down = true;
    final r = await a.sync(drive);
    expect(r.offline, isTrue);
    expect(r.status(), startsWith('Знания: нет связи'));
    drive.down = false;
    expect((await a.sync(drive)).sent, 1);
  });

  test('Drive полон — новые не отправляются, скачивание работает', () async {
    b.put('b.md', 'с b');
    await b.sync(drive);
    drive.full = true;
    a.put('a.md', 'x');
    final r = await a.sync(drive);
    expect(r.driveFull, isTrue);
    expect(r.got, 1);
    expect(drive.files.containsKey('a.md'), isFalse);
    drive.full = false;
    expect((await a.sync(drive)).sent, 1);
  });

  test('drivePaths собирает пути от папки «Знания», чужое пропускает', () {
    expect(
        drivePaths('root', {
          'd1': ('3D', 'root', true),
          'd2': ('Техники', 'd1', true),
          'f1': ('Щит.md', 'd2', false),
          'f2': ('Корень.md', 'root', false),
          'f3': ('Чужой.md', 'elsewhere', false),
          'f4': ('Сирота.md', null, false),
        }),
        {'f1': '3D/Техники/Щит.md', 'f2': 'Корень.md'});
  });

  test('mimeOf', () {
    expect(mimeOf('a/b.md'), 'text/markdown');
    expect(mimeOf('x.PNG'), 'image/png');
    expect(mimeOf('x.canvas'), 'application/json');
    expect(mimeOf('x'), 'application/octet-stream');
  });
}
