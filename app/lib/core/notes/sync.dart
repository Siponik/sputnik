// Синхронизация «Знаний» с Google Drive (docs/knowledge.md, шаг 5): что отправить, что скачать,
// где конфликт. Только расчёт — без сети и файлов.
//
// Сравниваем по md5 содержимого (Drive сам отдаёт md5Checksum). «База» — как файл выглядел при прошлой
// удачной сверке (md5 с обеих сторон совпадал). Правила:
// - изменился только один край — копируем в другой;
// - изменились оба и стали разными — конфликт: остаются обе копии, чужая — рядом с пометкой;
// - удалили на одном краю, а на другом не трогали — удаляем и там (в корзину, не насовсем);
// - удалили на одном, а на другом изменили — правка главнее: возвращаем файл.
import 'edit.dart';
import 'parse.dart';

/// Состояние файла на одном краю: md5 и время изменения (мс).
class SyncSide {
  final String md5;
  final int mtime;
  const SyncSide(this.md5, this.mtime);
}

enum SyncOp {
  /// Отправить с компьютера на Drive.
  upload,

  /// Скачать с Drive на компьютер.
  download,

  /// Удалить на Drive (в корзину Drive).
  trashRemote,

  /// Удалить на компьютере (в `.trash`).
  trashLocal,

  /// Конфликт: копию с Drive скачать как [SyncAction.conflictPath] (и отправить туда же), свою — отправить на место.
  conflict,

  /// Содержимое уже одинаковое — только записать в базу.
  record,

  /// Файла больше нет нигде — убрать из базы.
  forget,
}

class SyncAction {
  final SyncOp op;
  final String path;
  final String? conflictPath;
  const SyncAction(this.op, this.path, [this.conflictPath]);
  @override
  String toString() => conflictPath == null ? '${op.name} $path' : '${op.name} $path → $conflictPath';
  @override
  bool operator ==(Object other) => other is SyncAction && other.op == op && other.path == path && other.conflictPath == conflictPath;
  @override
  int get hashCode => Object.hash(op, path, conflictPath);
}

/// Имя для чужой копии при конфликте: «Щит (с другого компьютера).md», занято — «… 2.md».
String conflictName(String path, Iterable<String> taken) {
  final dot = path.lastIndexOf('.');
  final slash = path.lastIndexOf('/');
  final stem = dot > slash ? path.substring(0, dot) : path;
  final ext = dot > slash ? path.substring(dot) : '';
  return freeName('$stem (с другого компьютера)$ext', taken);
}

/// План сверки. [local] и [remote] — что есть сейчас, [base] — md5 при прошлой удачной сверке.
List<SyncAction> planSync(Map<String, SyncSide> local, Map<String, SyncSide> remote, Map<String, String> base) {
  final paths = {...local.keys, ...remote.keys, ...base.keys}.toList()..sort();
  final taken = {...local.keys, ...remote.keys};
  final out = <SyncAction>[];
  for (final p in paths) {
    final l = local[p], r = remote[p], b = base[p];
    if (l == null && r == null) {
      if (b != null) out.add(SyncAction(SyncOp.forget, p));
      continue;
    }
    if (l != null && r != null) {
      if (l.md5 == r.md5) {
        if (b != l.md5) out.add(SyncAction(SyncOp.record, p));
        continue;
      }
      final lc = b == null || l.md5 != b, rc = b == null || r.md5 != b;
      if (lc && !rc) {
        out.add(SyncAction(SyncOp.upload, p));
      } else if (rc && !lc) {
        out.add(SyncAction(SyncOp.download, p));
      } else {
        final c = conflictName(p, taken);
        taken.add(c);
        out.add(SyncAction(SyncOp.conflict, p, c));
      }
      continue;
    }
    if (l != null) {
      // На Drive нет: новый файл — отправить; был и удалён там — удалить и здесь, если здесь не меняли.
      if (b == null || l.md5 != b) {
        out.add(SyncAction(SyncOp.upload, p));
      } else {
        out.add(SyncAction(SyncOp.trashLocal, p));
      }
      continue;
    }
    if (b == null || r!.md5 != b) {
      out.add(SyncAction(SyncOp.download, p));
    } else {
      out.add(SyncAction(SyncOp.trashRemote, p));
    }
  }
  return out;
}

/// Итог сверки для строки «Знания» в «Состоянии».
class SyncReport {
  int sent = 0;
  int got = 0;
  int trashed = 0;
  final List<String> conflicts = [];
  final List<String> failed = [];
  bool offline = false;
  bool driveFull = false;

  bool get ok => failed.isEmpty && !offline && !driveFull;

  /// «Знания: всё отправлено / отправляю 3 / нет связи / Drive полон».
  String status({int pending = 0}) {
    if (driveFull) return 'Знания: Drive полон — новые заметки остаются только на компьютере';
    if (offline) return 'Знания: нет связи — отправлю, когда появится';
    if (pending > 0) return 'Знания: отправляю $pending';
    if (failed.isNotEmpty) return 'Знания: не отправилось ${failed.length} — повторю';
    if (conflicts.isNotEmpty) return 'Знания: ${conflicts.length} ${_plural(conflicts.length, 'конфликт', 'конфликта', 'конфликтов')} — обе копии сохранены';
    return 'Знания: всё отправлено';
  }
}

String _plural(int n, String one, String few, String many) {
  final m10 = n % 10, m100 = n % 100;
  if (m10 == 1 && m100 != 11) return one;
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few;
  return many;
}

/// Папки пути по порядку: `3D/Техники/Щит.md` → `[3D, 3D/Техники]`.
List<String> parentFolders(String path) {
  final dir = folderOf(path);
  if (dir.isEmpty) return const [];
  final parts = dir.split('/');
  return [for (var i = 1; i <= parts.length; i++) parts.sublist(0, i).join('/')];
}
