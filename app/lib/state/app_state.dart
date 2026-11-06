// Состояние приложения «сначала локально» (docs/flutter-architecture.md, п. 5).
// Экран читает память; действие меняет память, пишет файл и кладёт операцию в очередь исходящих (data/outbox.dart).
// Опрос Google — раз в 2 минуты и по кнопке; слой сливается с копией на Drive (core/layer.dart merge).
// Пока без Riverpod: один ChangeNotifier, чтобы быстрее дойти до рабочей сборки.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/dates.dart';
import '../core/habits.dart' as hb;
import '../core/layer.dart' as lay;
import '../core/repeat.dart' as rep;
import '../core/route.dart' as route;
import '../core/templates.dart' as tpl;
import '../core/today.dart' as today;
import '../data/google_api.dart';
import '../data/google_auth.dart';
import '../data/outbox.dart';
import '../data/store.dart';

typedef Json = Map<String, dynamic>;

class AppState extends ChangeNotifier {
  AppState() : api = GoogleApi(GoogleAuth()), store = Store() {
    outbox = Outbox(api, store)
      ..onCreated = _created
      ..onSaved = _saved
      ..onRejected = _rejected
      ..onChange = notifyListeners;
  }

  final GoogleApi api;
  final Store store;
  late final Outbox outbox;

  List<Json> lists = []; // списки Google Tasks
  Map<String, List<Json>> tasks = {}; // listId → задачи (как в Google)
  List<Json> calendars = [];
  List<Json> events = []; // события текущей и следующей недели, у каждого 'calId'
  Json layer = lay.emptyLayer();

  bool started = false;
  bool syncing = false;
  bool offline = false;
  bool needLogin = false;
  bool loggingIn = false;
  String? error;
  String? toast;
  DateTime? syncedAt;
  int loadMs = 0;

  Timer? _poll;
  Timer? _layerTimer;
  Timer? _toastTimer;
  bool _layerDirty = false;

  // ---------- запуск и синхронизация ----------

  Future<void> start() async {
    final sw = Stopwatch()..start();
    try {
      layer = {...lay.emptyLayer(), ...await store.readLayer()};
      await outbox.load();
      final c = await store.readCache();
      if (c != null) {
        lists = ((c['lists'] ?? []) as List).cast<Json>();
        tasks = {for (final e in ((c['tasks'] ?? {}) as Map).entries) e.key as String: (e.value as List).cast<Json>()};
        calendars = ((c['calendars'] ?? []) as List).cast<Json>();
        events = ((c['events'] ?? []) as List).cast<Json>();
      }
    } catch (e) {
      error = 'Не прочитал свои файлы: $e';
    }
    loadMs = sw.elapsedMilliseconds;
    started = true;
    needLogin = !await api.auth.hasLogin();
    notifyListeners();
    if (!needLogin) unawaited(refresh());
    _poll = Timer.periodic(const Duration(minutes: 2), (_) => refresh());
    Timer.periodic(const Duration(seconds: 30), (_) => outbox.flush());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    if (syncing || needLogin) return;
    syncing = true;
    notifyListeners();
    try {
      await outbox.flush(force: true);
      await _syncLayer();
      final ls = await api.lists();
      final got = await Future.wait(ls.map((l) => api.tasks(l['id'] as String)));
      final fresh = <String, List<Json>>{};
      for (var i = 0; i < ls.length; i++) {
        final id = ls[i]['id'] as String;
        final old = {for (final t in tasks[id] ?? const <Json>[]) t['id']: t};
        // Задачи с неотправленными правками и ещё не созданные — оставляем свои.
        final list = <Json>[
          for (final t in got[i])
            if (outbox.pendingFor(t['id'] as String) && old[t['id']] != null) old[t['id']]! else t,
          for (final t in tasks[id] ?? const <Json>[])
            if ((t['id'] as String).startsWith('tmp-') && outbox.pendingFor(t['id'] as String)) t,
        ];
        fresh[id] = list;
      }
      lists = ls;
      tasks = fresh;
      await _loadEvents();
      offline = false;
      error = null;
      syncedAt = DateTime.now();
      rollRepeats(quiet: true);
      unawaited(store.writeCache({'lists': lists, 'tasks': tasks, 'calendars': calendars, 'events': events}));
    } on AuthError catch (e) {
      needLogin = e.needLogin;
      if (!e.needLogin) offline = true;
      error = e.message;
    } on ApiError catch (e) {
      error = e.toString();
    } catch (e) {
      offline = true;
      error = 'Нет связи с Google';
    }
    syncing = false;
    notifyListeners();
  }

  DateTime? evFrom, evTo; // загруженное окно событий

  /// Календарь листают за пределы загруженного: догрузить события (по месяцу с запасом).
  Future<void> ensureEvents(DateTime from, DateTime to) async {
    if (needLogin || (evFrom != null && !from.isBefore(evFrom!) && !to.isAfter(evTo!))) return;
    final a = DateTime(from.year, from.month - 1, 1), b = DateTime(to.year, to.month + 2, 1);
    try {
      final got = await _eventsIn(a, b);
      final have = {for (final e in events) '${e['calId']}|${e['id']}'};
      events = [...events, ...got.where((e) => !have.contains('${e['calId']}|${e['id']}'))];
      evFrom = evFrom == null || a.isBefore(evFrom!) ? a : evFrom;
      evTo = evTo == null || b.isAfter(evTo!) ? b : evTo;
      notifyListeners();
    } catch (_) {}
  }

  Future<List<Json>> _eventsIn(DateTime from, DateTime to) async {
    final show = calendars.where((c) => calShown(c)).toList();
    final got = await Future.wait(
      show.map((c) async {
        try {
          return (await api.events(c['id'] as String, from, to)).map((e) => {...e, 'calId': c['id']}).toList();
        } catch (_) {
          return <Json>[];
        }
      }),
    );
    return got.expand((x) => x).where((e) => e['status'] != 'cancelled').toList();
  }

  Future<void> _loadEvents() async {
    final cals = await api.calendars();
    calendars = cals;
    final now = DateTime.now();
    final from = DateTime(now.year, now.month - 1, 1);
    final to = DateTime(now.year, now.month + 3, 1);
    evFrom = from;
    evTo = to;
    events = await _eventsIn(from, to);
  }

  /// Задача → новый день и время (перетаскивание в календаре). slot null — «весь день».
  void schedule(String listId, Json t, String day, Json? slot) {
    if (dueToYmd(t['due'] as String?) != day) setDue(listId, t, day);
    setTask(t['id'] as String, {'slot': slot});
  }

  bool isBirthday(Json e) =>
      ((e['extendedProperties'] as Map?)?['private'] as Map?)?['sputnik'] == 'birthday' ||
      e['eventType'] == 'birthday' ||
      ((e['calId'] ?? '') as String).contains('#contacts@');

  /// Показывать ли календарь: выбран в Google, не скрыт в слое, не служебный.
  bool calShown(Json c) {
    final name = (c['summary'] ?? '') as String;
    if (name.startsWith('Спутник · ')) return false;
    if (((c['description'] ?? '') as String).contains('sputnik-sphere')) return false;
    final r = (layer['cals'] as Map?)?[c['id']];
    if (r is Map && r['hidden'] != null) return r['hidden'] != true;
    return c['selected'] == true || c['primary'] == true;
  }

  Future<void> _syncLayer() async {
    final remote = await api.pullLayer();
    final r = lay.merge(layer, remote);
    if (r.localChanged) {
      layer = r.merged;
      await store.writeLayer(layer);
    }
    if (r.remoteChanged) await api.pushLayer(r.merged);
  }

  Future<void> login() async {
    loggingIn = true;
    error = null;
    notifyListeners();
    try {
      await api.auth.login();
      needLogin = false;
      loggingIn = false;
      notifyListeners();
      await refresh();
    } catch (e) {
      loggingIn = false;
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> cancelLogin() => api.auth.cancel();

  // ---------- слой ----------

  Json layTask(String id) => (((layer['tasks'] as Map?)?[id] as Map?) ?? const {}).cast<String, dynamic>();
  Json layList(String id) => (((layer['lists'] as Map?)?[id] as Map?) ?? const {}).cast<String, dynamic>();

  void touch(String section, String key, Json patch) {
    final s = (layer[section] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    layer[section] = s;
    s[key] = {...((s[key] as Map?) ?? const {}), ...patch, 't': DateTime.now().millisecondsSinceEpoch};
    _saveLayer();
  }

  void _saveLayer() {
    _layerDirty = true;
    unawaited(store.writeLayer(layer));
    _layerTimer?.cancel();
    _layerTimer = Timer(const Duration(seconds: 4), () async {
      if (!_layerDirty || needLogin) return;
      _layerDirty = false;
      try {
        await _syncLayer();
        notifyListeners();
      } catch (_) {
        _layerDirty = true;
      }
    });
  }

  // ---------- что показывать ----------

  /// Списки для доски и «Сегодня»: не скрытые, не удалённые, не «Привычки».
  List<Json> get boardLists => lists.where((l) {
    final L = layList(l['id'] as String);
    if (L['hidden'] == true || L['gone'] == true) return false;
    return !tpl.isHabitList(l, layer);
  }).toList();

  String listName(String id) =>
      (lists.firstWhere((l) => l['id'] == id, orElse: () => const {})['title'] ?? '') as String;

  Json? task(String listId, String id) {
    for (final t in tasks[listId] ?? const <Json>[]) {
      if (t['id'] == id) return t;
    }
    return null;
  }

  bool isDone(Json t) => t['status'] == 'completed';
  bool _top(Json t) => t['parent'] == null && ((t['title'] ?? '') as String).trim().isNotEmpty && t['deleted'] != true;

  String colOf(Json t, List cols) {
    if (isDone(t)) return 'done';
    final s = layTask(t['id'] as String)['status'];
    return s != null && s != 'done' && cols.any((c) => (c as Map)['id'] == s)
        ? s as String
        : (cols.first as Map)['id'] as String;
  }

  Json board(String listId) => tpl.boardOf(listId, layer);

  /// Задачи доски по колонкам; выполненные раньше срока архива — не на доске.
  Map<String, List<Json>> columns(String listId) {
    final b = board(listId);
    final cols = b['cols'] as List;
    final days = tpl.archiveDays(layList(listId));
    final out = {for (final c in cols) (c as Map)['id'] as String: <Json>[]};
    final items = (tasks[listId] ?? const <Json>[]).where(_top).where((t) => !tpl.isArchived(t, days)).toList();
    for (final t in tpl.orderTasks(items, layer['tasks'] as Map?, tpl.sortOf(layList(listId)))) {
      out[colOf(t, cols)]?.add(t);
    }
    return out;
  }

  String get todayYmd => ymd(DateTime.now());

  /// «Сегодня»: открытые со сроком сегодня и раньше + сделанные сегодня.
  List<(String, Json)> get todayItems {
    final t = todayYmd;
    final out = <(String, Json)>[];
    for (final l in boardLists) {
      final id = l['id'] as String;
      if (layList(id)['quiet'] == true) continue;
      for (final x in tasks[id] ?? const <Json>[]) {
        if (!_top(x)) continue;
        final due = dueToYmd(x['due'] as String?);
        if (isDone(x)) {
          if (dueToYmd(x['completed'] as String?) == t || (due.isNotEmpty && due == t)) out.add((id, x));
        } else if (due.isNotEmpty && due.compareTo(t) <= 0) {
          out.add((id, x));
        }
      }
    }
    int prio(Json x) => (layTask(x['id'] as String)['priority'] as num?)?.toInt() ?? 2;
    String slot(Json x) => ((layTask(x['id'] as String)['slot'] as Map?)?['s'] ?? '99') as String;
    final idx = {for (var i = 0; i < out.length; i++) out[i].$2['id']: i};
    out.sort((a, b) {
      final d = (isDone(a.$2) ? 1 : 0) - (isDone(b.$2) ? 1 : 0);
      if (d != 0) return d;
      final s = slot(a.$2).compareTo(slot(b.$2));
      if (s != 0) return s;
      final p = prio(a.$2) - prio(b.$2);
      if (p != 0) return p;
      final due = dueToYmd(a.$2['due'] as String?).compareTo(dueToYmd(b.$2['due'] as String?));
      return due != 0 ? due : idx[a.$2['id']]!.compareTo(idx[b.$2['id']]!);
    });
    return out;
  }

  /// События дня (местное время), весь день — первыми.
  List<Json> eventsOn(String day) {
    final out = events.where((e) {
      final s = e['start'] as Map? ?? const {};
      if (s['date'] != null) {
        final end = ((e['end'] as Map?)?['date'] ?? s['date']) as String;
        return (s['date'] as String).compareTo(day) <= 0 && day.compareTo(end) < 0;
      }
      final dt = DateTime.tryParse((s['dateTime'] ?? '') as String)?.toLocal();
      return dt != null && ymd(dt) == day;
    }).toList();
    String key(Json e) => ((e['start'] as Map?)?['dateTime'] ?? '') as String;
    out.sort((a, b) => key(a).compareTo(key(b)));
    return out;
  }

  /// Задачи со сроком в этот день (все списки).
  List<(String, Json)> tasksOn(String day) => [
    for (final l in boardLists)
      for (final x in tasks[l['id']] ?? const <Json>[])
        if (_top(x) && dueToYmd(x['due'] as String?) == day) (l['id'] as String, x),
  ];

  // ---------- привычки (задачи списка «Привычки», настройки — layer.habits, отметки — layer.log) ----------

  Json? get habitList {
    for (final l in lists) {
      if (tpl.isHabitList(l, layer)) return l;
    }
    return null;
  }

  /// Привычки как в App.svelte habitsRaw, по порядку sortHabits.
  List<Json> get habits {
    final hl = habitList;
    if (hl == null) return [];
    final items = (tasks[hl['id']] ?? const <Json>[]).where((t) => t['parent'] == null && !isDone(t)).toList();
    final idx = {for (var i = 0; i < items.length; i++) items[i]['id']: i};
    items.sort((a, b) {
      final c = ((a['position'] ?? '') as String).compareTo((b['position'] ?? '') as String);
      return c != 0 ? c : idx[a['id']]!.compareTo(idx[b['id']]!);
    });
    return hb.sortHabits([
      for (final t in items)
        () {
          final m = ((layer['habits'] as Map?)?[t['id']] as Map?) ?? const {};
          return <String, dynamic>{
            'id': t['id'],
            'name': ((t['title'] ?? '') as String).isEmpty ? 'Без названия' : t['title'],
            'days': m['days'] ?? [],
            'win': m['win'],
            'time': m['time'],
            'end': m['end'],
            'createdAt': m['createdAt'],
            'part': m['part'],
            'perWeek': m['perWeek'],
            'goal': m['goal'],
            'icon': m['icon'],
            'color': m['color'],
            'remind': m['remind'],
            'tipHide': m['tipHide'],
          };
        }(),
    ]);
  }

  Map get habitLog => (layer['log'] as Map?) ?? const {};

  int get habitsLeft => habits.where((h) => !hb.isDone(habitLog, h['id'], todayYmd)).length;

  /// Отметка сегодня (у количества — «+1»).
  void toggleHabit(Json h) {
    final day = todayYmd;
    touch('log', hb.logKey(h['id'], day), hb.nextMark(habitLog, h, day));
    final n = hb.stats(h, habitLog)['streak'] as int;
    if (hb.isDone(habitLog, h['id'], day) && hb.milestones.contains(n)) say('Серия $n! ${h['name']}');
    notifyListeners();
  }

  /// Задним числом: state = done | skip | none.
  void setHabitDay(Json h, String day, String state) {
    touch('log', hb.logKey(h['id'], day), hb.dayMark(h, state));
    notifyListeners();
  }

  void saveHabit(String id, Json patch) {
    touch('habits', id, patch);
    notifyListeners();
  }

  Future<void> addHabit(String name, Json fields) async {
    var hl = habitList;
    if (hl == null) {
      try {
        hl = await api.createList('Привычки');
        lists = [...lists, hl];
      } catch (e) {
        say('Не получилось создать список «Привычки»: $e');
        return;
      }
    }
    final t = addTask(hl['id'] as String, name);
    touch('habits', t['id'] as String, {...fields, 'createdAt': todayYmd});
    notifyListeners();
  }

  void renameHabit(String id, String name) {
    final hl = habitList;
    final t = hl == null ? null : task(hl['id'] as String, id);
    if (t != null) rename(hl!['id'] as String, t, name);
  }

  void removeHabit(String id) {
    final hl = habitList;
    final t = hl == null ? null : task(hl['id'] as String, id);
    if (t != null) remove(hl!['id'] as String, t);
  }

  // ---------- доска: вид, темы, закреп, перенос, дубль, архив ----------

  void setView(String listId, String view) {
    touch('lists', listId, {'view': view});
    notifyListeners();
  }

  void setListField(String listId, Json patch) {
    touch('lists', listId, patch);
    notifyListeners();
  }

  /// Ручной выбор списка учит угадывание (settings.route), как App.learnRoute.
  void learnRoute(String title, String listId, [String? topic]) {
    final st = Map<String, dynamic>.from(((layer['settings'] as Map?) ?? const {}));
    final cur = st['route'] is Map ? st['route'] as Map : null;
    final learned = route.learn(cur, title, listId, topic);
    touch('settings', 'route', learned);
  }

  void setTask(String id, Json patch) {
    touch('tasks', id, patch);
    notifyListeners();
  }

  /// Перенос в другой список: в Google — создать там и удалить здесь; поля слоя едут с задачей.
  void moveToList(String from, Json t, String to) {
    if (from == to) return;
    final L = Json.from(layTask(t['id'] as String))..remove('t');
    final x = addTask(to, (t['title'] ?? '') as String, due: dueToYmd(t['due'] as String?), layerPatch: L);
    if ((t['notes'] ?? '') != '') setNotes(to, x, t['notes'] as String);
    final id = t['id'] as String;
    tasks[from]?.removeWhere((y) => y['id'] == id);
    if (id.startsWith('tmp-')) {
      outbox.ops.removeWhere((o) => o['tmp'] == id || o['id'] == id);
    } else {
      unawaited(outbox.add({'op': 'delete', 'list': from, 'id': id}));
    }
    say('Перенесено в «${listName(to)}»');
  }

  void duplicate(String listId, Json t) {
    final L = Json.from(layTask(t['id'] as String))..remove('t');
    final x = addTask(listId, '${t['title'] ?? ''} (копия)', due: dueToYmd(t['due'] as String?), layerPatch: L);
    if ((t['notes'] ?? '') != '') setNotes(listId, x, t['notes'] as String);
  }

  /// Архив списка: выполненные дольше срока архива.
  List<Json> archived(String listId) {
    final days = tpl.archiveDays(layList(listId));
    return (tasks[listId] ?? const <Json>[]).where((t) => _top(t) && isDone(t) && tpl.isArchived(t, days)).toList()
      ..sort((a, b) => ((b['completed'] ?? '') as String).compareTo((a['completed'] ?? '') as String));
  }

  /// Открытые задачи верхнего уровня (для стикеров, конвейера, списка).
  List<Json> topTasks(String listId, {bool withDone = false}) => (tasks[listId] ?? const <Json>[])
      .where(_top)
      .where((t) => withDone ? !tpl.isArchived(t, tpl.archiveDays(layList(listId))) : !isDone(t))
      .toList();

  /// Подзадачи задачи.
  List<Json> subtasks(String listId, String id) =>
      (tasks[listId] ?? const <Json>[]).where((t) => t['parent'] == id && t['deleted'] != true).toList()
        ..sort((a, b) => ((a['position'] ?? '') as String).compareTo((b['position'] ?? '') as String));

  void addSubtask(String listId, String parent, String title) {
    final tmp = 'tmp-${DateTime.now().millisecondsSinceEpoch}-${_seq++}';
    (tasks[listId] ??= []).add({'id': tmp, 'title': title, 'status': 'needsAction', 'parent': parent});
    unawaited(
      outbox.add({
        'op': 'create',
        'list': listId,
        'tmp': tmp,
        'body': {'title': title},
        'parent': parent,
      }),
    );
    notifyListeners();
  }

  // ---------- события и дни рождения (сразу в Google, без очереди: событие без связи создать нельзя) ----------

  /// Календари, куда можно писать (без служебных).
  List<Json> get writableCals => calendars
      .where((c) => ['owner', 'writer'].contains(c['accessRole']) && calShown(c) || c['primary'] == true)
      .toList();

  static Map<String, dynamic> _remindProps(List<int> mins) =>
      mins.isEmpty ? {} : {'sputnikR': '1', 'sputnikRemind': mins.toSet().join(',')};

  Future<bool> createEvent({
    required String title,
    required String day,
    Json? slot,
    String notes = '',
    List<int> remind = const [],
    String calendarId = 'primary',
    String location = '',
    List<String>? recurrence,
  }) async {
    String local(String d, String hhmm) {
      final p = d.split('-').map(int.parse).toList();
      final t = hhmm.split(':').map(int.parse).toList();
      return DateTime(p[0], p[1], p[2], t[0], t[1]).toUtc().toIso8601String();
    }

    String next(String d) {
      final p = d.split('-').map(int.parse).toList();
      return ymd(DateTime(p[0], p[1], p[2] + 1));
    }

    final body = <String, dynamic>{
      'summary': title,
      'start': slot != null ? {'dateTime': local(day, slot['s'] as String)} : {'date': day},
      'end': slot != null ? {'dateTime': local(day, slot['e'] as String)} : {'date': next(day)},
      if (notes.isNotEmpty) 'description': notes,
      if (location.isNotEmpty) 'location': location,
      if (remind.isNotEmpty) 'extendedProperties': {'private': _remindProps(remind)},
    };
    if (recurrence != null && recurrence.isNotEmpty) {
      body['recurrence'] = recurrence;
      if (slot != null) {
        (body['start'] as Map)['timeZone'] = 'Europe/Moscow';
        (body['end'] as Map)['timeZone'] = 'Europe/Moscow';
      }
    }
    try {
      final e = await api.createEvent(calendarId, body);
      events = [
        ...events,
        {...e, 'calId': calendarId},
      ];
      notifyListeners();
      return true;
    } catch (e) {
      say('Событие не создалось: $e');
      return false;
    }
  }

  Future<bool> createBirthday({
    required String name,
    required String day,
    int? year,
    List<int> remind = const [],
    String calendarId = 'primary',
    int giftDays = 0,
    String? giftList,
  }) async {
    final p = day.split('-').map(int.parse).toList();
    final body = {
      'summary': '🎂 $name',
      'start': {'date': day},
      'end': {'date': ymd(DateTime(p[0], p[1], p[2] + 1))},
      'recurrence': ['RRULE:FREQ=YEARLY'],
      'transparency': 'transparent',
      'extendedProperties': {
        'private': {
          'sputnik': 'birthday',
          if (year != null) 'sputnikYear': '$year',
          if (giftDays > 0) 'sputnikGift': '$giftDays',
          if (giftDays > 0 && giftList != null) 'sputnikGiftList': giftList,
          ..._remindProps(remind),
        },
      },
      'reminders': {'useDefault': false},
    };
    try {
      final e = await api.createEvent(calendarId, body);
      events = [
        ...events,
        {...e, 'calId': calendarId},
      ];
      notifyListeners();
      return true;
    } catch (e) {
      say('День рождения не сохранился: $e');
      return false;
    }
  }

  // ---------- повтор: выполненная задача с правилом → следующая с новым сроком (как tasks.svelte.js rollRepeats) ----------

  void rollRepeats({bool quiet = false}) {
    final ls = lists.where((l) => !tpl.isHabitList(l, layer)).toList();
    final todo = rep.dueRepeats(ls, tasks, (layer['tasks'] as Map?)?.cast<String, dynamic>());
    for (final r in todo) {
      final listId = r['listId'] as String;
      final t = r['task'] as Json;
      final day = rep.nextDue(r['rule'], dueToYmd(t['due'] as String?), todayYmd);
      if (day == null) continue;
      final have = rep.existingNext(tasks[listId], t, day);
      if (have != null) {
        touch('tasks', t['id'] as String, {
          'repeatNext': have['id'],
          'repeatAt': DateTime.now().millisecondsSinceEpoch,
        });
        continue;
      }
      final was = layTask(t['id'] as String);
      final carry = {
        for (final k in rep.carry)
          if (was[k] != null) k: was[k],
      };
      final x = addTask(listId, (t['title'] ?? '') as String, due: day, layerPatch: carry);
      if ((t['notes'] ?? '') != '') setNotes(listId, x, t['notes'] as String);
      touch('tasks', t['id'] as String, {'repeatNext': x['id'], 'repeatAt': DateTime.now().millisecondsSinceEpoch});
      if (!quiet) say('Повтор: «${t['title']}» — снова ${day == todayYmd ? 'сегодня' : day}');
    }
  }

  /// «Отменить» выполнение в первые 10 минут убирает созданную копию.
  void _unroll(String listId, Json t) {
    final was = layTask(t['id'] as String);
    final next = was['repeatNext'] as String?;
    if (next == null || DateTime.now().millisecondsSinceEpoch - ((was['repeatAt'] ?? 0) as num) > 10 * 60000) return;
    touch('tasks', t['id'] as String, {'repeatNext': null, 'repeatAt': null});
    final n = task(listId, next);
    if (n != null && !isDone(n)) remove(listId, n);
  }

  // ---------- действия ----------

  void say(String msg) {
    toast = msg;
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 5), () {
      toast = null;
      notifyListeners();
    });
    notifyListeners();
  }

  void _patchLocal(String listId, String id, Json body) {
    final t = task(listId, id);
    if (t == null) return;
    body.forEach((k, v) => v == null ? t.remove(k) : t[k] = v);
    notifyListeners();
  }

  void _send(String listId, String id, Json body) {
    _patchLocal(listId, id, Json.from(body));
    unawaited(outbox.add({'op': 'patch', 'list': listId, 'id': id, 'body': body, 'prev': null}));
  }

  void toggleDone(String listId, Json t) {
    final done = !isDone(t);
    if (!done) _unroll(listId, t);
    _send(
      listId,
      t['id'] as String,
      done
          ? {'status': 'completed', 'completed': DateTime.now().toUtc().toIso8601String()}
          : {'status': 'needsAction', 'completed': null},
    );
    if (done && layTask(t['id'] as String)['repeat'] != null) rollRepeats();
  }

  /// Перенос по колонкам: «готово» — выполнить, из «готово» — вернуть.
  void setStage(String listId, Json t, String col) {
    final id = t['id'] as String;
    if (col == 'done') {
      if (!isDone(t)) toggleDone(listId, t);
      return;
    }
    if (isDone(t)) toggleDone(listId, t);
    touch('tasks', id, {'status': col, 'stageAt': DateTime.now().millisecondsSinceEpoch});
    notifyListeners();
  }

  void setDue(String listId, Json t, String? day) =>
      _send(listId, t['id'] as String, {'due': day == null || day.isEmpty ? null : ymdToDue(day)});

  void rename(String listId, Json t, String title) => _send(listId, t['id'] as String, {'title': title});
  void setNotes(String listId, Json t, String notes) => _send(listId, t['id'] as String, {'notes': notes});

  void setPriority(Json t, int? n) {
    touch('tasks', t['id'] as String, {'priority': n});
    notifyListeners();
  }

  void remove(String listId, Json t) {
    final id = t['id'] as String;
    tasks[listId]?.removeWhere((x) => x['id'] == id);
    touch('tasks', id, {'gone': true});
    if (id.startsWith('tmp-')) {
      outbox.ops.removeWhere((o) => o['tmp'] == id || o['id'] == id);
    } else {
      unawaited(outbox.add({'op': 'delete', 'list': listId, 'id': id}));
    }
    say('Задача удалена');
  }

  int _seq = 0;

  /// Новая задача: сразу в памяти с временным id, в Google — из очереди.
  Json addTask(String listId, String title, {String? due, Json layerPatch = const {}, String? col}) {
    final tmp = 'tmp-${DateTime.now().millisecondsSinceEpoch}-${_seq++}';
    final body = <String, dynamic>{'title': title, if (due != null && due.isNotEmpty) 'due': ymdToDue(due)};
    final t = <String, dynamic>{'id': tmp, ...body, 'status': 'needsAction'};
    (tasks[listId] ??= []).insert(0, t);
    final patch = {...layerPatch, if (col != null && col != 'done') 'status': col};
    if (patch.isNotEmpty) touch('tasks', tmp, patch);
    unawaited(outbox.add({'op': 'create', 'list': listId, 'tmp': tmp, 'body': body}));
    notifyListeners();
    return t;
  }

  /// Умная строка: «купить молоко завтра 17:00 @дом !!» → задача в угаданный список.
  ({String listId, String title})? addLine(String text, {String? listId}) {
    final p = route.parseLine(text);
    final title = (p['title'] ?? '') as String;
    if (title.trim().isEmpty) return null;
    final ls = boardLists.cast<Map>();
    var dest = listId;
    if (dest == null) {
      final r = route.route(text, lists: ls, layer: layer, tasks: tasks, current: null);
      dest = r.isNotEmpty ? r.first['listId'] as String? : null;
      dest ??= ls.isNotEmpty ? ls.first['id'] as String : null;
    }
    if (dest == null) return null;
    final x = today.taskFrom(p, todayYmd, dest);
    final patch = Json.from((x['layer'] as Map?) ?? const {});
    if (x['slot'] != null) patch['slot'] = x['slot'];
    addTask(dest, title, due: x['due'] as String?, layerPatch: patch);
    return (listId: dest, title: title);
  }

  void _created(String tmp, Json real) {
    for (final e in tasks.entries) {
      for (final c in e.value) {
        if (c['parent'] == tmp) c['parent'] = real['id'];
      }
      final i = e.value.indexWhere((x) => x['id'] == tmp);
      if (i < 0) continue;
      final local = e.value[i];
      e.value[i] = {...real, if (local['status'] != real['status']) 'status': local['status']};
      for (final r in ((layer['tasks'] as Map?) ?? const {}).values) {
        if (r is Map && r['repeatNext'] == tmp) r['repeatNext'] = real['id'];
      }
      final L = (layer['tasks'] as Map?)?[tmp];
      if (L != null) {
        (layer['tasks'] as Map)[real['id']] = L;
        (layer['tasks'] as Map)[tmp] = {'gone': true, 't': DateTime.now().millisecondsSinceEpoch};
        _saveLayer();
      }
    }
    notifyListeners();
  }

  void _saved(String listId, Json t) {
    if (outbox.pendingFor(t['id'] as String)) return;
    final list = tasks[listId];
    final i = list?.indexWhere((x) => x['id'] == t['id']) ?? -1;
    if (i >= 0) list![i] = t;
  }

  void _rejected(Op op, Object e) {
    say('Не сохранилось в Google: $e');
    unawaited(refresh());
  }

  String debugLayer() => const JsonEncoder.withIndent(' ').convert(layer);
}
