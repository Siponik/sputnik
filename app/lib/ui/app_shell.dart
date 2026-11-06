// Оболочка: шапка с вкладками «Сегодня · Доска · Календарь», состояние связи, обновить. Ctrl+1…3 — вкладки, F5 — обновить.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import 'board/board_page.dart';
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
  const AppShell({super.key, required this.state, this.initialTab = 0});
  final AppState state;
  final int initialTab;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int tab = widget.initialTab;
  static const tabs = ['Сегодня', 'Календарь', 'Доска', 'Привычки'];

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () => setState(() => tab = 0),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): () => setState(() => tab = 1),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true): () => setState(() => tab = 2),
        const SingleActivator(LogicalKeyboardKey.digit4, control: true): () => setState(() => tab = 3),
        const SingleActivator(LogicalKeyboardKey.f5): s.refresh,
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): _create,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): _search,
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () => setState(() => tab = 4),
      },
      child: Focus(
        autofocus: true,
        child: ListenableBuilder(
          listenable: s,
          builder: (context, _) => Scaffold(
            backgroundColor: SpColors.ground,
            body: Column(
              children: [
                _header(s),
                if (s.offline)
                  _bar('Нет связи с Google — правки сохранены и уйдут, когда связь вернётся', SpColors.headGold),
                if (s.error != null && !s.offline && !s.needLogin) _bar(s.error!, SpColors.headRed),
                Expanded(child: _body(s)),
              ],
            ),
            bottomSheet: s.toast == null
                ? null
                : Container(
                    width: double.infinity,
                    color: SpColors.node,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(child: Text(s.toast!, style: SpType.text(13))),
                        if (s.toastAction != null)
                          TextButton(
                            onPressed: () {
                              final a = s.toastAction!;
                              s.toastAction = null;
                              s.toast = null;
                              a();
                            },
                            child: Text(s.toastLabel),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  void _search() {
    if (widget.state.needLogin) return;
    openSearch(context, widget.state, (t, list) {
      setState(() {
        tab = t;
        if (list != null) widget.state.activeList = list;
      });
    });
  }

  void _create() {
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
          for (var i = 0; i < tabs.length; i++)
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
                    tabs[i].toUpperCase(),
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
              onTap: () => setState(() => tab = 4),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tab == 4 ? SpColors.accent : SpColors.line),
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
