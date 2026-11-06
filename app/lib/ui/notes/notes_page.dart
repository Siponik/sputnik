// Экран «Знания» (docs/knowledge.md, шаг 6; макет G_Notes и G_NotesStates): слева одна колонка —
// поиск, «Недавние», папки с заметками; справа главная нода — заметка с вкладками, свойствами в строку
// и «Ссылаются сюда» внизу. Правка и чтение — один и тот же текст, ссылки подсвечены.
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/notes/edit.dart';
import '../../core/notes/parse.dart';
import '../../core/notes/sync.dart' show parentFolders;
import '../../core/notes/view.dart';
import '../../state/notes_state.dart';
import '../theme/tokens.dart';
import 'canvas_view.dart';
import 'folder_view.dart';
import 'graph_view.dart';
import 'hue.dart';
import 'links_panel.dart';
import 'note_editor.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key, required this.state, this.pickFolder});
  final NotesState state;

  /// Выбор папки (в тестах — подмена системного окна).
  final Future<String?> Function()? pickFolder;

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  NotesState get st => widget.state;

  Future<String?> _pick() => (widget.pickFolder ?? () => getDirectoryPath(confirmButtonText: 'Выбрать'))();

  Future<void> _choose() async {
    final p = await _pick();
    if (p != null) await st.open(p);
  }

  /// «Создать новую»: папка «Знания» в Документах.
  Future<void> _makeNew() async {
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '.';
    final dir = Directory('$home${Platform.pathSeparator}Documents${Platform.pathSeparator}Знания');
    await dir.create(recursive: true);
    await st.open(dir.path);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) {
        Widget body;
        if (st.loading) {
          body = _Center(child: _StateNode(head: 'ИДЁТ ИНДЕКСАЦИЯ', title: 'Читаю заметки…', text: 'Первый раз — около минуты. Дальше только изменённые файлы, за секунды.'));
        } else if (st.error != null) {
          body = _Center(
            child: _StateNode(
              head: 'ПАПКА НЕДОСТУПНА',
              tone: SpColors.headRed,
              title: 'Не вижу папку «${dirName(st.missingFolder ?? st.config.folder ?? '')}»',
              text: 'Диск отключён или папку переименовали. Заметки не пропали — я просто их не нахожу.',
              actions: [
                _Btn('Найти заново…', main: true, onTap: _choose),
                _Btn('Убрать из списка', onTap: st.forget),
              ],
            ),
          );
        } else if (!st.hasFolder) {
          body = _Center(
            child: _StateNode(
              head: 'ПЕРВЫЙ ЗАПУСК',
              title: 'Где лежат твои заметки?',
              text: 'Подключи папку с файлами .md — например, хранилище Obsidian. Файлы останутся твоими и на месте.',
              actions: [
                _Btn('Выбрать папку…', main: true, onTap: _choose),
                _Btn('Создать новую', onTap: _makeNew),
              ],
            ),
          );
        } else if (st.view == 'graph') {
          body = GraphView(st: st);
        } else {
          body = Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 264, child: _Side(st: st)),
                const SizedBox(width: 16),
                Expanded(child: st.view == 'folder' && st.folder != null ? FolderView(st: st, folder: st.folder!) : _Main(st: st)),
              ],
            ),
          );
        }
        return DotGround(child: body);
      },
    );
  }
}

class _Center extends StatelessWidget {
  const _Center({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Center(child: SizedBox(width: 460, child: child));
}

/// Нода состояния: цветная шапка, заголовок, пояснение, кнопки.
class _StateNode extends StatelessWidget {
  const _StateNode({required this.head, required this.title, required this.text, this.actions = const [], this.tone = SpColors.headGrey});
  final String head;
  final String title;
  final String text;
  final List<Widget> actions;
  final Color tone;
  @override
  Widget build(BuildContext context) => _Node(
        head: head,
        tone: tone,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: SpType.text(19, w: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(text, style: SpType.text(13.5, color: SpColors.muted, height: 20)),
              if (actions.isNotEmpty) ...[const SizedBox(height: 18), Wrap(spacing: 8, runSpacing: 8, children: actions)],
            ],
          ),
        ),
      );
}

/// Нода: контур, цветная шапка с моно-подписью.
class _Node extends StatelessWidget {
  const _Node({required this.head, required this.child, this.tone = SpColors.headGrey, this.count});
  final String head;
  final String? count;
  final Widget child;
  final Color tone;
  @override
  Widget build(BuildContext context) {
    const r = SpRadius.node;
    return Container(
      decoration: BoxDecoration(
        color: SpColors.node,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: SpColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 34,
            padding: const EdgeInsets.only(left: 12, right: 10),
            decoration: BoxDecoration(color: tone, borderRadius: BorderRadius.vertical(top: Radius.circular(r - 1))),
            child: Row(children: [
              Text(head, style: SpType.label(10.5, w: FontWeight.w500, color: Colors.white, spacing: .14)),
              const Spacer(),
              if (count != null) Text(count!, style: SpType.label(10.5, color: const Color(0xB8FFFFFF))),
            ]),
          ),
          Flexible(child: child),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn(this.label, {this.onTap, this.main = false, this.small = false});
  final String label;
  final VoidCallback? onTap;
  final bool main;
  final bool small;
  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          minimumSize: Size(0, small ? 28 : 34),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          backgroundColor: main ? SpColors.accent : Colors.transparent,
          foregroundColor: main ? SpColors.onAccent : SpColors.ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SpRadius.button),
            side: main ? BorderSide.none : const BorderSide(color: SpColors.lineStrong),
          ),
          textStyle: SpType.text(small ? 12.5 : 13, w: FontWeight.w600),
        ),
        child: Text(label),
      );
}

// ---------------- левая колонка ----------------

class _Side extends StatefulWidget {
  const _Side({required this.st});
  final NotesState st;
  @override
  State<_Side> createState() => _SideState();
}

class _SideState extends State<_Side> {
  final _q = TextEditingController();
  final Set<String> _open = {};
  String? _seenActive;

  NotesState get st => widget.st;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  /// Папки активной заметки — раскрыты, чтобы её было видно в дереве.
  void _reveal() {
    final a = st.active;
    if (a == _seenActive) return;
    _seenActive = a;
    if (a != null) _open.addAll(parentFolders(a));
  }

  @override
  Widget build(BuildContext context) {
    _reveal();
    final notes = st.index.paths.toList();
    final canv = st.index.files.where(isCanvasPath).toList();
    final q = _q.text.trim();
    final rows = <Widget>[];
    if (q.isNotEmpty) {
      final hits = st.index.search(q, limit: 40);
      rows.add(_Section('НАЙДЕНО · ${hits.length}'));
      for (final h in hits) {
        rows.add(_Row(
          icon: '¶',
          name: baseName(h.path),
          hint: h.snippet,
          active: h.path == st.active,
          onTap: () => st.openNote(h.path),
        ));
      }
      if (hits.isEmpty) rows.add(Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 6), child: Text('Ничего не нашёл', style: SpType.text(12.5, color: SpColors.muted))));
    } else {
      final recent = st.config.recent.take(3).toList();
      if (recent.isNotEmpty) {
        rows.add(_Section('НЕДАВНИЕ'));
        for (final p in recent) {
          rows.add(_Row(icon: isCanvasPath(p) ? '▦' : '¶', name: shownName(p), active: p == st.active, onTap: () => st.openNote(p)));
        }
      }
      rows.add(_Section('ПАПКИ', line: recent.isNotEmpty));
      for (final r in folderTree([...notes, ...canv], _open, cap: 5)) {
        if (r.path.startsWith('…more:')) {
          rows.add(InkWell(
            onTap: () => setState(() => _open.add('…all:${r.path.substring(6)}')),
            child: Padding(padding: EdgeInsets.fromLTRB(24.0 + 14 * r.depth + 22, 2, 0, 4), child: Text(r.name, style: SpType.text(12, color: SpColors.muted))),
          ));
        } else if (r.folder) {
          rows.add(_Row(
            depth: r.depth,
            caret: r.open ? '▾' : '▸',
            dot: r.depth == 0 ? folderHue('${r.path}/', notes) : null,
            icon: r.depth == 0 ? null : '▭',
            name: r.name,
            count: '${r.count}',
            active: st.view == 'folder' && st.folder == r.path,
            onCaret: () => setState(() => r.open ? _open.remove(r.path) : _open.add(r.path)),
            onTap: () {
              setState(() => _open.add(r.path));
              st.openFolder(r.path);
            },
          ));
        } else {
          final row = _Row(depth: r.depth, icon: isCanvasPath(r.path) ? '▦' : '¶', name: shownName(r.path), active: st.view == 'note' && r.path == st.active, onTap: () => st.openNote(r.path));
          // Заметку можно перетащить на открытый холст.
          rows.add(Draggable<String>(
            data: r.path,
            feedback: Material(color: Colors.transparent, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: SpColors.node, borderRadius: BorderRadius.circular(8), border: Border.all(color: SpColors.accentLine)),
              child: Text(shownName(r.path), style: SpType.text(13)),
            )),
            child: row,
          ));
        }
      }
    }
    return _Node(
      head: 'ЗАМЕТКИ',
      count: '${st.index.length}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            child: Row(children: [
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    controller: _q,
                    onChanged: (_) => setState(() {}),
                    style: SpType.text(13),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Найти заметку',
                      hintStyle: SpType.text(13, color: SpColors.muted),
                      prefixIcon: const Icon(Icons.search, size: 15, color: SpColors.muted),
                      prefixIconConstraints: const BoxConstraints(minWidth: 30),
                      filled: true,
                      fillColor: SpColors.bg,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: SpColors.lineStrong)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: SpColors.accent)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _Square(label: '＋', tip: 'Новая заметка', onTap: () => newNoteDialog(context, st)),
              const SizedBox(width: 6),
              _Square(label: '▦', tip: 'Новый холст', onTap: () => newCanvasDialog(context, st)),
            ]),
          ),
          Expanded(child: ListView(padding: const EdgeInsets.only(bottom: 8), children: rows)),
          Container(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: SpColors.line))),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Expanded(
                child: Text('${dirName(st.config.folder ?? '').toUpperCase()} · ${st.index.length}',
                    overflow: TextOverflow.ellipsis, style: SpType.label(9.5)),
              ),
              Tooltip(message: st.syncStatus, child: Text(st.syncing ? 'DRIVE ⟳' : 'DRIVE', style: SpType.label(9.5, color: _syncColor(st)))),
            ]),
          ),
        ],
      ),
    );
  }
}

Color _syncColor(NotesState st) {
  final r = st.lastSync;
  if (st.syncError != null || r?.driveFull == true) return SpColors.red;
  if (r == null || r.offline || r.failed.isNotEmpty) return SpColors.muted;
  return SpColors.green;
}

class _Square extends StatelessWidget {
  const _Square({required this.label, required this.onTap, this.tip});
  final String label;
  final String? tip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Tooltip(
        message: tip ?? '',
        child: Material(
          color: SpColors.accent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: SizedBox(width: 32, height: 32, child: Center(child: Text(label, style: SpType.text(16, w: FontWeight.w600, color: SpColors.onAccent)))),
          ),
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section(this.text, {this.line = false});
  final String text;
  final bool line;
  @override
  Widget build(BuildContext context) => Container(
        margin: EdgeInsets.only(top: line ? 8 : 0),
        padding: EdgeInsets.fromLTRB(16, line ? 12 : 8, 16, 4),
        decoration: line ? const BoxDecoration(border: Border(top: BorderSide(color: SpColors.line))) : null,
        child: Text(text, style: SpType.label(9.5)),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.name, required this.onTap, this.onCaret, this.depth = 0, this.caret, this.icon, this.dot, this.count, this.hint, this.active = false});
  final VoidCallback? onCaret;
  final String name;
  final int depth;
  final String? caret;
  final String? icon;
  final Color? dot;
  final String? count;
  final String? hint;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: active ? SpColors.accentWash : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          hoverColor: SpColors.nodeHover,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 28),
            padding: EdgeInsets.only(left: 8.0 + 14 * depth, right: 10, top: hint == null ? 0 : 4, bottom: hint == null ? 0 : 4),
            decoration: active ? const BoxDecoration(border: Border(left: BorderSide(color: SpColors.accent, width: 2))) : null,
            child: Row(children: [
              onCaret == null
                  ? SizedBox(width: 10, child: Text(caret ?? '', style: SpType.text(10, color: SpColors.dim)))
                  : InkWell(
                      onTap: onCaret,
                      child: SizedBox(width: 14, height: 24, child: Center(child: Text(caret ?? '', style: SpType.text(10, color: SpColors.dim)))),
                    ),
              const SizedBox(width: 7),
              if (dot != null)
                Container(width: 7, height: 7, margin: const EdgeInsets.only(right: 5), decoration: BoxDecoration(color: dot, borderRadius: BorderRadius.circular(2)))
              else
                SizedBox(width: 12, child: Text(icon ?? '', style: SpType.text(11, color: SpColors.dim))),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: SpType.text(13, color: depth > 0 && !active ? SpColors.ink2 : SpColors.ink)),
                    if (hint != null && hint!.isNotEmpty)
                      Text(hint!, maxLines: 1, overflow: TextOverflow.ellipsis, style: SpType.text(11.5, color: SpColors.muted)),
                  ],
                ),
              ),
              if (count != null) Text(count!, style: SpType.label(11, color: SpColors.dim, spacing: 0)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------------- заметка ----------------

class _Main extends StatefulWidget {
  const _Main({required this.st});
  final NotesState st;
  @override
  State<_Main> createState() => _MainState();
}

class _MainState extends State<_Main> {
  bool _read = false;
  bool _links = false;
  NotesState get st => widget.st;

  @override
  Widget build(BuildContext context) {
    final path = st.active;
    final hub = _hub(context, path);
    if (!_links || path == null || isCanvasPath(path)) return hub;
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(child: hub),
      const SizedBox(width: 16),
      SizedBox(width: 320, child: LinksPanel(st: st, path: path, onClose: () => setState(() => _links = false))),
    ]);
  }

  Widget _hub(BuildContext context, String? path) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: SpColors.node,
              borderRadius: BorderRadius.circular(SpRadius.hub),
              border: Border.all(color: SpColors.accentLine),
              boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 40, offset: Offset(0, 18))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Tabs(st: st),
                if (path == null)
                  Expanded(child: _Empty(st: st))
                else if (isCanvasPath(path))
                  Expanded(child: CanvasView(key: ValueKey(path), st: st, path: path))
                else ...[
                  _Toolbar(st: st, path: path, read: _read, onMode: (r) => setState(() => _read = r), links: _links, onLinks: () => setState(() => _links = !_links)),
                  if (st.conflicts.containsKey(path)) _ConflictBar(st: st, path: path),
                  Expanded(child: _NoteBody(key: ValueKey(path), st: st, path: path, read: _read, onAllLinks: () => setState(() => _links = true))),
                  _Footer(st: st, path: path),
                ],
              ],
            ),
          ),
        ),
        // Уголки-скобки главной ноды.
        for (final c in const [Alignment.topLeft, Alignment.topRight, Alignment.bottomLeft, Alignment.bottomRight])
          Positioned(
            left: c.x < 0 ? -5 : null,
            right: c.x > 0 ? -5 : null,
            top: c.y < 0 ? -5 : null,
            bottom: c.y > 0 ? -5 : null,
            child: IgnorePointer(child: CustomPaint(size: const Size(14, 14), painter: _Bracket(c))),
          ),
      ],
    );
  }
}

class _Bracket extends CustomPainter {
  _Bracket(this.corner);
  final Alignment corner;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = SpColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final left = corner.x < 0, top = corner.y < 0;
    final path = Path();
    final x0 = left ? s.width : 0.0, x1 = left ? 0.0 : s.width;
    final y0 = top ? 0.0 : s.height, y1 = top ? s.height : 0.0;
    path.moveTo(x0, y0);
    path.quadraticBezierTo(x1, y0, x1, y1);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _Bracket old) => old.corner != corner;
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.st});
  final NotesState st;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(color: SpColors.headMain, borderRadius: BorderRadius.vertical(top: Radius.circular(SpRadius.hub - 1))),
      child: Row(children: [
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final t in st.config.tabs)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: t == st.active
                        ? Container(
                            height: 30,
                            padding: const EdgeInsets.only(left: 12, right: 6),
                            decoration: BoxDecoration(color: const Color(0xEBFFFFFF), borderRadius: BorderRadius.circular(7)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(shownName(t), style: SpType.text(13, w: FontWeight.w500, color: const Color(0xFF5A3412))),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => st.closeTab(t),
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(padding: const EdgeInsets.all(4), child: Text('✕', style: SpType.text(11, color: const Color(0x995A3412)))),
                              ),
                            ]),
                          )
                        : InkWell(
                            onTap: () => st.openNote(t),
                            borderRadius: BorderRadius.circular(7),
                            child: Container(
                              height: 30,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(shownName(t), style: SpType.text(13, color: const Color(0xD1FFFFFF))),
                            ),
                          ),
                  ),
                ),
            ],
          ),
        ),
        Tooltip(
          message: 'Новая заметка',
          child: InkWell(
            onTap: () => newNoteDialog(context, st),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('＋', style: SpType.text(15, color: const Color(0xCCFFFFFF)))),
          ),
        ),
      ]),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.st, required this.path, required this.read, required this.onMode, required this.links, required this.onLinks});
  final NotesState st;
  final String path;
  final bool read;
  final ValueChanged<bool> onMode;
  final bool links;
  final VoidCallback onLinks;
  @override
  Widget build(BuildContext context) {
    final dir = folderOf(path);
    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 20, right: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: SpColors.line))),
      child: Row(children: [
        Expanded(child: Text(dir.isEmpty ? 'Корень папки' : dir.replaceAll('/', ' › '), overflow: TextOverflow.ellipsis, style: SpType.text(12.5, color: SpColors.muted))),
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(border: Border.all(color: SpColors.line), borderRadius: BorderRadius.circular(7)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final (label, r) in const [('ПРАВКА', false), ('ЧТЕНИЕ', true)])
              InkWell(
                onTap: () => onMode(r),
                borderRadius: BorderRadius.circular(5),
                child: Container(
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: r == read ? SpColors.ink : Colors.transparent, borderRadius: BorderRadius.circular(5)),
                  child: Text(label, style: SpType.label(10.5, w: FontWeight.w500, color: r == read ? SpColors.bg : SpColors.muted)),
                ),
              ),
          ]),
        ),
        const SizedBox(width: 10),
        TextButton(
          onPressed: onLinks,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 28),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            backgroundColor: links ? SpColors.accentWash : Colors.transparent,
            foregroundColor: links ? SpColors.accentInk : SpColors.ink,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SpRadius.button), side: BorderSide(color: links ? SpColors.accentLine : SpColors.lineStrong)),
            textStyle: SpType.text(12.5, w: FontWeight.w500),
          ),
          child: Text('↔ Связи · ${st.index.degree(path)}'),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: () => st.show('graph'),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 28),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            foregroundColor: SpColors.muted,
            textStyle: SpType.text(12.5, w: FontWeight.w500),
          ),
          child: const Text('Граф'),
        ),
        const SizedBox(width: 6),
        PopupMenuButton<String>(
          tooltip: 'Ещё',
          color: SpColors.node,
          icon: Text('⋯', style: SpType.text(15, color: SpColors.muted)),
          onSelected: (v) async {
            if (v == 'rename') await renameDialog(context, st, path);
            if (v == 'image') await attachDialog(st, path);
            if (v == 'trash') await st.trash(path);
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'rename', child: Text('Переименовать…', style: SpType.text(13))),
            PopupMenuItem(value: 'image', child: Text('Вставить картинку…', style: SpType.text(13))),
            PopupMenuItem(value: 'trash', child: Text('Удалить в корзину папки', style: SpType.text(13, color: SpColors.red))),
          ],
        ),
      ]),
    );
  }
}

class _ConflictBar extends StatelessWidget {
  const _ConflictBar({required this.st, required this.path});
  final NotesState st;
  final String path;
  @override
  Widget build(BuildContext context) => Container(
        color: SpColors.accentWash,
        padding: const EdgeInsets.fromLTRB(20, 10, 14, 10),
        child: Row(children: [
          Expanded(
            child: Text('«${baseName(path)}» изменили в другой программе, пока она была открыта здесь. Ничего не затёрто.',
                style: SpType.text(13, color: SpColors.accentInk)),
          ),
          const SizedBox(width: 10),
          _Btn('Взять из файла', small: true, onTap: () => st.resolve(path, keep: 'disk')),
          const SizedBox(width: 6),
          _Btn('Оставить мою', small: true, onTap: () => st.resolve(path, keep: 'mine')),
          const SizedBox(width: 6),
          _Btn('Обе', small: true, main: true, onTap: () => st.resolve(path, keep: 'both')),
        ]),
      );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.st});
  final NotesState st;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(st.index.length == 0 ? 'В папке пока пусто' : 'Открой заметку слева', style: SpType.text(17, w: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(st.index.length == 0 ? 'Новая заметка ляжет сюда.' : 'Или заведи новую.', style: SpType.text(13, color: SpColors.muted)),
          const SizedBox(height: 16),
          _Btn('＋ Заметка', main: true, onTap: () => newNoteDialog(context, st)),
        ]),
      );
}

class _NoteBody extends StatelessWidget {
  const _NoteBody({super.key, required this.st, required this.path, required this.read, required this.onAllLinks});
  final NotesState st;
  final String path;
  final bool read;
  final VoidCallback onAllLinks;

  void _follow(BuildContext context, String? to, NoteLink l) {
    if (to != null) {
      st.openNote(to);
    } else {
      st.create(folderOf(path), l.target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = st.index.doc(path);
    final back = st.index.backlinks(path);
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth.clamp(0.0, 640.0 + 80) - 80;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB((box.maxWidth - w) / 2, 30, (box.maxWidth - w) / 2, 30),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(doc?.title ?? baseName(path), style: SpType.text(28, w: FontWeight.w600)),
          if (doc != null) ...[const SizedBox(height: 12), _Props(doc: doc)],
          const SizedBox(height: 20),
          NoteEditor(st: st, path: path, read: read, onLink: (to, l) => _follow(context, to, l)),
          if (back.isNotEmpty) ...[
            const SizedBox(height: 26),
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: SpColors.line))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('ССЫЛАЮТСЯ СЮДА · ${back.length}', style: SpType.label(9.5)),
                  const Spacer(),
                  InkWell(onTap: onAllLinks, child: Text('все связи →', style: SpType.text(12.5, color: SpColors.accent))),
                ]),
                const SizedBox(height: 8),
                LayoutBuilder(builder: (context, b) {
                  final cw = (b.maxWidth - 8) / 2;
                  return Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final bl in back)
                      SizedBox(
                        width: cw,
                        child: Material(
                          color: SpColors.nodeHover,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => st.openNote(bl.from),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Container(width: 6, height: 6, decoration: BoxDecoration(color: SpColors.accent, borderRadius: BorderRadius.circular(2))),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(baseName(bl.from), overflow: TextOverflow.ellipsis, style: SpType.text(13, w: FontWeight.w600))),
                                ]),
                                const SizedBox(height: 2),
                                Text(bl.snippet, maxLines: 2, overflow: TextOverflow.ellipsis, style: SpType.text(12.5, color: SpColors.muted)),
                              ]),
                            ),
                          ),
                        ),
                      ),
                  ]);
                }),
              ]),
            ),
          ],
        ]),
      );
    });
  }
}

/// Свойства в строку: тип, теги, прочие поля шапки.
class _Props extends StatelessWidget {
  const _Props({required this.doc});
  final NoteDoc doc;
  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    Widget chip(List<Widget> kids) => Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(border: Border.all(color: SpColors.line), borderRadius: BorderRadius.circular(13)),
          child: Row(mainAxisSize: MainAxisSize.min, children: kids),
        );
    for (final e in doc.props.entries) {
      if (const {'tags', 'tag', 'aliases', 'alias', 'cssclasses'}.contains(e.key)) continue;
      final v = e.value;
      if (v == null || (v is String && v.isEmpty)) continue;
      final text = v is List ? v.join(', ') : '$v';
      chips.add(Tooltip(
        message: e.key,
        child: chip([
          if (e.key == 'type') ...[
            Container(width: 7, height: 7, decoration: BoxDecoration(color: SpColors.accent, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 6),
          ] else ...[
            Text('${e.key} ', style: SpType.text(12, color: SpColors.dim)),
          ],
          Text(text.replaceAll(RegExp(r'\[\[|\]\]'), ''), style: SpType.text(12.5)),
        ]),
      ));
    }
    for (final t in doc.tags) {
      chips.add(chip([Text('#', style: SpType.label(12, spacing: 0)), const SizedBox(width: 4), Text(t, style: SpType.text(12.5))]));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.st, required this.path});
  final NotesState st;
  final String path;
  @override
  Widget build(BuildContext context) {
    final dirty = st.isDirty(path);
    final conflict = st.conflicts.containsKey(path);
    final (color, text) = conflict
        ? (SpColors.red, 'Не сохранено · файл изменили снаружи')
        : dirty
            ? (SpColors.gold, 'Сохраняю…')
            : (SpColors.green, 'Сохранено · ${path.substring(path.lastIndexOf('/') + 1)}');
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: SpColors.line))),
      child: Row(children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Expanded(child: Text(text, overflow: TextOverflow.ellipsis, style: SpType.text(12, color: SpColors.dim))),
        Text('${wordCount(st.textOf(path))} слов', style: SpType.text(12, color: SpColors.dim)),
      ]),
    );
  }
}

// ---------------- окна ----------------

Future<String?> _ask(BuildContext context, {required String title, required String label, String initial = '', String ok = 'Готово', Widget? extra}) {
  final c = TextEditingController(text: initial)..selection = TextSelection(baseOffset: 0, extentOffset: initial.length);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: SpColors.node,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SpRadius.hub), side: const BorderSide(color: SpColors.line)),
      title: Text(title, style: SpType.text(17, w: FontWeight.w600)),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: SpType.text(13, color: SpColors.muted)),
          const SizedBox(height: 8),
          TextField(
            controller: c,
            autofocus: true,
            style: SpType.text(14),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            decoration: _field(),
          ),
          ?extra,
        ]),
      ),
      actions: [
        _Btn('Отмена', onTap: () => Navigator.pop(ctx)),
        _Btn(ok, main: true, onTap: () => Navigator.pop(ctx, c.text.trim())),
      ],
    ),
  );
}

/// Заметки-заготовки: всё из папки «Шаблоны» (или «Templates», как у Obsidian).
List<String> templatesOf(NotesState st) => st.index.paths.where((p) {
      final top = p.contains('/') ? p.substring(0, p.indexOf('/')).toLowerCase() : '';
      return top == 'шаблоны' || top == 'templates';
    }).toList()
  ..sort();

/// Новая заметка: в папке открытой заметки (или в корне), можно из шаблона.
Future<void> newNoteDialog(BuildContext context, NotesState st) async {
  final a = st.active;
  var dir = a == null ? '' : folderOf(a);
  if (templatesOf(st).contains(a)) dir = '';
  final tpls = templatesOf(st);
  String? tpl;
  final c = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        backgroundColor: SpColors.node,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SpRadius.hub), side: const BorderSide(color: SpColors.line)),
        title: Text('Новая заметка', style: SpType.text(17, w: FontWeight.w600)),
        content: SizedBox(
          width: 440,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(dir.isEmpty ? 'Название — ляжет в корень папки' : 'Название — ляжет в «${dir.replaceAll('/', ' › ')}»', style: SpType.text(13, color: SpColors.muted)),
            const SizedBox(height: 8),
            TextField(
              controller: c,
              autofocus: true,
              style: SpType.text(14),
              onSubmitted: (_) => Navigator.pop(ctx, true),
              decoration: _field(),
            ),
            if (tpls.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Из шаблона', style: SpType.text(13, color: SpColors.muted)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final t in [null, ...tpls])
                  ChoiceChip(
                    label: Text(t == null ? 'Пустая' : baseName(t), style: SpType.text(12.5, color: tpl == t ? SpColors.onAccent : SpColors.ink)),
                    selected: tpl == t,
                    showCheckmark: false,
                    selectedColor: SpColors.accent,
                    backgroundColor: SpColors.bg,
                    side: const BorderSide(color: SpColors.line),
                    onSelected: (_) => set(() => tpl = t),
                  ),
              ]),
            ],
          ]),
        ),
        actions: [
          _Btn('Отмена', onTap: () => Navigator.pop(ctx, false)),
          _Btn('Создать', main: true, onTap: () => Navigator.pop(ctx, true)),
        ],
      ),
    ),
  );
  final name = c.text.trim();
  if (ok != true || name.isEmpty) return;
  await st.create(dir, name, template: tpl);
}

/// Новый холст `.canvas` в папке открытой заметки (или в корне).
Future<void> newCanvasDialog(BuildContext context, NotesState st) async {
  final a = st.active;
  final dir = a == null ? '' : folderOf(a);
  final name = await _ask(context, title: 'Новый холст', label: dir.isEmpty ? 'Название — ляжет в корень папки' : 'Название — ляжет в «${dir.replaceAll('/', ' › ')}»', ok: 'Создать');
  if (name == null || name.isEmpty) return;
  await st.createCanvas(dir, name);
}

InputDecoration _field() => InputDecoration(
      filled: true,
      fillColor: SpColors.bg,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: SpColors.lineStrong)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: SpColors.accent)),
    );

/// Картинка с диска → в «Вложения/», ссылка — в конец заметки.
Future<void> attachDialog(NotesState st, String path) async {
  const types = XTypeGroup(label: 'Картинки', extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'svg']);
  final f = await openFile(acceptedTypeGroups: const [types], confirmButtonText: 'Вставить');
  if (f == null) return;
  final embed = await st.attach(f.name, await f.readAsBytes());
  final t = st.textOf(path);
  st.edit(path, '${t.isEmpty || t.endsWith('\n') ? t : '$t\n'}$embed\n');
}

/// Переименовать с обновлением ссылок в других заметках.
Future<void> renameDialog(BuildContext context, NotesState st, String path) async {
  final n = st.renameTouches(path);
  final name = await _ask(
    context,
    title: 'Переименовать',
    label: 'Новое название',
    initial: baseName(path),
    ok: 'Переименовать',
    extra: n == 0 ? null : Padding(padding: const EdgeInsets.only(top: 10), child: Text('Ссылки поправлю в $n ${n == 1 ? 'заметке' : 'заметках'}.', style: SpType.text(12.5, color: SpColors.muted))),
  );
  if (name == null || name.isEmpty || name == baseName(path)) return;
  final dir = folderOf(path);
  final ext = path.substring(path.lastIndexOf('.'));
  final to = '${dir.isEmpty ? '' : '$dir/'}${safeFileName(name)}$ext';
  if (st.index.doc(to) != null && to.toLowerCase() != path.toLowerCase()) {
    if (context.mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('Заметка «$name» уже есть в этой папке')));
    return;
  }
  try {
    await st.rename(path, to);
  } on FileSystemException catch (e) {
    if (context.mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('Не переименовалось: ${e.message}')));
  }
}

/// Клавиши раздела (Ctrl+N — новая заметка, Ctrl+W — закрыть вкладку, Ctrl+G — граф).
Map<ShortcutActivator, VoidCallback> notesKeys(BuildContext context, NotesState st) => {
      const SingleActivator(LogicalKeyboardKey.keyN, control: true): () => newNoteDialog(context, st),
      const SingleActivator(LogicalKeyboardKey.keyG, control: true): () => st.show(st.view == 'graph' ? 'note' : 'graph'),
      const SingleActivator(LogicalKeyboardKey.keyW, control: true): () {
        if (st.active != null) st.closeTab(st.active!);
      },
    };
