// Окно «Создать» (Ctrl+N): четыре вида — задача, событие, привычка, день рождения (Alt+1…4).
// Задача — умная строка (core/route.dart parseLine + route), «Куда» угадывается, поля: колонка, приоритет, срок, напомнить, повтор.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/create.dart' as cr;
import '../../core/reminders.dart' as rem;
import '../../core/repeat.dart' as rep;
import '../../core/route.dart' as route;
import '../../core/today.dart' as today;
import '../../state/app_state.dart';
import '../board/card_menu.dart';
import '../habits/habits_page.dart';
import '../keys.dart';
import '../widgets/date_time_picker.dart';
import '../theme/tokens.dart';
import '../widgets/task_dialog.dart';
import '../g/kit.dart';
import '../today/today_page.dart' show listHue;

/// Одно окно «Создать». [kinds] — какие виды можно выбрать (один — вместо переключателя заголовок),
/// [kind] — вид при открытии, [preset] — заранее выбранные поля (`col`, `topic`), [text] — строка из «Сегодня».
Future<void> openCreate(
  BuildContext context,
  AppState s, {
  String kind = 'task',
  List<String> kinds = const ['task', 'event', 'habit', 'birthday'],
  String? listId,
  String text = '',
  String? day,
  String? time,
  Json preset = const {},
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      _Create(s: s, kind: kind, kinds: kinds, listId: listId, text: text, day: day, time: time, preset: preset),
);

class _Create extends StatefulWidget {
  const _Create({
    required this.s,
    required this.kind,
    required this.kinds,
    this.listId,
    this.text = '',
    this.day,
    this.time,
    this.preset = const {},
  });
  final List<String> kinds;
  final Json preset;
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
  bool extra = false;
  bool help = false;
  Set<String> opened = {};
  final subs = <String>[];
  final sub = TextEditingController();

  /// Открыть параметр из «Ещё» и запомнить, что его открывают.
  void _open(String k) {
    if (opened.contains(k)) return;
    setState(() => opened.add(k));
    final used = ((s.layer['settings'] as Map?)?['createMore'] as Map?) ?? const {};
    s.touch('settings', 'createMore', {k: ((used[k] as num?) ?? 0) + 1});
  }

  AppState get s => widget.s;

  @override
  void initState() {
    super.initState();
    listId = widget.listId;
    col = widget.preset['col'] as String?;
    due = widget.day;
    // «Ещё параметры»: что человек открывает чаще, показываем сразу.
    final used = ((s.layer['settings'] as Map?)?['createMore'] as Map?) ?? const {};
    opened = {
      for (final e in used.entries)
        if (e.value is num && (e.value as num) >= 2) e.key as String,
    };
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
        if (prio != null && prio != 0) patch['priority'] = prio;
        if (repeat != null) patch['repeat'] = {'every': repeat};
        if (remind.isNotEmpty) {
          patch['remind'] = [
            for (final m in remind) {'kind': 'lead', 'min': m},
          ];
        }
        final t = s.addTask(dest, title, due: due ?? x['due'] as String?, layerPatch: patch, col: col);
        if (notes.text.trim().isNotEmpty) s.setNotes(dest, t, notes.text.trim());
        for (final x in subs) {
          s.addSubtask(dest, t['id'] as String, x);
        }
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
      subs.clear();
    } else {
      Navigator.pop(context);
    }
  }

  static final allKinds = [
    ('task', 'Задача', SpColors.accent, Icons.check),
    ('event', 'Событие', SpColors.blue, Icons.schedule),
    ('habit', 'Привычка', SpColors.gold, Icons.autorenew),
    ('birthday', 'День рождения', SpColors.violet, Icons.auto_awesome),
  ];
  List<(String, String, Color, IconData)> get kinds => [
    for (final k in allKinds)
      if (widget.kinds.contains(k.$1)) k,
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
    final kc = allKinds.firstWhere((k) => k.$1 == kind).$3;
    final p = parsed;
    final hint = cr.suggestKind(line.text, p);
    return CallbackShortcuts(
      bindings: {
        for (final (i, k) in kinds.indexed) PKey(digits[i], alt: true): () => _setKind(k.$1),
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () => _submit(more: true),
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        alignment: const Alignment(0, -.6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth > 700;
              final fields = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (kind == 'task') ..._task(p),
                  if (kind == 'event') ..._event(),
                  if (kind == 'birthday') ..._bday(),
                ],
              );
              return GNode(
                hub: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: headFill(kc),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                      ),
                      child: Row(
                        children: [
                          if (kinds.length > 1)
                            for (final (i, k) in kinds.indexed)
                              Expanded(
                                child: InkWell(
                                  onTap: () => _setKind(k.$1),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    height: 32,
                                    margin: const EdgeInsets.symmetric(horizontal: 2),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: kind == k.$1 ? SpColors.ink : null,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(k.$4, size: 14, color: kind == k.$1 ? kc : Colors.white),
                                          const SizedBox(width: 7),
                                          Text(
                                            k.$2,
                                            style: SpType.text(
                                              13,
                                              w: FontWeight.w500,
                                              color: kind == k.$1 ? SpColors.bg : Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 7),
                                          Text(
                                            'ALT ${i + 1}',
                                            style: gMicro(c: kind == k.$1 ? SpColors.muted : Colors.white70),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              )
                          else
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  '${kinds.first.$2}${line.text.trim().isEmpty ? '' : ' · ${line.text.trim()}'}',
                                  style: gLbl(c: Colors.white, size: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.close, size: 18, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: line,
                              autofocus: true,
                              style: SpType.text(17),
                              decoration: InputDecoration(
                                hintText: switch (kind) {
                                  'event' => 'Что за событие? Например: встреча с Олей в пятницу 15:00',
                                  'birthday' => 'Чей день рождения? Имя и дата',
                                  _ => 'Что сделать? Пиши как в заметке: «завтра 17:00 @работа !!»',
                                },
                                suffixIcon: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: InkWell(
                                    onTap: () => setState(() => help = !help),
                                    customBorder: const CircleBorder(),
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: help ? kc : SpColors.line),
                                      ),
                                      child: Text('?', style: gMono(11, c: help ? kc : SpColors.muted)),
                                    ),
                                  ),
                                ),
                                hintStyle: SpType.text(17, color: SpColors.dim),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: kc, width: 1.3),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: kc.withValues(alpha: .6)),
                                ),
                              ),
                              onSubmitted: (_) => _submit(),
                            ),
                            if (help)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  kind == 'birthday' ? 'Имя и дату — остальное подставлю сам.' : 'Пиши как в заметке: «в пятницу», «каждую неделю», «@работа», «!!!». Остальное подставлю сам.',
                                  style: SpType.text(12, color: SpColors.muted),
                                ),
                              ),
                            if (hint != null && hint['kind'] != kind && kind == 'task')
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: InkWell(
                                  onTap: () => _setKind(hint['kind'] as String),
                                  child: Text(
                                    'Похоже на ${hint['what']} (${hint['why']}) — сделать так?',
                                    style: SpType.text(12.5, color: SpColors.accent),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 6),
                            if (wide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: fields),
                                  const SizedBox(width: 24),
                                  SizedBox(width: 280, child: _preview(p, kc)),
                                ],
                              )
                            else
                              fields,
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: SpColors.line)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Enter — добавить · Esc — закрыть',
                              style: SpType.text(12, color: SpColors.muted),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GBtn('Добавить и ещё', kind: BtnKind.sec, onTap: () => _submit(more: true)),
                          const SizedBox(width: 10),
                          GBtn(
                            busy
                                ? 'Сохраняю…'
                                : switch (kind) {
                                    'event' => 'Добавить событие',
                                    'birthday' => 'Сохранить',
                                    _ => 'Добавить задачу',
                                  },
                            kind: BtnKind.acc,
                            onTap: busy ? null : _submit,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _preview(Json p, Color kc) {
    final title = ((p['title'] ?? '') as String).trim();
    final dest = kind == 'task' ? guessList : null;
    final cols = dest == null ? const <Map>[] : (s.board(dest)['cols'] as List).cast<Map>();
    final c = col ?? (cols.isEmpty ? null : cols.first['id']);
    final colName = cols.where((x) => x['id'] == c).firstOrNull?['name'] as String?;
    final idx = cols.indexWhere((x) => x['id'] == c);
    final when = '${humanDay(day)}${slotS != null && !allDay ? ' в $slotS' : ''}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(kind == 'task' ? 'Так появится на доске' : 'Так появится в календаре'),
        GNode(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GHead(
                name: kind == 'task'
                    ? (dest == null ? '—' : s.listName(dest))
                    : (kind == 'event' ? 'Событие' : 'День рождения'),
                color: kind == 'task' ? listHue(s, dest ?? '') : kc,
                kind: kind == 'task' ? colName : null,
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: SpColors.bg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: SpColors.line),
                      ),
                      child: Text(
                        title.isEmpty ? '·' : title.characters.first.toUpperCase(),
                        style: gMono(13, c: SpColors.ink, w: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title.isEmpty ? 'Название' : title,
                            style: SpType.text(
                              13.5,
                              w: FontWeight.w600,
                              color: title.isEmpty ? SpColors.dim : SpColors.ink,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(when, style: SpType.text(12, color: SpColors.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (kind == 'task' && cols.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      for (var i = 0; i < cols.length; i++) ...[
                        if (i > 0) const SizedBox(width: 4),
                        Expanded(
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: i < idx ? SpColors.green : (i == idx ? SpColors.accent : SpColors.line),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        CoonTip(
          pose: 'think',
          color: kc,
          text: switch (kind) {
            'event' => 'Напомню заранее, а пересечения покажу сразу.',
            'birthday' => 'Могу завести задачу «Подарок» за неделю до дня.',
            _ =>
              dest == null
                  ? 'Сначала заведи список.'
                  : 'Положу в «${s.listName(dest)}». Не туда — выбери другой список.',
          },
        ),
      ],
    );
  }

  /// Строка поля: подпись слева (104 px), чипы справа.
  Widget _row(String label, Widget child) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(label, style: SpType.text(13, color: SpColors.muted)),
          ),
        ),
        Expanded(child: child),
      ],
    ),
  );

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 8),
    child: Text(
      t,
      style: SpType.text(12.5, color: SpColors.muted, w: FontWeight.w500),
    ),
  );

  Widget _dayChip() => GPick(
    due == '' ? 'Выбрать день' : humanDay(day) + (slotS != null && !allDay ? ' · $slotS' : ''),
    on: due != '',
    onTap: () => _pick(withTime: kind != 'birthday'),
  );

  Future<void> _pick({bool withTime = true}) async {
    final r = await pickDateTime(
      context,
      day: day,
      time: slotS,
      withTime: withTime && !allDay,
      withEnd: false,
      allowClear: false,
      title: kind == 'event' ? 'Когда' : 'Срок',
      busy: (d) => busyHours(s, d),
    );
    if (r == null || !mounted) return;
    setState(() {
      if (r.day != null) due = r.day;
      if (withTime && !allDay) time = r.time;
    });
  }

  Widget _timeChip() => GPick(slotS == null ? '+ время' : 'Другое время', onTap: _pick);

  Widget _remindChips(String k) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final l
          in rem
              .leadsFor(k)
              .where((l) => extra || remind.contains(l['min']) || const [60, 1440, 15, 0].contains(l['min'])))
        GPick(
          l['name'] as String,
          on: remind.contains(l['min']),
          onTap: () =>
              setState(() => remind.contains(l['min']) ? remind.remove(l['min']) : remind.add(l['min'] as int)),
        ),
    ],
  );

  List<Widget> _task(Json p) {
    final dest = guessList;
    final cols = dest == null ? const [] : (s.board(dest)['cols'] as List).cast<Map>();
    final why = listId == null && dest != null ? _why(dest) : null;
    return [
      _row(
        'Куда',
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            InkWell(
              onTap: _otherList,
              borderRadius: BorderRadius.circular(SpRadius.button),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: SpColors.bg.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(SpRadius.button),
                  border: Border.all(color: SpColors.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (dest != null) ...[GDot(listHue(s, dest)), const SizedBox(width: 8)],
                    Text(dest == null ? 'Нет списков' : s.listName(dest), style: SpType.text(13, w: FontWeight.w600)),
                    if (why != null) ...[
                      const SizedBox(width: 8),
                      Text(why, style: SpType.text(12, color: SpColors.gold)),
                    ],
                    const SizedBox(width: 6),
                    Icon(Icons.arrow_drop_down, size: 16, color: SpColors.muted),
                  ],
                ),
              ),
            ),
            Text('Alt L', style: SpType.text(12, color: SpColors.accent)),
          ],
        ),
      ),
      _row(
        'Когда',
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _dayChip(),
            GPick('Без срока', on: due == '', onTap: () => setState(() => due = '')),
          ],
        ),
      ),
      if (cols.isNotEmpty)
        _row(
          s.board(dest!)['view'] == 'pipe' ? 'Этап' : 'Колонка',
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in cols.where((c) => c['id'] != 'done'))
                GPick(
                  c['name'] as String,
                  on: (col ?? cols.first['id']) == c['id'],
                  onTap: () => setState(() => col = c['id'] as String),
                ),
            ],
          ),
        ),
      _row('Напомнить', _remindChips('task')),
      _more([
        ('prio', 'Приоритет', _row('Приоритет', _prioChips(p))),
        ('subs', 'Подзадачи', _row('Подзадачи', _subs())),
        ('repeat', 'Повтор', _row('Повтор', _repeatChips())),
        ('notes', 'Заметка', _row('Заметка', _notes())),
      ]),
    ];
  }

  String? _why(String dest) {
    final r = route.route(line.text, lists: s.boardLists.cast<Map>(), layer: s.layer, tasks: s.tasks);
    final w = r.isEmpty ? null : r.first['why'];
    return w is String && w.isNotEmpty ? w : null;
  }

  Future<void> _otherList() async {
    final to = await pickList(context, s);
    if (to != null) setState(() => listId = to);
  }

  Widget _prioChips(Json p) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final (n, l) in [(1, '!!! Высокий'), (2, '!! Средний'), (3, '! Низкий'), (0, 'Нет')])
        GPick(l, on: (prio ?? p['priority'] ?? 0) == n, onTap: () => setState(() => prio = n)),
    ],
  );

  Widget _subs() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (i, x) in subs.indexed)
        Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              GCheck(done: false),
              const SizedBox(width: 8),
              Expanded(child: Text(x, style: SpType.text(13))),
              InkWell(
                onTap: () => setState(() => subs.removeAt(i)),
                child: Text('×', style: gMono(12, c: SpColors.muted)),
              ),
            ],
          ),
        ),
      TextField(
        controller: sub,
        style: SpType.text(13),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: '+ подзадача',
          hintStyle: SpType.text(13, color: SpColors.dim),
        ),
        onSubmitted: (v) {
          if (v.trim().isEmpty) return;
          setState(() => subs.add(v.trim()));
          sub.clear();
        },
      ),
    ],
  );

  /// «▾ Ещё параметры»: открытые параметры строками, остальные — кнопками «+ …».
  Widget _more(List<(String, String, Widget)> items) {
    final shown = items.where((x) => opened.contains(x.$1) || _filled(x.$1)).toList();
    final rest = items.where((x) => !shown.contains(x)).toList();
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SpColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => extra = !extra),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  Text('${extra ? '▾' : '▸'} Ещё параметры', style: SpType.text(13, w: FontWeight.w600)),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'открыто ${shown.length} из ${items.length} · запомню, какие ты открываешь',
                      style: SpType.text(12, color: SpColors.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (extra || shown.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final x in shown) x.$3,
                  if (extra && rest.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Divider(height: 1, color: SpColors.line),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final x in rest)
                          InkWell(
                            onTap: () => _open(x.$1),
                            borderRadius: BorderRadius.circular(SpRadius.button),
                            child: Dashed(
                              r: SpRadius.button,
                              color: SpColors.line,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                                child: Text('+ ${x.$2}', style: SpType.text(12.5, color: SpColors.ink2)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool _filled(String k) => switch (k) {
    'prio' => prio != null && prio != 0,
    'subs' => subs.isNotEmpty,
    'repeat' => repeat != null,
    'notes' => notes.text.isNotEmpty,
    _ => false,
  };

  Widget _repeatChips() => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      GPick('Нет', on: repeat == null, onTap: () => setState(() => repeat = null)),
      for (final r in rep.repeats) GPick(r.label, on: repeat == r.id, onTap: () => setState(() => repeat = r.id)),
    ],
  );

  Widget _notes() => TextField(
    controller: notes,
    minLines: 2,
    maxLines: 6,
    style: SpType.text(13.5),
    decoration: InputDecoration(
      hintText: 'Необязательно',
      hintStyle: SpType.text(13.5, color: SpColors.dim),
      contentPadding: const EdgeInsets.all(12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: SpColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: SpColors.accent),
      ),
    ),
  );

  Widget _calPick() {
    final cals = s.writableCals;
    if (cals.length < 2) return const SizedBox();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final c in cals)
          GPick(
            (c['summaryOverride'] ?? c['summary'] ?? '') as String,
            on: calId == c['id'] || (calId == 'primary' && c['primary'] == true),
            color: SpColors.blue,
            onTap: () => setState(() => calId = c['id'] as String),
          ),
      ],
    );
  }

  List<Widget> _event() {
    final st = slotS;
    final free = st == null || allDay ? null : cr.freeCheck(s.eventsOn(day), day, {'s': st, 'e': cr.addMin(st, dur)});
    return [
      _row(
        'Когда',
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _dayChip(),
            if (!allDay) _timeChip(),
            for (final (m, l) in [(15, '15 мин'), (30, '30 мин'), (60, '1 час'), (120, '2 часа')])
              GPick(
                l,
                on: !allDay && dur == m,
                onTap: () => setState(() {
                  allDay = false;
                  dur = m;
                }),
              ),
            GPick('Весь день', on: allDay, onTap: () => setState(() => allDay = !allDay)),
          ],
        ),
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
      if (s.writableCals.length > 1) _row('Календарь', _calPick()),
      _row(
        'Место',
        TextField(
          controller: place,
          style: SpType.text(13.5),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Адрес или ссылка',
            hintStyle: SpType.text(13.5, color: SpColors.dim),
            contentPadding: const EdgeInsets.all(11),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: SpColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: SpColors.accent),
            ),
          ),
        ),
      ),
      _row('Напомнить', _remindChips('event')),
      _more([('repeat', 'Повтор', _row('Повтор', _repeatChips())), ('notes', 'Заметка', _row('Заметка', _notes()))]),
    ];
  }

  List<Widget> _bday() => [
    _row(
      'Дата',
      Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _dayChip(),
          SizedBox(
            width: 140,
            child: TextField(
              controller: year,
              style: SpType.text(13.5),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Год, если знаешь',
                hintStyle: SpType.text(13.5, color: SpColors.dim),
                contentPadding: const EdgeInsets.all(11),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: SpColors.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: SpColors.accent),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    _row('Напомнить', _remindChips('birthday')),
    _row(
      'Подарок',
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final d in [0, 3, 7, 14, 30])
            GPick(d == 0 ? 'Не нужен' : 'за $d дн.', on: giftDays == d, onTap: () => setState(() => giftDays = d)),
        ],
      ),
    ),
    if (s.writableCals.length > 1) _row('Календарь', _calPick()),
  ];
}
