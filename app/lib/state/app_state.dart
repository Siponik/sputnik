// Состояние приложения «сначала локально» (docs/flutter-architecture.md, п. 5).
// Экран читает память; действие меняет память, пишет файл и кладёт операцию в очередь исходящих (data/outbox.dart).
// Опрос Google — раз в 2 минуты и по кнопке; слой сливается с копией на Drive (core/layer.dart merge).
// Пока без Riverpod: один ChangeNotifier, чтобы быстрее дойти до рабочей сборки.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/dates.dart';
import '../core/habits.dart' as hb;
import '../core/inbox.dart' as inbox;
import '../core/layer.dart' as lay;
import '../core/repeat.dart' as rep;
import '../core/route.dart' as route;
import '../core/spheres.dart' as sph;
import '../core/templates.dart' as tpl;
import '../core/today.dart' as today;
import '../core/reminders.dart' as rem;
import '../core/sharedbot.dart' as sbot;
import 'notes_state.dart';
import '../data/bot_api.dart';
import '../data/google_api.dart';
import '../data/notify.dart';
import '../data/google_auth.dart';
import '../data/outbox.dart';
import '../data/store.dart';
import '../data/paths.dart';
import '../data/shared_store.dart';
import '../core/sharedcore.dart' as shc;

typedef Json = Map<String, dynamic>;

class AppState extends ChangeNotifier {
  AppState() : api = GoogleApi(GoogleAuth()), store = Store() {
    outbox = Outbox(api, store)
      ..onCreated = _created
      ..onSaved = _saved
      ..onRejected = _rejected
      ..onChange = notifyListeners;
    shared = SharedStore(api, store);
    outbox.shared = shared;
  }

  late final SharedStore shared;

  /// «Знания» (для блока «Заметки» в окне задачи) и как открыть заметку — задаёт оболочка.
  NotesState? notes;
  void Function(String path)? showNote;

  final GoogleApi api;
  final Store store;
  final BotApi bot = BotApi();
  String botErr = '';
  DateTime? botAt;
  late final Outbox outbox;

  List<Json> lists = []; // списки Google Tasks
  Map<String, List<Json>> tasks = {}; // listId → задачи (как в Google)
  List<Json> calendars = [];
  List<Json> events = []; // события текущей и следующей недели, у каждого 'calId'
  Json layer = lay.emptyLayer();
  Json? inboxSt; // статус «Входящих от Claude» (событие «Спутник · статус»)

  String? activeList; // список, открытый на доске
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
  Timer? _botTimer;
  Timer? _toastTimer;
  bool _layerDirty = false;

  // ---------- запуск и синхронизация ----------

  Future<void> start() async {
    final sw = Stopwatch()..start();
    try {
      layer = {...lay.emptyLayer(), ...await store.readLayer()};
      await outbox.load();
      await shared.load();
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
    Timer.periodic(const Duration(minutes: 1), (_) => _tickNotify());
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
      await _step('отправка правок', () => outbox.flush(force: true));
      await _step('слой', _syncLayer);
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
      await _step('общие сферы', () async {
        final gone = await shared.pullAll();
        if (gone.isNotEmpty) say('Пропал доступ к общей сфере');
      });
      final shl = shared.lists();
      for (final l in shl) {
        final id = l['id'] as String;
        final old = {for (final t in tasks[id] ?? const <Json>[]) t['id']: t};
        fresh[id] = [
          for (final t in shared.tasks(id))
            if (outbox.pendingFor(t['id'] as String) && old[t['id']] != null) old[t['id']]! else t,
          for (final t in tasks[id] ?? const <Json>[])
            if ((t['id'] as String).startsWith('tmp-') && outbox.pendingFor(t['id'] as String)) t,
        ];
      }
      lists = [...ls, ...shl];
      tasks = fresh;
      offline = false;
      error = null;
      await _step('общие задачи', () async => _reconcileShared());
      await _step('календарь', _loadEvents);
      await _step('входящие', _loadInbox);
      syncedAt = DateTime.now();
      await _step('повторы', () async => rollRepeats(quiet: true));
      unawaited(botSync());
      unawaited(store.writeCache({'lists': lists, 'tasks': tasks, 'calendars': calendars, 'events': events}));
    } on AuthError catch (e) {
      needLogin = e.needLogin;
      if (!e.needLogin) offline = true;
      error = e.message;
    } on ApiError catch (e) {
      error = e.toString();
    } on SocketException catch (e) {
      offline = true;
      error = 'Нет связи с Google';
      _log('refresh', e);
    } catch (e, st) {
      error = 'Не смог забрать задачи: $e';
      _log('refresh', e, st);
    }
    syncing = false;
    notifyListeners();
  }

  /// Необязательный шаг синхронизации: его ошибка не мешает показать задачи.
  Future<void> _step(String name, Future<void> Function() f) async {
    try {
      await f();
    } catch (e, st) {
      _log(name, e, st);
      error ??= 'Сбой ($name): $e';
    }
  }

  void _log(String where, Object e, [StackTrace? st]) {
    try {
      final f = ownFile('errors.log');
      f.writeAsStringSync('${DateTime.now().toIso8601String()} [$where] $e\n${st ?? ''}\n', mode: FileMode.append);
    } catch (_) {}
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
    if (key.startsWith('sh:') || section == 'tasks') _pushShared(section, key);
    _saveLayer();
  }

  void _saveLayer() {
    _layerDirty = true;
    unawaited(store.writeLayer(layer));
    _layerTimer?.cancel();
    _botTimer?.cancel();
    _botTimer = Timer(const Duration(seconds: 3), () => botSync());
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
        if (id.startsWith('sh:') && !_mine(x)) continue;
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

  // ---------- входящие от Claude ----------

  Future<void> _loadInbox() async {
    final q = calendars.where((c) => ((c['summary'] ?? '') as String).startsWith('Спутник · входящие')).firstOrNull;
    if (q == null) return;
    try {
      final evs = await api.events(q['id'] as String, DateTime.utc(2029, 12, 31), DateTime.utc(2030, 1, 3));
      final ev = evs.where((e) => e['summary'] == 'Спутник · статус').firstOrNull;
      final text = ((ev?['description'] ?? '') as String)
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll('&quot;', '"')
          .replaceAll('&amp;', '&');
      final a = text.indexOf('{'), b = text.lastIndexOf('}');
      if (a < 0 || b < a) return;
      inboxSt = jsonDecode(text.substring(a, b + 1)) as Json;
      _pullInboxLayer();
    } catch (_) {}
  }

  /// Поля Спутника из чатов и бота — в свой слой один раз (как App.pullInboxLayer).
  void _pullInboxLayer() {
    final r = inbox.pullPatches(inboxSt, layer);
    final def = (((layer['settings'] as Map?)?['remind'] as Map?)?['task'] as num?)?.toInt() ?? 60;
    for (final x in (r['spheres'] as List)) {
      touch('spheres', x[0] as String, Json.from(x[1] as Map));
    }
    for (final x in (r['lists'] as List)) {
      touch('lists', x[0] as String, Json.from(x[1] as Map));
    }
    for (final x in (r['tasks'] as List)) {
      final patch = Json.from(x[1] as Map);
      if (layTask(x[0] as String)['remind'] == null && patch['remind'] == null) {
        patch['remind'] = {'kind': 'lead', 'min': def};
      }
      touch('tasks', x[0] as String, patch);
    }
  }

  List<Json> get inboxItems => inbox.pending(inboxSt, boardLists.cast<Map>(), tasks, layer['tasks'] as Map?);

  void acceptInbox(List<Json> items) {
    for (final x in items) {
      final t = x['task'] as Json;
      touch('tasks', t['id'] as String, {'inbox': 'accepted'});
      final dest = x['dest'] as String?;
      if (dest != null && dest != x['listId']) moveToList(x['listId'] as String, t, dest);
    }
    say(items.length > 1 ? 'Принято задач: ${items.length}' : '«${(items.first['task'] as Json)['title']}» — принято');
  }

  void rejectInbox(Json x) {
    final t = x['task'] as Json;
    touch('tasks', t['id'] as String, {'inbox': 'rejected'});
    remove(x['listId'] as String, t);
    say('«${t['title']}» — отклонено и удалено');
  }

  // ---------- списки и сферы ----------

  List<Json> get spheres => [
    ...sph.spheresFrom(layer),
    for (final cal in [...shared.activeCalendars, ...shared.stores.keys.where(shared.isLost)])
      if (shared.sphereRec(cal) case final Map r)
        {
          ...((r['f'] as Map).cast<String, dynamic>()),
          'id': shc.sphereId(cal),
          'order': 1000,
          'shared': true,
          'lost': shared.isLost(cal),
          'owner': shared.isOwner(cal),
        },
  ];

  // ---------- общие сферы ----------

  List<Json> get invites => shared.invites;
  String? calOf(String sphereId) => shc.calOfSphere(sphereId);
  List<Json> people(String sphereId) => shared.people(calOf(sphereId) ?? '');
  String get myEmail => shared.me;

  /// Поля слоя задач и списков общих сфер ↔ записи календаря (трёхстороннее сведение, как App.svelte).
  void _reconcileShared() {
    var changed = false;
    for (final cal in shared.activeCalendars) {
      final st = shared.stores[cal]!;
      final recs = (st['recs'] ?? const {}) as Map;
      final base = (st['base'] ??= <String, dynamic>{}) as Map;
      for (final r in recs.values.whereType<Map>()) {
        final k = r['k'] as String;
        final kind = shc.kindOf(k);
        if (kind != 'task' && kind != 'list') continue;
        final lk = kind == 'list' ? shc.listId(k) : k;
        final sec = kind == 'list' ? 'lists' : 'tasks';
        final cur = (layer[sec] as Map?)?[lk] as Map?;
        final res = shc.reconcile(cur, base[k] as Map?, r, kind!);
        final toLayer = (res['toLayer'] as Map).cast<String, dynamic>();
        if (kind == 'list' && cur?['sphere'] != shc.sphereId(cal)) toLayer['sphere'] = shc.sphereId(cal);
        if (toLayer.isNotEmpty) {
          final s0 = (layer[sec] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
          layer[sec] = s0;
          s0[lk] = {...?cur, ...toLayer, 't': cur?['t'] ?? DateTime.now().millisecondsSinceEpoch};
          changed = true;
        }
        final toRec = res['toRec'] as Map;
        if (toRec.isNotEmpty) shared.patchSoon(cal, k, toRec);
        base[k] = r;
      }
    }
    if (changed) _saveLayer();
  }

  /// Правка слоя задачи/списка общей сферы — сразу в календарь (поля с «$»).
  void _pushShared(String section, String key) {
    if (section != 'tasks' && section != 'lists') return;
    final rk = section == 'lists' ? shc.listKey(key) : key;
    final cal = shared.calOfList(section == 'lists' ? rk : _listOfTask(key));
    if (cal == null || rk == null) return;
    final patch = shc.sharedOf((layer[section] as Map?)?[key], section == 'lists' ? 'list' : 'task');
    if (section == 'lists') patch.remove(r'$sphere');
    if (patch.isNotEmpty) shared.patchSoon(cal, rk, patch);
  }

  /// Задача общей сферы — моя или ничья (sharedcore.forMe).
  bool _mine(Json t) {
    final w = layTask(t['id'] as String)['who'];
    return w == null || w == '' || w == shared.me;
  }

  String? _listOfTask(String id) {
    for (final e in tasks.entries) {
      if (e.key.startsWith('sh:') && e.value.any((t) => t['id'] == id)) return shc.listKey(e.key);
    }
    return null;
  }

  Future<void> _shared(Future<void> Function() f, String fail) async {
    try {
      await f();
      await refresh();
    } catch (e) {
      say('$fail: $e');
    }
  }

  Future<void> acceptInvite(String cal) => _shared(() => shared.accept(cal), 'Не принялось');
  Future<void> declineInvite(String cal) => _shared(() => shared.decline(cal), 'Не получилось');
  Future<void> joinSphere(String code) => _shared(() => shared.join(code), 'Не вошёл в сферу');
  Future<void> forgetSphere(String cal) => _shared(() => shared.forget(cal), 'Не убралось');
  Future<void> invitePerson(String cal, String email) => _shared(() => shared.invite(cal, email), 'Не позвал');
  Future<void> removePerson(String cal, String email) => _shared(() => shared.removeMember(cal, email), 'Не убрал');

  /// Сделать сферу общей: календарь сферы, списки переезжают туда вместе с задачами.
  Future<String?> shareSphere(String sphereId) async {
    final sp = spheres.firstWhere((x) => x['id'] == sphereId, orElse: () => {});
    if (sp.isEmpty) return null;
    try {
      final cal = await shared.createSphere(
        (sp['name'] ?? 'Сфера') as String,
        (sp['color'] ?? 'clay') as String,
        (sp['icon'] ?? 'star') as String,
      );
      for (final l in lists.where((l) => sphereOf(l['id'] as String) == sphereId).toList()) {
        final nl = await shared.createList(cal, (l['title'] ?? '') as String);
        final nid = nl['id'] as String;
        final L = Json.from(layList(l['id'] as String))..remove('t');
        touch('lists', nid, {...L, 'sphere': shc.sphereId(cal)});
        final old = tasks[l['id']] ?? const <Json>[];
        final ids = <String, String>{};
        for (final t in old.where((t) => t['parent'] == null)) {
          final lt = Json.from(layTask(t['id'] as String))..remove('t');
          final r = await shared.createTask(nid, _body(t), layer: shc.sharedOf(lt));
          ids[t['id'] as String] = r['id'] as String;
          if (lt.isNotEmpty) touch('tasks', r['id'] as String, lt);
        }
        for (final t in old.where((t) => t['parent'] != null)) {
          final p = ids[t['parent']];
          if (p != null) await shared.createTask(nid, _body(t), parent: p);
        }
        await api.deleteList(l['id'] as String);
      }
      deleteSphere(sphereId);
      await refresh();
      say('Сфера стала общей — позови людей');
      return shc.sphereId(cal);
    } catch (e) {
      say('Не получилось сделать общей: $e');
      return null;
    }
  }

  Json _body(Json t) => {
    'title': t['title'] ?? '',
    'notes': t['notes'] ?? '',
    'due': ?t['due'],
    'status': t['status'] ?? 'needsAction',
    'completed': ?t['completed'],
  };

  String inviteText(String sphereId) {
    final sp = spheres.firstWhere((x) => x['id'] == sphereId, orElse: () => {});
    return shared.inviteText(calOf(sphereId) ?? '', (sp['name'] ?? '') as String);
  }

  String? sphereOf(String listId) => sph.sphereOf(listId, layer);

  Future<String?> createList(String title, {String template = 'work', String? sphere, String? view}) async {
    try {
      final cal = sphere == null ? null : shc.calOfSphere(sphere);
      final l = cal != null ? await shared.createList(cal, title) : await api.createList(title);
      lists = [...lists, l];
      touch('lists', l['id'] as String, {'template': template, 'sphere': ?sphere, 'view': ?view});
      notifyListeners();
      return l['id'] as String;
    } catch (e) {
      say('Список не создался: $e');
      return null;
    }
  }

  Future<void> renameList(String id, String title) async {
    final l = lists.firstWhere((x) => x['id'] == id);
    final was = l['title'];
    l['title'] = title;
    notifyListeners();
    try {
      await (id.startsWith('sh:') ? shared.renameList(id, title) : api.renameList(id, title));
    } catch (e) {
      l['title'] = was;
      say('Не переименовался: $e');
    }
  }

  Future<void> deleteList(String id) async {
    try {
      await (id.startsWith('sh:') ? shared.deleteList(id) : api.deleteList(id));
      final ids = [for (final t in tasks[id] ?? const <Json>[]) t['id'] as String];
      layer = lay.forgetList(layer, id, ids);
      lists = lists.where((l) => l['id'] != id).toList();
      tasks.remove(id);
      _saveLayer();
      notifyListeners();
      say('Список удалён');
    } catch (e) {
      say('Не удалось удалить список: $e');
    }
  }

  /// Другой шаблон колонок: задачи переезжают по switchPlan.
  void switchTemplate(String listId, String tplId) {
    final plan = tpl.switchPlan(layer, listId, tplId, tasks[listId]);
    touch('lists', listId, Json.from(plan['patch'] as Map));
    for (final m in (plan['moves'] as List)) {
      touch('tasks', m['id'] as String, {'status': m['status']});
    }
    notifyListeners();
  }

  void saveSphere(String? id, Json fields) {
    final cal = id == null ? null : shc.calOfSphere(id);
    if (cal != null) {
      shared.patchSoon(cal, shc.sphereKey, fields);
      final r = shared.sphereRec(cal);
      if (r != null) (r['f'] as Map).addAll(fields);
      notifyListeners();
      return;
    }
    final sid = id ?? 'sp-${DateTime.now().millisecondsSinceEpoch}';
    final order = spheres.fold<num>(0, (m, x) => ((x['order'] ?? 0) as num) > m ? (x['order'] as num) : m) + 1;
    touch('spheres', sid, {if (id == null) 'order': order, ...fields});
    notifyListeners();
  }

  void deleteSphere(String id) {
    final cal = shc.calOfSphere(id);
    if (cal != null) {
      unawaited(_shared(() => shared.removeSphere(cal), 'Не удалилась сфера'));
      return;
    }
    touch('spheres', id, {'removed': true});
    for (final l in lists) {
      if (layList(l['id'] as String)['sphere'] == id) touch('lists', l['id'] as String, {'sphere': null});
    }
    notifyListeners();
  }

  // ---------- общий Telegram-бот ----------

  String? get botKey => ((layer['settings'] as Map?)?['tgbot'] as Map?)?['key'] as String?;

  /// Пункты напоминаний (как в App.svelte) — для бота.
  List<Json> remindItems() {
    final hb0 = (((layer['settings'] as Map?)?['remindHour'] as Map?)?['v']) as String?;
    rem.setDefaultTime(hb0);
    final evs = events
        .where((e) => ((e['extendedProperties'] as Map?)?['private'] as Map?)?['sputnikR'] == '1')
        .toList();
    final ls = boardLists.cast<Map>();
    return [
      ...rem.collect(ls, tasks, layer['tasks'] as Map?, habitList, const [], evs.cast<Map>()),
      ...rem.habitItems(habits, habitLog),
      ...rem.assignedItems(ls, tasks, layer['tasks'] as Map?),
    ];
  }

  Future<void> botSync() async {
    final key = botKey;
    if (key == null || key.isEmpty) return;
    try {
      final live = boardLists.where((l) => layList(l['id'] as String)['quiet'] != true).cast<Map>().toList();
      await bot.push(
        key,
        remindItems(),
        sbot.snapshot(live, tasks, layer['tasks'] as Map?),
        sbot.guessCtx(boardLists.cast<Map>(), layer),
      );
      final r = await bot.inbox(key);
      final ok = <Object?>[];
      var added = 0;
      for (final x in ((r['items'] ?? []) as List).cast<Map>()) {
        if (x['type'] == 'add') {
          final ctx = boardLists.cast<Map>();
          final t = x['draft'] is Map
              ? sbot.fromDraft(x['draft'] as Map, lists: ctx, layer: layer, tasks: tasks)
              : sbot.fromText(x['text'], lists: ctx, layer: layer, tasks: tasks);
          if (t != null) {
            final patch = Json.from((t['layer'] as Map?) ?? const {});
            if (t['slot'] != null) patch['slot'] = t['slot'];
            if (!patch.containsKey('remind')) patch['remind'] = rem.defaultRule(layer['settings'] as Map?);
            if (patch['remind'] == null) patch.remove('remind');
            final n = addTask(t['listId'] as String, t['title'] as String, due: t['due'] as String?, layerPatch: patch);
            if (((t['notes'] ?? '') as String).isNotEmpty) setNotes(t['listId'] as String, n, t['notes'] as String);
            added++;
          }
        } else if (x['type'] == 'move' || x['type'] == 'done') {
          final tk = task(x['listId'] as String, x['taskId'] as String);
          if (tk != null && !isDone(tk)) {
            if (x['type'] == 'done') {
              toggleDone(x['listId'] as String, tk);
            } else {
              setDue(x['listId'] as String, tk, x['due'] as String?);
            }
          }
        }
        ok.add(x['id']);
      }
      if (ok.isNotEmpty) await bot.ack(key, ok);
      if (added > 0) say(added == 1 ? 'Из Telegram — новая задача' : 'Из Telegram — новых задач: $added');
      botErr = '';
      botAt = DateTime.now();
    } catch (e) {
      botErr = '$e';
    }
    notifyListeners();
  }

  Future<String?> botLinkCode(String code) async {
    final key = botKey ?? sbot.newKey();
    try {
      final r = await bot.link(code, key);
      bot.forget();
      touch('settings', 'tgbot', {'key': key, 'name': r['name'] ?? '', 'at': DateTime.now().millisecondsSinceEpoch});
      say('Telegram подключён ✓ — напоминания придут туда');
      unawaited(botSync());
      return null;
    } catch (e) {
      return '$e';
    }
  }

  Future<void> botTest() async {
    try {
      await bot.test(botKey ?? '');
      say('Отправил проверку — загляни в Telegram');
    } catch (e) {
      say('Бот не ответил: $e');
    }
  }

  Future<void> botUnlink() async {
    try {
      await bot.unlink(botKey ?? '');
    } catch (_) {}
    touch('settings', 'tgbot', {'key': null, 'name': '', 'at': null});
    say('Telegram отключён');
  }

  // ---------- уведомления Windows: окно привычки и задачи «за N минут», пока приложение открыто ----------

  final Set<String> _shown = {};

  void _tickNotify() {
    if (layer['settings'] is Map && ((layer['settings'] as Map)['notify'] as Map?)?['v'] == false) return;
    final today = todayYmd;
    for (final h in rem.habitWinDue(habits, habitLog, _shown.toList())) {
      _shown.add('${h['id']}|$today');
      notify('Привычка · ${h['name']}', 'Ещё не отмечено сегодня');
    }
    // Задачи и события — в Telegram, если бот привязан; иначе — уведомлением Windows.
    if (botKey != null && botKey!.isNotEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final it in remindItems()) {
      final at = DateTime.tryParse((it['fireAt'] ?? '') as String)?.millisecondsSinceEpoch;
      final key = '${it['key']}';
      if (at == null || _shown.contains(key) || at > now || now - at > 5 * 60000) continue;
      _shown.add(key);
      notify('Спутник · напоминание', '${it['title'] ?? ''}${it['list'] != null ? ' · ${it['list']}' : ''}');
    }
  }

  // ---------- действия ----------

  VoidCallback? toastAction;
  String toastLabel = 'Отменить';

  void say(String msg, [VoidCallback? action, String label = 'Отменить']) {
    toast = msg;
    toastAction = action;
    toastLabel = label;
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 6), () {
      toast = null;
      toastAction = null;
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
  Json addTask(String listId, String title, {String? due, Json layerPatch = const {}, String? col, String notes = ''}) {
    final tmp = 'tmp-${DateTime.now().millisecondsSinceEpoch}-${_seq++}';
    final body = <String, dynamic>{
      'title': title,
      if (due != null && due.isNotEmpty) 'due': ymdToDue(due),
      if (notes.isNotEmpty) 'notes': notes,
    };
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
