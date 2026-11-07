// Вид «Конвейер» (строка = задача, дорожка этапов, группы по проектам) и вид «Список» (строки с меткой этапа).
// Плюс окно «Архив» списка.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/dates.dart';
import '../../state/app_state.dart';
import '../theme/tokens.dart';
import '../g/kit.dart';
import '../widgets/task_dialog.dart';
import 'card_menu.dart';
import '../keys.dart';
import '../widgets/date_time_picker.dart';
import '../../core/reminders.dart' as rem;
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
  bool shut = false; // Esc — свернуть раскрытую строку
  AppState get s => widget.s;
  String get listId => widget.listId;

  static const _tile = 48.0;

  @override
  void dispose() {
    PageKeys.clear(this);
    super.dispose();
  }

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
    final order = [for (final k in keys) ...groups[k]!];
    final cur = shut ? null : (open ?? (items.where((t) => !s.isDone(t)).firstOrNull?['id'] as String?));
    PageKeys.set(this, {
      const PKey(PhysicalKeyboardKey.escape): () => setState(() => shut = true),
      const PKey(PhysicalKeyboardKey.space): () {
        if (order.isEmpty) return;
        final i = order.indexWhere((t) => t['id'] == cur);
        setState(() {
          shut = false;
          open = order[(i + 1) % order.length]['id'] as String;
        });
      },
      const PKey(PhysicalKeyboardKey.enter): () {
        final t = order.where((t) => t['id'] == cur).firstOrNull;
        if (t != null) openTask(context, s, listId, t);
      },
    });
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        for (final (gi, k) in keys.indexed) ...[
          Padding(
            padding: EdgeInsets.only(top: gi == 0 ? 0 : 8, bottom: 8, left: 2, right: 2),
            child: Row(
              children: [
                GDot(k.isEmpty ? SpColors.grey : SpColors.accent),
                const SizedBox(width: 8),
                Text(k.isEmpty ? 'Без проекта' : k, style: SpType.text(13, w: FontWeight.w600)),
                const SizedBox(width: 8),
                Text(_assets(groups[k]!.length), style: SpType.text(12, color: SpColors.muted)),
                const Spacer(),
                InkWell(
                  onTap: () => _addAsset(context, cols, k),
                  child: Text(k.isEmpty ? '+ Ассет' : '+ Ассет в «$k»', style: SpType.text(12, color: SpColors.accent)),
                ),
              ],
            ),
          ),
          for (final t in groups[k]!) ...[_row(context, t, cols, t['id'] == cur), const SizedBox(height: 8)],
        ],
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 10),
            child: _NewAsset(onAdd: (v) => s.addTask(listId, v, col: cols.first['id'] as String)),
          ),
      ],
    );
  }

  static String _assets(int n) {
    final m10 = n % 10, m100 = n % 100;
    final w = m10 == 1 && m100 != 11
        ? 'ассет'
        : (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14) ? 'ассета' : 'ассетов');
    return '$n $w';
  }

  Future<void> _addAsset(BuildContext context, List<Map> cols, String project) async {
    final c = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (dc) => Dialog(
        backgroundColor: Colors.transparent,
        child: SizedBox(
          width: 420,
          child: GNode(
            hub: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GHead(hub: true, name: project.isEmpty ? 'Новый ассет' : 'Новый ассет · $project'),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: TextField(
                    controller: c,
                    autofocus: true,
                    style: SpType.text(14),
                    decoration: InputDecoration(
                      hintText: 'Название и Enter',
                      hintStyle: SpType.text(14, color: SpColors.dim),
                    ),
                    onSubmitted: (v) => Navigator.pop(dc, v),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (v == null || v.trim().isEmpty) return;
    s.addTask(
      listId,
      v.trim(),
      col: cols.first['id'] as String,
      layerPatch: project.isEmpty ? const {} : {'project': project},
    );
  }

  int _stage(Json t, List<Map> cols) => t.isEmpty ? -1 : cols.indexWhere((c) => c['id'] == s.colOf(t, cols));

  Widget _row(BuildContext context, Json t, List<Map> cols, bool on) {
    final i = _stage(t, cols);
    final done = s.isDone(t);
    final id = t['id'] as String;
    final L = s.layTask(id);
    final due = dueToYmd(t['due'] as String?);
    final title = (t['title'] ?? '') as String;
    final proj = (L['project'] ?? '') as String;
    final at = L['stageAt'] is num ? DateTime.fromMillisecondsSinceEpoch((L['stageAt'] as num).toInt()) : null;
    final days = at == null ? null : DateTime.now().difference(at).inDays;
    final prio = (L['priority'] as num?)?.toInt();
    final meta = [
      if (proj.isNotEmpty) proj,
      if (i >= 0) '${(cols[i]['name'] as String).toLowerCase()}${days != null && days > 0 ? ' $days дн' : ''}',
      if (prio != null && prio > 0 && prio < 4) '!' * (4 - prio),
    ].join(' · ');
    final late = due.isNotEmpty && !done && due.compareTo(s.todayYmd) < 0;
    final next = !done && i >= 0 && i < cols.length - 1 ? cols[i + 1] : null;
    final head = Row(
      children: [
        Text(on ? '▾' : '▸', style: SpType.text(11, color: SpColors.dim)),
        const SizedBox(width: 10),
        _thumb(t, _tile),
        const SizedBox(width: 14),
        SizedBox(
          width: 170,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SpType.text(14, w: FontWeight.w600, color: done ? SpColors.dim : SpColors.ink),
              ),
              const SizedBox(height: 3),
              Text(
                meta,
                style: SpType.text(12, color: SpColors.muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: _track(t, cols, i, done)),
        const SizedBox(width: 14),
        SizedBox(
          width: 64,
          child: Text(
            done ? 'сдано' : (due.isEmpty ? '' : humanDay(due)),
            textAlign: TextAlign.right,
            style: SpType.text(13, color: late ? SpColors.red : (done ? SpColors.green : SpColors.ink2)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 104,
          child: next == null
              ? const SizedBox.shrink()
              : GBtn(
                  '${next['name']} →',
                  kind: on ? BtnKind.acc : BtnKind.sec,
                  onTap: () => s.setStage(listId, t, next['id'] as String),
                ),
        ),
      ],
    );
    final Widget base = Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: head);
    Widget inner = base;
    if (on) {
      final x = _expanded(context, t, cols, i, head);
      // Узкое окно: раскрытая строка прокручивается вбок, а не ломает раскладку.
      inner = LayoutBuilder(
        builder: (_, b) => b.maxWidth >= 1000
            ? x
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: 1000, child: x),
              ),
      );
    } else {
      inner = LayoutBuilder(
        builder: (_, b) => b.maxWidth >= 640
            ? base
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: 640, child: base),
              ),
      );
    }
    return GestureDetector(
      onSecondaryTapUp: (d) => cardMenu(context, s, listId, t, d.globalPosition),
      child: GNode(
        hub: on,
        child: InkWell(
          borderRadius: BorderRadius.circular(on ? 12 : 8),
          onTap: () => on
              ? setState(() => shut = true)
              : setState(() {
                  shut = false;
                  open = id;
                }),
          // Раскрытие строки: высота растёт плавно.
          child: AnimatedSize(
            duration: SpMotion.d(context, SpMotion.dur3),
            curve: SpMotion.easeOut,
            alignment: Alignment.topCenter,
            child: inner,
          ),
        ),
      ),
    );
  }

  Widget _expanded(BuildContext context, Json t, List<Map> cols, int i, Widget head) {
    final id = t['id'] as String;
    final L = s.layTask(id);
    final colId = i >= 0 ? cols[i]['id'] : null;
    final subs = s.subtasks(listId, id).where((x) {
      final st = s.layTask(x['id'] as String)['stage'];
      return st == null || st == colId;
    }).toList();
    final sd = subs.where(s.isDone).length;
    final stage = i >= 0 ? cols[i]['name'] as String : '';
    final prev = i > 0 ? cols[i - 1] : null;
    final due = dueToYmd(t['due'] as String?);
    final prio = (L['priority'] as num?)?.toInt();
    final client = (L['client'] ?? '') as String;
    final rm = L['remind'];
    final remMin = rm is Map && rm['kind'] == 'lead'
        ? (rm['min'] as num?)?.toInt()
        : (rm is List && rm.isNotEmpty && rm.first is Map ? ((rm.first as Map)['min'] as num?)?.toInt() : null);
    final leadName = {for (final l in rem.leads) l['min'] as int: l['name'] as String};
    final notes = (t['notes'] ?? '') as String;
    final pv = L['preview'] as Map?;
    Widget lbl(String a, [String b = '']) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(a, style: SpType.text(13, w: FontWeight.w600)),
          if (b.isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(b, style: SpType.text(12, color: SpColors.muted), maxLines: 1),
            ),
          ],
        ],
      ),
    );
    Widget detail(String k, Widget v) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(k, style: SpType.text(12.5, color: SpColors.muted)),
          ),
          Flexible(child: v),
        ],
      ),
    );
    Widget key(String k) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: SpColors.line),
      ),
      child: Text(k, style: gMicro()),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 8), child: head),
        Padding(
          padding: const EdgeInsets.fromLTRB(110, 8, 18, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Этап «$stage»',
                            style: SpType.text(13, w: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('$sd из ${subs.length}', style: SpType.text(12, color: SpColors.muted)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: subs.isEmpty ? 0 : sd / subs.length,
                              minHeight: 3,
                              color: SpColors.accent,
                              backgroundColor: SpColors.line,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final st in subs)
                      InkWell(
                        onTap: () => s.toggleDone(listId, st),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              GCheck(done: s.isDone(st), onTap: () => s.toggleDone(listId, st)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  (st['title'] ?? '') as String,
                                  style: SpType.text(13, color: s.isDone(st) ? SpColors.dim : SpColors.ink).copyWith(
                                    decoration: s.isDone(st) ? TextDecoration.lineThrough : null,
                                    decorationColor: SpColors.dim,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    _SubAdd(onAdd: (v) => s.addSubtask(listId, id, v)),
                  ],
                ),
              ),
              const SizedBox(width: 22),
              SizedBox(
                width: 300,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    lbl('Превью', pv == null ? '' : [if (pv['w'] != null) '${pv['w']} × ${pv['h']}'].join(' · ')),
                    SizedBox(
                      width: 300,
                      height: 150,
                      child: Stack(
                        children: [
                          Positioned.fill(child: _thumb(t, 150, big: true)),
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Row(
                              children: [
                                if (pv != null) ...[
                                  GBtn('⤢ Крупно', sm: true, onTap: () => openTask(context, s, listId, t)),
                                  const SizedBox(width: 6),
                                ],
                                GBtn(
                                  pv == null ? 'Добавить' : 'Заменить',
                                  sm: true,
                                  onTap: () => openTask(context, s, listId, t),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Перетащи картинку сюда или Ctrl+V', style: SpType.text(12, color: SpColors.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 22),
              SizedBox(
                width: 256,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    lbl('Детали'),
                    detail(
                      'Срок',
                      Builder(
                        builder: (bc) => GPick(
                          due.isEmpty ? 'Без срока' : humanDay(due),
                          on: due.isNotEmpty,
                          onTap: () async {
                            final r = await pickDateTime(bc, day: due, withTime: false, busy: (d) => busyHours(s, d));
                            if (r == null) return;
                            s.setDue(listId, t, r.cleared ? null : r.day);
                          },
                        ),
                      ),
                    ),
                    if (client.isNotEmpty) detail('Клиент', GPick(client, on: true)),
                    detail(
                      'Приоритет',
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final (n, l) in [(1, '!!!'), (2, '!!'), (3, '!')])
                            GPick(l, on: prio == n, onTap: () => s.setTask(id, {'priority': prio == n ? null : n})),
                        ],
                      ),
                    ),
                    detail(
                      'Напомнить',
                      GPick(remMin == null ? 'Нет' : 'За ${leadName[remMin] ?? '$remMin мин'}', on: remMin != null),
                    ),
                    if (notes.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: SpColors.nodeHover, borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          notes,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: SpType.text(12.5, color: SpColors.ink2),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(110, 10, 18, 12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: SpColors.line)),
          ),
          child: Row(
            children: [
              if (prev != null)
                InkWell(
                  onTap: () => s.setStage(listId, t, prev['id'] as String),
                  child: Text('← $stage назад к ${prev['name']}', style: SpType.text(12, color: SpColors.muted)),
                ),
              const Spacer(),
              key('ESC'),
              const SizedBox(width: 6),
              Text('свернуть', style: SpType.text(12, color: SpColors.muted)),
              const SizedBox(width: 14),
              key('SPACE'),
              const SizedBox(width: 6),
              Text('следующий', style: SpType.text(12, color: SpColors.muted)),
              const SizedBox(width: 14),
              key('ENTER'),
              const SizedBox(width: 6),
              Text('окно задачи', style: SpType.text(12, color: SpColors.muted)),
              const SizedBox(width: 14),
              InkWell(
                onTap: () => openTask(context, s, listId, t),
                child: Text(
                  'Открыть полностью ↗',
                  style: SpType.text(
                    12,
                    color: SpColors.accent,
                  ).copyWith(decoration: TextDecoration.underline, decorationColor: SpColors.accent),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Превью ассета: картинка из слоя, без неё — сетка с первой буквой.
  Widget _thumb(Json t, double size, {bool big = false}) {
    final title = (t['title'] ?? '') as String;
    final th = (s.layTask(t['id'] as String)['preview'] as Map?)?['thumb'];
    Widget? img;
    if (th is String && th.startsWith('data:image')) {
      try {
        img = Image.memory(UriData.parse(th).contentAsBytes(), fit: BoxFit.cover);
      } catch (_) {}
    }
    return Container(
      width: big ? null : size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF2B2520),
        borderRadius: BorderRadius.circular(big ? 8 : 6),
        border: Border.all(color: const Color(0xFF3F352B)),
      ),
      child:
          img ??
          CustomPaint(
            painter: _Grid(),
            child: Center(
              child: Text(
                big ? 'ПРЕВЬЮ' : (title.isEmpty ? '?' : title.characters.first.toUpperCase()),
                style: big ? gMicro(c: SpColors.muted) : gMono(14, c: SpColors.accentInk, w: FontWeight.w500),
              ),
            ),
          ),
    );
  }

  /// Дорожка этапов: подписанные плашки на всю ширину. Сделанные — зелёные с ✓, текущий — оранжевый и шире,
  /// будущие — пунктир.
  Widget _track(Json t, List<Map> cols, int i, bool done) {
    final cur = done ? cols.length : i;
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          for (var k = 0; k < cols.length; k++) ...[
            if (k > 0) const SizedBox(width: 3),
            Expanded(
              flex: k == cur ? 18 : 10,
              child: Tooltip(
                message: cols[k]['name'] as String,
                child: InkWell(
                  onTap: () => s.setStage(listId, t, cols[k]['id'] as String),
                  borderRadius: BorderRadius.circular(5),
                  child: _plate(cols[k]['name'] as String, k < cur ? 0 : (k == cur ? 1 : 2)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _plate(String name, int st) {
    final text = Text(
      st == 0 ? '✓ $name' : name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: SpType.text(
        12,
        w: st == 1 ? FontWeight.w600 : FontWeight.w400,
        color: switch (st) {
          0 => SpColors.green,
          1 => SpColors.onAccent,
          _ => SpColors.dim,
        },
      ),
    );
    if (st == 2) {
      return Dashed(
        r: 5,
        color: SpColors.line,
        child: Center(
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: text),
        ),
      );
    }
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: st == 1 ? SpColors.accent : SpColors.headGreen.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(5),
        border: st == 1 ? null : Border.all(color: SpColors.headGreen),
      ),
      child: text,
    );
  }
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
        hintText: '+ Подзадача этапа… Enter — добавить',
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
          decoration: BoxDecoration(
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
