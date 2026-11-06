// Порт tracker/src/lib/sharedcore.js — общая сфера, чистая логика без запросов.
// Сфера, которую видят и меняют несколько человек, живёт в своём Google Календаре. Каждая запись (сфера, список,
// задача, участник) — одно служебное событие, в описании JSON: { v, k, f: { поле: значение }, ft: { поле: время, мс } }.
// Сливаем по полям: у каждого поля побеждает более свежая правка.
//
// В JS у записи может быть поле со значением undefined (его как будто нет) и со значением null (очищено).
// В Dart это различается наличием ключа: ключа нет — «undefined», ключ есть со значением null — null.
// Поэтому в make/edit/sharedOf передавайте только те поля, которые есть.
import 'dart:convert';

import 'search.dart' show ruCompare;

typedef Json = Map<String, dynamic>;

const mark = 'sputnik-sphere';
const summary = 'Спутник · служебная запись';
const prefix = 'sh:';
const notesMax = 6000;

const _ownTask = {'t', 'gone', 'timer', 'spent', 'remind', 'inbox', 'pulled', 'cheer', 'given'};
const _ownList = {'t', 'gone', 'hidden', 'sphere', 'group', 'sort', 'cvGroup'};
const sphereFields = ['name', 'color', 'icon'];

bool _t(Object? v) => v != null && v != false && v != 0 && v != '';

/// «Нет поля» (undefined в JS).
const Object _u = _Undef();

class _Undef {
  const _Undef();
}

Object? _get(Object? m, Object? k) => m is Map && m.containsKey(k) ? m[k] : _u;
Map _f(Object? rec) => rec is Map && rec['f'] is Map ? rec['f'] as Map : const {};
Map _ft(Object? rec) => rec is Map && rec['ft'] is Map ? rec['ft'] as Map : const {};

/// Одинаковы ли значения (порядок ключей не важен; нет поля = null).
bool same(Object? a, Object? b) {
  if (identical(a, _u)) a = null;
  if (identical(b, _u)) b = null;
  if (a == b) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || !same(a[k], b[k])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!same(a[i], b[i])) return false;
    }
    return true;
  }
  return false;
}

// ---------- ключи ----------

const _b32 = '0123456789abcdefghijklmnopqrstuv';
String newKey(String kind, [double Function()? rnd]) {
  final r = rnd ?? _rand;
  final s = StringBuffer(kind);
  for (var i = 0; i < 16; i++) {
    s.write(_b32[(r() * 32).floor()]);
  }
  return s.toString();
}

double _rand() => _rng.nextDouble();
final _rng = _Rng();

class _Rng {
  int _s = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
  double nextDouble() {
    _s = (_s * 1103515245 + 12345) & 0x7fffffff;
    return _s / 0x80000000;
  }
}

const sphereKey = 's0000000000000000';
String? kindOf(Object? k) {
  if (k == sphereKey) return 'sphere';
  if (k is! String || k.isEmpty) return null;
  return const {'l': 'list', 't': 'task', 'm': 'member'}[k[0]];
}

/// Ключ записи участника — из почты (FNV, как в JS).
String memberKey(Object? email) {
  final e = (email ?? '').toString().trim().toLowerCase();
  var h1 = 0x811c9dc5, h2 = 0x01000193;
  for (var i = 0; i < e.length; i++) {
    final c = e.codeUnitAt(i);
    h1 = ((h1 ^ c) * 16777619) & 0xFFFFFFFF;
    h2 = ((h2 + c) * 2246822519) & 0xFFFFFFFF;
  }
  final s = StringBuffer('m');
  for (final h in [h1, h2]) {
    for (var i = 0; i < 8; i++) {
      s.write(_b32[(h >> (i * 4)) & 31]);
    }
  }
  return s.toString();
}

bool isSharedId(Object? id) => id is String && id.startsWith(prefix);
String listId(String lk) => prefix + lk;
String? listKey(Object? id) => isSharedId(id) ? (id as String).substring(prefix.length) : null;
String sphereId(String cal) => prefix + cal;
String? calOfSphere(Object? id) => isSharedId(id) ? (id as String).substring(prefix.length) : null;

// ---------- записи ----------

int _now() => DateTime.now().millisecondsSinceEpoch;

/// Новая запись: все поля с одним временем.
Json make(String k, Map fields, [int? now]) {
  now ??= _now();
  final f = <String, dynamic>{}, ft = <String, dynamic>{};
  for (final e in fields.entries) {
    f[e.key] = e.value;
    ft[e.key] = now;
  }
  return {'v': 1, 'k': k, 'f': f, 'ft': ft};
}

/// Правка записи: меняются только поля, значение которых действительно другое. null — поле очищено.
Json edit(Map rec, Map patch, [int? now]) {
  now ??= _now();
  final f = <String, dynamic>{..._f(rec)}, ft = <String, dynamic>{..._ft(rec)};
  var changed = false;
  for (final e in patch.entries) {
    if (same(_get(f, e.key), e.value)) continue;
    f[e.key] = e.value;
    final prev = ((ft[e.key] ?? 0) as num) + 1;
    ft[e.key] = now > prev ? now : prev;
    changed = true;
  }
  return changed ? {...rec.cast<String, dynamic>(), 'f': f, 'ft': ft} : rec.cast<String, dynamic>();
}

/// Слияние двух версий записи по полям.
Json? mergeRec(Map? a, Map? b) {
  if (a == null) return b?.cast<String, dynamic>();
  if (b == null) return a.cast<String, dynamic>();
  final af = _f(a), bf = _f(b), aft = _ft(a), bft = _ft(b);
  final f = <String, dynamic>{}, ft = <String, dynamic>{};
  for (final n in {...af.keys, ...bf.keys}) {
    final ta = (aft[n] ?? 0) as num, tb = (bft[n] ?? 0) as num;
    final pickB = tb != ta ? tb > ta : jsonEncode(bf[n]).compareTo(jsonEncode(af[n])) > 0;
    final src = pickB ? bf : af;
    if (src.containsKey(n)) f[n] = src[n];
    ft[n] = pickB ? tb : ta;
  }
  return {'v': 1, 'k': a['k'] ?? b['k'], 'f': f, 'ft': ft};
}

num lastTime(Map? rec) {
  num m = 0;
  for (final v in _ft(rec).values) {
    if (v is num && v > m) m = v;
  }
  return m;
}

// ---------- событие календаря ----------

Json toEvent(Map rec) {
  final f = <String, dynamic>{..._f(rec)};
  final n = f['notes'];
  if (n is String && n.length > notesMax) f['notes'] = n.substring(0, notesMax);
  return {
    'id': rec['k'],
    'summary': summary,
    'description': jsonEncode({'v': 1, 'k': rec['k'], 'f': f, 'ft': rec['ft']}),
    'start': {'date': '2000-01-01'},
    'end': {'date': '2000-01-02'},
    'transparency': 'transparent',
    'reminders': {'useDefault': false, 'overrides': []},
    'extendedProperties': {
      'shared': {'sputnik': 'rec'},
    },
  };
}

/// Запись из события или null (чужое событие, испорченное описание, удалённое).
Json? fromEvent(Map? ev) {
  if (ev == null || ev['status'] == 'cancelled') return null;
  if ((((ev['extendedProperties'] as Map?)?['shared']) as Map?)?['sputnik'] != 'rec') return null;
  try {
    final j = jsonDecode((ev['description'] ?? '') as String);
    if (j is! Map || j['f'] is! Map || j['k'] is! String || kindOf(j['k']) == null) return null;
    return {'v': 1, 'k': j['k'], 'f': j['f'], 'ft': j['ft'] is Map ? j['ft'] : <String, dynamic>{}};
  } catch (_) {
    return null;
  }
}

// ---------- как запись выглядит для трекера ----------

String _pad20(num n) {
  final v = n > 0 ? n.floor() : 0;
  return v.toString().padLeft(20, '0');
}

String newPos([int? now]) => _pad20(1e15 - (now ?? _now()));

String _iso(num ms) => DateTime.fromMillisecondsSinceEpoch(ms.toInt(), isUtc: true).toIso8601String();

Json taskView(Map rec) {
  final f = _f(rec);
  final done = f['status'] == 'completed';
  return {
    'id': rec['k'],
    'title': f['title'] ?? '',
    'notes': f['notes'] ?? '',
    if (_t(f['due'])) 'due': f['due'],
    'status': done ? 'completed' : 'needsAction',
    if (done && _t(f['completed'])) 'completed': f['completed'],
    if (_t(f['parent'])) 'parent': f['parent'],
    'position': f['pos'] ?? '',
    'updated': _iso(lastTime(rec)),
    'shared': true,
  };
}

Json listView(Map rec, Object? cal) => {
  'id': listId(rec['k']),
  'title': _f(rec)['title'] ?? 'Без названия',
  'updated': _iso(lastTime(rec)),
  'shared': cal,
};

/// Правка задачи в духе Google Tasks → поля записи.
Json taskPatch(Map body, [int? now]) {
  final p = <String, dynamic>{};
  if (body.containsKey('title')) p['title'] = body['title'] ?? '';
  if (body.containsKey('notes')) p['notes'] = body['notes'] ?? '';
  if (body.containsKey('due')) p['due'] = body['due'];
  if (body.containsKey('status')) {
    p['status'] = body['status'] == 'completed' ? 'completed' : 'needsAction';
    p['completed'] = p['status'] == 'completed' ? (body['completed'] ?? _iso(now ?? _now())) : null;
  }
  return p;
}

// ---------- поля слоя ----------

Json layerOf(Map? rec) => {
  for (final e in _f(rec).entries)
    if ((e.key as String).startsWith(r'$')) (e.key as String).substring(1): e.value,
};

Json sharedOf(Object? layRec, [String kind = 'task']) {
  final own = kind == 'list' ? _ownList : _ownTask;
  if (layRec is! Map || _t(layRec['gone'])) return {};
  return {
    for (final e in layRec.entries)
      if (!own.contains(e.key)) '\$${e.key}': e.value,
  };
}

/// Трёхстороннее сведение полей слоя. toLayer — что вписать в слой, toRec — что дописать в календарь.
Json reconcile(Map? l, Map? base, Map? rec, [String kind = 'task']) {
  final loc = sharedOf(l, kind);
  final b = _f(base), r = _f(rec);
  final toLayer = <String, dynamic>{}, toRec = <String, dynamic>{};
  final names = {...loc.keys, ...r.keys.cast<String>().where((n) => n.startsWith(r'$'))};
  final lt = (l?['t'] ?? 0) as num;
  for (final n in names) {
    final lv = _get(loc, n), bv = _get(b, n), rv = _get(r, n);
    final localChanged = !identical(lv, _u) && !same(lv, bv);
    final remoteChanged = !same(rv, bv);
    if (same(lv, rv)) continue;
    final rvv = identical(rv, _u) ? null : rv;
    if (remoteChanged && (!localChanged || ((_ft(rec)[n] ?? 0) as num) >= lt)) {
      toLayer[n.substring(1)] = rvv;
    } else if (localChanged) {
      toRec[n] = lv;
    } else if (identical(lv, _u)) {
      toLayer[n.substring(1)] = rvv;
    }
  }
  return {'toLayer': toLayer, 'toRec': toRec};
}

/// Поля сферы: то же сведение, но поля без '$'.
Json reconcileSphere(Map? s, Map? base, Map? rec) {
  final toLayer = <String, dynamic>{}, toRec = <String, dynamic>{};
  final st = (s?['t'] ?? 0) as num;
  for (final n in sphereFields) {
    final lv = _get(s, n), bv = _get(_f(base), n), rv = _get(_f(rec), n);
    if (same(lv, rv)) continue;
    final localChanged = !identical(lv, _u) && !same(lv, bv);
    final remoteChanged = !same(rv, bv);
    if (remoteChanged && (!localChanged || ((_ft(rec)[n] ?? 0) as num) >= st)) {
      if (!identical(rv, _u)) toLayer[n] = rv;
    } else if (localChanged) {
      toRec[n] = lv;
    } else if (identical(lv, _u) && !identical(rv, _u)) {
      toLayer[n] = rv;
    }
  }
  return {'toLayer': toLayer, 'toRec': toRec};
}

// ---------- хранилище одной сферы ----------

Iterable<Map> _recs(Map? recs) => (recs ?? const {}).values.whereType<Map>();

List<Json> tasksOf(Map recs, String lk) => [
  for (final r in _recs(recs))
    if (kindOf(r['k']) == 'task' && _f(r)['list'] == lk) taskView(r),
];

List<Json> listsOf(Map recs, Object? cal) {
  final xs = [
    for (final r in _recs(recs))
      if (kindOf(r['k']) == 'list') r,
  ];
  final idx = {for (final (i, r) in xs.indexed) r: i};
  xs.sort((a, b) {
    final c = ((_f(a)['created'] ?? 0) as num).compareTo((_f(b)['created'] ?? 0) as num);
    if (c != 0) return c;
    final d = (a['k'] as String).compareTo(b['k']);
    return d != 0 ? d : idx[a]!.compareTo(idx[b]!);
  });
  return [for (final r in xs) listView(r, cal)];
}

List<String> withChildren(Map recs, String k) => [
  k,
  for (final r in _recs(recs))
    if (kindOf(r['k']) == 'task' && _f(r)['parent'] == k) r['k'] as String,
];

bool isSphereCal(Map? c) => c?['description'] is String && (c!['description'] as String).contains(mark);

// ---------- участники и исполнители ----------

const memberColors = [
  'var(--clay)',
  'var(--type-study)',
  'var(--type-work)',
  'var(--type-personal)',
  'var(--gold)',
  'var(--signal-done)',
];

/// Участники сферы по порядку; убранные — не показываем.
List<Json> membersOf(Map? recs) {
  final owner = _f(recs?[sphereKey])['owner'];
  final xs = <Json>[];
  for (final r in _recs(recs)) {
    final f = _f(r);
    if (kindOf(r['k']) != 'member' || !_t(f['email']) || _t(f['removed'])) continue;
    xs.add({
      'email': f['email'],
      'name': _t(f['name']) ? f['name'] : nameOf(f['email']),
      'order': f['order'] ?? 0,
      'owner': f['email'] == owner,
      'joined': _t(f['joined']) || f['email'] == owner,
      'seen': f['seen'],
      'invited': _ft(r)['email'],
      '_hue': _okHue(f['color']),
      'pic': okPic(f['pic']),
    });
  }
  final idx = {for (final (i, m) in xs.indexed) m: i};
  xs.sort((a, b) {
    final o = (b['owner'] ? 1 : 0) - (a['owner'] ? 1 : 0);
    if (o != 0) return o;
    final c = (a['order'] as num).compareTo(b['order'] as num);
    if (c != 0) return c;
    final d = ruCompare(a['email'], b['email']);
    return d != 0 ? d : idx[a]!.compareTo(idx[b]!);
  });
  return [
    for (final (i, m) in xs.indexed)
      () {
        final hue = m.remove('_hue') as int?;
        final nm = ((_t(m['name']) ? m['name'] : m['email']) as String).trim();
        return {
          ...m,
          'color': memberColors[hue ?? i % memberColors.length],
          'letter': nm.isEmpty ? '?' : nm[0].toUpperCase(),
        };
      }(),
  ];
}

// ---------- «Как меня видят» ----------

const nameMax = 24;
const picMax = 6000;
int? _okHue(Object? c) => c is num && c == c.roundToDouble() && c >= 0 && c < memberColors.length ? c.toInt() : null;

/// Фото участника — только маленькая картинка data:image (никаких ссылок наружу).
String? okPic(Object? p) =>
    p is String && p.length <= picMax && RegExp(r'^data:image\/(png|jpeg|webp);base64,[A-Za-z0-9+/]+=*$').hasMatch(p)
    ? p
    : null;

Json profileFields(Map? profile) {
  var name = (profile?['name'] ?? '').toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (name.length > nameMax) name = name.substring(0, nameMax);
  return {'name': name.isEmpty ? null : name, 'color': _okHue(profile?['color']), 'pic': okPic(profile?['pic'])};
}

/// Что дописать в мою запись участника, чтобы она совпала с профилем; {} — ничего.
Json profilePatch(Map? rec, Map? profile) {
  final out = <String, dynamic>{};
  for (final e in profileFields(profile).entries) {
    if (_f(rec)[e.key] != e.value) out[e.key] = e.value;
  }
  return out;
}

/// Имя из почты, пока человек не назвался: anya.k@gmail.com → «Anya».
String nameOf(Object? email) {
  final n = (email ?? '').toString().split('@')[0].split(RegExp(r'[._+-]'))[0];
  return n.isNotEmpty ? n[0].toUpperCase() + n.substring(1) : 'Участник';
}

num nextOrder(Map? recs) {
  num m = 0;
  for (final r in _recs(recs)) {
    if (kindOf(r['k']) != 'member') continue;
    final o = (_f(r)['order'] ?? 0) as num;
    if (o > m) m = o;
  }
  return 1 + m;
}

String? whoOf(Map? l) => l != null && l['who'] is String && (l['who'] as String).isNotEmpty ? l['who'] : null;

bool assignedMatch(Map? l, String? me, String mode) {
  final w = whoOf(l);
  if (mode == 'mine') return _t(me) && w == me;
  if (mode == 'none') return w == null;
  if (mode == 'mineOrNone') return w == null || (_t(me) && w == me);
  return true;
}

/// Передача на Конвейере при «Этап →».
Json handoff(Map? l, String toCol) {
  final next = (l?['stageWho'] as Map?)?[toCol];
  return _t(next) && next != whoOf(l) ? {'who': next} : {};
}

Json setStageWho(Map? l, String col, String? who) {
  final cur = <String, dynamic>{...?(l?['stageWho'] as Map?)?.cast<String, dynamic>()};
  if (_t(who)) {
    cur[col] = who;
  } else {
    cur.remove(col);
  }
  return {'stageWho': cur};
}

bool isTogether(List<Map> people) => people.any((m) => !_t(m['owner']));

const _monShort = ['янв.', 'февр.', 'мар.', 'апр.', 'мая', 'июн.', 'июл.', 'авг.', 'сент.', 'окт.', 'нояб.', 'дек.'];

/// «сегодня в 12:40» / «вчера в 9:05» / «20 окт.».
String seenText(num? ms, [int? now]) {
  if (!_t(ms)) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(ms!.toInt()), n = DateTime.fromMillisecondsSinceEpoch(now ?? _now());
  final hm = '${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  int day(DateTime x) => DateTime(x.year, x.month, x.day).millisecondsSinceEpoch;
  final diff = ((day(n) - day(d)) / 864e5 + 0.5).floor();
  if (diff == 0) return 'сегодня в $hm';
  if (diff == 1) return 'вчера в $hm';
  return '${d.day} ${_monShort[d.month - 1]}';
}

/// Разбор поля приглашения: почты через запятую, пробел или точку с запятой; неверные — отдельно.
Json parseEmails(Object? text) {
  final ok = <String>{}, bad = <String>[];
  for (final raw in (text ?? '').toString().split(RegExp(r'[\s,;]+'))) {
    final e = raw.trim().toLowerCase();
    if (e.isEmpty) continue;
    if (RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(e)) {
      ok.add(e);
    } else {
      bad.add(e);
    }
  }
  return {'ok': ok.toList(), 'bad': bad};
}

String _fold(Object? s) => (s ?? '').toString().toLowerCase().replaceAll('ё', 'е').trim();

/// Участник по почте (или «бывший» — убранный: кружок без цвета, имя из почты).
Map? memberOf(List<Map> people, Object? email) {
  if (!_t(email)) return null;
  for (final p in people) {
    if (p['email'] == email) return p;
  }
  final n = nameOf(email);
  return {'email': email, 'name': n, 'letter': n[0], 'color': 'var(--ink-faint)', 'joined': true, 'gone': true};
}

/// Строки поповера «Кому отдать…»: «Я» первым, остальные, «Без исполнителя» последним.
List<Json> whoOptions(List<Map> people, String? me, [String q = '', Map counts = const {}]) {
  final f = _fold(q);
  bool hit(Map p) =>
      f.isEmpty ||
      _fold(p['name']).contains(f) ||
      _fold(p['email']).contains(f) ||
      (p['email'] == me && 'я'.startsWith(f));
  final ppl = [...people.where((p) => p['email'] == me), ...people.where((p) => p['email'] != me)].where(hit).toList();
  final rows = <Json>[
    for (final (i, p) in ppl.indexed)
      {
        'email': p['email'],
        'm': p,
        'label': p['email'] == me ? 'Я' : p['name'],
        'note': _t(p['joined']) ? '' : 'ещё не принял',
        'n': counts[p['email']] ?? 0,
        'key': i < 9 ? '${i + 1}' : '',
      },
  ];
  if (f.isEmpty || 'без исполнителя'.contains(f) || 'никто'.contains(f)) {
    rows.add({'email': null, 'm': null, 'label': 'Без исполнителя', 'note': '', 'n': counts[''] ?? 0, 'key': '0'});
  }
  return rows;
}

/// Такой строки нет (в JS — undefined).
const noWho = _Undef();

/// Цифра → почта исполнителя; null — без исполнителя, [noWho] — такой строки нет.
Object? whoByDigit(List<Map> people, String? me, String d) {
  if (d == '0') return null;
  for (final r in whoOptions(people, me)) {
    if (r['key'] == d && _t(r['email'])) return r['email'];
  }
  return noWho;
}

/// «@аня» в умной строке → участник, если имя или почта начинаются с этого слова (иначе null — это список).
Map? memberByWord(List<Map> people, String? word) {
  final w = _fold(word).replaceFirst(RegExp(r'^@'), '');
  if (w.isEmpty) return null;
  for (final p in people) {
    if (_fold(p['name']) == w) return p;
  }
  for (final p in people) {
    if (_fold(p['name']).startsWith(w) || _fold((p['email'] as String).split('@')[0]).startsWith(w)) return p;
  }
  return null;
}

/// Последнее изменение записи: кто, когда и какие поля поменял той же правкой.
Json? editOf(Map? rec) {
  final by = _f(rec)['by'];
  if (!_t(by)) return null;
  final ts = _ft(rec).entries.where((e) => e.key != 'by').toList();
  num at = 0;
  for (final e in ts) {
    if ((e.value as num) > at) at = e.value as num;
  }
  if (at == 0) return null;
  return {
    'by': by,
    'at': at,
    'fields': [
      for (final e in ts)
        if (at - (e.value as num) < 3000) e.key,
    ],
    'col': _f(rec)[r'$status'],
    'who': _f(rec)[r'$who'],
  };
}

/// Строка «Изменения» в окне задачи: «Аня · перенос в «Блокаут» · 12:40»; свои правки не показываем.
String changeText(Map? ed, List<Map> people, String? me, [String Function(Object?)? colName, int? now]) {
  if (ed == null || ed['by'] == me) return '';
  colName ??= (c) => '$c';
  final who = memberOf(people, ed['by'])?['name'] ?? nameOf(ed['by']);
  final f = (ed['fields'] as List).toSet();
  var what = 'правка';
  if (f.contains('status')) {
    what = 'отметка «сделано»';
  } else if (f.contains(r'$status')) {
    what = 'перенос${_t(ed['col']) ? ' в «${colName(ed['col'])}»' : ''}';
  } else if (f.contains(r'$who')) {
    what = _t(ed['who'])
        ? 'отдано: ${ed['who'] == me ? 'тебе' : memberOf(people, ed['who'])!['name']}'
        : 'снят исполнитель';
  } else if (f.contains('title')) {
    what = 'новое название';
  } else if (f.contains('due')) {
    what = 'новый срок';
  } else if (f.contains('notes')) {
    what = 'заметка';
  }
  final when = seenText(ed['at'], now).replaceFirst(RegExp(r'^сегодня в '), '');
  return '$who · $what · $when';
}

/// Задачу отдали мне: исполнитель — я, раньше был не я, и поменял это не я.
bool assignedToMe(Map? base, Map? rec, String? me) {
  if (!_t(me) || rec == null || kindOf(rec['k']) != 'task') return false;
  final f = _f(rec);
  return f[r'$who'] == me && _f(base)[r'$who'] != me && _t(f['by']) && f['by'] != me && f['status'] != 'completed';
}

/// Открытых задач у каждого исполнителя: { почта: n, '': ничьих }.
Json whoCounts(List<Map> tasks, Map? layTasks) {
  final out = <String, dynamic>{};
  for (final t in tasks) {
    if (_t(t['parent']) || t['status'] == 'completed') continue;
    final w = whoOf(layTasks?[t['id']]) ?? '';
    out[w] = (out[w] ?? 0) + 1;
  }
  return out;
}

/// Счётчики для фильтра доски: { all, mine, none }.
Json whoTally(List<Map> tasks, Map? layTasks, String? me) {
  var all = 0, mine = 0, none = 0;
  for (final t in tasks) {
    if (_t(t['parent']) || t['status'] == 'completed') continue;
    all++;
    final w = whoOf(layTasks?[t['id']]);
    if (w == null) {
      none++;
    } else if (_t(me) && w == me) {
      mine++;
    }
  }
  return {'all': all, 'mine': mine, 'none': none};
}

const whoModes = ['all', 'mine', 'none'];

/// Задачи для «Сегодня» и календаря: из общих сфер — только мои и ничьи; подзадачи идут за родителем.
Json forMe(Map? tasksByList, Map? layTasks, String? me, bool Function(String listId) together) {
  final out = <String, dynamic>{};
  for (final e in (tasksByList ?? const {}).entries) {
    final ts = (e.value as List).cast<Map>();
    if (!together(e.key)) {
      out[e.key] = ts;
      continue;
    }
    final keep = {
      for (final t in ts)
        if (!_t(t['parent']) && assignedMatch(layTasks?[t['id']], me, 'mineOrNone')) t['id'],
    };
    out[e.key] = ts.where((t) => _t(t['parent']) ? keep.contains(t['parent']) : keep.contains(t['id'])).toList();
  }
  return out;
}

// ---------- Конвейер: исполнители этапов и передача ----------

String _who2(List<Map> people, Object? email, String? me, [bool dat = false]) =>
    email == me ? (dat ? 'тебе' : 'ты') : (memberOf(people, email)?['name'] ?? 'никто');

/// Передача при «Этап →» с записью в историю (последние 8).
Json stagePass(Map? l, String from, String to, String by, [int? now]) {
  final h = handoff(l, to);
  final who = h['who'] ?? whoOf(l);
  final passes = [
    ...(l?['passes'] is List ? l!['passes'] as List : const []),
    {'from': from, 'to': to, 'by': by, 'who': who, 'at': now ?? _now()},
  ];
  final last8 = passes.length > 8 ? passes.sublist(passes.length - 8) : passes;
  final sw = l?['stageWho'] as Map?;
  final keep = whoOf(l) != null && !_t(sw?[from])
      ? {
          'stageWho': {...?sw?.cast<String, dynamic>(), from: whoOf(l)},
        }
      : const <String, dynamic>{};
  return {...h, ...keep, 'passes': last8};
}

/// Строка истории «Как передаётся».
String passText(Map p, List<Map> people, String? me, [String Function(Object?)? colName]) {
  colName ??= (c) => '$c';
  final by = _who2(people, p['by'], me);
  final head = '${by[0].toUpperCase()}${by.substring(1)} · «${colName(p['from'])}» готов${_t(p['from']) ? 'о' : ''}';
  if (!_t(p['who'])) return '$head → на этапе никого';
  if (p['who'] != p['by']) return '$head → ${_who2(people, p['who'], me, true)}';
  return '$head → «${colName(p['to'])}» '
      '${p['who'] == me ? 'остаётся у тебя' : 'снова у: ${memberOf(people, p['who'])!['name']}'}';
}

/// Подсказка у кнопки следующего этапа: у кого он останется.
String nextHint(Map? l, String? next, String? me, List<Map> people) {
  if (!_t(next)) return '';
  final cur = whoOf(l), to = (l?['stageWho'] as Map?)?[next];
  final target = to ?? cur;
  if (!_t(target)) return 'этап без исполнителя';
  if (target == cur) {
    return target == me ? 'этап твой — останется у тебя' : 'останется: ${memberOf(people, target)!['name']}';
  }
  return target == me ? 'уйдёт к тебе' : 'уйдёт: ${memberOf(people, target)!['name']}';
}

/// Кто на этапах: [{ col, who }].
List<Json> stageCrew(Map? l, List<Map> cols, Object? cur) => [
  for (final c in cols) {'col': c, 'who': (l?['stageWho'] as Map?)?[c['id']] ?? (c['id'] == cur ? whoOf(l) : null)},
];

// ---------- состояния: приглашение, «ещё не дошло», нет доступа ----------

bool isInvite(Map? store, String me) {
  if (store == null || store['role'] == 'owner' || _t(store['accepted'])) return false;
  final r = (store['recs'] as Map?)?[memberKey(me)];
  return !(_t(_f(r)['joined']) && !_t(_f(r)['removed']));
}

Json inviteInfo(Map? store, String? me) {
  final recs = (store?['recs'] as Map?) ?? const {};
  final people = membersOf(recs);
  Map? owner;
  for (final p in people) {
    if (p['owner'] == true) {
      owner = p;
      break;
    }
  }
  final all = _recs(recs);
  return {
    'cal': store?['cal'],
    'name': _f(recs[sphereKey])['name'] ?? 'Общая сфера',
    'owner': owner,
    'lists': all.where((r) => kindOf(r['k']) == 'list').length,
    'tasks': all
        .where((r) => kindOf(r['k']) == 'task' && !_t(_f(r)['parent']) && _f(r)['status'] != 'completed')
        .length,
    'people': people.where((p) => p['joined'] == true && p['email'] != me).toList(),
  };
}

/// Задачу отдал я, а Спутник исполнителя с тех пор не обменивался со сферой — «ждёт Аню».
Map? waitingFor(Map? rec, List<Map> people, String? me) {
  final w = _f(rec)[r'$who'];
  if (!_t(w) || w == me || _f(rec)['by'] != me) return null;
  Map? m;
  for (final p in people) {
    if (p['email'] == w) {
      m = p;
      break;
    }
  }
  if (m == null || !_t(m['joined']) || !_t(m['seen'])) return null;
  return ((_ft(rec)[r'$who'] ?? 0) as num) > (m['seen'] as num) ? m : null;
}

/// Сколько моих правок ещё не видел каждый участник: [{ m, n }] по убыванию.
List<Json> unseenBy(Map? recs, List<Map> people, String? me) {
  final mine = _recs(recs)
      .where((r) => (kindOf(r['k']) == 'task' || kindOf(r['k']) == 'list') && _f(r)['by'] == me)
      .toList();
  final xs = [
    for (final p in people)
      if (p['email'] != me && _t(p['joined']) && _t(p['seen']))
        {'m': p, 'n': mine.where((r) => lastTime(r) > (p['seen'] as num)).length},
  ].where((x) => (x['n'] as int) > 0).toList();
  final idx = {for (final (i, x) in xs.indexed) x: i};
  xs.sort((a, b) {
    final c = (b['n'] as int).compareTo(a['n'] as int);
    return c != 0 ? c : idx[a]!.compareTo(idx[b]!);
  });
  return xs;
}

/// Пора ли отметить «был тогда-то»: раз в час, а если пришли чужие правки — через 2 минуты.
bool seenDue(num? seen, bool foreignNewer, [int? now]) {
  if (!_t(seen)) return true;
  final n = now ?? _now();
  return n - seen! > 36e5 || (foreignNewer && n - seen > 120e3);
}

/// Текст для «Попросить доступ»: письмо владельцу.
String askAccessText(String sphereName, String? ownerEmail) =>
    '${_t(ownerEmail) ? 'Кому: $ownerEmail\n' : ''}Тема: Доступ к сфере «$sphereName» в Спутнике\n\n'
    'Привет! У меня пропал доступ к общей сфере «$sphereName». Позови меня снова, пожалуйста: «Участники» → почта.';
