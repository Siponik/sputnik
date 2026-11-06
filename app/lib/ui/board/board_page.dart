// «Доска»: слева списки, справа колонки шаблона списка (канбан), карточки перетаскиваются между колонками.
// Конвейер, стикеры и «список» пока показываются тем же канбаном — их виды придут следующими.
import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/task_dialog.dart';
import 'card_menu.dart';
import 'list_dialogs.dart';
import '../../core/spheres.dart' as sph;
import 'rows_view.dart';
import 'stickers_view.dart';

class BoardPage extends StatefulWidget {
  const BoardPage({super.key, required this.state});
  final AppState state;

  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  String? get active => widget.state.activeList;
  set active(String? v) => widget.state.activeList = v;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final ls = s.boardLists;
    final id = ls.any((l) => l['id'] == active) ? active! : (ls.isEmpty ? null : ls.first['id'] as String);
    final groups = <String?, List<Json>>{};
    for (final l in ls) {
      (groups[s.sphereOf(l['id'] as String)] ??= []).add(l);
    }
    final folded = (((s.layer['settings'] as Map?)?['sphereFold'] as Map?) ?? const {});
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 240,
          color: SpColors.bg,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 10),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                child: Row(
                  children: [
                    Expanded(child: Text('СПИСКИ', style: SpType.label(11))),
                    IconButton(
                      tooltip: 'Новая сфера',
                      onPressed: () => sphereDialog(context, s),
                      icon: const Icon(Icons.workspaces_outline, size: 16, color: SpColors.muted),
                    ),
                    IconButton(
                      tooltip: 'Новый список',
                      onPressed: () async {
                        final nid = await newListDialog(context, s);
                        if (nid != null) setState(() => active = nid);
                      },
                      icon: const Icon(Icons.add, size: 18, color: SpColors.muted),
                    ),
                  ],
                ),
              ),
              for (final sp in [...s.spheres, null])
                if (groups[sp?['id']] != null) ...[
                  if (sp != null)
                    GestureDetector(
                      onSecondaryTap: () => sphereDialog(context, s, sp),
                      child: InkWell(
                        onTap: () => s.touch('settings', 'sphereFold', {sp['id'] as String: folded[sp['id']] != true}),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 12, 4),
                          child: Row(
                            children: [
                              CircleAvatar(radius: 4, backgroundColor: cssColor(sph.sphereColor(sp))),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  ((sp['name'] ?? '') as String).toUpperCase(),
                                  style: SpType.label(10.5, color: SpColors.ink2),
                                ),
                              ),
                              Icon(
                                folded[sp['id']] == true ? Icons.chevron_right : Icons.expand_more,
                                size: 14,
                                color: SpColors.dim,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (s.spheres.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 12, 4),
                      child: Text('БЕЗ СФЕРЫ', style: SpType.label(10.5, color: SpColors.dim)),
                    ),
                  if (sp == null || folded[sp['id']] != true)
                    for (final l in groups[sp?['id']]!) _listRow(s, l, l['id'] == id),
                ],
            ],
          ),
        ),
        Expanded(
          child: DotGround(
            child: id == null
                ? Center(
                    child: Text('Списков пока нет — создай первый «＋»', style: SpType.text(14, color: SpColors.muted)),
                  )
                : _board(context, s, id),
          ),
        ),
      ],
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
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: on ? SpColors.nodeHover : Colors.transparent,
            borderRadius: BorderRadius.circular(SpRadius.button),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  (l['title'] ?? '') as String,
                  style: SpType.text(13.5, color: on ? SpColors.ink : SpColors.ink2),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('$open', style: SpType.label(11)),
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

  Widget _board(BuildContext context, AppState s, String listId) {
    final b = s.board(listId);
    final cols = (b['cols'] as List).cast<Map>();
    final byCol = s.columns(listId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(s.listName(listId), style: SpType.text(20, w: FontWeight.w600)),
              const SizedBox(width: 12),
              Text((b['name'] ?? '') as String, style: SpType.label(11)),

              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'kanban', label: Text('Канбан')),
                  ButtonSegment(value: 'pipe', label: Text('Конвейер')),
                  ButtonSegment(value: 'stickers', label: Text('Стикеры')),
                  ButtonSegment(value: 'list', label: Text('Список')),
                ],
                selected: {_view(b)},
                onSelectionChanged: (v) => s.setView(listId, v.first),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Настройки списка',
                onPressed: () => listSettings(context, s, listId),
                icon: const Icon(Icons.more_horiz, size: 18, color: SpColors.muted),
              ),
              IconButton(
                tooltip: 'Архив',
                onPressed: () => archiveDialog(context, s, listId),
                icon: const Icon(Icons.inventory_2_outlined, size: 18, color: SpColors.muted),
              ),
            ],
          ),
        ),
        if (_view(b) == 'stickers')
          Expanded(
            child: StickersView(s: s, listId: listId),
          )
        else if (_view(b) == 'pipe')
          Expanded(
            child: ConveyorView(s: s, listId: listId),
          )
        else if (_view(b) == 'list')
          Expanded(
            child: ListRowsView(s: s, listId: listId),
          )
        else
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                for (final c in cols)
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: SizedBox(width: 280, child: _column(context, s, listId, c, byCol[c['id']] ?? const [])),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _column(BuildContext context, AppState s, String listId, Map c, List<Json> items) {
    final colId = c['id'] as String;
    final limit = (c['limit'] as num?)?.toInt() ?? 0;
    final over = limit > 0 && items.length > limit;
    return DragTarget<(String, Json)>(
      onWillAcceptWithDetails: (d) => d.data.$1 == listId,
      onAcceptWithDetails: (d) => s.setStage(listId, d.data.$2, colId),
      builder: (context, cand, _) => AnimatedContainer(
        duration: SpMotion.fast,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SpRadius.node),
          border: Border.all(color: cand.isNotEmpty ? SpColors.accent : Colors.transparent),
        ),
        child: Node(
          title: '${c['name']} · ${items.length}${limit > 0 ? '/$limit' : ''}',
          head: headFor(c['color']),
          trailing: over ? Text('много', style: SpType.label(10.5, color: SpColors.accentInk)) : null,
          child: Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(8),
              children: [
                for (final t in items) _card(context, s, listId, t, cols: c),
                if (colId != 'done')
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: AddLine(
                      hint: 'Добавить задачу',
                      onSubmit: (v) => s.addTask(listId, v, col: colId),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, AppState s, String listId, Json t, {required Map cols}) {
    final card = _cardBody(s, t);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Draggable<(String, Json)>(
        data: (listId, t),
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(width: 264, child: card),
        ),
        childWhenDragging: Opacity(opacity: .3, child: card),
        child: GestureDetector(
          onSecondaryTapUp: (d) => cardMenu(context, s, listId, t, d.globalPosition),
          child: InkWell(onTap: () => openTask(context, s, listId, t), child: card),
        ),
      ),
    );
  }

  Widget _cardBody(AppState s, Json t) {
    final done = s.isDone(t);
    final L = s.layTask(t['id'] as String);
    final prio = (L['priority'] as num?)?.toInt();
    final due = dueToYmd(t['due'] as String?);
    final late = !done && due.isNotEmpty && due.compareTo(s.todayYmd) < 0;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SpColors.nodeHover,
        borderRadius: BorderRadius.circular(SpRadius.button),
        border: Border.all(color: SpColors.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text((t['title'] ?? '') as String, style: SpType.text(13.5, color: done ? SpColors.dim : SpColors.ink)),
          if (due.isNotEmpty || prio != null || (t['notes'] ?? '') != '')
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  if (prio != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '!' * (4 - prio),
                        style: SpType.label(11, color: prio == 1 ? SpColors.red : SpColors.muted),
                      ),
                    ),
                  if (due.isNotEmpty)
                    Text(humanDay(due), style: SpType.label(11, color: late ? SpColors.red : SpColors.muted)),
                  const Spacer(),
                  if ((t['notes'] ?? '') != '') const Icon(Icons.notes, size: 13, color: SpColors.dim),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
