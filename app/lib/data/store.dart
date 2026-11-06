// Файлы нового приложения: слой, очередь исходящих, кэш задач для мгновенного запуска.
// Читаем свою подпапку flutter/, слой при её отсутствии — из layer.json старого приложения (только чтение).
// Запись — через временный файл и переименование, чтобы оборванная запись не портила данные.
import 'dart:convert';
import 'dart:io';

import 'paths.dart';

class Store {
  Future<Object?> _read(File f) async {
    if (!await f.exists()) return null;
    try {
      return jsonDecode(await f.readAsString());
    } catch (_) {
      return null;
    }
  }

  Future<void> _write(String name, Object data) async {
    final f = ownFile(name);
    await f.parent.create(recursive: true);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    await tmp.rename(f.path);
  }

  Future<Map<String, dynamic>> readLayer() async {
    final own = await _read(ownFile('layer.json'));
    if (own is Map<String, dynamic>) return own;
    final old = await _read(dataFile('layer.json'));
    return old is Map<String, dynamic> ? old : <String, dynamic>{};
  }

  /// Раз в день перед первой записью — копия backups/layer-ГГГГ-ММ-ДД.json, хранится 14 (как backup.rs).
  Future<void> writeLayer(Map<String, dynamic> layer) async {
    try {
      final now = DateTime.now();
      final day = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final cur = ownFile('layer.json');
      final b = ownFile('backups${Platform.pathSeparator}layer-$day.json');
      if (await cur.exists() && !await b.exists()) {
        await b.parent.create(recursive: true);
        await cur.copy(b.path);
        final all = (await b.parent.list().toList()).whereType<File>().where((f) => f.path.contains('layer-')).toList()
          ..sort((x, y) => y.path.compareTo(x.path));
        for (final f in all.skip(14)) {
          await f.delete();
        }
      }
    } catch (_) {}
    await _write('layer.json', layer);
  }

  Future<List<Map<String, dynamic>>> readOutbox() async {
    final j = await _read(ownFile('outbox.json'));
    return j is List ? j.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : [];
  }

  Future<void> writeOutbox(List<Map<String, dynamic>> ops) => _write('outbox.json', ops);

  Future<Map<String, dynamic>?> readCache() async {
    final j = await _read(ownFile('cache.json'));
    return j is Map<String, dynamic> ? j : null;
  }

  Future<Map<String, dynamic>?> readShared() async => (await _read(ownFile('shared.json'))) as Map<String, dynamic>?;
  Future<void> writeShared(Map<String, dynamic> j) => _write('shared.json', j);

  Future<void> writeCache(Map<String, dynamic> c) => _write('cache.json', c);
}
