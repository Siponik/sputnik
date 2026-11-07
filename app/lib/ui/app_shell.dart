// Оболочка: шапка с вкладками «Сегодня · Календарь · Доска · Привычки · Знания», состояние связи, обновить.
// Клавиши — по физической клавише (keys.dart): 1–4 и Q/E — вкладки, N — создать, / и Ctrl+K — поиск, R/F5 — обновить.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/notes/parse.dart' show folderOf;
import '../state/app_state.dart';
import '../state/notes_state.dart';
import 'notes/notes_page.dart';
import 'notes/notes_search.dart';
import 'board/board_page.dart';
import 'board/rows_view.dart' show archiveDialog;
import 'keys.dart';
import 'calendar/calendar_page.dart';
import 'create/create_dialog.dart';
import 'settings/settings_page.dart';
import '../state/updater.dart';
import 'widgets/search_dialog.dart';
import 'habits/habits_page.dart';
import 'theme/tokens.dart';
import 'g/kit.dart';
import 'today/today_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.state,
    this.notes,
    this.initialTab = 0,
    this.syncEvery = const Duration(minutes: 2),
  });
  final AppState state;

  /// «Знания»; нет — вкладки нет.
  final NotesState? notes;
  final int initialTab;
  final Duration syncEvery;

  @override
  State<AppShell> createState() => _AppShellState();
}

const tabNames = {0: 'Сегодня', 1: 'Календарь', 2: 'Доска', 3: 'Привычки', 5: 'Знания'};

/// Порядок вкладок: сохранённый (неизвестные выброшены, недостающие — в конец) или исходный.
List<int> tabOrder(Object? settings, {bool notes = true}) {
  final all = [0, 1, 2, 3, if (notes) 5];
  final saved = (((settings as Map?)?['tabs'] as Map?)?['v'] as List?)?.whereType<num>().map((x) => x.toInt());
  final out = <int>{
    for (final t in saved ?? const <int>[])
      if (all.contains(t)) t,
  }.toList();
  return [
    ...out,
    for (final t in all)
      if (!out.contains(t)) t,
  ];
}

class _AppShellState extends State<AppShell> {
  late int tab = widget.initialTab;

  /// Настройки — не вкладка шапки, а кнопка «Состояние»; «Знания» в шапке пятые, но номер у них 5.
  static const settingsTab = 4;
  static const notesTab = 5;
  Timer? _sync;
  final _findKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    updater.autoOn = () => (((widget.state.layer['settings'] as Map?)?['update'] as Map?)?['auto']) != false;
    final n = widget.notes;
    if (n == null) return;
    widget.state.showNote = (path) {
      setState(() => tab = notesTab);
      n.openNote(path);
    };
    // «Знания» сверяются с Drive раз в 2 минуты и вскоре после запуска.
    _sync = Timer.periodic(widget.syncEvery, (_) => n.syncNow());
    Future.delayed(const Duration(seconds: 3), () => mounted ? n.syncNow() : null);
  }

  void _go(int t) => setState(() => tab = t);

  /// Порядок вкладок для Q/E и 1–4.
  /// Порядок вкладок шапки, Q/E и 1–4 — из Настройки → Вид (`settings.tabs.v`).
  List<int> get _order => tabOrder(widget.state.layer['settings'], notes: widget.notes != null);

  /// Глобальные клавиши по физической клавише — работают в русской раскладке и не теряют фокус.
  bool _onKey(KeyEvent e) {
    if (!mounted || e is KeyUpEvent) return false;
    // Открыто окно поверх — общие клавиши не трогаем (кроме самих окон).
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    final s = widget.state;
    final notes = widget.notes != null && tab == notesTab;
    bool hit(PKey k, VoidCallback f) {
      if (!k.matches(e)) return false;
      f();
      return true;
    }

    if (hit(const PKey(PhysicalKeyboardKey.keyK, ctrl: true), _search)) return true;
    if (!notes && hit(const PKey(PhysicalKeyboardKey.keyN, ctrl: true), _create)) return true;
    if (hit(const PKey(PhysicalKeyboardKey.comma, ctrl: true), () => _go(settingsTab))) return true;
    if (hit(const PKey(PhysicalKeyboardKey.f5), s.refresh)) return true;
    for (final (i, t) in _order.indexed) {
      if (hit(PKey(digits[i], ctrl: true), () => _go(t))) return true;
    }
    if (typing() || notes) return false;
    for (final (i, t) in _order.take(4).indexed) {
      if (hit(PKey(digits[i]), () => _go(t))) return true;
    }
    void step(int d) {
      final o = _order;
      final i = o.indexOf(tab);
      _go(o[((i < 0 ? 0 : i) + d) % o.length]);
    }

    if (hit(const PKey(PhysicalKeyboardKey.keyQ), () => step(-1))) return true;
    if (hit(const PKey(PhysicalKeyboardKey.keyE), () => step(1))) return true;
    if (hit(const PKey(PhysicalKeyboardKey.keyN), _create)) return true;
    if (hit(const PKey(PhysicalKeyboardKey.slash), _search)) return true;
    if (hit(const PKey(PhysicalKeyboardKey.keyR), s.refresh)) return true;
    void list(int d) {
      final ls = s.boardLists;
      if (ls.isEmpty) return;
      final i = ls.indexWhere((l) => l['id'] == s.activeList);
      s.activeList = ls[((i < 0 ? 0 : i) + d) % ls.length]['id'] as String;
      _go(2);
    }

    if (hit(const PKey(PhysicalKeyboardKey.bracketLeft), () => list(-1))) return true;
    if (hit(const PKey(PhysicalKeyboardKey.bracketRight), () => list(1))) return true;
    if (hit(const PKey(PhysicalKeyboardKey.keyF), () {
      final id = s.activeList ?? (s.boardLists.isEmpty ? null : s.boardLists.first['id'] as String);
      if (id != null && !s.needLogin) archiveDialog(context, s, id);
    })) {
      return true;
    }
    return PageKeys.handle(e);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _sync?.cancel();
    widget.notes?.flush();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return CallbackShortcuts(
      bindings: {if (widget.notes != null && tab == notesTab) ...notesKeys(context, widget.notes!)},
      child: Focus(
        autofocus: true,
        child: ListenableBuilder(
          listenable: s,
          builder: (context, _) => Scaffold(
            backgroundColor: SpColors.ground,
            body: Builder(
              builder: (context) {
                SpMotion.mode = (((s.layer['settings'] as Map?)?['motion'] as Map?)?['v'] ?? 'full') as String;
                final dur = SpMotion.d(context, SpMotion.dur3);
                final moves = SpMotion.moves(context);
                return Stack(
                  children: [
                    Column(
                      children: [
                        _header(s),
                        if (s.offline)
                          _bar(
                            'Нет связи с Google — правки сохранены и уйдут, когда связь вернётся',
                            SpColors.headGold,
                          ),
                        if (s.error != null && !s.offline && !s.needLogin) _bar(s.error!, SpColors.headRed),
                        // Смена раздела: новый экран проявляется и чуть поднимается, старый уходит быстрее.
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: dur,
                            reverseDuration: SpMotion.d(context, SpMotion.dur1),
                            switchInCurve: SpMotion.easeOut,
                            switchOutCurve: SpMotion.easeIn,
                            transitionBuilder: (w, a) => FadeTransition(
                              opacity: a,
                              child: moves
                                  ? SlideTransition(
                                      position: Tween(begin: const Offset(0, .012), end: Offset.zero).animate(a),
                                      child: w,
                                    )
                                  : w,
                            ),
                            child: KeyedSubtree(key: ValueKey(tab), child: _body(s)),
                          ),
                        ),
                      ],
                    ),
                    // Плашка «Готово · Отменить»: выезжает снизу.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 20,
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: SpMotion.d(context, SpMotion.dur2),
                          reverseDuration: SpMotion.d(context, SpMotion.dur1),
                          switchInCurve: SpMotion.easeOut,
                          switchOutCurve: SpMotion.easeIn,
                          transitionBuilder: (w, a) => FadeTransition(
                            opacity: a,
                            child: moves
                                ? SlideTransition(
                                    position: Tween(begin: const Offset(0, .5), end: Offset.zero).animate(a),
                                    child: w,
                                  )
                                : w,
                          ),
                          child: s.toast == null ? const SizedBox.shrink() : _toast(s),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _toast(AppState s) => Container(
    key: ValueKey(s.toast),
    constraints: const BoxConstraints(maxWidth: 560),
    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
    decoration: BoxDecoration(
      color: SpColors.node,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: SpColors.line),
      boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 20, offset: Offset(0, 8))],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(s.toast!, style: SpType.text(13), maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 12),
        if (s.toastAction != null)
          GBtn(
            s.toastLabel,
            sm: true,
            onTap: () {
              final a = s.toastAction!;
              s.toastAction = null;
              s.toast = null;
              a();
            },
          )
        else
          const SizedBox(width: 8),
      ],
    ),
  );

  void _search() {
    if (tab == notesTab && widget.notes != null) {
      _notesSearch(widget.notes!);
      return;
    }
    if (widget.state.needLogin) return;
    final box = _findKey.currentContext?.findRenderObject() as RenderBox?;
    final at = box == null || !box.hasSize ? null : box.localToGlobal(Offset.zero) & box.size;
    openSearch(context, widget.state, anchor: at, (t, list) {
      setState(() {
        tab = t;
        if (list != null) widget.state.activeList = list;
      });
    });
  }

  /// Ctrl K в «Знаниях»: заметки, задачи, новая заметка.
  Future<void> _notesSearch(NotesState notes) async {
    final s = widget.state;
    final ts = [
      for (final l in s.boardLists)
        for (final t in s.topTasks(l['id'] as String))
          (title: (t['title'] ?? '') as String, list: (l['title'] ?? '') as String),
    ];
    final pick = await showNotesSearch(context, notes, tasks: ts);
    if (!mounted || pick == null) return;
    switch (pick) {
      case PickNote(:final path):
        notes.openNote(path);
      case PickNew(:final title):
        await notes.create(notes.active == null ? '' : folderOf(notes.active!), title);
      case PickTask():
        setState(() => tab = 0);
    }
  }

  void _create() {
    if (tab == notesTab && widget.notes != null) {
      newNoteDialog(context, widget.notes!);
      return;
    }
    final s = widget.state;
    if (s.needLogin) return;
    if (tab == 3) {
      editHabit(context, s, null);
    } else {
      openCreate(context, s);
    }
  }

  Widget _bar(String text, Color c) => Container(
    width: double.infinity,
    color: c,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Text(text, style: SpType.text(12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
  );

  static const _wd = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];

  Widget _header(AppState s) {
    final pending = s.outbox.ops.length;
    final n = DateTime.now();
    String two(int x) => x.toString().padLeft(2, '0');
    final dots = [
      s.offline ? SpColors.red : SpColors.green,
      pending > 0 ? SpColors.gold : SpColors.green,
      s.error != null ? SpColors.red : SpColors.green,
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: SpColors.bg,
        border: Border(bottom: BorderSide(color: SpColors.line)),
      ),
      child: Row(
        children: [
          const Logo(),
          const SizedBox(width: 10),
          Text('СПУТНИК', style: gLbl(c: SpColors.ink, size: 11)),
          const SizedBox(width: 26),
          for (final i in _order)
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: InkWell(
                onTap: () => setState(() => tab = i),
                child: Container(
                  padding: const EdgeInsets.only(bottom: 3),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: tab == i ? SpColors.accent : Colors.transparent)),
                  ),
                  child: Text(
                    tabNames[i]!.toUpperCase(),
                    style: gLbl(c: tab == i ? SpColors.ink : SpColors.muted, size: 11),
                  ),
                ),
              ),
            ),
          const Spacer(),
          ListenableBuilder(
            listenable: updater,
            builder: (context, _) => updater.found == null
                ? const SizedBox()
                : Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: InkWell(
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: Text('Вышла версия ${updater.found!['version']}'),
                          content: Text((updater.found!['notes'] ?? '') as String),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Позже')),
                            FilledButton(onPressed: updater.install, child: const Text('Обновить сейчас')),
                          ],
                        ),
                      ),
                      child: Text('✦ ВЕРСИЯ ${updater.found!['version']}', style: gLbl(c: SpColors.gold, size: 11)),
                    ),
                  ),
          ),
          Text(
            '${_wd[n.weekday - 1]} ${two(n.day)}.${two(n.month)} · ${two(n.hour)}:${two(n.minute)}',
            style: gLbl(size: 11),
          ),
          const SizedBox(width: 26),
          InkWell(
            key: _findKey,
            onTap: _search,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 32,
              constraints: const BoxConstraints(minWidth: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: SpColors.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search, size: 13, color: SpColors.muted),
                  const SizedBox(width: 8),
                  Text('НАЙТИ', style: gLbl(size: 11)),
                  const SizedBox(width: 24),
                  Text('CTRL K', style: gLbl(size: 10, c: SpColors.dim)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 26),
          Tooltip(
            message: s.offline
                ? 'Нет связи с Google'
                : pending > 0
                ? 'Ждёт отправки: $pending'
                : (s.syncedAt == null
                      ? 'Всё в порядке'
                      : 'Всё в порядке · обновлено ${two(s.syncedAt!.hour)}:${two(s.syncedAt!.minute)}'),
            child: InkWell(
              onTap: () => setState(() => tab = settingsTab),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tab == settingsTab ? SpColors.accent : SpColors.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (i, c) in dots.indexed) ...[if (i > 0) const SizedBox(width: 6), GDot(c)],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 26),
          GBtn('+ Создать', kind: BtnKind.ink, onTap: s.needLogin ? null : _create),
        ],
      ),
    );
  }

  Widget _body(AppState s) {
    // «Знаниям» Google не нужен: папка заметок — на этом компьютере.
    if (tab == notesTab && widget.notes != null) return NotesPage(state: widget.notes!);
    if (!s.started) return const Center(child: CircularProgressIndicator());
    if (s.loggingIn) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Открыл браузер: войди в Google и вернись сюда', style: SpType.text(15)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: s.cancelLogin, child: const Text('Отмена')),
          ],
        ),
      );
    }
    if (s.needLogin) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Спутник работает с твоими Google Задачами и Календарём', style: SpType.text(16)),
            const SizedBox(height: 6),
            Text(
              'Своего сервера нет: данные идут прямо между этим компьютером и Google.',
              style: SpType.text(13, color: SpColors.muted),
            ),
            if (s.error != null) ...[
              const SizedBox(height: 12),
              Text(
                s.error!,
                style: SpType.text(13, color: SpColors.red),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(onPressed: s.login, child: const Text('Войти в Google')),
          ],
        ),
      );
    }
    return switch (tab) {
      0 => TodayPage(state: s),
      1 => CalendarPage(state: s),
      2 => BoardPage(state: s),
      3 => HabitsPage(state: s),
      _ => SettingsPage(state: s),
    };
  }
}
