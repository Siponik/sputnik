// Состояние раздела «Знания» (docs/knowledge.md, шаги 6–7): папка заметок, индекс, открытые вкладки,
// «Недавние», сохранение, переименование со ссылками, корзина, синхронизация с Drive.
// Правило «сначала локально»: экран меняется сразу, файл пишется с короткой задержкой, Drive догоняет в фоне.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/notes/edit.dart';
import '../core/notes/index.dart';
import '../core/notes/parse.dart';
import '../core/notes/sync.dart';
import '../data/notes/notes_sync.dart';
import '../data/notes/vault.dart';

/// Настройки раздела: папка, недавние, открытые вкладки. Файл — в папке настроек приложения.
class NotesConfig {
  String? folder;
  List<String> recent;
  List<String> tabs;
  String? active;
  bool sync;
  NotesConfig({this.folder, List<String>? recent, List<String>? tabs, this.active, this.sync = true})
      : recent = recent ?? [],
        tabs = tabs ?? [];

  Map<String, dynamic> toJson() => {
        'folder': folder,
        'recent': recent,
        'tabs': tabs,
        'active': active,
        'sync': sync,
      };

  factory NotesConfig.fromJson(Map<String, dynamic> j) => NotesConfig(
        folder: j['folder'] as String?,
        recent: (j['recent'] as List?)?.cast<String>(),
        tabs: (j['tabs'] as List?)?.cast<String>(),
        active: j['active'] as String?,
        sync: j['sync'] as bool? ?? true,
      );
}

/// Куда сохранять настройки, базу синхронизации и т. п. (в приложении — подпапка flutter/ папки данных).
abstract class NotesFiles {
  Future<String?> read(String name);
  Future<void> write(String name, String text);
}

class DirNotesFiles implements NotesFiles {
  final Directory dir;
  DirNotesFiles(this.dir);
  File _f(String n) => File('${dir.path}${Platform.pathSeparator}$n');
  @override
  Future<String?> read(String name) async => await _f(name).exists() ? _f(name).readAsString() : null;
  @override
  Future<void> write(String name, String text) async {
    await dir.create(recursive: true);
    final t = File('${_f(name).path}.tmp');
    await t.writeAsString(text, flush: true);
    await t.rename(_f(name).path);
  }
}

class NotesState extends ChangeNotifier {
  final NotesFiles files;

  /// Как достать общую копию на Drive (null — синхронизации нет, например без входа в Google).
  final RemoteStore? Function()? remote;

  NotesState(this.files, {this.remote});

  NotesConfig config = NotesConfig();
  NoteVault? vault;
  NoteIndex index = NoteIndex();
  bool loading = false;

  /// «Читаю 152 заметки…» во время первого чтения.
  int scanned = 0;
  String? error;

  /// Какую папку не нашли (для «Не вижу папку …»).
  String? missingFolder;

  /// Файлы, которые изменили снаружи, пока в них были несохранённые правки: путь → наш текст.
  final Map<String, String> conflicts = {};

  /// Несохранённые правки: путь → текст (пишутся через [saveDelay]).
  final Map<String, String> _dirty = {};
  final Map<String, Timer> _timers = {};
  Duration saveDelay = const Duration(milliseconds: 600);

  /// Следить за папкой (в тестах экрана выключено).
  bool watchFiles = true;

  SyncReport? lastSync;
  bool syncing = false;

  /// Сверка упала не из-за связи (нет входа в Google и т. п.) — текст для «Состояния».
  String? syncError;
  Map<String, BaseEntry> _base = {};
  StreamSubscription<VaultChange>? _watch;

  static const _cfg = 'notes.json';
  static const _baseFile = 'notes-sync.json';
  static const maxRecent = 12;

  bool get hasFolder => vault != null;

  /// Строка для «Состояния».
  String get syncStatus => syncError != null
      ? 'Знания: не сверилось — $syncError'
      : lastSync?.status(pending: _dirty.length) ?? (config.sync ? 'Знания: ещё не сверялись' : 'Знания: синхронизация выключена');

  Future<void> load() async {
    final t = await files.read(_cfg);
    if (t != null) {
      try {
        config = NotesConfig.fromJson(jsonDecode(t) as Map<String, dynamic>);
      } catch (_) {}
    }
    final b = await files.read(_baseFile);
    if (b != null) {
      try {
        _base = baseFromJson(b);
      } catch (_) {}
    }
    if (config.folder != null) await open(config.folder!, remember: false);
  }

  /// Записи настроек идут по очереди: иначе две одновременные гоняются за один временный файл.
  Future<void> _cfgWrite = Future.value();
  Future<void> _saveConfig() {
    final text = jsonEncode(config.toJson());
    return _cfgWrite = _cfgWrite.catchError((_) {}).then((_) => files.write(_cfg, text));
  }

  /// Дождаться, пока запишутся настройки (для тестов и перед выходом).
  Future<void> flush() async {
    await saveAll();
    await _cfgWrite.catchError((_) {});
  }

  /// Забыть папку (она пропала или больше не нужна). Файлы не трогаем.
  Future<void> forget() async {
    await _watch?.cancel();
    vault = null;
    error = null;
    index = NoteIndex();
    config = NotesConfig(sync: config.sync);
    _base = {};
    await files.write(_baseFile, baseToJson(_base));
    await _saveConfig();
    notifyListeners();
  }

  /// Подключить папку заметок. Пустая папка на новом компьютере заполнится при первой синхронизации.
  Future<void> open(String folder, {bool remember = true, bool watch = true}) async {
    loading = true;
    error = null;
    notifyListeners();
    await _watch?.cancel();
    final v = NoteVault(Directory(folder));
    try {
      if (!await v.root.exists()) {
        error = 'Папка «$folder» недоступна';
        missingFolder = folder;
        vault = null;
        return;
      }
      missingFolder = null;
      final s = await v.scan();
      scanned = s.notes.length;
      index = NoteIndex.of(s.notes, files: s.files);
      vault = v;
      if (config.folder != folder) {
        config
          ..folder = folder
          ..recent = []
          ..tabs = []
          ..active = null;
        _base = {};
        await files.write(_baseFile, baseToJson(_base));
      }
      config.tabs.removeWhere((p) => index.doc(p) == null);
      config.recent.removeWhere((p) => index.doc(p) == null);
      if (config.active != null && !config.tabs.contains(config.active)) config.active = config.tabs.isEmpty ? null : config.tabs.first;
      if (remember) await _saveConfig();
      if (watch && watchFiles) _watch = v.watch().listen(_onChange);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void _onChange(VaultChange c) {
    switch (c.kind) {
      case VaultChangeKind.removed:
        index.remove(c.path);
      case VaultChangeKind.added:
      case VaultChangeKind.changed:
        if (_dirty.containsKey(c.path)) {
          // Мы правим этот файл, а его изменили снаружи: не затираем — показываем выбор.
          conflicts[c.path] = _dirty.remove(c.path)!;
          _timers.remove(c.path)?.cancel();
        }
        index.update(c.path, c.text ?? '');
    }
    notifyListeners();
  }

  // ---- вкладки и недавние ----

  String? get active => config.active;

  void openNote(String path) {
    if (!config.tabs.contains(path)) config.tabs.add(path);
    config.active = path;
    config.recent
      ..remove(path)
      ..insert(0, path);
    if (config.recent.length > maxRecent) config.recent.removeRange(maxRecent, config.recent.length);
    _saveConfig();
    notifyListeners();
  }

  void closeTab(String path) {
    final i = config.tabs.indexOf(path);
    if (i < 0) return;
    config.tabs.removeAt(i);
    if (config.active == path) config.active = config.tabs.isEmpty ? null : config.tabs[i.clamp(0, config.tabs.length - 1)];
    _saveConfig();
    notifyListeners();
  }

  /// Есть несохранённые правки.
  bool isDirty(String path) => _dirty.containsKey(path);

  /// Текст заметки, как его видит редактор (с несохранёнными правками).
  String textOf(String path) => _dirty[path] ?? index.text(path) ?? '';

  // ---- правка ----

  /// Правка из редактора: индекс и экран — сразу, файл — через [saveDelay].
  void edit(String path, String text) {
    _dirty[path] = text;
    index.update(path, text);
    _timers.remove(path)?.cancel();
    _timers[path] = Timer(saveDelay, () => save(path));
    notifyListeners();
  }

  /// Записать правки сейчас. Файл изменили снаружи — конфликт (ничего не пишем).
  Future<bool> save(String path) async {
    _timers.remove(path)?.cancel();
    final t = _dirty[path];
    if (t == null || vault == null) return true;
    try {
      await vault!.write(path, t);
      _dirty.remove(path);
      notifyListeners();
      return true;
    } on VaultConflict {
      conflicts[path] = _dirty.remove(path)!;
      notifyListeners();
      return false;
    }
  }

  Future<void> saveAll() async {
    for (final p in _dirty.keys.toList()) {
      await save(p);
    }
  }

  /// Конфликт: оставить свою правку (затереть файл) или ту, что на диске, или обе (своя — рядом).
  Future<void> resolve(String path, {required String keep}) async {
    final mine = conflicts.remove(path);
    if (mine == null || vault == null) return;
    switch (keep) {
      case 'mine':
        await vault!.write(path, mine, force: true);
        index.update(path, mine);
      case 'both':
        final p = conflictName(path, index.paths);
        final made = await vault!.create(p, mine);
        index.update(made, mine);
      default: // 'disk'
        final t = await vault!.file(path).readAsString();
        await vault!.refresh(path);
        index.update(path, t);
    }
    notifyListeners();
  }

  /// Новая заметка в папке [folder] (по шаблону [template] — путь заметки-шаблона). Вернёт путь.
  Future<String?> create(String folder, String title, {String? template}) async {
    if (vault == null) return null;
    var text = '';
    if (template != null) text = index.text(template) ?? '';
    final today = DateTime.now();
    final ymd = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    text = text.replaceAll('{{title}}', title).replaceAll('{{date}}', ymd);
    final want = '${folder.isEmpty ? '' : '$folder/'}${safeFileName(title)}.md';
    final p = await vault!.create(want, text);
    index.update(p, text);
    openNote(p);
    return p;
  }

  /// Сколько файлов изменится, если переименовать [from] в [to] с обновлением ссылок (для вопроса в окне).
  int renameTouches(String from) => index.referencing(from).length;

  /// Переименовать/перенести. [updateLinks] — поправить ссылки в других заметках. Вернёт новый путь.
  Future<String> rename(String from, String to, {bool updateLinks = true}) async {
    final v = vault!;
    await save(from);
    final refs = updateLinks ? index.referencing(from) : const <String, List<NoteLink>>{};
    await v.rename(from, to);
    index.rename(from, to);
    final all = index.paths.toList();
    for (final e in refs.entries) {
      final src = e.key == from ? to : e.key;
      final text = textOf(src);
      // Ссылки ищем заново в текущем тексте: смещения могли сдвинуться от несохранённых правок.
      final links = parseNote(src, text).links.where((l) => e.value.any((x) => x.start == l.start && x.end == l.end)).toList();
      final (out, n) = rewriteLinks(src, text, links, to, all);
      if (n == 0) continue;
      await v.write(src, out, force: false);
      index.update(src, out);
    }
    config.tabs = [for (final t in config.tabs) t == from ? to : t];
    config.recent = [for (final t in config.recent) t == from ? to : t];
    if (config.active == from) config.active = to;
    await _saveConfig();
    notifyListeners();
    return to;
  }

  /// Удалить — в `.trash` папки заметок.
  Future<void> trash(String path) async {
    _timers.remove(path)?.cancel();
    _dirty.remove(path);
    await vault!.trash(path);
    index.remove(path);
    closeTab(path);
    config.recent.remove(path);
    await _saveConfig();
    notifyListeners();
  }

  /// Положить картинку в `Вложения/` и вернуть строку для вставки в текст.
  Future<String> attach(String name, List<int> bytes, {String folder = 'Вложения'}) async {
    final p = await vault!.addFile('$folder/${safeFileName(name.replaceAll(RegExp(r'\.[^.]+$'), ''))}${RegExp(r'\.[^.]+$').stringMatch(name) ?? ''}', bytes);
    index.update(p, '');
    notifyListeners();
    return '![[${p.substring(p.lastIndexOf('/') + 1)}]]';
  }

  /// Отметить чек-лист прямо в тексте заметки.
  void toggleTask(String path, int line, bool done) => edit(path, setTaskDone(textOf(path), line, done));

  /// Поменять одно свойство в шапке (таблица, плашка свойств).
  void setProp(String path, String key, Object? value) => edit(path, setFrontProp(textOf(path), key, value));

  // ---- синхронизация ----

  /// Одна сверка с Drive. Сначала записываются несохранённые правки.
  Future<SyncReport?> syncNow() async {
    final store = remote?.call();
    if (store == null || vault == null || !config.sync || syncing) return lastSync;
    syncing = true;
    notifyListeners();
    try {
      await saveAll();
      final SyncReport rep;
      try {
        rep = await NotesSync(vault!, store).run(_base);
      } catch (e) {
        syncError = '$e';
        return lastSync;
      }
      syncError = null;
      await files.write(_baseFile, baseToJson(_base));
      lastSync = rep;
      if (rep.got > 0 || rep.trashed > 0 || rep.conflicts.isNotEmpty) {
        // Слежение тоже увидит, но перечитаем сразу, чтобы экран не ждал.
        final s = await vault!.scan();
        index = NoteIndex.of(s.notes, files: s.files);
      }
      return rep;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _watch?.cancel();
    super.dispose();
  }
}
