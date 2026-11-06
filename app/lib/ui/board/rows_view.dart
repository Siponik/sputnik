// Вид «Конвейер» (строка = задача, дорожка этапов, группы по проектам) и вид «Список» (строки с меткой этапа).
// Плюс окно «Архив» списка.
import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../state/app_state.dart';
import '../theme/tokens.dart';
import '../g/kit.dart';
import '../widgets/task_dialog.dart';
import 'card_menu.dart';
import '../today/today_page.dart' show listHue;

class ConveyorView extends StatefulWidget {
  const ConveyorView({super.key, required this.s, required this.listId});
  final AppState s;
  final String listId;
  @override
  State<ConveyorView> createState() => _ConveyorState();
}

class _ConveyorState extends State<ConveyorView> {
  String? open;
  AppState get s => widget.s;
  String get listId => widget.listId;

  static const _tile = 54.0, _info = 230.0, _right = 110.0;

  @override
  Widget build(BuildContext context) {
    final cols = (s.board(listId)['cols'] as List).cast<Map>();
    final items = s.topTasks(listId, withDone: true);
    final groups = <String, List<Json>>{};
    for (final t in items) {
      final p = (s.layTask(t['id'] as String)['project'] ?? '') as String;
      (groups[p] ??= []).add(t);
    }
    final keys = groups.keys.toList()..sort((a, b) => a.isEmpty ? 1 : (b.isEmpty ? -1 : a.compareTo(b)));
    final cur = open ?? (items.where((t) => !s.isDone(t)).firstOrNull?['id'] as String?);
    final tplName = (s.board(listId)['name'] ?? '') as String;
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        for (final (gi, k) in keys.indexed) ...[
          Padding(
            padding: EdgeInsets.only(top: gi == 0 ? 0 : 14, bottom: 10),
            child: Row(
              children: [
                Text(k.isEmpty ? 'БЕЗ ПРОЕКТА' : 'ПРОЕКТ · ${k.toUpperCase()}', style: gLbl(c: SpColors.dim, size: 10)),
                const SizedBox(width: 10),
                if (gi == 0)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 0),
                      child: Row(
                        children: [
                          const SizedBox(width: _tile + _info - 120),
                          Expanded(
                            child: Row(
                              children: [
                                for (final c in cols)
                                  Expanded(
                                    child: Text(
                                      ((c['name'] ?? '') as String).toUpperCase(),
                                      textAlign: TextAlign.left,
                                      maxLines: 1,
                                      overflow: TextOverflow.clip,
                                      style: gMicro(
                                        c:
                                            cur != null &&
                                                _stage(
                                                      items.firstWhere((t) => t['id'] == cur, orElse: () => {}),
                                                      cols,
                                                    ) ==
                                                    cols.indexOf(c)
                                            ? SpColors.accent
                                            : SpColors.dim,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: _right),
                        ],
                      ),
                    ),
                  )
                else
                  const Expanded(child: Divider(height: 1, color: SpColors.line)),
              ],
            ),
          ),
          for (final t in groups[k]!) ...[_row(context, t, cols, t['id'] == cur), const SizedBox(height: 10)],
        ],
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 10),
          child: _NewAsset(onAdd: (v) => s.addTask(listId, v, col: cols.first['id'] as String)),
        ),
        DimLine(
          '${(cols.first['name'] as String).toUpperCase()} → ${(cols.last['name'] as String).toUpperCase()} · ${cols.length} ЭТАПОВ${tplName.isEmpty ? '' : ' ИЗ ШАБЛОНА «${tplName.toUpperCase()}»'}',
        ),
      ],
    );
  }

  int _stage(Json t, List<Map> cols) => t.isEmpty ? -1 : cols.indexWhere((c) => c['id'] == s.colOf(t, cols));

  Widget _row(BuildContext context, Json t, List<Map> cols, bool on) {
    final i = _stage(t, cols);
    final done = s.isDone(t);
    final L = s.layTask(t['id'] as String);
    final due = dueToYmd(t['due'] as String?);
    final title = (t['title'] ?? '') as String;
    final proj = (L['project'] ?? '') as String;
    final at = L['stageAt'] is num ? DateTime.fromMillisecondsSinceEpoch((L['stageAt'] as num).toInt()) : null;
    final days = at == null ? null : DateTime.now().difference(at).inDays;
    final meta = [
      if (proj.isNotEmpty) proj,
      if (i >= 0) cols[i]['name'] as String,
      if (on && days != null && days > 0) '$days ДН В ЭТАПЕ',
    ].join(' · ').toUpperCase();
    final soon = due.isNotEmpty && due.compareTo(ymd(DateTime.now().add(const Duration(days: 2)))) <= 0 && !done;
    final head = Row(
      children: [
        _letter(title),
        const SizedBox(width: 12),
        SizedBox(
          width: _info - 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SpType.text(14, w: FontWeight.w600, color: done ? SpColors.dim : SpColors.ink),
              ),
              const SizedBox(height: 8),
              Text(meta, style: gMicro(), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        Expanded(child: _track(t, cols, i, done)),
        SizedBox(
          width: _right,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                done
                    ? 'СДАНО'
                    : (i == cols.length - 1 ? 'ГОТОВ К СДАЧЕ' : (due.isEmpty ? '—' : humanDay(due).toUpperCase())),
                style: gLbl(c: soon ? SpColors.accent : SpColors.ink, size: 10.5),
              ),
              const SizedBox(height: 8),
              if (!done && i < cols.length - 1)
                InkWell(
                  onTap: () => s.setStage(listId, t, cols[i + 1]['id'] as String),
                  child: Text('ЭТАП →', style: gMicro()),
                ),
            ],
          ),
        ),
      ],
    );
    Widget inner = Padding(padding: const EdgeInsets.all(12), child: head);
    if (on) {
      final subs = s.subtasks(listId, t['id'] as String);
      final sd = subs.where(s.isDone).length;
      inner = Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            head,
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(left: _tile + 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i >= 0 ? (cols[i]['name'] as String).toUpperCase() : ''} · ЧЕК-ЛИСТ $sd / ${subs.length}',
                          style: gLbl(c: SpColors.accent, size: 10),
                        ),
                        const SizedBox(height: 8),
                        for (final st in subs)
                          InkWell(
                            onTap: () => s.toggleDone(listId, st),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                children: [
                                  GCheck(done: s.isDone(st), onTap: () => s.toggleDone(listId, st)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      (st['title'] ?? '') as String,
                                      style: SpType.text(13, color: s.isDone(st) ? SpColors.dim : SpColors.ink)
                                          .copyWith(
                                            decoration: s.isDone(st) ? TextDecoration.lineThrough : null,
                                            decorationColor: SpColors.dim,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        _SubAdd(onAdd: (v) => s.addSubtask(listId, t['id'] as String, v)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(flex: 4, child: _preview(t)),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 250,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!done && i >= 0 && i < cols.length - 1)
                          GBtn(
                            'Этап → ${cols[i + 1]['name']}',
                            kind: BtnKind.acc,
                            onTap: () => s.setStage(listId, t, cols[i + 1]['id'] as String),
                          ),
                        const SizedBox(height: 8),
                        GBtn('Открыть задачу', onTap: () => openTask(context, s, listId, t)),
                        if ((t['notes'] ?? '') != '') ...[
                          const SizedBox(height: 10),
                          Text(
                            (t['notes'] as String),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: SpType.text(12.5, color: SpColors.muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onSecondaryTapUp: (d) => cardMenu(context, s, listId, t, d.globalPosition),
      child: GNode(
        hub: on,
        child: InkWell(
          borderRadius: BorderRadius.circular(on ? 12 : 8),
          onTap: () => on ? openTask(context, s, listId, t) : setState(() => open = t['id'] as String),
          child: inner,
        ),
      ),
    );
  }

  Widget _letter(String title) => Container(
    width: _tile,
    height: _tile,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xFF2B2520),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: const Color(0xFF3F352B)),
    ),
    child: CustomPaint(
      painter: _Grid(),
      child: SizedBox.expand(
        child: Center(
          child: Text(
            title.isEmpty ? '?' : title.characters.first.toUpperCase(),
            style: gMono(12, c: SpColors.accentInk, w: FontWeight.w500),
          ),
        ),
      ),
    ),
  );

  Widget _preview(Json t) {
    final th = (s.layTask(t['id'] as String)['preview'] as Map?)?['thumb'];
    Widget? img;
    if (th is String && th.startsWith('data:image')) {
      try {
        img = Image.memory(UriData.parse(th).contentAsBytes(), fit: BoxFit.cover);
      } catch (_) {}
    }
    return Container(
      height: 100,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF2B2520),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF3F352B)),
      ),
      child:
          img ??
          CustomPaint(
            painter: _Grid(),
            child: Center(
              child: Text('ПРЕВЬЮ', style: gMicro(c: SpColors.muted)),
            ),
          ),
    );
  }

  Widget _track(Json t, List<Map> cols, int i, bool done) => LayoutBuilder(
    builder: (context, box) {
      final n = cols.length;
      final w = box.maxWidth;
      double x(int k) => n == 1 ? 6 : k * (w - 12) / n + 6;
      final cur = done ? n : i;
      return SizedBox(
        height: 24,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: x(0),
              width: x(n - 1) - x(0),
              top: 11.5,
              child: Container(height: 1, color: SpColors.lineStrong),
            ),
            if (cur > 0)
              Positioned(
                left: x(0),
                width: x(cur.clamp(0, n - 1)) - x(0),
                top: 11,
                child: Container(height: 2, color: SpColors.green),
              ),
            for (var k = 0; k < n; k++)
              Positioned(
                left: x(k) - 6,
                top: 6,
                child: Tooltip(
                  message: cols[k]['name'] as String,
                  child: InkWell(
                    onTap: () => s.setStage(listId, t, cols[k]['id'] as String),
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: k < cur ? SpColors.green : (k == cur ? SpColors.accent : SpColors.node),
                        borderRadius: BorderRadius.circular(3),
                        border: k <= cur ? null : Border.all(color: SpColors.lineStrong),
                      ),
                      child: k < cur ? const Icon(Icons.check, size: 9, color: kDark) : null,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _Grid extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x14F0A04B);
    for (var x = 0.0; x < size.width; x += 14) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), p);
    }
    for (var y = 0.0; y < size.height; y += 14) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NewAsset extends StatelessWidget {
  const _NewAsset({required this.onAdd});
  final void Function(String) onAdd;
  @override
  Widget build(BuildContext context) => Dashed(
    child: SizedBox(
      height: 40,
      child: Row(
        children: [
          const SizedBox(width: 14),
          Text(
            '+',
            style: SpType.text(14, color: SpColors.accent, w: FontWeight.w600),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              style: SpType.text(13),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Новый ассет — название и Enter',
                hintStyle: SpType.text(13, color: SpColors.muted),
              ),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) onAdd(v.trim());
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _SubAdd extends StatelessWidget {
  const _SubAdd({required this.onAdd});
  final void Function(String) onAdd;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: TextField(
      style: SpType.text(13),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: '+ пункт чек-листа',
        hintStyle: SpType.text(13, color: SpColors.dim),
      ),
      onSubmitted: (v) {
        if (v.trim().isNotEmpty) onAdd(v.trim());
      },
    ),
  );
}

class ListRowsView extends StatelessWidget {
  const ListRowsView({super.key, required this.s, required this.listId});
  final AppState s;
  final String listId;

  static const _wd = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = ymd(now);
    final weekEnd = ymd(now.add(Duration(days: 7 - now.weekday)));
    final open = s.topTasks(listId);
    final groups = <(String, Color), List<Json>>{
      ('Просрочено', SpColors.red): [],
      ('Сегодня', SpColors.accent): [],
      ('На неделе', SpColors.dim): [],
      ('Позже', SpColors.dim): [],
      ('Без срока', SpColors.dim): [],
    };
    final keys = groups.keys.toList();
    for (final t in open) {
      final d = dueToYmd(t['due'] as String?);
      final k = d.isEmpty
          ? 4
          : d.compareTo(today) < 0
          ? 0
          : d == today
          ? 1
          : d.compareTo(weekEnd) <= 0
          ? 2
          : 3;
      groups[keys[k]]!.add(t);
    }
    for (final g in groups.values) {
      g.sort((a, b) => dueToYmd(a['due'] as String?).compareTo(dueToYmd(b['due'] as String?)));
    }
    final hue = listHue(s, listId);
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        GNode(
          hub: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GHead(
                name: '${s.listName(listId)} · все задачи',
                hub: true,
                trailing: Text('${open.length} ОТКРЫТО', style: gLbl(c: Colors.white)),
              ),
              for (final k in keys)
                if (groups[k]!.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                    child: Row(
                      children: [
                        GDot(k.$2),
                        const SizedBox(width: 8),
                        Text(k.$1, style: SpType.text(12.5, color: SpColors.muted)),
                      ],
                    ),
                  ),
                  for (final t in groups[k]!) _row(context, t, today, hue),
                ],
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                child: TextField(
                  style: SpType.text(13),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: '+ Добавить задачу',
                    hintStyle: SpType.text(13, color: SpColors.muted),
                  ),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) s.addTask(listId, v.trim());
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, Json t, String today, Color hue) {
    final id = t['id'] as String;
    final L = s.layTask(id);
    final d = dueToYmd(t['due'] as String?);
    final subs = s.subtasks(listId, id);
    final done = subs.where(s.isDone).length;
    final slot = L['slot'] is Map ? (L['slot'] as Map)['s'] as String? : null;
    final prio = L['priority'];
    String due;
    if (d.isEmpty) {
      due = '—';
    } else if (d == today) {
      due = slot ?? 'СЕГОДНЯ';
    } else {
      final dt = DateTime.parse(d);
      due = dt.difference(DateTime.parse(today)).inDays.abs() < 7
          ? '${_wd[dt.weekday - 1]} ${dt.day.toString().padLeft(2, '0')}'
          : '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}';
    }
    final late = d.isNotEmpty && d.compareTo(today) < 0;
    final notes = ((t['notes'] ?? '') as String).split('\n').first;
    return GestureDetector(
      onSecondaryTapUp: (e) => cardMenu(context, s, listId, t, e.globalPosition),
      child: InkWell(
        onTap: () => openTask(context, s, listId, t),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: SpColors.lineSoft)),
          ),
          child: Row(
            children: [
              GCheck(done: s.isDone(t), onTap: () => s.toggleDone(listId, t)),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        (t['title'] ?? '') as String,
                        style: SpType.text(13.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (notes.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          notes,
                          style: SpType.text(12.5, color: SpColors.dim),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (prio == 1 || prio == 2)
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Text(prio == 1 ? '!!!' : '!!', style: gMono(12, c: SpColors.accent)),
                ),
              if (subs.isNotEmpty) ...[
                SizedBox(
                  width: 90,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: done / subs.length,
                      minHeight: 3,
                      backgroundColor: SpColors.line,
                      color: hue,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(width: 70, child: Text('УРОК $done/${subs.length}', style: gMicro())),
              ],
              SizedBox(
                width: 64,
                child: Text(
                  due,
                  textAlign: TextAlign.right,
                  style: gMono(11, c: late ? SpColors.red : SpColors.ink2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> archiveDialog(BuildContext context, AppState s, String listId) => showDialog<void>(
  context: context,
  builder: (_) => ListenableBuilder(
    listenable: s,
    builder: (context, _) {
      final items = s.archived(listId);
      return Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
          child: GNode(
            hub: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GHead(
                  hub: true,
                  name: 'Архив · ${s.listName(listId)}',
                  trailing: InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Text('✕', style: gMono(12, c: Colors.white)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Выполненные за последние 14 дней, ушедшие с доски',
                          style: SpType.text(12.5, color: SpColors.muted),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: items.isEmpty
                              ? Center(
                                  child: Text('Пусто', style: SpType.text(14, color: SpColors.muted)),
                                )
                              : ListView(
                                  children: [
                                    for (final t in items)
                                      ListTile(
                                        dense: true,
                                        title: Text((t['title'] ?? '') as String, style: SpType.text(14)),
                                        subtitle: Text(
                                          'сделано ${humanDay(dueToYmd(t['completed'] as String?))}',
                                          style: SpType.label(10.5),
                                        ),
                                        trailing: GBtn(
                                          'Вернуть',
                                          kind: BtnKind.sec,
                                          sm: true,
                                          onTap: () => s.toggleDone(listId, t),
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  ),
);
