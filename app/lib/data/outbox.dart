// Очередь исходящих (docs/flutter-architecture.md, п. 5): действие сразу меняет память, а в Google уходит отсюда.
// Операции: create { list, tmp, body } · patch { list, id, body } · delete { list, id }.
// Нет связи — операция остаётся и повторяется позже. Google отказал (4xx) — операция снимается, экран откатывает.
import 'dart:async';
import 'dart:io';

import 'google_api.dart';
import 'shared_store.dart';
import 'google_auth.dart';
import 'store.dart';

typedef Op = Map<String, dynamic>;

class Outbox {
  Outbox(this.api, this.store);
  final GoogleApi api;
  final Store store;
  SharedStore? shared; // списки sh:… — в календарь общей сферы
  List<Op> ops = [];
  bool _busy = false;
  int _fails = 0;
  DateTime _next = DateTime.fromMillisecondsSinceEpoch(0);

  /// Задача создана в Google: временный id → настоящий.
  void Function(String tmp, Map<String, dynamic> real)? onCreated;

  /// Задача обновлена в Google (ответ с новыми полями).
  void Function(String listId, Map<String, dynamic> task)? onSaved;

  /// Google отказал — операцию сняли.
  void Function(Op op, Object error)? onRejected;
  void Function()? onChange;

  Future<void> load() async => ops = await store.readOutbox();
  Future<void> _save() => store.writeOutbox(ops);

  bool pendingFor(String id) => ops.any((o) => o['id'] == id || o['tmp'] == id);

  Future<void> add(Op op) async {
    // Две правки одной задачи подряд — склеиваем (меньше запросов).
    if (op['op'] == 'patch' && ops.isNotEmpty) {
      final last = ops.last;
      if (last['op'] == 'patch' && last['id'] == op['id'] && last['list'] == op['list']) {
        last['body'] = {...(last['body'] as Map), ...(op['body'] as Map)};
        await _save();
        unawaited(flush());
        return;
      }
      if (last['op'] == 'create' && last['tmp'] == op['id']) {
        last['body'] = {...(last['body'] as Map), ...(op['body'] as Map)};
        await _save();
        unawaited(flush());
        return;
      }
    }
    ops.add(op);
    await _save();
    unawaited(flush());
  }

  Future<void> flush({bool force = false}) async {
    if (_busy || ops.isEmpty) return;
    if (!force && DateTime.now().isBefore(_next)) return;
    _busy = true;
    try {
      while (ops.isNotEmpty) {
        final op = ops.first;
        try {
          await _send(op);
          ops.removeAt(0);
          _fails = 0;
        } on ApiError catch (e) {
          if (e.status >= 500 || e.status == 429) {
            _backoff();
            break;
          }
          ops.removeAt(0);
          onRejected?.call(op, e);
        } on AuthError {
          _backoff();
          break;
        } on SocketException {
          _backoff();
          break;
        } on HttpException {
          _backoff();
          break;
        }
        await _save();
        onChange?.call();
      }
    } finally {
      _busy = false;
      await _save();
      onChange?.call();
    }
  }

  void _backoff() {
    _fails++;
    final s = [5, 15, 30, 60, 120, 300][(_fails - 1).clamp(0, 5)];
    _next = DateTime.now().add(Duration(seconds: s));
  }

  Future<void> _send(Op op) async {
    final list = op['list'] as String;
    final sh = list.startsWith('sh:') ? shared : null;
    switch (op['op']) {
      case 'create':
        final parent = op['parent'] as String?;
        if (parent != null && parent.startsWith('tmp-')) throw const SocketException('родитель ещё не создан');
        final body = Map<String, dynamic>.from(op['body'] as Map);
        final r = sh != null
            ? await sh.createTask(list, body, parent: parent)
            : await api.createTask(list, body, parent: parent);
        final tmp = op['tmp'] as String;
        final real = r['id'] as String;
        for (final o in ops) {
          if (o['id'] == tmp) o['id'] = real;
          if (o['parent'] == tmp) o['parent'] = real;
        }
        onCreated?.call(tmp, r);
      case 'patch':
        final body = Map<String, dynamic>.from(op['body'] as Map);
        final r = sh != null
            ? await sh.patchTask(list, op['id'] as String, body)
            : await api.patchTask(list, op['id'] as String, body);
        onSaved?.call(list, r);
      case 'delete':
        try {
          await (sh != null ? sh.deleteTask(list, op['id'] as String) : api.deleteTask(list, op['id'] as String));
        } on ApiError catch (e) {
          if (e.status != 404) rethrow;
        }
    }
  }
}
