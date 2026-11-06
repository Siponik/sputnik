// Настройки (Ctrl+,): Вид, Что показывать, Напоминания, Синхронизация, Обновления, Клавиши.
// Всё хранится в слое (settings.*, lists[id].hidden, cals[id].hidden) — общее со старым трекером.
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/reminders.dart' as rem;
import '../../data/paths.dart';
import '../../state/app_state.dart';
import '../../state/updater.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.state});
  final AppState state;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int sec = 0;
  static const secs = ['Вид', 'Что показывать', 'Напоминания', 'Синхронизация', 'Обновления', 'Клавиши'];

  AppState get s => widget.state;
  Json get settings => ((s.layer['settings'] as Map?) ?? const {}).cast<String, dynamic>();

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        width: 220,
        color: SpColors.bg,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Text('НАСТРОЙКИ', style: SpType.label(11)),
            ),
            for (final (i, n) in secs.indexed)
              InkWell(
                onTap: () => setState(() => sec = i),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(
                    color: sec == i ? SpColors.nodeHover : Colors.transparent,
                    borderRadius: BorderRadius.circular(SpRadius.button),
                  ),
                  child: Text(n, style: SpType.text(13.5, color: sec == i ? SpColors.ink : SpColors.ink2)),
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: DotGround(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(secs[sec], style: SpType.text(22, w: FontWeight.w600)),
              const SizedBox(height: 16),
              ...switch (sec) {
                0 => _view(),
                1 => _show(),
                2 => _remind(),
                3 => _sync(),
                4 => _updates(),
                _ => _keys(),
              },
            ],
          ),
        ),
      ),
    ],
  );

  Widget _card(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Node(
      title: title,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    ),
  );

  Widget _chips<T>(List<(T, String)> opts, T cur, void Function(T) on) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [for (final (v, l) in opts) ChoiceChip(label: Text(l), selected: cur == v, onSelected: (_) => on(v))],
  );

  void _set(String key, Json patch) => s.touch('settings', key, patch);

  List<Widget> _view() {
    final start = ((settings['start'] as Map?)?['v'] ?? 'last') as String;
    final motion = ((settings['motion'] as Map?)?['v'] ?? 'full') as String;
    return [
      _card('Открывать при запуске', [
        _chips(
          [
            ('last', 'Где был'),
            ('today', 'Сегодня'),
            ('calendar', 'Календарь'),
            ('board', 'Доска'),
            ('habits', 'Привычки'),
          ],
          start,
          (v) => setState(() => _set('start', {'v': v})),
        ),
      ]),
      _card('Анимации', [
        _chips(
          [('full', 'Полные'), ('min', 'Минимум'), ('off', 'Выключены')],
          motion,
          (v) => setState(() => _set('motion', {'v': v})),
        ),
      ]),
      _card('Тема', [
        Text(
          'Новый Спутник сделан в тёмной теме дизайна G. Светлая тема появится вместе с макетами.',
          style: SpType.text(13, color: SpColors.muted),
        ),
      ]),
    ];
  }

  List<Widget> _show() => [
    _card('Списки', [
      for (final l in s.lists)
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text((l['title'] ?? '') as String),
          value: s.layList(l['id'] as String)['hidden'] != true,
          onChanged: (v) => setState(() => s.setListField(l['id'] as String, {'hidden': !v})),
        ),
    ]),
    _card('Календари', [
      for (final c in s.calendars.where((c) => !((c['summary'] ?? '') as String).startsWith('Спутник · ')))
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text((c['summaryOverride'] ?? c['summary'] ?? '') as String),
          value: s.calShown(c),
          onChanged: (v) {
            s.touch('cals', c['id'] as String, {'hidden': !v});
            s.refresh();
            setState(() {});
          },
        ),
    ]),
  ];

  List<Widget> _remind() {
    final r = ((settings['remind'] as Map?) ?? const {}).cast<String, dynamic>();
    int mins(String k, int def) => (r[k] as num?)?.toInt() ?? def;
    final hour = settings['remindHour'] is Map ? (settings['remindHour'] as Map)['v'] : null;
    return [
      _card('По умолчанию', [
        Text('Задача', style: SpType.label(10.5)),
        const SizedBox(height: 6),
        _chips([for (final l in rem.leads) (l['min'] as int, l['name'] as String)], mins('task', 60), (v) {
          setState(() => _set('remind', {'task': v}));
        }),
        const SizedBox(height: 12),
        Text('Событие', style: SpType.label(10.5)),
        const SizedBox(height: 6),
        _chips([for (final l in rem.leads) (l['min'] as int, l['name'] as String)], mins('event', 15), (v) {
          setState(() => _set('remind', {'event': v}));
        }),
        const SizedBox(height: 12),
        Text('День рождения', style: SpType.label(10.5)),
        const SizedBox(height: 6),
        _chips([for (final l in rem.bdayLeads) (l['min'] as int, l['name'] as String)], mins('birthday', 1440), (v) {
          setState(() => _set('remind', {'birthday': v}));
        }),
      ]),
      _card('Задачи без времени', [
        Text('Во сколько напоминать о задаче без времени', style: SpType.text(13, color: SpColors.muted)),
        const SizedBox(height: 8),
        _chips<Object>(
          [('09:00', '9:00'), ('10:00', '10:00'), ('12:00', '12:00'), ('18:00', '18:00'), ('off', 'Не напоминать')],
          hour ?? '10:00',
          (v) => setState(() => _set('remindHour', {'v': v})),
        ),
      ]),
      _card('Telegram', [
        Text(
          'Общий бот @SputnikTasksBot привязывается в старом Спутнике (Настройки → Напоминания → Telegram). '
          'Новый Спутник шлёт напоминания через тот же бот, когда он привязан.',
          style: SpType.text(13, color: SpColors.muted),
        ),
      ]),
    ];
  }

  List<Widget> _sync() => [
    _card('Google', [
      Text(
        s.needLogin
            ? 'Не выполнен вход'
            : (s.offline ? 'Нет связи' : 'Связь есть · обновлено ${s.syncedAt == null ? '—' : _hm(s.syncedAt!)}'),
        style: SpType.text(14),
      ),
      const SizedBox(height: 4),
      Text('Ждут отправки: ${s.outbox.ops.length}', style: SpType.text(13, color: SpColors.muted)),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        children: [
          FilledButton(onPressed: s.refresh, child: const Text('Обновить сейчас')),
          OutlinedButton(onPressed: s.login, child: const Text('Войти заново')),
        ],
      ),
    ]),
    _card('Слой Спутника', [
      Text(
        'Статусы, приоритеты, привычки и настройки хранятся в файле на этом компьютере и копией в скрытой папке '
        'приложения на твоём Google Диске — так их видят оба компьютера и старый Спутник.',
        style: SpType.text(13, color: SpColors.muted),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () {
          final dir = ownFile('backups').path;
          if (Platform.isWindows) Process.run('explorer', [dir]);
        },
        icon: const Icon(Icons.folder_open, size: 16),
        label: const Text('Резервные копии слоя'),
      ),
    ]),
  ];

  String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  List<Widget> _updates() => [
    _card('Версия', [
      Text('Новый Спутник $appVersion', style: SpType.text(14)),
      const SizedBox(height: 10),
      ListenableBuilder(
        listenable: updater,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(updater.status, style: SpType.text(13, color: SpColors.muted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(onPressed: updater.busy ? null : updater.check, child: const Text('Проверить')),
                if (updater.found != null)
                  FilledButton(onPressed: updater.busy ? null : updater.install, child: const Text('Обновить сейчас')),
              ],
            ),
          ],
        ),
      ),
    ]),
  ];

  List<Widget> _keys() => [
    _card('Везде', [
      for (final (k, v) in [
        ('Ctrl+1…4', 'Сегодня · Календарь · Доска · Привычки'),
        ('Ctrl+N', 'Создать'),
        ('Ctrl+K', 'Найти'),
        ('Ctrl+,', 'Настройки'),
        ('F5', 'Обновить из Google'),
      ])
        _keyRow(k, v),
    ]),
    _card('Окно «Создать»', [
      for (final (k, v) in [
        ('Alt+1…4', 'Задача · Событие · Привычка · День рождения'),
        ('Enter', 'Добавить'),
        ('Ctrl+Enter', 'Создать и ещё'),
      ])
        _keyRow(k, v),
    ]),
    _card('Календарь', [
      for (final (k, v) in [('← →', 'Неделя или месяц назад / вперёд'), ('T', 'Сегодня'), ('W / M', 'Неделя / Месяц')])
        _keyRow(k, v),
    ]),
  ];

  Widget _keyRow(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(k, style: SpType.label(12, color: SpColors.accentInk)),
        ),
        Expanded(child: Text(v, style: SpType.text(13.5))),
      ],
    ),
  );
}
