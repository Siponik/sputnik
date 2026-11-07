// Общие сферы: участники (позвать по почте, убрать, текст приглашения), вход по коду, плашка приглашений.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/app_state.dart';
import '../theme/tokens.dart';

Future<void> shareDialog(BuildContext context, AppState s, String sphereId) => showDialog<void>(
  context: context,
  builder: (_) => _People(s: s, sphereId: sphereId),
);

class _People extends StatefulWidget {
  const _People({required this.s, required this.sphereId});
  final AppState s;
  final String sphereId;
  @override
  State<_People> createState() => _PeopleState();
}

class _PeopleState extends State<_People> {
  final mail = TextEditingController();
  bool busy = false;

  Future<void> _do(Future<void> Function() f) async {
    setState(() => busy = true);
    await f();
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final cal = s.calOf(widget.sphereId) ?? '';
        final sp = s.spheres.firstWhere((x) => x['id'] == widget.sphereId, orElse: () => {});
        final owner = s.shared.isOwner(cal);
        final lost = s.shared.isLost(cal);
        final ppl = s.people(widget.sphereId);
        return AlertDialog(
          backgroundColor: SpColors.node,
          title: Text('Участники · ${sp['name'] ?? ''}'),
          content: SizedBox(
            width: 480,
            child: lost
                ? Text(
                    'К этой сфере больше нет доступа: владелец её удалил или убрал тебя. Попроси позвать снова или убери её из колонки.',
                    style: SpType.text(14, color: SpColors.ink2),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final p in ppl)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: SpColors.accentWash,
                            child: Text(
                              ((p['name'] ?? p['email'] ?? '?') as String).characters.first.toUpperCase(),
                              style: SpType.text(12, color: SpColors.accentInk),
                            ),
                          ),
                          title: Text(
                            '${p['name'] ?? p['email']}${p['email'] == s.myEmail ? ' (ты)' : ''}',
                            style: SpType.text(14),
                          ),
                          subtitle: Text(
                            p['owner'] == true
                                ? 'владелец'
                                : (p['joined'] == true ? (p['email'] ?? '') as String : 'ещё не принял'),
                            style: SpType.label(10.5),
                          ),
                          trailing: owner && p['owner'] != true
                              ? IconButton(
                                  tooltip: 'Убрать',
                                  onPressed: busy ? null : () => _do(() => s.removePerson(cal, p['email'] as String)),
                                  icon: Icon(Icons.close, size: 16, color: SpColors.muted),
                                )
                              : null,
                        ),
                      if (owner) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: mail,
                                decoration: const InputDecoration(hintText: 'Почта Google того, кого позвать'),
                                onSubmitted: (_) => _invite(cal),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(onPressed: busy ? null : () => _invite(cal), child: const Text('Позвать')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Google пришлёт письмо. В Спутнике у человека появится приглашение.',
                          style: SpType.text(12, color: SpColors.muted),
                        ),
                      ],
                    ],
                  ),
          ),
          actions: [
            if (!lost)
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: s.inviteText(widget.sphereId)));
                  s.say('Приглашение скопировано');
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Скопировать приглашение'),
              ),
            TextButton(
              onPressed: () async {
                final ok = await _confirm(
                  context,
                  lost ? 'Убрать сферу из колонки?' : (owner ? 'Удалить сферу у всех?' : 'Выйти из сферы?'),
                  owner && !lost ? 'Списки и задачи сферы удалятся у всех участников.' : 'Её списки пропадут у тебя.',
                );
                if (ok) {
                  s.deleteSphere(widget.sphereId);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: Text(lost ? 'Убрать из колонки' : (owner ? 'Удалить сферу' : 'Выйти')),
            ),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Готово')),
          ],
        );
      },
    );
  }

  void _invite(String cal) {
    final e = mail.text.trim();
    if (!e.contains('@')) return;
    mail.clear();
    _do(() => s.invitePerson(cal, e));
  }

  AppState get s => widget.s;
}

Future<bool> _confirm(BuildContext context, String title, String text) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(autofocus: true, onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Да')),
        ],
      ),
    ) ==
    true;

Future<void> joinDialog(BuildContext context, AppState s) async {
  final code = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: SpColors.node,
      title: const Text('Войти в общую сферу'),
      content: SizedBox(
        width: 440,
        child: TextField(
          controller: code,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Код из приглашения (…@group.calendar.google.com)'),
          onSubmitted: (_) => Navigator.pop(c, true),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Войти')),
      ],
    ),
  );
  if (ok == true && code.text.trim().isNotEmpty) await s.joinSphere(code.text.trim());
}

/// Плашка «X зовёт тебя в сферу» над «Сегодня» и доской.
class InviteBar extends StatelessWidget {
  const InviteBar({super.key, required this.s});
  final AppState s;

  @override
  Widget build(BuildContext context) {
    final inv = s.invites;
    if (inv.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final i in inv)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: SpColors.accentWash,
              borderRadius: BorderRadius.circular(SpRadius.node),
              border: Border.all(color: SpColors.accentLine),
            ),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Text(
                  '${((i['owner'] as Map?)?['name'] ?? (i['owner'] as Map?)?['email'] ?? 'Тебя')} зовёт в сферу «${i['name']}» · списков ${i['lists']}, задач ${i['tasks']}',
                  style: SpType.text(13.5),
                ),
                FilledButton(onPressed: () => s.acceptInvite(i['cal'] as String), child: const Text('Принять')),
                TextButton(onPressed: () => s.declineInvite(i['cal'] as String), child: const Text('Отказаться')),
              ],
            ),
          ),
      ],
    );
  }
}
