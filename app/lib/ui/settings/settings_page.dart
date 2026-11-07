// Настройки (Ctrl+,): Вид, Что показывать, Напоминания, Синхронизация, Обновления, Клавиши.
// Всё хранится в слое (settings.*, lists[id].hidden, cals[id].hidden) — общее со старым трекером.
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/reminders.dart' as rem;
import '../../data/paths.dart';
import '../../state/app_state.dart';
import '../../state/updater.dart';
import '../theme/tokens.dart';
import '../g/kit.dart';

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
  Widget build(BuildContext context) => DotGround(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 240,
            child: GNode(
              child: Column(
                children: [
                  GHead(
                    name: 'Настройки',
                    trailing: Text('CTRL ,', style: gMicro()),
                  ),
                  const SizedBox(height: 10),
                  for (final (i, n) in secs.indexed)
                    InkWell(
                      onTap: () => setState(() => sec = i),
                      child: Container(
                        height: 36,
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: sec == i ? SpColors.accentWash : Colors.transparent,
                          borderRadius: BorderRadius.circular(SpRadius.button),
                          border: Border.all(color: sec == i ? SpColors.accent : Colors.transparent),
                        ),
                        child: Row(
                          children: [
                            Text((i + 1).toString().padLeft(2, '0'), style: gMicro()),
                            const SizedBox(width: 10),
                            Text(n.toUpperCase(), style: gLbl(c: sec == i ? SpColors.ink : SpColors.muted)),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('СПУТНИК $appVersion · БЕТА', style: gMicro()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: GNode(
                    hub: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GHead(hub: true, num: (sec + 1).toString().padLeft(2, '0'), name: secs[sec]),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: switch (sec) {
                              0 => _view(),
                              1 => _show(),
                              2 => _remind(),
                              3 => _sync(),
                              4 => _updates(),
                              _ => _keys(),
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _card(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Padding(
            padding: const EdgeInsets.only(top: 8, right: 10),
            child: Text(title.toUpperCase(), style: gLbl(c: SpColors.muted)),
          ),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      ],
    ),
  );

  Widget _chips<T>(List<(T, String)> opts, T cur, void Function(T) on) {
    if (opts.length <= 5 && opts.fold<int>(0, (a, o) => a + o.$2.length) < 48) {
      final i = opts.indexWhere((o) => o.$1 == cur);
      return GSeg(items: [for (final o in opts) o.$2], active: i, onTap: (k) => on(opts[k].$1));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final (v, l) in opts) GPick(l, on: cur == v, onTap: () => on(v))],
    );
  }

  Widget _toggle(String text, bool on, void Function(bool) set, {Color? dot}) =>
      GChip(text, on: on, dot: dot ?? (on ? SpColors.accent : SpColors.dim), onTap: () => set(!on));

  void _set(String key, Json patch) => s.touch('settings', key, patch);

  List<Widget> _view() {
    final start = ((settings['start'] as Map?)?['v'] ?? 'last') as String;
    final motion = ((settings['motion'] as Map?)?['v'] ?? 'full') as String;
    return [
      _card('При запуске', [
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
        GSeg(items: const ['Тёмная'], active: 0, onTap: (_) {}),
        const SizedBox(height: 6),
        Text('Светлая тема появится позже.', style: SpType.text(12.5, color: SpColors.muted)),
      ]),
    ];
  }

  List<Widget> _show() => [
    _card('Списки', [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final l in s.lists)
            _toggle(
              (l['title'] ?? '') as String,
              s.layList(l['id'] as String)['hidden'] != true,
              (v) => setState(() => s.setListField(l['id'] as String, {'hidden': !v})),
            ),
        ],
      ),
    ]),
    _card('Календари', [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in s.calendars.where((c) => !((c['summary'] ?? '') as String).startsWith('Спутник · ')))
            _toggle((c['summaryOverride'] ?? c['summary'] ?? '') as String, s.calShown(c), (v) {
              s.touch('cals', c['id'] as String, {'hidden': !v});
              s.refresh();
              setState(() {});
            }),
        ],
      ),
    ]),
    Text('СКРЫТЫЕ СПИСКИ НЕ ПОПАДАЮТ В «СЕГОДНЯ», КАЛЕНДАРЬ И НАПОМИНАНИЯ', style: gMicro()),
  ];

  List<Widget> _remind() {
    final r = ((settings['remind'] as Map?) ?? const {}).cast<String, dynamic>();
    int mins(String k, int def) => (r[k] as num?)?.toInt() ?? def;
    final hour = settings['remindHour'] is Map ? (settings['remindHour'] as Map)['v'] : null;
    return [
      _card('По умолчанию', [
        Text('ЗАДАЧА', style: gMicro()),
        const SizedBox(height: 6),
        _chips([for (final l in rem.leads) (l['min'] as int, l['name'] as String)], mins('task', 60), (v) {
          setState(() => _set('remind', {'task': v}));
        }),
        const SizedBox(height: 12),
        Text('СОБЫТИЕ', style: gMicro()),
        const SizedBox(height: 6),
        _chips([for (final l in rem.leads) (l['min'] as int, l['name'] as String)], mins('event', 15), (v) {
          setState(() => _set('remind', {'event': v}));
        }),
        const SizedBox(height: 12),
        Text('ДЕНЬ РОЖДЕНИЯ', style: gMicro()),
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
      _card('Telegram', [_Tg(s: s)]),
      _card('Уведомления Windows', [
        _chips(
          [(true, 'Показывать'), (false, 'Не показывать')],
          ((settings['notify'] as Map?)?['v']) != false,
          (v) => setState(() => _set('notify', {'v': v})),
        ),
        const SizedBox(height: 6),
        Text('Окно привычки; задачи — если Telegram не привязан', style: SpType.text(12.5, color: SpColors.muted)),
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
          GBtn('Обновить сейчас', kind: BtnKind.acc, onTap: s.refresh),
          GBtn('Войти заново', onTap: s.login),
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
      GBtn(
        'Резервные копии слоя',
        onTap: () {
          final dir = ownFile('backups').path;
          if (Platform.isWindows) Process.run('explorer', [dir]);
        },
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
                GBtn('Проверить', onTap: updater.busy ? null : updater.check),
                if (updater.found != null)
                  GBtn('Обновить сейчас', kind: BtnKind.acc, onTap: updater.busy ? null : updater.install),
              ],
            ),
          ],
        ),
      ),
    ]),
    _card('Как ставить', [
      _toggle(
        'Проверять и предлагать сами',
        ((settings['update'] as Map?)?['auto']) != false,
        (v) => setState(() => _set('update', {'auto': v})),
      ),
    ]),
  ];

  static const _allKeys = [
    (
      'Везде',
      [
        ('1 … 4', 'Сегодня · Календарь · Доска · Привычки'),
        ('Q / E', 'Раздел левее / правее'),
        ('Ctrl+1 … 5', 'Разделы, «Знания» — пятый'),
        ('N, Ctrl+N', 'Создать'),
        ('/, Ctrl+K', 'Найти'),
        ('R, F5', 'Обновить из Google'),
        ('[ ]', 'Предыдущий / следующий список'),
        ('F', 'Архив списка'),
        ('Ctrl+,', 'Настройки'),
      ],
    ),
    (
      'Окно «Создать»',
      [
        ('Alt+1 … 4', 'Задача · Событие · Привычка · День рождения'),
        ('Enter', 'Добавить'),
        ('Ctrl+Enter', 'Создать и ещё'),
        ('Esc', 'Закрыть'),
      ],
    ),
    (
      'Календарь',
      [
        ('← →', 'Неделя или месяц назад / вперёд'),
        ('T', 'Сегодня'),
        ('W / M', 'Неделя / Месяц'),
        ('A', 'Добавить на выбранный день'),
      ],
    ),
    ('Конвейер', [('Space', 'Следующий ассет'), ('Enter', 'Окно задачи'), ('Esc', 'Свернуть строку')]),
    ('Привычки', [('Shift+1 … 9', 'Отметить привычку по порядку')]),
    ('Поиск', [('↑ ↓', 'Выбрать'), ('Enter', 'Открыть'), ('Esc', 'Закрыть')]),
  ];

  String keyQuery = '';

  List<Widget> _keys() {
    final q = keyQuery.trim().toLowerCase().replaceAll('ё', 'е');
    bool hit(String a, String b) => q.isEmpty || '$a $b'.toLowerCase().replaceAll('ё', 'е').contains(q);
    return [
      TextField(
        style: SpType.text(13.5),
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Icons.search, size: 16, color: SpColors.muted),
          hintText: 'Найти клавишу или действие',
          hintStyle: SpType.text(13.5, color: SpColors.dim),
        ),
        onChanged: (v) => setState(() => keyQuery = v),
      ),
      const SizedBox(height: 6),
      Text(
        'Клавиши работают в любой раскладке; одиночные молчат, пока курсор в поле ввода.',
        style: SpType.text(12.5, color: SpColors.muted),
      ),
      for (final (g, rows) in _allKeys)
        if (rows.any((r) => hit(r.$1, r.$2) || hit(g, '')))
          _card(g, [
            for (final (k, v) in rows)
              if (hit(k, v) || hit(g, '')) _keyRow(k, v),
          ]),
    ];
  }

  Widget _keyRow(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(k, style: gMono(11.5, c: SpColors.accent)),
        ),
        Expanded(child: Text(v, style: SpType.text(13.5))),
      ],
    ),
  );
}

class _Tg extends StatefulWidget {
  const _Tg({required this.s});
  final AppState s;
  @override
  State<_Tg> createState() => _TgState();
}

class _TgState extends State<_Tg> {
  final code = TextEditingController();
  String? err;
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final linked = (s.botKey ?? '').isNotEmpty;
    if (linked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Подключён @SputnikTasksBot — напоминания и задачи на неделю идут туда', style: SpType.text(13.5)),
          if (s.botErr.isNotEmpty) Text(s.botErr, style: SpType.text(12.5, color: SpColors.red)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              GBtn('Проверить', onTap: s.botTest),
              GBtn(
                'Отключить',
                kind: BtnKind.ghost,
                onTap: () async {
                  await s.botUnlink();
                  setState(() {});
                },
              ),
            ],
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Открой @SputnikTasksBot в Telegram, нажми /start и введи сюда код из 6 цифр.', style: SpType.text(13.5)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            SizedBox(
              width: 160,
              child: TextField(
                controller: code,
                decoration: const InputDecoration(hintText: '123456', isDense: true),
              ),
            ),
            GBtn(
              'Подключить',
              kind: BtnKind.acc,
              onTap: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      final e = await s.botLinkCode(code.text);
                      if (mounted) {
                        setState(() {
                          busy = false;
                          err = e;
                        });
                      }
                    },
            ),
          ],
        ),
        if (err != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(err!, style: SpType.text(12.5, color: SpColors.red)),
          ),
      ],
    );
  }
}
