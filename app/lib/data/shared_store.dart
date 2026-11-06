// Общая сфера — обмен с Google Календарём (порт tracker/src/lib/shared.js; чистая логика — core/sharedcore.dart).
// У каждой общей сферы свой календарь «Спутник · сфера …» с меткой в описании; каждая запись — одно событие.
// Записи кэшируются в flutter/shared.json, изменения забираем токеном изменений Google.
import 'dart:async';
import 'dart:io';

import '../core/sharedcore.dart' as core;
import 'google_api.dart';
import 'store.dart';

typedef Json = Map<String, dynamic>;

const _cal = 'https://www.googleapis.com/calendar/v3';
String _e(String s) => Uri.encodeComponent(s);
bool _gone(Object e) => e is ApiError && (e.status == 404 || e.status == 410);
bool _offline(Object e) => e is SocketException || e is HttpException || e is TimeoutException;

class SharedStore {
  SharedStore(this.api, this.store);
  final GoogleApi api;
  final Store store;

  /// stores[cal] = { cal, title, role, sync, recs, base, pending, accepted, lost }.
  /// base[k] — запись, с которой последний раз сводили слой (для трёхстороннего сведения).
  Map<String, Json> stores = {};
  String me = '';

  Future<void> load() async {
    final j = await store.readShared();
    if (j?['stores'] is Map) {
      stores = {for (final e in (j!['stores'] as Map).entries) e.key as String: Json.from(e.value as Map)};
      me = (j['me'] ?? '') as String;
    }
  }

  void _persist() => unawaited(store.writeShared({'stores': stores, 'me': me}).catchError((_) {}));

  void reset() {
    stores = {};
    me = '';
    _persist();
  }

  Map _recs(String cal) => (stores[cal]?['recs'] ??= <String, dynamic>{}) as Map;
  Map _pending(Json s) => (s['pending'] ??= <String, dynamic>{}) as Map;

  bool _invite(Json s) => core.isInvite(s, me);
  List<String> get activeCalendars => [
    for (final s in stores.values)
      if (s['lost'] != true && !_invite(s)) s['cal'] as String,
  ];
  List<Json> get invites => [
    for (final s in stores.values)
      if (s['lost'] != true && _invite(s)) core.inviteInfo(s, me),
  ];
  bool isLost(String cal) => stores[cal]?['lost'] == true;
  bool isOwner(String cal) => stores[cal]?['role'] == 'owner';
  List<Json> people(String cal) => core.membersOf(stores[cal]?['recs'] as Map?);
  Map? sphereRec(String cal) => (stores[cal]?['recs'] as Map?)?[core.sphereKey] as Map?;

  String? calOfList(String? lk) {
    if (lk == null) return null;
    for (final s in stores.values) {
      if ((s['recs'] as Map?)?.containsKey(lk) == true) return s['cal'] as String;
    }
    return null;
  }

  String? calOfListId(String id) => calOfList(core.listKey(id));

  /// Списки общих сфер (как списки Google Tasks).
  List<Json> lists() => [
    for (final s in stores.values)
      if (!_invite(s))
        for (final l in core.listsOf((s['recs'] ?? const {}) as Map, s['cal']))
          if (s['lost'] == true) {...l, 'lost': true} else l,
  ];

  List<Json> tasks(String id) {
    final lk = core.listKey(id), cal = calOfList(lk);
    return cal == null ? [] : core.tasksOf(_recs(cal), lk!);
  }

  // ---------- обмен ----------

  /// Найти календари сфер и забрать изменения. Возвращает потерянные только что календари.
  Future<List<String>> pullAll() async {
    final r = await api.call('GET', '$_cal/users/me/calendarList?minAccessRole=reader&showHidden=true');
    final items = ((r['items'] ?? const []) as List).cast<Map>();
    for (final c in items) {
      if (c['primary'] == true) me = c['id'] as String;
    }
    final found = items.where((c) => core.isSphereCal(c)).toList();
    final gone = <String>[];
    void lose(Json s) {
      if (s['lost'] != true) {
        s['lost'] = true;
        gone.add(s['cal'] as String);
      }
    }

    for (final s in stores.values) {
      if (!found.any((c) => c['id'] == s['cal'])) lose(s);
    }
    for (final c in found) {
      final id = c['id'] as String;
      final s = stores[id] ??= {'cal': id, 'title': c['summary'], 'role': c['accessRole'], 'sync': '', 'recs': {}};
      s['role'] = c['accessRole'];
      s['title'] = c['summary'];
      try {
        await _flush(s);
        final got = await _pull(s);
        s['lost'] = false;
        if (!_invite(s)) await _markJoined(s, got);
      } on ApiError catch (e) {
        if (e.status == 403 || e.status == 404) {
          lose(s);
        } else {
          rethrow;
        }
      }
    }
    _persist();
    return gone;
  }

  /// Забирает изменения; возвращает изменившиеся записи (null — удалена).
  Future<List<Json?>> _pull(Json s) async {
    final out = <Json?>[];
    final full = ((s['sync'] ?? '') as String).isEmpty;
    final seen = <String>{};
    final recs = _recs(s['cal'] as String);
    var page = '';
    while (true) {
      final q = <String, String>{'maxResults': '2500', 'showDeleted': full ? 'false' : 'true'};
      if (!full) q['syncToken'] = s['sync'] as String;
      if (page.isNotEmpty) q['pageToken'] = page;
      Json r;
      try {
        r = await api.call('GET', '$_cal/calendars/${_e(s['cal'] as String)}/events?${Uri(queryParameters: q).query}');
      } on ApiError catch (e) {
        if (e.status == 410 && !full) {
          s['sync'] = '';
          return _pull(s);
        }
        rethrow;
      }
      for (final ev in ((r['items'] ?? const []) as List).cast<Map>()) {
        final rec = core.fromEvent(ev);
        final k = (rec?['k'] ?? ev['id']) as String;
        seen.add(k);
        final base = recs[k] as Map?;
        if (rec == null) {
          if (base != null && ev['status'] == 'cancelled') {
            recs.remove(k);
            out.add(null);
          }
          continue;
        }
        final m = core.mergeRec(base, rec)!;
        if (base != null && core.same(base, m)) continue;
        recs[k] = m;
        out.add(m);
      }
      page = (r['nextPageToken'] ?? '') as String;
      if (page.isEmpty) {
        s['sync'] = r['nextSyncToken'] ?? '';
        break;
      }
    }
    if (full) {
      for (final k in recs.keys.toList()) {
        if (!seen.contains(k) && _pending(s)[k] == null) {
          recs.remove(k);
          out.add(null);
        }
      }
    }
    return out;
  }

  Future<Json> _write(String cal, Map rec) async {
    var r = Json.from(rec);
    if (me.isNotEmpty && (r['f'] as Map?)?['by'] != me) r = core.edit(r, {'by': me});
    try {
      return await _put(cal, r);
    } catch (e) {
      if (!_offline(e) || stores[cal] == null) rethrow;
      _recs(cal)[r['k']] = r;
      _pending(stores[cal]!)[r['k']] = 'w';
      _persist();
      return r;
    }
  }

  Future<Json> _put(String cal, Map rec) async {
    final k = rec['k'] as String;
    final url = '$_cal/calendars/${_e(cal)}/events/${_e(k)}';
    Json? cur;
    try {
      cur = core.fromEvent(await api.call('GET', url));
    } catch (e) {
      if (!_gone(e)) rethrow;
    }
    final m = core.mergeRec(cur, rec)!;
    final body = core.toEvent(m);
    if (cur != null) {
      await api.call('PUT', url, body);
    } else {
      try {
        await api.call('POST', '$_cal/calendars/${_e(cal)}/events', body);
      } on ApiError catch (e) {
        if (e.status != 409) rethrow;
        await api.call('PUT', url, {...body, 'status': 'confirmed'});
      }
    }
    if (stores[cal] != null) {
      _recs(cal)[k] = m;
      _pending(stores[cal]!).remove(k);
      _persist();
    }
    return m;
  }

  Future<void> _drop(String cal, String k) async {
    try {
      await api.call('DELETE', '$_cal/calendars/${_e(cal)}/events/${_e(k)}');
    } catch (e) {
      if (_offline(e) && stores[cal] != null) {
        _pending(stores[cal]!)[k] = 'd';
      } else if (!_gone(e)) {
        rethrow;
      }
    }
    if (stores[cal] != null) {
      _recs(cal).remove(k);
      if (_pending(stores[cal]!)[k] != 'd') _pending(stores[cal]!).remove(k);
      _persist();
    }
  }

  Future<void> _flush(Json s) async {
    final p = _pending(s), cal = s['cal'] as String;
    for (final e in p.entries.toList()) {
      final k = e.key as String;
      if (e.value == 'd') {
        try {
          await api.call('DELETE', '$_cal/calendars/${_e(cal)}/events/${_e(k)}');
        } catch (err) {
          if (!_gone(err)) rethrow;
        }
        p.remove(k);
      } else if (_recs(cal)[k] != null) {
        await _put(cal, _recs(cal)[k] as Map);
      } else {
        p.remove(k);
      }
    }
  }

  Future<void> _markJoined(Json s, [List<Json?> got = const []]) async {
    final cal = s['cal'] as String;
    if (me.isEmpty || _recs(cal)[core.sphereKey] == null) return;
    final k = core.memberKey(me);
    final cur = _recs(cal)[k] as Map?;
    final cf = (cur?['f'] ?? const {}) as Map;
    final foreign = got.any(
      (r) =>
          r != null &&
          (r['f'] as Map)['by'] != null &&
          (r['f'] as Map)['by'] != me &&
          core.lastTime(r) > ((cf['seen'] ?? 0) as num),
    );
    final stale = core.seenDue(cf['seen'] as num?, foreign);
    if (cf['joined'] == true && cf['removed'] != true && !stale) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final next = cur != null
        ? core.edit(cur, {'joined': true, 'removed': false, 'seen': now})
        : core.make(k, {'email': me, 'order': core.nextOrder(_recs(cal)), 'joined': true, 'seen': now});
    await _write(cal, next);
  }

  Future<Json?> patchRec(String cal, String k, Map patch) async {
    final cur = _recs(cal)[k] as Map?;
    if (cur == null) return null;
    final next = core.edit(cur, patch);
    return identical(next, cur) ? Json.from(cur) : _write(cal, next);
  }

  /// Записать без ожидания сети (слой → календарь); ошибки не роняют обмен.
  void patchSoon(String cal, String k, Map patch) => unawaited(patchRec(cal, k, patch).catchError((_) => null));

  Future<void> applyProfile(Map? profile) async {
    if (me.isEmpty) return;
    for (final cal in activeCalendars) {
      final cur = _recs(cal)[core.memberKey(me)] as Map?;
      if (cur == null || (cur['f'] as Map)['removed'] == true) continue;
      final patch = core.profilePatch(cur, profile);
      if (patch.isNotEmpty) await _write(cal, core.edit(cur, patch));
    }
  }

  // ---------- задачи и списки — как Google Tasks ----------

  (String, String) _need(String id) {
    final lk = core.listKey(id), cal = calOfList(lk);
    if (lk == null || cal == null) throw ApiError(404, 'общий список не найден');
    return (lk, cal);
  }

  Future<Json> createTask(String id, Json body, {String? parent, Json layer = const {}}) async {
    final (lk, cal) = _need(id);
    final f = <String, dynamic>{
      'list': lk,
      'pos': core.newPos(),
      ...core.taskPatch({'title': '', 'notes': '', 'status': 'needsAction', ...body}),
      'parent': ?parent,
      for (final e in layer.entries) '\$${e.key}': e.value,
    };
    if (f['completed'] == null) f.remove('completed');
    return core.taskView(await _write(cal, core.make(core.newKey('t'), f)));
  }

  Future<Json> patchTask(String id, String taskId, Json body) async {
    final (_, cal) = _need(id);
    final cur = _recs(cal)[taskId] as Map?;
    if (cur == null) throw ApiError(404, 'задача не найдена');
    final next = core.edit(cur, core.taskPatch(body));
    return core.taskView(identical(next, cur) ? cur : await _write(cal, next));
  }

  Future<void> deleteTask(String id, String taskId) async {
    final (_, cal) = _need(id);
    for (final k in core.withChildren(_recs(cal), taskId).reversed) {
      await _drop(cal, k);
    }
  }

  Future<Json> createList(String cal, String title) async => core.listView(
    await _write(cal, core.make(core.newKey('l'), {'title': title, 'created': DateTime.now().millisecondsSinceEpoch})),
    cal,
  );

  Future<void> renameList(String id, String title) async {
    final (lk, cal) = _need(id);
    await patchRec(cal, lk, {'title': title});
  }

  Future<void> deleteList(String id) async {
    final (lk, cal) = _need(id);
    final recs = _recs(cal);
    for (final r in recs.values.whereType<Map>().toList()) {
      final f = r['f'] as Map;
      if (f['list'] == lk && f['parent'] != null) await _drop(cal, r['k'] as String);
    }
    for (final r in recs.values.whereType<Map>().toList()) {
      if ((r['f'] as Map)['list'] == lk) await _drop(cal, r['k'] as String);
    }
    await _drop(cal, lk);
  }

  // ---------- сфера ----------

  Future<String> createSphere(String name, String color, String icon) async {
    final c = await api.call('POST', '$_cal/calendars', {
      'summary': 'Спутник · сфера $name',
      'description':
          '${core.mark} v1 — служебный календарь общей сферы Спутника. Не удаляй и не меняй его события вручную.',
      'timeZone': 'Europe/Moscow',
    });
    final id = c['id'] as String;
    await api
        .call('PATCH', '$_cal/users/me/calendarList/${_e(id)}', {'selected': false, 'hidden': true})
        .catchError((_) => <String, dynamic>{});
    stores[id] = {'cal': id, 'title': c['summary'], 'role': 'owner', 'sync': '', 'recs': {}, 'accepted': true};
    await _write(
      id,
      core.make(core.sphereKey, {'name': name, 'color': color, 'icon': icon, 'owner': me.isEmpty ? null : me}),
    );
    if (me.isNotEmpty) await _write(id, core.make(core.memberKey(me), {'email': me, 'order': 0, 'joined': true}));
    return id;
  }

  Future<void> removeSphere(String cal) async {
    if (isLost(cal)) return forget(cal);
    if (isOwner(cal)) {
      await api.call('DELETE', '$_cal/calendars/${_e(cal)}');
    } else {
      final k = core.memberKey(me);
      if (me.isNotEmpty && _recs(cal)[k] != null) await patchRec(cal, k, {'removed': true}).catchError((_) => null);
      await api.call('DELETE', '$_cal/users/me/calendarList/${_e(cal)}');
    }
    stores.remove(cal);
    _persist();
  }

  Future<String> join(String code) async {
    final id = code.trim();
    final c = await api.call('POST', '$_cal/users/me/calendarList', {'id': id, 'selected': false, 'hidden': true});
    if (!core.isSphereCal(c)) {
      Json? ev;
      try {
        ev = await api.call('GET', '$_cal/calendars/${_e(id)}/events/${core.sphereKey}');
      } catch (_) {}
      if (core.fromEvent(ev) == null) throw ApiError(400, 'Это не общая сфера Спутника');
    }
    stores[id] = {
      ...(stores[id] ??
          {'cal': id, 'title': c['summary'] ?? '', 'role': c['accessRole'] ?? 'writer', 'sync': '', 'recs': {}}),
      'accepted': true,
      'lost': false,
    };
    _persist();
    return id;
  }

  Future<void> accept(String cal) async {
    final s = stores[cal];
    if (s == null) return;
    s['accepted'] = true;
    _persist();
    await api
        .call('PATCH', '$_cal/users/me/calendarList/${_e(cal)}', {'selected': false, 'hidden': true})
        .catchError((_) => <String, dynamic>{});
    await _markJoined(s);
    _persist();
  }

  Future<void> decline(String cal) => removeSphere(cal);

  Future<void> forget(String cal) async {
    try {
      await api.call('DELETE', '$_cal/users/me/calendarList/${_e(cal)}');
    } catch (_) {}
    stores.remove(cal);
    _persist();
  }

  // ---------- участники (только владелец) ----------

  Future<void> invite(String cal, String email) async {
    final e = email.trim().toLowerCase();
    await api.call('POST', '$_cal/calendars/${_e(cal)}/acl?sendNotifications=true', {
      'role': 'writer',
      'scope': {'type': 'user', 'value': e},
    });
    final recs = _recs(cal), k = core.memberKey(e);
    final cur = recs[k] as Map?;
    final next = cur != null
        ? core.edit(cur, {'removed': false})
        : core.make(k, {'email': e, 'order': core.nextOrder(recs), 'joined': false});
    if (!identical(next, cur)) await _write(cal, next);
  }

  Future<void> removeMember(String cal, String email) async {
    final e = email.trim().toLowerCase();
    try {
      await api.call('DELETE', '$_cal/calendars/${_e(cal)}/acl/${_e('user:$e')}');
    } catch (err) {
      if (!_gone(err)) rethrow;
    }
    final k = core.memberKey(e);
    if (_recs(cal)[k] != null) await patchRec(cal, k, {'removed': true});
  }

  String inviteText(String cal, String sphereName) {
    final link = 'https://calendar.google.com/calendar/r?cid=${Uri.encodeComponent(cal)}';
    return 'Зову тебя в общую сферу «$sphereName» в Спутнике.\n1) Открой ссылку и добавь календарь: $link\n'
        '2) Или в Спутнике: Доска → ＋ сфера → «Войти в общую сферу…» и код: $cal';
  }
}
