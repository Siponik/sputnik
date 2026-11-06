// Оболочка: шапка с вкладками «Сегодня · Доска · Календарь», состояние связи, обновить. Ctrl+1…3 — вкладки, F5 — обновить.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import 'board/board_page.dart';
import 'calendar/calendar_page.dart';
import 'create/create_dialog.dart';
import 'habits/habits_page.dart';
import 'theme/tokens.dart';
import 'today/today_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.state});
  final AppState state;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int tab = 0;
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

  Widget _header(AppState s) {
    final pending = s.outbox.ops.length;
    return Container(
      height: 48,
      color: SpColors.bg,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Text(
            'СПУТНИК',
            style: SpType.label(12, color: SpColors.accent, w: FontWeight.w700, spacing: .2),
          ),
          const SizedBox(width: 20),
          for (var i = 0; i < tabs.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton(
                onPressed: () => setState(() => tab = i),
                style: TextButton.styleFrom(
                  backgroundColor: tab == i ? SpColors.nodeHover : Colors.transparent,
                  foregroundColor: tab == i ? SpColors.ink : SpColors.muted,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SpRadius.button)),
                ),
                child: Text(tabs[i], style: SpType.text(13.5, color: tab == i ? SpColors.ink : SpColors.muted)),
              ),
            ),
          const Spacer(),
          if (pending > 0)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text('ждёт отправки · $pending', style: SpType.label(11, color: SpColors.gold)),
            ),
          if (s.syncedAt != null)
            Text(
              'обновлено ${s.syncedAt!.hour.toString().padLeft(2, '0')}:${s.syncedAt!.minute.toString().padLeft(2, '0')}',
              style: SpType.label(11),
            ),
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: s.needLogin ? null : _create,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Создать'),
          ),
          IconButton(
            tooltip: 'Обновить (F5)',
            onPressed: s.syncing ? null : s.refresh,
            icon: s.syncing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh, size: 18, color: SpColors.muted),
          ),
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
      _ => HabitsPage(state: s),
    };
  }
}
