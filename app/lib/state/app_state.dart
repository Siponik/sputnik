// Состояние пилота. Действие сначала меняет память (экран обновляется сразу), Google догоняет в фоне.
// Ошибка Google — откат и сообщение. В целевой версии здесь будет Riverpod и очередь исходящих (docs/flutter-architecture.md).
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../core/dates.dart';
import '../core/today_tasks.dart';
import '../data/google_api.dart';
import '../data/google_auth.dart';
import '../data/paths.dart';

class AppState extends ChangeNotifier {
  AppState() : api = GoogleApi(GoogleAuth());
  final GoogleApi api;

  List<TodayTask> all = [];
  Map<String, dynamic> layer = {};
  Map<String, String> listNames = {};
  bool loading = true;
  String? error;
  String? toast;
  bool needLogin = false;
  bool loggingIn = false;
  int lastTapMs = 0; // сколько мс от нажатия до обновления экрана (замер для решения «идём ли дальше»)
  int loadMs = 0;

  List<TodayTask> get today => todayTasks(all, layer, DateTime.now());

  Future<void> load() async {
    loading = true;
    error = null;
    needLogin = false;
    notifyListeners();
    final sw = Stopwatch()..start();
    try {
      final f = dataFile('layer.json');
      layer = await f.exists() ? jsonDecode(await f.readAsString()) as Map<String, dynamic> : {};
      final lists = (await api.lists()).where((l) => showList(l, layer)).toList();
      listNames = {for (final l in lists) l['id'] as String: (l['title'] ?? '') as String};
      final fetched = await Future.wait(
        lists.map((l) async {
          final id = l['id'] as String;
          final items = await api.tasks(id);
          return items.map(
            (t) => TodayTask(
              id: t['id'] as String,
              listId: id,
              title: ((t['title'] ?? '') as String),
              day: dueToYmd(t['due'] as String?),
            ),
          );
        }),
      );
      all = fetched.expand((x) => x).where((t) => t.title.trim().isNotEmpty).toList();
    } on AuthError catch (e) {
      needLogin = e.needLogin;
      error = e.message;
    } catch (e) {
      error = e.toString();
    }
    loadMs = sw.elapsedMilliseconds;
    loading = false;
    notifyListeners();
  }

  Future<void> login() async {
    loggingIn = true;
    error = null;
    notifyListeners();
    try {
      await api.auth.login();
      loggingIn = false;
      await load();
    } catch (e) {
      loggingIn = false;
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> cancelLogin() async {
    await api.auth.cancel();
  }

  Future<void> toggle(TodayTask t) async {
    final sw = Stopwatch()..start();
    t.done = !t.done;
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      lastTapMs = sw.elapsedMilliseconds;
      notifyListeners();
    });
    try {
      await api.setDone(t.listId, t.id, t.done);
    } catch (e) {
      t.done = !t.done;
      toast = 'Не получилось отметить: $e';
      notifyListeners();
    }
  }
}
