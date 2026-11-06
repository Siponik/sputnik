// Окно задачи (упрощённое): название, колонка, приоритет, срок, заметка, удалить.
import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/notes/parse.dart' show baseName, folderOf;
import '../../core/notes/tasks.dart' show notesForTask;
import '../../state/app_state.dart';
import '../theme/tokens.dart';
import '../../core/reminders.dart' as rem;
import '../../core/repeat.dart' as repeats;
import '../board/card_menu.dart';
import '../g/kit.dart';
import '../today/today_page.dart' show listHue;

Future<void> openTask(BuildContext context, AppState s, String listId, Json t) => showDialog<void>(
  context: context,
  barrierColor: const Color(0x88000000),
  builder: (_) => _TaskDialog(s: s, listId: listId, id: t['id'] as String),
);

class _TaskDialog extends StatefulWidget {
  const _TaskDialog({required this.s, required this.listId, required this.id});
  final AppState s;
  final String listId;
  final String id;

  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  late final TextEditingController title;
  late final TextEditingController notes;

  Json? get t => widget.s.task(widget.listId, widget.id);

  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: (t?['title'] ?? '') as String);
    notes = TextEditingController(text: (t?['notes'] ?? '') as String);
  }

  void _commit() {
    final x = t;
    if (x == null) return;
    if (title.text.trim().isNotEmpty && title.text != x['title']) widget.s.rename(widget.listId, x, title.text.trim());
    if (notes.text != (x['notes'] ?? '')) widget.s.setNotes(widget.listId, x, notes.text);
  }

  @override
  void dispose() {
    _commit();
    title.dispose();
    notes.dispose();
    super.dispose();
  }

  bool more = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final x = t;
        if (x == null) return const SizedBox();
        final id = widget.id;
        final L = s.layTask(id);
        final cols = (s.board(widget.listId)['cols'] as List).cast<Map>();
        final cur = s.colOf(x, cols);
        final prio = (L['priority'] as num?)?.toInt();
        final due = dueToYmd(x['due'] as String?);
        final slot = L['slot'] as Map?;
        final fields = (s.board(widget.listId)['fields'] as List?) ?? const [];
        final view = s.board(widget.listId)['view'];
        final subs = s.subtasks(widget.listId, id);
        final rules = L['remind'] is List ? (L['remind'] as List) : (L['remind'] is Map ? [L['remind']] : const []);
        final mins = <int>{
          for (final r in rules)
            if (r is Map && r['kind'] == 'lead') (r['min'] as num).toInt(),
        };
        void setMins(Set<int> next) => s.setTask(id, {
          'remind': next.isEmpty
              ? null
              : [
                  for (final m in next) {'kind': 'lead', 'min': m},
                ],
        });
        final narrow = MediaQuery.sizeOf(context).width < 700;
        Widget row(String label, Widget child) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 106,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(label.toUpperCase(), style: gLbl(c: SpColors.muted)),
                ),
              ),
              Expanded(child: child),
            ],
          ),
        );
        Widget chip(String text, bool on, VoidCallback tap, {VoidCallback? x}) => InkWell(
          onTap: tap,
          borderRadius: BorderRadius.circular(SpRadius.button),
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: on ? SpColors.accentWash : Colors.transparent,
              borderRadius: BorderRadius.circular(SpRadius.button),
              border: Border.all(color: on ? SpColors.accent : SpColors.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(text.toUpperCase(), style: gLbl(c: on ? SpColors.ink : SpColors.muted)),
                if (x != null) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: x,
                    child: Text('×', style: gMono(12, c: SpColors.ink)),
                  ),
                ],
              ],
            ),
          ),
        );
        final open = cols.where((c) => c['id'] == cur).firstOrNull;
        final inCol = open == null
            ? 0
            : s.topTasks(widget.listId).where((t2) => s.colOf(t2, cols) == open['id']).length;
        final leadName = {for (final l in rem.leads) l['min'] as int: l['name'] as String};
        final panel = GNode(
          hub: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Куда · ⋯ · ✕
              Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: SpColors.line)),
                ),
                child: Row(
                  children: [
                    Text('КУДА', style: gMicro()),
                    const SizedBox(width: 10),
                    Flexible(
                      child: GPick(
                        '${s.listName(widget.listId)}  ▾',
                        dot: listHue(s, widget.listId),
                        onTap: () async {
                          final to = await pickList(context, s, exclude: widget.listId);
                          if (to == null || !context.mounted) return;
                          Navigator.pop(context);
                          s.moveToList(widget.listId, x, to);
                        },
                      ),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      tooltip: 'Ещё',
                      color: SpColors.node,
                      onSelected: (v) {
                        if (v == 'del') {
                          Navigator.pop(context);
                          s.remove(widget.listId, x);
                        } else if (v == 'done') {
                          s.toggleDone(widget.listId, x);
                        } else if (v == 'dup') {
                          s.addTask(widget.listId, '${x['title']} (копия)', due: x['due'] as String?);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'done',
                          child: Text(s.isDone(x) ? 'Вернуть в работу' : 'Отметить сделанной', style: SpType.text(13)),
                        ),
                        PopupMenuItem(
                          value: 'dup',
                          child: Text('Дублировать', style: SpType.text(13)),
                        ),
                        PopupMenuItem(
                          value: 'del',
                          child: Text('Удалить', style: SpType.text(13, color: SpColors.red)),
                        ),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text('···', style: gMono(13, c: SpColors.muted)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text('✕', style: gMono(13, c: SpColors.muted)),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: title,
                        maxLines: null,
                        style: SpType.text(20, w: FontWeight.w600),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Название',
                          hintStyle: SpType.text(20, color: SpColors.dim),
                        ),
                        onSubmitted: (_) => _commit(),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                        decoration: BoxDecoration(
                          color: SpColors.bg.withValues(alpha: .45),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            row(
                              view == 'pipe' ? 'Этап' : 'Колонка',
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final c in cols)
                                    chip(
                                      c['id'] == cur && c['limit'] != null
                                          ? '${c['name']} · $inCol/${c['limit']}'
                                          : c['name'] as String,
                                      c['id'] == cur,
                                      () => s.setStage(widget.listId, x, c['id'] as String),
                                    ),
                                ],
                              ),
                            ),
                            if (s.sphereOf(widget.listId) case final String sid when sid.startsWith('sh:'))
                              row(
                                'Делает',
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    chip('Никто', L['who'] == null, () => s.setTask(id, {'who': null})),
                                    for (final p in s.people(sid))
                                      chip(
                                        '${p['name'] ?? p['email']}${p['email'] == s.myEmail ? ' (я)' : ''}',
                                        L['who'] == p['email'],
                                        () => s.setTask(id, {'who': p['email']}),
                                      ),
                                  ],
                                ),
                              ),
                            row(
                              'Приоритет',
                              Wrap(
                                spacing: 6,
                                children: [
                                  for (final (n, label) in [(1, '!!!'), (2, '!!'), (3, '!'), (null, '—')])
                                    chip(label, prio == n, () => s.setPriority(x, n)),
                                ],
                              ),
                            ),
                            if (view == 'pipe')
                              row(
                                'Проект',
                                _field(
                                  L['project'],
                                  'Название проекта',
                                  (v) => s.setTask(id, {'project': v.isEmpty ? null : v}),
                                ),
                              ),
                            if (fields.contains('client'))
                              row(
                                'Клиент',
                                Row(
                                  children: [
                                    Expanded(
                                      child: _field(
                                        L['client'],
                                        'Клиент',
                                        (v) => s.setTask(id, {'client': v.isEmpty ? null : v}),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text('СУММА', style: gMicro()),
                                    const SizedBox(width: 6),
                                    SizedBox(
                                      width: 100,
                                      child: _field(
                                        L['money'],
                                        '0 ₽',
                                        (v) => s.setTask(id, {'money': num.tryParse(v.replaceAll(' ', ''))}),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            row(
                              'Срок',
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  chip(
                                    due.isEmpty
                                        ? 'Без срока'
                                        : '${_human(due)}${slot?['s'] == null ? '' : ' · ${slot!['s']}${slot['e'] == null ? '' : '–${slot['e']}'}'}',
                                    due.isNotEmpty,
                                    () => _pickDue(context, x, due),
                                    x: due.isEmpty ? null : () => s.setDue(widget.listId, x, null),
                                  ),
                                  chip(
                                    slot?['s'] == null ? '+ время' : 'время',
                                    false,
                                    () => _pickTime(context),
                                    x: slot?['s'] == null ? null : () => s.setTask(id, {'slot': null}),
                                  ),
                                  for (final m in mins.toList()..sort())
                                    chip(
                                      'за ${leadName[m] ?? '$m мин'}',
                                      true,
                                      () {},
                                      x: () => setMins({...mins}..remove(m)),
                                    ),
                                  PopupMenuButton<int>(
                                    tooltip: 'Напомнить',
                                    color: SpColors.node,
                                    onSelected: (m) => setMins({...mins, m}),
                                    itemBuilder: (_) => [
                                      for (final l in rem.leads)
                                        if (!mins.contains(l['min']))
                                          PopupMenuItem(
                                            value: l['min'] as int,
                                            child: Text(l['name'] as String, style: SpType.text(13)),
                                          ),
                                    ],
                                    child: Container(
                                      height: 28,
                                      width: 28,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(SpRadius.button),
                                        border: Border.all(color: SpColors.line),
                                      ),
                                      child: Text('+', style: gMono(12, c: SpColors.muted)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'ПОДЗАДАЧИ · ${subs.where(s.isDone).length} / ${subs.length}',
                        style: gLbl(c: SpColors.muted),
                      ),
                      const SizedBox(height: 6),
                      for (final st in subs)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: SpColors.lineSoft)),
                          ),
                          child: Row(
                            children: [
                              GCheck(done: s.isDone(st), onTap: () => s.toggleDone(widget.listId, st)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  (st['title'] ?? '') as String,
                                  style: SpType.text(
                                    13.5,
                                    color: s.isDone(st) ? SpColors.dim : SpColors.ink,
                                  ).copyWith(decoration: s.isDone(st) ? TextDecoration.lineThrough : null),
                                ),
                              ),
                              InkWell(
                                onTap: () => s.remove(widget.listId, st),
                                child: Text('×', style: gMono(12, c: SpColors.dim)),
                              ),
                            ],
                          ),
                        ),
                      TextField(
                        style: SpType.text(13),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: '+ Подзадача',
                          hintStyle: SpType.text(13, color: SpColors.muted),
                        ),
                        onSubmitted: (v) {
                          if (v.trim().isNotEmpty) s.addSubtask(widget.listId, id, v.trim());
                        },
                      ),
                      const SizedBox(height: 16),
                      Text('ЗАМЕТКА', style: gLbl(c: SpColors.muted)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: notes,
                        minLines: 2,
                        maxLines: 12,
                        style: SpType.text(13.5, color: SpColors.body),
                        decoration: InputDecoration(
                          hintText: 'Пара слов о задаче',
                          hintStyle: SpType.text(13.5, color: SpColors.dim),
                          contentPadding: const EdgeInsets.all(12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: SpColors.line),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: SpColors.accent),
                          ),
                        ),
                      ),
                      _notesBlock(context, x),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: () => setState(() => more = !more),
                        child: Row(
                          children: [
                            Text('${more ? '▾' : '▸'} ЕЩЁ', style: gLbl(c: SpColors.ink)),
                            const SizedBox(width: 10),
                            Text('ПОВТОР · НАПОМНИТЬ', style: gMicro()),
                          ],
                        ),
                      ),
                      if (more) _more(context, x),
                    ],
                  ),
                ),
              ),
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: SpColors.line)),
                ),
                child: Row(
                  children: [
                    GDot(s.outbox.pendingFor(id) ? SpColors.gold : SpColors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.outbox.pendingFor(id) ? 'СОХРАНЯЮ…' : 'СОХРАНЕНО В GOOGLE TASKS',
                        style: gMicro(c: SpColors.ink2),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (s.isDone(x)) Text('СДЕЛАНО', style: gMicro(c: SpColors.green)),
                  ],
                ),
              ),
            ],
          ),
        );
        return Align(
          alignment: narrow ? Alignment.center : Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 80, narrow ? 16 : 96, 16),
            child: Material(
              color: Colors.transparent,
              child: SizedBox(width: narrow ? double.infinity : 464, child: panel),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickDue(BuildContext context, Json x, String due) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      locale: const Locale('ru'),
      initialDate: due.isEmpty ? now : DateTime.parse(due),
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null) widget.s.setDue(widget.listId, x, ymd(d));
  }

  Future<void> _pickTime(BuildContext context) async {
    final t = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: w!),
    );
    if (t == null) return;
    final st = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final e = t.hour >= 23
        ? '23:59'
        : '${(t.hour + 1).toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    widget.s.setTask(widget.id, {
      'slot': {'s': st, 'e': e},
    });
  }
}

extension on _TaskDialogState {
  /// «Заметки» из «Знаний»: откуда задача пришла и где о ней написано. Клик — открыть заметку.
  Widget _notesBlock(BuildContext context, Json x) {
    final s = widget.s, kn = s.notes, go = s.showNote;
    if (kn == null || go == null || !kn.hasFolder) return const SizedBox.shrink();
    final title = ((x['title'] ?? '') as String).trim();
    final found = notesForTask(kn.index, title, (x['notes'] ?? '') as String);
    void open(String p) {
      Navigator.of(context).pop();
      go(p);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(found.isEmpty ? 'ЗАМЕТКИ' : 'ЗАМЕТКИ · ${found.length}', style: gLbl(c: SpColors.muted)),
          const SizedBox(height: 6),
          for (final p in found)
            InkWell(
              onTap: () => open(p),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                child: Row(
                  children: [
                    Text('¶', style: SpType.text(13, color: SpColors.accent)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(baseName(p), overflow: TextOverflow.ellipsis, style: SpType.text(13.5)),
                    ),
                    if (folderOf(p).isNotEmpty)
                      Flexible(
                        child: Text(
                          folderOf(p).replaceAll('/', ' › '),
                          overflow: TextOverflow.ellipsis,
                          style: gMicro(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (title.isNotEmpty && !found.any((p) => baseName(p).toLowerCase() == title.toLowerCase()))
            InkWell(
              onTap: () async {
                final nav = Navigator.of(context);
                final p = await kn.create('', title);
                nav.pop();
                if (p != null) go(p);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                child: Text('＋ Заметка «$title»', style: SpType.text(13, color: SpColors.muted)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _more(BuildContext context, Json x) {
    final s = widget.s;
    final id = widget.id;
    final L = s.layTask(id);
    final rules = L['remind'] is List ? (L['remind'] as List) : (L['remind'] is Map ? [L['remind']] : const []);
    final mins = {
      for (final r in rules)
        if (r is Map && r['kind'] == 'lead') (r['min'] as num).toInt(),
    };
    final rep = (L['repeat'] as Map?)?['every'];
    Widget label(String t) => Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Text(t.toUpperCase(), style: SpType.label(10.5)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label('Повтор'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            GPick('Нет', on: rep == null, onTap: () => s.setTask(id, {'repeat': null})),
            for (final r in repeats.repeats)
              GPick(
                r.label,
                on: rep == r.id,
                onTap: () => s.setTask(id, {
                  'repeat': {'every': r.id},
                }),
              ),
          ],
        ),
        label('Напомнить ещё'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final l in rem.leads)
              GPick(
                l['name'] as String,
                on: mins.contains(l['min']),
                onTap: () {
                  final next = {...mins};
                  mins.contains(l['min']) ? next.remove(l['min']) : next.add(l['min'] as int);
                  s.setTask(id, {
                    'remind': next.isEmpty
                        ? null
                        : [
                            for (final m in next) {'kind': 'lead', 'min': m},
                          ],
                  });
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _field(Object? v, String hint, void Function(String) save) => TextFormField(
    initialValue: v == null ? '' : '$v',
    style: SpType.text(13.5),
    decoration: InputDecoration(
      isDense: true,
      hintText: hint,
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
    ),
    onFieldSubmitted: save,
    onTapOutside: (_) {},
    onChanged: save,
  );
}

const _mon = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];

String _human(String day) {
  final d = DateTime.parse(day);
  final now = DateTime.now();
  final diff = DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  if (diff == 0) return 'Сегодня';
  if (diff == 1) return 'Завтра';
  if (diff == -1) return 'Вчера';
  return '${d.day} ${_mon[d.month - 1]}';
}

String humanDay(String day) => _human(day);
