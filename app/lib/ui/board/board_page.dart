// «Доска» по макету G_Kanban: слева нода «Сферы» (фильтр, списки по сферам с буквой вида, совет енота, док
// «Шаблоны · Архив · Показывать»), справа шапка доски (название, «по шаблону …», вид) и колонки-ноды с цветными
// шапками, соединённые проводами; «В работе» — главная нода с уголками и лимитом. Карточки перетаскиваются.
import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/spheres.dart' as sph;
import '../../core/templates.dart' as tpl;
import '../../state/app_state.dart';
import '../g/kit.dart';
import '../theme/tokens.dart';
import '../today/today_page.dart' show listHue;
import '../widgets/common.dart';
import '../widgets/task_dialog.dart';
import 'card_menu.dart';
import 'list_dialogs.dart';
import 'rows_view.dart';
import 'share_dialog.dart';
import 'stickers_view.dart';

Color colHue(Map c) => cssColor(tpl.colColor(c));

String viewLetter(Object? v) => switch (v) {
  'pipe' || 'gallery' => 'П',
  'stickers' => 'С',
  'list' => 'Л',
  _ => 'К',
};

class BoardPage extends StatefulWidget {
  const BoardPage({super.key, required this.state});
  final AppState state;

  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  String? get active => widget.state.activeList;
  set active(String? v) => widget.state.activeList = v;
  String filter = '';
  final folded = <String, bool>{};

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final ls = s.boardLists;
    final id = ls.any((l) => l['id'] == active) ? active! : (ls.isEmpty ? null : ls.first['id'] as String);
    return DotGround(
      child: LayoutBuilder(
        builder: (context, box) {
          final narrow = box.maxWidth < 900;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!narrow) ...[SizedBox(width: 220, child: _side(s, ls, id)), const SizedBox(width: 16)],
                Expanded(
                  child: id == null
                      ? Center(
                          child: Text(
                            'Списков пока нет — создай первый «+»',
                            style: SpType.text(14, color: SpColors.muted),
                          ),
                        )
                      : _board(context, s, id, narrow, ls),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------- левая колонка ----------

  Widget _side(AppState s, List<Json> ls, String? id) {
    final groups = <String?, List<Json>>{};
    final f = filter.toLowerCase().replaceAll('ё', 'е');
    for (final l in ls) {
      if (f.isNotEmpty && !((l['title'] ?? '') as String).toLowerCase().replaceAll('ё', 'е').contains(f)) continue;
      (groups[s.sphereOf(l['id'] as String)] ??= []).add(l);
    }
    final fold = (((s.layer['settings'] as Map?)?['sphereFold'] as Map?) ?? const {});
    final doing = id == null ? null : _doingInfo(s, id);
    return GNode(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GHead(
            name: 'Сферы',
            kind: '${s.spheres.length}',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 6),
                _mini(Icons.group_add_outlined, 'Войти в общую сферу', () => joinDialog(context, s)),
                _mini(Icons.workspaces_outline, 'Новая сфера', () => sphereDialog(context, s)),
                _mini(Icons.add, 'Новый список', () async {
                  final nid = await newListDialog(context, s);
                  if (nid != null) setState(() => active = nid);
                }),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: SpColors.bg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: SpColors.lineStrong),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      style: SpType.text(13),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Список…',
                        hintStyle: SpType.text(13, color: SpColors.muted),
                      ),
                      onChanged: (v) => setState(() => filter = v.trim()),
                    ),
                  ),
                  Text('CTRL ⇧ L', style: gMicro()),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                for (final sp in [...s.spheres, null])
                  if (groups[sp?['id']] != null || (sp?['shared'] == true && f.isEmpty)) ...[
                    _sphereRow(s, sp, fold),
                    if (sp == null || fold[sp['id']] != true)
                      for (final l in groups[sp?['id']] ?? const <Json>[]) _listRow(s, l, l['id'] == id),
                  ],
              ],
            ),
          ),
          if (doing != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: CoonTip(pose: 'think', text: doing),
            ),
          Container(
            height: 40,
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: SpColors.line)),
            ),
            child: Row(
              children: [
                for (final w in [
                  _dock('Шаблоны', () => s.say('Шаблоны досок — в настройках списка: «Колонки из шаблона»')),
                  _dock('Архив', id == null ? null : () => archiveDialog(context, s, id)),
                  _dock('Показывать', id == null ? null : () => listSettings(context, s, id)),
                ])
                  Expanded(
                    child: Center(
                      child: FittedBox(fit: BoxFit.scaleDown, child: w),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mini(IconData i, String tip, VoidCallback on) => Tooltip(
    message: tip,
    child: InkWell(
      onTap: on,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Icon(i, size: 14, color: SpColors.muted),
      ),
    ),
  );

  Widget _dock(String t, VoidCallback? on) => InkWell(
    onTap: on,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(t.toUpperCase(), style: gLbl(size: 9.5)),
    ),
  );

  /// Совет енота: «В работе» уже N из лимита.
  String? _doingInfo(AppState s, String id) {
    final cols = (s.board(id)['cols'] as List).cast<Map>();
    final by = s.columns(id);
    for (final c in cols) {
      final lim = (c['limit'] as num?)?.toInt() ?? 0;
      final n = (by[c['id']] ?? const []).length;
      if (lim > 0 && n >= lim - 1 && n > 0) {
        return n >= lim
            ? 'В «${c['name']}» уже $n из $lim. Закончи одну до новой.'
            : 'В «${c['name']}» уже $n из $lim. Закончи одну до новой.';
      }
    }
    return null;
  }

  Widget _sphereRow(AppState s, Json? sp, Map fold) {
    if (sp == null) {
      if (s.spheres.isEmpty) return const SizedBox(height: 6);
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 6),
        child: Row(
          children: [
            const GDot(SpColors.grey),
            const SizedBox(width: 8),
            Text('БЕЗ СФЕРЫ', style: gLbl(size: 10, c: SpColors.muted)),
          ],
        ),
      );
    }
    final shared = sp['shared'] == true;
    return GestureDetector(
      onSecondaryTap: () => shared ? shareDialog(context, s, sp['id'] as String) : sphereDialog(context, s, sp),
      child: InkWell(
        onTap: () => s.touch('settings', 'sphereFold', {sp['id'] as String: fold[sp['id']] != true}),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 6),
          child: Row(
            children: [
              GDot(cssColor(sph.sphereColor(sp))),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ((sp['name'] ?? '') as String).toUpperCase(),
                  style: gLbl(size: 10, c: SpColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (shared)
                _mini(
                  sp['lost'] == true ? Icons.link_off : Icons.group_outlined,
                  'Участники',
                  () => shareDialog(context, s, sp['id'] as String),
                ),
              if (fold[sp['id']] == true) Text('▸', style: gMicro()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _listRow(AppState s, Json l, bool on) {
    final lid = l['id'] as String;
    final open = (s.tasks[lid] ?? const <Json>[]).where((t) => !s.isDone(t) && t['parent'] == null).length;
    return GestureDetector(
      onSecondaryTap: () => listSettings(context, s, lid),
      child: InkWell(
        onTap: () => setState(() => active = lid),
        child: Container(
          height: 30,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: on ? SpColors.accentWash : Colors.transparent,
            borderRadius: BorderRadius.circular(SpRadius.button),
            border: Border.all(color: on ? SpColors.accent : Colors.transparent),
          ),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: SpColors.line),
                ),
                child: Text(
                  viewLetter(s.board(lid)['view']),
                  style: SpType.label(9, color: SpColors.muted, spacing: 0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  (l['title'] ?? '') as String,
                  style: SpType.text(13, color: SpColors.ink),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              Text('$open', style: gMono(10.5, c: SpColors.dim)),
            ],
          ),
        ),
      ),
    );
  }

  String _view(Json b) {
    final v = (b['view'] ?? 'kanban') as String;
    return v == 'gallery' ? 'pipe' : (['kanban', 'pipe', 'stickers', 'list'].contains(v) ? v : 'kanban');
  }

  // ---------- доска ----------

  Widget _board(BuildContext context, AppState s, String listId, bool narrow, List<Json> ls) {
    final b = s.board(listId);
    final cols = (b['cols'] as List).cast<Map>();
    final byCol = s.columns(listId);
    final view = _view(b);
    final L = s.layList(listId);
    final tplName = tpl
        .templatesFrom(s.layer)
        .firstWhere((t) => t['id'] == (L['template'] ?? 'work'), orElse: () => {'name': ''})['name'];
    const views = ['kanban', 'pipe', 'stickers', 'list'];
    const names = ['Канбан', 'Конвейер', 'Стикеры', 'Список'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GNode(
          child: Container(
            height: 46,
            padding: const EdgeInsets.fromLTRB(14, 0, 12, 0),
            child: Row(
              children: [
                GDot(listHue(s, listId), size: 8),
                const SizedBox(width: 12),
                if (narrow)
                  Flexible(
                    child: PopupMenuButton<String>(
                      tooltip: 'Другой список',
                      onSelected: (v) => setState(() => active = v),
                      itemBuilder: (_) => [
                        for (final l in ls)
                          PopupMenuItem(value: l['id'] as String, child: Text((l['title'] ?? '') as String)),
                      ],
                      child: Text(
                        s.listName(listId),
                        style: SpType.text(15, w: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: GestureDetector(
                      onDoubleTap: () => listSettings(context, s, listId),
                      child: Text(
                        s.listName(listId),
                        style: SpType.text(15, w: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: () => listSettings(context, s, listId),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text('···', style: gMono(13, c: SpColors.muted)),
                  ),
                ),
                const SizedBox(width: 10),
                if (!narrow)
                  Flexible(
                    child: Text(
                      view == 'pipe'
                          ? _pipeMeta(s, listId)
                          : (b['own'] == true ? 'СВОЙ ВИД' : 'ПО ШАБЛОНУ «${(tplName as String).toUpperCase()}»'),
                      style: gMicro(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: GSeg(
                      items: [
                        for (final (i, v) in views.indexed)
                          if (v != 'list' || view == 'list' || !narrow) names[i],
                      ],
                      active: views.indexOf(view),
                      onTap: (i) => s.setView(listId, views[i]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: switch (view) {
            'stickers' => StickersView(s: s, listId: listId),
            'pipe' => ConveyorView(s: s, listId: listId),
            'list' => ListRowsView(s: s, listId: listId),
            _ => _kanban(context, s, listId, cols, byCol),
          },
        ),
      ],
    );
  }

  Widget _kanban(BuildContext context, AppState s, String listId, List<Map> cols, Map<String, List<Json>> byCol) {
    final wires = [
      for (var i = 0; i + 1 < cols.length; i++)
        Wire('col:${cols[i]['id']}:r', 'col:${cols[i + 1]['id']}:l', colHue(cols[i + 1])),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 28.0;
        final w = ((box.maxWidth - gap * (cols.length - 1)) / cols.length).clamp(230.0, 320.0);
        final fits = w * cols.length + gap * (cols.length - 1) <= box.maxWidth + 1;
        final row = WireBoard(
          wires: wires,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, c) in cols.indexed) ...[
                if (i > 0) const SizedBox(width: gap),
                SizedBox(
                  width: w,
                  child: _column(
                    context,
                    s,
                    listId,
                    c,
                    byCol[c['id']] ?? const [],
                    cols,
                    first: i == 0,
                    last: i == cols.length - 1,
                  ),
                ),
              ],
            ],
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: fits
                  ? row
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(right: 8, left: 6, top: 6),
                      child: SizedBox(width: w * cols.length + gap * (cols.length - 1), child: row),
                    ),
            ),
            const SizedBox(height: 10),
            DimLine(
              '${cols.map((c) => (c['name'] as String).toUpperCase()).join(' → ')} · СТРЕЛКА НА КАРТОЧКЕ — СЛЕДУЮЩИЙ ЭТАП',
            ),
          ],
        );
      },
    );
  }

  Widget _column(
    BuildContext context,
    AppState s,
    String listId,
    Map c,
    List<Json> items,
    List<Map> cols, {
    required bool first,
    required bool last,
  }) {
    final colId = c['id'] as String;
    final limit = (c['limit'] as num?)?.toInt() ?? 0;
    final hub = limit > 0;
    final hue = colHue(c);
    final idx = cols.indexOf(c);
    final doneCol = last;
    final key = '$listId:$colId';
    final showAll = folded[key] == true;
    final shown = doneCol && !showAll && items.length > 2 ? items.take(2).toList() : items;
    return DragTarget<(String, Json)>(
      onWillAcceptWithDetails: (d) => d.data.$1 == listId,
      onAcceptWithDetails: (d) => s.setStage(listId, d.data.$2, colId),
      builder: (context, cand, _) => GNode(
        hub: hub,
        child: Container(
          decoration: cand.isNotEmpty
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(hub ? 12 : 8),
                  border: Border.all(color: SpColors.accent),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SockRow(
                left: first ? null : Sock('col:$colId:l', hue),
                right: last ? null : Sock('col:$colId:r', colHue(cols[idx + 1])),
                child: GHead(
                  num: (idx + 1).toString().padLeft(2, '0'),
                  name: (c['name'] ?? '') as String,
                  kind: hub ? '${items.length} / $limit' : '${items.length}',
                  color: idx == 0 ? SpColors.grey : hue,
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(10),
                  children: [
                    for (final t in shown) _card(context, s, listId, t, cols, hot: hub),
                    if (doneCol && items.length > 2)
                      InkWell(
                        onTap: () => setState(() => folded[key] = !showAll),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Center(
                            child: Text(
                              showAll ? 'СВЕРНУТЬ' : '+ ЕЩЁ ${items.length - 2} · СВЕРНУТО',
                              style: gMicro(c: SpColors.muted),
                            ),
                          ),
                        ),
                      ),
                    if (hub && items.length < limit && items.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: SpColors.accentLine),
                        ),
                        child: Text(
                          'Лимит $limit. Можно взять ещё ${limit - items.length == 1 ? 'одну' : '${limit - items.length}'}.',
                          style: SpType.text(12.5, color: SpColors.accentInk),
                        ),
                      ),
                    if (hub && items.length > limit)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: SpColors.red),
                        ),
                        child: Text(
                          'Больше лимита ($limit). Закончи одну, прежде чем брать новую.',
                          style: SpType.text(12.5, color: SpColors.red),
                        ),
                      ),
                    if (items.isEmpty && !first)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          children: [
                            const GCoon('sleep', size: 42),
                            const SizedBox(height: 10),
                            Text('ТУТ ПОКА ПУСТОВАТО', style: gMicro()),
                          ],
                        ),
                      ),
                    if (first) _AddCard(onAdd: (v) => s.addTask(listId, v, col: colId)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, AppState s, String listId, Json t, List<Map> cols, {bool hot = false}) {
    final card = _cardBody(s, listId, t, cols, hot);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Draggable<(String, Json)>(
        data: (listId, t),
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(width: 230, child: card),
        ),
        childWhenDragging: Opacity(opacity: .3, child: card),
        child: GestureDetector(
          onSecondaryTapUp: (d) => cardMenu(context, s, listId, t, d.globalPosition),
          child: InkWell(onTap: () => openTask(context, s, listId, t), child: card),
        ),
      ),
    );
  }

  Widget _cardBody(AppState s, String listId, Json t, List<Map> cols, bool hot) {
    final done = s.isDone(t);
    final L = s.layTask(t['id'] as String);
    final prio = (L['priority'] as num?)?.toInt();
    final due = dueToYmd(t['due'] as String?);
    final late = !done && due.isNotEmpty && due.compareTo(s.todayYmd) < 0;
    final slot = L['slot'] as Map?;
    final tag = (L['client'] ?? L['project']) as String?;
    final subs = s.subtasks(listId, t['id'] as String);
    final subsDone = subs.where(s.isDone).length;
    final cur = s.colOf(t, cols);
    final ci = cols.indexWhere((c) => c['id'] == cur);
    final meta = [
      if (due.isNotEmpty)
        (due == s.todayYmd ? 'СЕГОДНЯ' : humanDay(due).toUpperCase()) + (slot?['s'] != null ? ' ${slot!['s']}' : ''),
      if (due.isEmpty && !done) 'БЕЗ СРОКА',
    ].join();
    final metaC = hot ? SpColors.accent : (late ? SpColors.red : SpColors.dim);
    Widget body = Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      decoration: BoxDecoration(
        color: hot ? SpColors.accentWash : SpColors.node,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: hot ? SpColors.accent : SpColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  (t['title'] ?? '') as String,
                  style: SpType.text(
                    13,
                    color: done ? SpColors.dim : SpColors.ink,
                  ).copyWith(decoration: done ? TextDecoration.lineThrough : null, decorationColor: SpColors.dim),
                ),
              ),
              if (prio != null && !done)
                Text(
                  '!' * (4 - prio),
                  style: gMono(11, c: prio == 1 ? SpColors.accent : SpColors.muted, w: FontWeight.w600),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (meta.isNotEmpty) Text(meta, style: gMicro(c: metaC)),
              if (tag != null && tag.isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    tag.toUpperCase(),
                    style: gMicro(c: SpColors.blue),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const Spacer(),
              if (!done && ci >= 0 && ci < cols.length - 1)
                InkWell(
                  onTap: () => s.setStage(listId, t, cols[ci + 1]['id'] as String),
                  child: Tooltip(
                    message: 'Дальше: ${cols[ci + 1]['name']}',
                    child: Text('→', style: gMono(12, c: SpColors.muted)),
                  ),
                ),
            ],
          ),
          if (subs.isNotEmpty) ...[
            const SizedBox(height: 8),
            GStages(done: subsDone, now: subsDone < subs.length ? subsDone : -1, total: subs.length, h: 3),
          ],
        ],
      ),
    );
    if (hot) body = CustomPaint(foregroundPainter: _Hatch(), child: body);
    return body;
  }
}

class _Hatch extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x10F0A04B)
      ..strokeWidth = 1;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6)));
    for (var x = -size.height; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// «+ Добавить задачу» — пунктирная кнопка, по клику — поле прямо в колонке (Enter — добавить, Esc — отмена).
class _AddCard extends StatefulWidget {
  const _AddCard({required this.onAdd});
  final void Function(String) onAdd;
  @override
  State<_AddCard> createState() => _AddCardState();
}

class _AddCardState extends State<_AddCard> {
  bool open = false;
  final c = TextEditingController();
  final f = FocusNode();

  @override
  Widget build(BuildContext context) {
    if (!open) {
      return InkWell(
        onTap: () {
          setState(() => open = true);
          f.requestFocus();
        },
        child: Dashed(
          r: 6,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text('+ Добавить задачу', style: SpType.text(13, color: SpColors.muted)),
                const Spacer(),
                Text('N', style: gMicro()),
              ],
            ),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: SpColors.bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SpColors.accent),
      ),
      child: Focus(
        onKeyEvent: (_, e) {
          if (e.logicalKey.keyLabel == 'Escape') {
            setState(() => open = false);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: c,
          focusNode: f,
          style: SpType.text(13),
          decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: 'Название и Enter'),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) widget.onAdd(v.trim());
            c.clear();
            f.requestFocus();
          },
        ),
      ),
    );
  }
}

String _pipeMeta(AppState s, String listId) {
  final items = s.topTasks(listId, withDone: true);
  final projects = {for (final t in items) (s.layTask(t['id'] as String)['project'] ?? '') as String}..remove('');
  return '${items.length} АССЕТОВ · ${projects.length} ПРОЕКТ${projects.length == 1 ? '' : (projects.length < 5 ? 'А' : 'ОВ')}';
}
