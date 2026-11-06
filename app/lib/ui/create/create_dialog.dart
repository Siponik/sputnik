// Окно «Создать» (Ctrl+N): четыре вида — задача, событие, привычка, день рождения (Alt+1…4).
// Задача — умная строка (core/route.dart parseLine + route), «Куда» угадывается, поля: колонка, приоритет, срок, напомнить, повтор.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/create.dart' as cr;
import '../../core/dates.dart';
import '../../core/reminders.dart' as rem;
import '../../core/repeat.dart' as rep;
import '../../core/route.dart' as route;
import '../../core/today.dart' as today;
import '../../state/app_state.dart';
import '../board/card_menu.dart';
import '../habits/habits_page.dart';
import '../theme/tokens.dart';
import '../widgets/task_dialog.dart';

Future<void> openCreate(
  BuildContext context,
  AppState s, {
  String kind = 'task',
  String? listId,
  String text = '',
  String? day,
  String? time,
}) => showDialog<void>(
  context: context,
  builder: (_) => _Create(s: s, kind: kind, listId: listId, text: text, day: day, time: time),
);

class _Create extends StatefulWidget {
  const _Create({required this.s, required this.kind, this.listId, this.text = '', this.day, this.time});
  final String? day;
  final String? time;
  final AppState s;
  final String kind;
  final String? listId;
  final String text;

  @override
  State<_Create> createState() => _CreateState();
}

class _CreateState extends State<_Create> {
  late String kind = widget.kind;
  late final TextEditingController line = TextEditingController(text: widget.text);
  final place = TextEditingController();
  final notes = TextEditingController();
  final year = TextEditingController();
  String? listId; // выбранный вручную
  String? col;
  int? prio;
  String? due; // выбранный вручную день
  String? time;
  int dur = 60;
  bool allDay = false;
  Set<int> remind = {};
  String? repeat;
  String calId = 'primary';
  int giftDays = 0;
  bool busy = false;

  AppState get s => widget.s;

  @override
  void initState() {
    super.initState();
    listId = widget.listId;
    due = widget.day;
    time = widget.time;
    remind = {kind == 'event' ? 15 : (kind == 'birthday' ? 1440 : 60)};
    line.addListener(() => setState(() {}));
  }

  Json get parsed => route.parseLine(line.text);

  String? get guessList {
    if (listId != null) return listId;
    final r = route.route(line.text, lists: s.boardLists.cast<Map>(), layer: s.layer, tasks: s.tasks);
    return r.isNotEmpty
        ? r.first['listId'] as String?
        : (s.boardLists.isEmpty ? null : s.boardLists.first['id'] as String);
  }

  String get day => due ?? (parsed['day'] as String?) ?? s.todayYmd;
  String? get slotS => time ?? parsed['time'] as String?;

  Future<void> _submit({bool more = false}) async {
    final p = parsed;
    final title = ((p['title'] ?? '') as String).trim();
    if (title.isEmpty || busy) return;
    var ok = true;
    switch (kind) {
      case 'task':
        final dest = guessList;
        if (dest == null) return;
        final x = today.taskFrom(p, s.todayYmd, dest);
        final patch = Json.from((x['layer'] as Map?) ?? const {});
        final st = slotS;
        if (st != null) patch['slot'] = {'s': st, 'e': cr.addMin(st, 60)};
        if (prio != null) patch['priority'] = prio;
        if (repeat != null) patch['repeat'] = {'every': repeat};
        if (remind.isNotEmpty) {
          patch['remind'] = [
            for (final m in remind) {'kind': 'lead', 'min': m},
          ];
        }
        final t = s.addTask(dest, title, due: due ?? x['due'] as String?, layerPatch: patch, col: col);
        if (notes.text.trim().isNotEmpty) s.setNotes(dest, t, notes.text.trim());
        if (listId != null) s.learnRoute(title, listId!);
        s.say('Создано в «${s.listName(dest)}»');
      case 'event':
        setState(() => busy = true);
        final st = slotS;
        ok = await s.createEvent(
          title: title,
          day: day,
          slot: allDay || st == null ? null : {'s': st, 'e': cr.addMin(st, dur)},
          notes: notes.text.trim(),
          location: place.text.trim(),
          remind: remind.toList(),
          calendarId: calId,
          recurrence: repeat == null ? null : cr.recurrenceOf({'every': repeat}),
        );
        if (ok) s.say('Событие «$title» добавлено');
      case 'birthday':
        setState(() => busy = true);
        ok = await s.createBirthday(
          name: title,
          day: day,
          year: int.tryParse(year.text.trim()),
          remind: remind.toList(),
          calendarId: calId,
          giftDays: giftDays,
          giftList: guessList,
        );
        if (ok) s.say('День рождения: $title, ${cr.dayMonth(day)}');
    }
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) return;
    if (more) {
      line.clear();
      notes.clear();
    } else {
      Navigator.pop(context);
    }
  }

  static const kinds = [
    ('task', 'Задача', SpColors.accent),
    ('event', 'Событие', SpColors.blue),
    ('habit', 'Привычка', SpColors.gold),
    ('birthday', 'День рождения', SpColors.violet),
  ];

  void _setKind(String k) {
    if (k == 'habit') {
      Navigator.pop(context);
      editHabit(context, s, null, preset: {'name': parsed['title'] ?? line.text});
      return;
    }
    setState(() {
      kind = k;
      remind = {k == 'event' ? 15 : (k == 'birthday' ? 1440 : 60)};
    });
  }

  @override
  Widget build(BuildContext context) {
    final kc = kinds.firstWhere((k) => k.$1 == kind).$3;
    final p = parsed;
    final hint = cr.suggestKind(line.text, p);
    return CallbackShortcuts(
      bindings: {
        for (final (i, k) in kinds.indexed)
          SingleActivator(LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i), alt: true): () => _setKind(k.$1),
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () => _submit(more: true),
      },
      child: Dialog(
        backgroundColor: SpColors.node,
        alignment: const Alignment(0, -.5),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  children: [
                    for (final (i, k) in kinds.indexed)
                      ChoiceChip(
                        label: Text('${k.$2}  Alt+${i + 1}'),
                        selected: kind == k.$1,
                        selectedColor: k.$3.withValues(alpha: .25),
                        onSelected: (_) => _setKind(k.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: line,
                  autofocus: true,
                  style: SpType.text(18),
                  decoration: InputDecoration(
                    hintText: switch (kind) {
                      'event' => 'Встреча с Олей в пятницу 15:00',
                      'birthday' => 'Имя',
                      _ => 'Что сделать: «отправить макет завтра 17:00 @работа !!»',
                    },
                    filled: true,
                    fillColor: SpColors.bg,
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: kc, width: 1.5)),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: kc.withValues(alpha: .5))),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                if (hint != null && hint['kind'] != kind && kind == 'task')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: InkWell(
                      onTap: () => _setKind(hint['kind'] as String),
                      child: Text(
                        'Похоже на ${hint['what']} (${hint['why']}) — сделать так?',
                        style: SpType.text(12.5, color: SpColors.accentInk),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                if (kind == 'task') ..._task(p),
                if (kind == 'event') ..._event(),
                if (kind == 'birthday') ..._bday(),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Enter — добавить · Ctrl+Enter — и ещё', style: SpType.label(10.5)),
                    TextButton(onPressed: () => _submit(more: true), child: const Text('Создать и ещё')),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: kc),
                      onPressed: busy ? null : _submit,
                      child: Text(busy ? 'Сохраняю…' : 'Добавить'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 6),
    child: Text(t.toUpperCase(), style: SpType.label(10.5)),
  );

  Widget _dayChip() => ActionChip(
    avatar: const Icon(Icons.event, size: 16),
    label: Text(humanDay(day) + (slotS != null && !allDay ? ', $slotS' : '')),
    onPressed: () async {
      final d = await showDatePicker(
        context: context,
        initialDate: DateTime.parse(day),
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (d != null) setState(() => due = ymd(d));
    },
  );

  Widget _timeChip() => ActionChip(
    avatar: const Icon(Icons.schedule, size: 16),
    label: Text(slotS ?? 'Время'),
    onPressed: () async {
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: DateTime.now().hour + 1, minute: 0),
        builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: w!),
      );
      if (t != null) {
        setState(() => time = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
      }
    },
  );

  Widget _remindChips(String k) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final l in rem.leadsFor(k))
        FilterChip(
          label: Text(l['name'] as String),
          selected: remind.contains(l['min']),
          onSelected: (on) => setState(() => on ? remind.add(l['min'] as int) : remind.remove(l['min'])),
        ),
    ],
  );

  List<Widget> _task(Json p) {
    final dest = guessList;
    final cols = dest == null ? const [] : (s.board(dest)['cols'] as List).cast<Map>();
    return [
      Row(
        children: [
          Text('Куда:', style: SpType.text(13, color: SpColors.muted)),
          const SizedBox(width: 8),
          ActionChip(
            avatar: Icon(listId == null ? Icons.auto_awesome : Icons.list, size: 15, color: SpColors.gold),
            label: Text(dest == null ? 'Нет списков' : s.listName(dest)),
            onPressed: () async {
              final to = await pickList(context, s);
              if (to != null) setState(() => listId = to);
            },
          ),
          if (listId == null && dest != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text('угадал', style: SpType.label(10.5, color: SpColors.gold)),
            ),
        ],
      ),
      if (cols.isNotEmpty) ...[
        _label('Колонка'),
        Wrap(
          spacing: 6,
          children: [
            for (final c in cols.where((c) => c['id'] != 'done'))
              ChoiceChip(
                label: Text(c['name'] as String),
                selected: (col ?? cols.first['id']) == c['id'],
                onSelected: (_) => setState(() => col = c['id'] as String),
              ),
          ],
        ),
      ],
      _label('Срок и приоритет'),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _dayChip(),
          _timeChip(),
          for (final (n, l) in [(1, '!!!'), (2, '!!'), (3, '!')])
            ChoiceChip(
              label: Text(l),
              selected: (prio ?? p['priority']) == n,
              onSelected: (on) => setState(() => prio = on ? n : null),
            ),
        ],
      ),
      _label('Напомнить'),
      _remindChips('task'),
      _label('Повтор'),
      _repeatChips(),
      _label('Заметка'),
      _notes(),
    ];
  }

  Widget _repeatChips() => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      ChoiceChip(label: const Text('Нет'), selected: repeat == null, onSelected: (_) => setState(() => repeat = null)),
      for (final r in rep.repeats)
        ChoiceChip(label: Text(r.label), selected: repeat == r.id, onSelected: (_) => setState(() => repeat = r.id)),
    ],
  );

  Widget _notes() => TextField(
    controller: notes,
    minLines: 2,
    maxLines: 6,
    decoration: const InputDecoration(filled: true, fillColor: SpColors.bg, hintText: 'Необязательно'),
  );

  Widget _calPick() {
    final cals = s.writableCals;
    if (cals.length < 2) return const SizedBox();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final c in cals)
          ChoiceChip(
            label: Text((c['summaryOverride'] ?? c['summary'] ?? '') as String),
            selected: calId == c['id'] || (calId == 'primary' && c['primary'] == true),
            onSelected: (_) => setState(() => calId = c['id'] as String),
          ),
      ],
    );
  }

  List<Widget> _event() {
    final st = slotS;
    final free = st == null || allDay ? null : cr.freeCheck(s.eventsOn(day), day, {'s': st, 'e': cr.addMin(st, dur)});
    return [
      _label('Когда'),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _dayChip(),
          if (!allDay) _timeChip(),
          for (final (m, l) in [(15, '15 мин'), (30, '30 мин'), (60, '1 час'), (120, '2 часа')])
            ChoiceChip(
              label: Text(l),
              selected: !allDay && dur == m,
              onSelected: (_) => setState(() {
                allDay = false;
                dur = m;
              }),
            ),
          ChoiceChip(label: const Text('Весь день'), selected: allDay, onSelected: (v) => setState(() => allDay = v)),
        ],
      ),
      if (free != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            free['clash'] != null
                ? 'Пересекается: ${free['clash']}'
                : (free['until'] != null ? 'Свободно до ${free['until']}' : 'Свободно'),
            style: SpType.text(12.5, color: free['clash'] != null ? SpColors.red : SpColors.green),
          ),
        ),
      _label('Календарь'),
      _calPick(),
      _label('Место'),
      TextField(
        controller: place,
        decoration: const InputDecoration(filled: true, fillColor: SpColors.bg, hintText: 'Адрес или ссылка'),
      ),
      _label('Напомнить'),
      _remindChips('event'),
      _label('Повтор'),
      _repeatChips(),
      _label('Заметка'),
      _notes(),
    ];
  }

  List<Widget> _bday() => [
    _label('Дата'),
    Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _dayChip(),
        SizedBox(
          width: 140,
          child: TextField(
            controller: year,
            decoration: const InputDecoration(isDense: true, hintText: 'Год (необяз.)'),
          ),
        ),
      ],
    ),
    _label('Напомнить'),
    _remindChips('birthday'),
    _label('Задача «Подарок» заранее'),
    Wrap(
      spacing: 6,
      children: [
        for (final d in [0, 3, 7, 14, 30])
          ChoiceChip(
            label: Text(d == 0 ? 'Не нужна' : 'за $d дн.'),
            selected: giftDays == d,
            onSelected: (_) => setState(() => giftDays = d),
          ),
      ],
    ),
    _label('Календарь'),
    _calPick(),
  ];
}
