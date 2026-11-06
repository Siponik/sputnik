// Синхронизация папки заметок с Drive (docs/knowledge.md, шаг 5): выполняет план из core/notes/sync.dart.
// Удачно сверенные файлы записываются в «базу» (md5, размер, время) — она лежит в папке настроек приложения.
// Не получилось (нет связи, ошибка) — файл остаётся как был и сверится в следующий раз: это и есть очередь.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../core/notes/sync.dart';
import 'vault.dart';

/// Файл на другом краю.
class RemoteFile {
  final String id;
  final String path;
  final String md5;
  final int mtime;
  const RemoteFile(this.id, this.path, this.md5, this.mtime);
}

/// На Drive кончилось место.
class DriveFull implements Exception {
  @override
  String toString() => 'На Google Drive нет места';
}

/// Где лежит общая копия. Настоящая — DriveStore, в тестах — память.
abstract class RemoteStore {
  Future<Map<String, RemoteFile>> list();
  Future<List<int>> download(RemoteFile f);

  /// Новый файл или новое содержимое старого ([existing]).
  Future<RemoteFile> upload(String path, List<int> bytes, {RemoteFile? existing});
  Future<void> trash(RemoteFile f);
}

/// Запись базы: каким файл был при прошлой сверке.
class BaseEntry {
  final String md5;
  final int size;
  final int mtime;
  const BaseEntry(this.md5, this.size, this.mtime);
  Map<String, dynamic> toJson() => {'md5': md5, 'size': size, 'mtime': mtime};
  factory BaseEntry.fromJson(Map<String, dynamic> j) =>
      BaseEntry(j['md5'] as String, (j['size'] as num).toInt(), (j['mtime'] as num).toInt());
}

String md5Of(List<int> b) => md5.convert(b).toString();

String baseToJson(Map<String, BaseEntry> base) => jsonEncode({for (final e in base.entries) e.key: e.value.toJson()});

Map<String, BaseEntry> baseFromJson(String s) {
  final j = jsonDecode(s) as Map<String, dynamic>;
  return {for (final e in j.entries) e.key: BaseEntry.fromJson(e.value as Map<String, dynamic>)};
}

bool _offline(Object e) => e is SocketException || e is HttpException || e is HandshakeException || e is TlsException;

class NotesSync {
  final NoteVault vault;
  final RemoteStore store;
  NotesSync(this.vault, this.store);

  /// Одна сверка. [base] меняется на месте; вернуть — что произошло.
  Future<SyncReport> run(Map<String, BaseEntry> base) async {
    final rep = SyncReport();
    // md5 своих файлов: если размер и время те же, что в базе, — не читаем файл заново.
    final files = await vault.listFiles();
    final local = <String, SyncSide>{};
    for (final e in files.entries) {
      final b = base[e.key];
      final (size, mtime) = e.value;
      String sum;
      if (b != null && b.size == size && b.mtime == mtime) {
        sum = b.md5;
      } else {
        try {
          sum = md5Of(await vault.readBytes(e.key));
        } on FileSystemException {
          continue;
        }
      }
      local[e.key] = SyncSide(sum, mtime);
    }

    Map<String, RemoteFile> remote;
    try {
      remote = await store.list();
    } catch (e) {
      if (_offline(e)) {
        rep.offline = true;
        return rep;
      }
      rethrow;
    }

    final plan = planSync(
      local,
      {for (final e in remote.entries) e.key: SyncSide(e.value.md5, e.value.mtime)},
      {for (final e in base.entries) e.key: e.value.md5},
    );

    Future<void> remember(String p) async {
      final f = vault.file(p);
      if (!await f.exists()) return;
      final st = await f.stat();
      final bytes = await f.readAsBytes();
      base[p] = BaseEntry(md5Of(bytes), st.size, st.modified.millisecondsSinceEpoch);
    }

    for (final a in plan) {
      if (rep.offline) break;
      try {
        switch (a.op) {
          case SyncOp.record:
            await remember(a.path);
          case SyncOp.forget:
            base.remove(a.path);
          case SyncOp.upload:
            if (rep.driveFull) continue;
            await store.upload(a.path, await vault.readBytes(a.path), existing: remote[a.path]);
            await remember(a.path);
            rep.sent++;
          case SyncOp.download:
            final bytes = await store.download(remote[a.path]!);
            // Пока шла сверка, файл поправили здесь — не затираем, сверим в следующий раз.
            final was = local[a.path];
            if (was != null && await vault.file(a.path).exists() && md5Of(await vault.readBytes(a.path)) != was.md5) continue;
            await vault.writeBytes(a.path, bytes);
            await remember(a.path);
            rep.got++;
          case SyncOp.trashRemote:
            await store.trash(remote[a.path]!);
            base.remove(a.path);
            rep.trashed++;
          case SyncOp.trashLocal:
            await vault.trash(a.path);
            base.remove(a.path);
            rep.trashed++;
          case SyncOp.conflict:
            final theirs = await store.download(remote[a.path]!);
            final c = a.conflictPath!;
            await vault.writeBytes(c, theirs);
            rep.conflicts.add(a.path);
            if (!rep.driveFull) {
              await store.upload(c, theirs);
              await remember(c);
              await store.upload(a.path, await vault.readBytes(a.path), existing: remote[a.path]);
              await remember(a.path);
              rep.sent += 2;
            }
            rep.got++;
        }
      } on DriveFull {
        rep.driveFull = true;
      } catch (e) {
        if (_offline(e)) {
          rep.offline = true;
        } else {
          rep.failed.add(a.path);
        }
      }
    }
    return rep;
  }
}
