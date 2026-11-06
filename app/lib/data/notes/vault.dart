// Папка заметок «Знаний» на диске (docs/knowledge.md, шаг 4): прочитать всё, следить за изменениями,
// бережно записывать. Правила бережности: файл меняется только по действию пользователя; если его изменили
// снаружи после того, как мы его прочли, — не затираем (VaultConflict); пишем через временный файл
// и переименование; удаление — в папку `.trash` внутри папки заметок (как у Obsidian), а не насовсем.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:watcher/watcher.dart';

import '../../core/notes/edit.dart';

/// Отпечаток файла: размер, время изменения и sha256 содержимого.
class FileStamp {
  final int size;
  final int mtime;
  final String hash;
  const FileStamp(this.size, this.mtime, this.hash);

  Map<String, dynamic> toJson() => {'size': size, 'mtime': mtime, 'hash': hash};
  factory FileStamp.fromJson(Map<String, dynamic> j) =>
      FileStamp((j['size'] as num).toInt(), (j['mtime'] as num).toInt(), j['hash'] as String);
}

String hashBytes(List<int> b) => sha256.convert(b).toString();

/// Что изменилось в папке.
enum VaultChangeKind { added, changed, removed }

class VaultChange {
  final VaultChangeKind kind;
  final String path;

  /// Текст заметки (для .md, кроме удаления).
  final String? text;
  const VaultChange(this.kind, this.path, [this.text]);
  @override
  String toString() => '${kind.name} $path';
}

/// Файл изменили снаружи (другая программа, синхронизация) после того, как мы его прочли.
class VaultConflict implements Exception {
  final String path;
  VaultConflict(this.path);
  @override
  String toString() => 'Файл «$path» изменился, пока был открыт';
}

/// Что не читаем: служебные папки других программ и свои временные файлы.
bool skipPath(String rel) {
  final parts = rel.split('/');
  if (parts.any((p) => p.startsWith('.'))) return true; // .git, .obsidian, .trash, .sputnik-tmp
  final name = parts.last.toLowerCase();
  return name == 'desktop.ini' || name == 'thumbs.db' || name.endsWith('~') || name.endsWith('.tmp') || name.endsWith('.sputnik-tmp');
}

class NoteVault {
  final Directory root;
  final Map<String, FileStamp> _stamps = {};

  NoteVault(this.root);

  /// Отпечатки прочитанных файлов (для синхронизации и кэша).
  Map<String, FileStamp> get stamps => Map.unmodifiable(_stamps);

  String rel(String abs) {
    var r = abs.substring(root.path.length).replaceAll('\\', '/');
    while (r.startsWith('/')) {
      r = r.substring(1);
    }
    return r;
  }

  File file(String rel) => File('${root.path}${Platform.pathSeparator}${rel.replaceAll('/', Platform.pathSeparator)}');

  static bool isNote(String rel) => rel.toLowerCase().endsWith('.md');
  static bool isCanvas(String rel) => rel.toLowerCase().endsWith('.canvas');

  /// Текстовые файлы, которые мы сами правим: заметки и холсты (у них отпечаток с хешем — для защиты от затирания).
  static bool isText(String rel) => isNote(rel) || isCanvas(rel);

  /// Прочитать всю папку: заметки с текстом и пути прочих файлов.
  Future<({Map<String, String> notes, List<String> files})> scan() async {
    final notes = <String, String>{};
    final files = <String>[];
    _stamps.clear();
    if (!await root.exists()) return (notes: notes, files: files);
    await for (final e in root.list(recursive: true, followLinks: false)) {
      if (e is! File) continue;
      final r = rel(e.path);
      if (skipPath(r)) continue;
      if (isNote(r)) {
        final t = await _read(r);
        if (t != null) notes[r] = t;
      } else if (isCanvas(r)) {
        await _read(r);
        files.add(r);
      } else {
        final st = await e.stat();
        _stamps[r] = FileStamp(st.size, st.modified.millisecondsSinceEpoch, '');
        files.add(r);
      }
    }
    return (notes: notes, files: files..sort());
  }

  /// Прочитать заметку и запомнить отпечаток. Нет файла — null. Не UTF-8 — читаем как Latin-1, чтобы не упасть.
  Future<String?> _read(String r) async {
    final f = file(r);
    try {
      final bytes = await f.readAsBytes();
      final st = await f.stat();
      _stamps[r] = FileStamp(bytes.length, st.modified.millisecondsSinceEpoch, hashBytes(bytes));
      try {
        return utf8.decode(bytes);
      } on FormatException {
        return latin1.decode(bytes);
      }
    } on FileSystemException {
      return null;
    }
  }

  /// Перечитать файл после сигнала от слежения. Содержимое то же (например, это наша же запись) — null.
  Future<VaultChange?> refresh(String r) async {
    if (skipPath(r)) return null;
    final f = file(r);
    final was = _stamps[r];
    if (!await f.exists()) {
      if (was == null) return null;
      _stamps.remove(r);
      return VaultChange(VaultChangeKind.removed, r);
    }
    if (!isText(r)) {
      final st = await f.stat();
      _stamps[r] = FileStamp(st.size, st.modified.millisecondsSinceEpoch, '');
      return was == null ? VaultChange(VaultChangeKind.added, r) : null;
    }
    final t = await _read(r);
    if (t == null) return null;
    final now = _stamps[r]!;
    if (was != null && was.hash == now.hash) return null;
    return VaultChange(was == null ? VaultChangeKind.added : VaultChangeKind.changed, r, t);
  }

  /// Следить за папкой. Сигналы склеиваются за [debounce]; наши собственные записи не приходят.
  Stream<VaultChange> watch({Duration debounce = const Duration(milliseconds: 250), Watcher? watcher}) {
    final w = watcher ?? DirectoryWatcher(root.path);
    final ctrl = StreamController<VaultChange>();
    final pending = <String>{};
    Timer? timer;
    StreamSubscription<WatchEvent>? sub;
    Future<void> flush() async {
      final batch = pending.toList()..sort();
      pending.clear();
      for (final r in batch) {
        final c = await refresh(r);
        if (c != null && !ctrl.isClosed) ctrl.add(c);
      }
    }

    ctrl.onListen = () {
      sub = w.events.listen((ev) {
        final r = rel(ev.path);
        if (skipPath(r)) return;
        pending.add(r);
        timer?.cancel();
        timer = Timer(debounce, flush);
      }, onError: ctrl.addError);
    };
    ctrl.onCancel = () async {
      timer?.cancel();
      await sub?.cancel();
    };
    return ctrl.stream;
  }

  /// Все файлы папки (заметки и вложения, без служебных): путь → (размер, время изменения).
  Future<Map<String, (int, int)>> listFiles() async {
    final out = <String, (int, int)>{};
    if (!await root.exists()) return out;
    await for (final e in root.list(recursive: true, followLinks: false)) {
      if (e is! File) continue;
      final r = rel(e.path);
      if (skipPath(r)) continue;
      final st = await e.stat();
      out[r] = (st.size, st.modified.millisecondsSinceEpoch);
    }
    return out;
  }

  Future<List<int>> readBytes(String r) => file(r).readAsBytes();

  /// Прочитать текстовый файл (холст) и запомнить отпечаток — потом [write] не затрёт чужую правку.
  Future<String?> readText(String r) => _read(r);

  /// Записать содержимое, пришедшее с другого компьютера (через временный файл).
  Future<void> writeBytes(String r, List<int> bytes) => _atomicWrite(r, bytes);

  /// Изменился ли файл на диске с тех пор, как мы его прочли.
  Future<bool> changedOutside(String r) async {
    final was = _stamps[r];
    final f = file(r);
    if (!await f.exists()) return was != null;
    if (was == null) return true;
    final bytes = await f.readAsBytes();
    return hashBytes(bytes) != was.hash;
  }

  /// Записать заметку. Файл изменился снаружи с прошлого чтения — VaultConflict (если не [force]).
  /// Текст не изменился — ничего не пишем.
  Future<void> write(String r, String text, {bool force = false}) async {
    final bytes = utf8.encode(text);
    final h = hashBytes(bytes);
    if (_stamps[r]?.hash == h && await file(r).exists()) return;
    if (!force && _stamps.containsKey(r) && await changedOutside(r)) throw VaultConflict(r);
    await _atomicWrite(r, bytes);
  }

  Future<void> _atomicWrite(String r, List<int> bytes) async {
    final f = file(r);
    await f.parent.create(recursive: true);
    final name = r.split('/').last;
    final tmp = File('${f.parent.path}${Platform.pathSeparator}.$name.sputnik-tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(f.path);
    final st = await f.stat();
    _stamps[r] = FileStamp(bytes.length, st.modified.millisecondsSinceEpoch, isText(r) ? hashBytes(bytes) : '');
  }

  /// Новая заметка (или файл): имя занято — берётся «Имя 2.md». Возвращает путь, куда записано.
  Future<String> create(String wanted, String text) async {
    final taken = await _siblings(wanted);
    final r = freeName(wanted, taken);
    await _atomicWrite(r, utf8.encode(text));
    return r;
  }

  /// Положить файл (картинку) в папку, имя занято — «имя 2.png».
  Future<String> addFile(String wanted, List<int> bytes) async {
    final r = freeName(wanted, await _siblings(wanted));
    await _atomicWrite(r, bytes);
    return r;
  }

  Future<List<String>> _siblings(String r) async {
    final dir = file(r).parent;
    if (!await dir.exists()) return const [];
    final folder = r.contains('/') ? r.substring(0, r.lastIndexOf('/') + 1) : '';
    return [
      await for (final e in dir.list(followLinks: false)) '$folder${e.path.split(Platform.pathSeparator).last}',
    ];
  }

  /// Переименовать или перенести. Новое имя занято — исключение (чужой файл не затираем).
  Future<void> rename(String from, String to) async {
    if (from == to) return;
    final dst = file(to);
    final same = from.toLowerCase() == to.toLowerCase(); // в Windows «щит» и «Щит» — один файл
    if (!same && await dst.exists()) throw FileSystemException('Имя уже занято', dst.path);
    await dst.parent.create(recursive: true);
    if (same && from != to) {
      final mid = '$from.sputnik-tmp';
      await file(from).rename(file(mid).path);
      await file(mid).rename(dst.path);
    } else {
      await file(from).rename(dst.path);
    }
    final st = _stamps.remove(from);
    if (st != null) _stamps[to] = st;
  }

  /// Удалить — перенести в `.trash` внутри папки заметок, с сохранением папок (как Obsidian).
  Future<String> trash(String r) async {
    final taken = <String>[];
    final dst0 = '.trash/$r';
    final dir = file(dst0).parent;
    if (await dir.exists()) {
      final folder = dst0.substring(0, dst0.lastIndexOf('/') + 1);
      await for (final e in dir.list()) {
        taken.add('$folder${e.path.split(Platform.pathSeparator).last}');
      }
    }
    final dst = freeName(dst0, taken);
    await file(dst).parent.create(recursive: true);
    await file(r).rename(file(dst).path);
    _stamps.remove(r);
    return dst;
  }

  /// Отпечатки — в JSON (кэш в папке настроек приложения, не в папке заметок).
  String stampsJson() => jsonEncode({for (final e in _stamps.entries) e.key: e.value.toJson()});

  static Map<String, FileStamp> parseStamps(String json) {
    final j = jsonDecode(json) as Map<String, dynamic>;
    return {for (final e in j.entries) e.key: FileStamp.fromJson(e.value as Map<String, dynamic>)};
  }
}
