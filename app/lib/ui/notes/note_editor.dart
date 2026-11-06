// Текст заметки: правка (поле с подсветкой ссылок, заголовков и тегов) и чтение (ссылки нажимаются,
// у ссылки с подписью видна подпись, шапка свойств скрыта). Разметку считает core/notes/view.dart.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/notes/parse.dart';
import '../../core/notes/view.dart';
import '../../state/notes_state.dart';
import '../theme/tokens.dart';

typedef LinkTap = void Function(String? to, NoteLink link);

TextStyle _base() => SpType.text(14.5, color: SpColors.body, height: 24);

TextStyle _styleOf(SpanKind k) => switch (k) {
      SpanKind.link => _base().copyWith(color: SpColors.accentInk, decoration: TextDecoration.underline, decorationColor: SpColors.accentLine),
      SpanKind.missing => _base().copyWith(color: SpColors.muted, decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.dashed, decorationColor: SpColors.dim),
      SpanKind.heading => SpType.text(17, w: FontWeight.w600, height: 28),
      SpanKind.tag => _base().copyWith(color: SpColors.blue),
      SpanKind.code => _base().copyWith(fontFamily: SpType.mono, fontFamilyFallback: SpType.monoFallback),
      SpanKind.front => SpType.label(12.5, color: SpColors.dim, spacing: 0),
      SpanKind.text => _base(),
    };

/// Куда ведёт каждая ссылка заметки (по началу ссылки в тексте).
Map<int, String?> _targets(NotesState st, String path) => {for (final r in st.index.outgoing(path)) r.link.start: r.to};

bool _isImage(String p) => RegExp(r'\.(png|jpe?g|gif|webp)$', caseSensitive: false).hasMatch(p);

class _HiController extends TextEditingController {
  _HiController(this.st, this.path, String text) : super(text: text);
  final NotesState st;
  final String path;

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    // Пока идёт набор (IME), не режем текст — иначе ломается подчёркивание набираемого.
    if (withComposing && value.composing.isValid && !value.composing.isCollapsed) return TextSpan(style: _base(), text: text);
    final to = _targets(st, path);
    final ps = pieces(path, text, (l) => to[l.start]);
    return TextSpan(style: _base(), children: [for (final p in ps) TextSpan(text: text.substring(p.start, p.end), style: _styleOf(p.kind))]);
  }
}

class NoteEditor extends StatefulWidget {
  const NoteEditor({super.key, required this.st, required this.path, required this.read, required this.onLink});
  final NotesState st;
  final String path;
  final bool read;
  final LinkTap onLink;
  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late _HiController _c;
  final List<TapGestureRecognizer> _taps = [];

  @override
  void initState() {
    super.initState();
    _c = _HiController(widget.st, widget.path, widget.st.textOf(widget.path));
    widget.st.addListener(_outside);
  }

  /// Файл поменялся снаружи (или синхронизацией), а своих правок нет — показываем новый текст.
  void _outside() {
    final t = widget.st.textOf(widget.path);
    if (t == _c.text || widget.st.isDirty(widget.path)) return;
    final sel = _c.selection;
    _c.value = TextEditingValue(
      text: t,
      selection: sel.isValid ? TextSelection.collapsed(offset: sel.baseOffset.clamp(0, t.length)) : const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  void dispose() {
    widget.st.removeListener(_outside);
    for (final t in _taps) {
      t.dispose();
    }
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.read) {
      return TextField(
        controller: _c,
        maxLines: null,
        minLines: 8,
        keyboardType: TextInputType.multiline,
        cursorColor: SpColors.accent,
        style: _base(),
        decoration: const InputDecoration.collapsed(hintText: 'Пиши здесь. [[ — ссылка на заметку, # — тег.'),
        onChanged: (t) => widget.st.edit(widget.path, t),
      );
    }
    return SelectableText.rich(_readSpan());
  }

  /// Чтение: без шапки свойств, ссылки — подписью и нажимаются.
  TextSpan _readSpan() {
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
    final text = widget.st.textOf(widget.path);
    final doc = parseNote(widget.path, text);
    final byStart = {for (final l in doc.links) l.start: l};
    final to = _targets(widget.st, widget.path);
    final ps = pieces(widget.path, text, (l) => to[l.start]);
    final kids = <InlineSpan>[];
    for (final p in ps) {
      if (p.kind == SpanKind.front) continue;
      var s = text.substring(p.start, p.end);
      if (p.kind == SpanKind.heading) s = s.replaceFirst(RegExp(r'^#{1,6}\s+'), '');
      if (p.kind == SpanKind.link || p.kind == SpanKind.missing) {
        final l = byStart[p.start];
        final to = p.to;
        if (l != null && l.embed && to != null && _isImage(to) && widget.st.vault != null) {
          kids.add(WidgetSpan(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(SpRadius.button),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: Image.file(widget.st.vault!.file(to), errorBuilder: (_, _, _) => Text(l.label, style: _styleOf(SpanKind.missing))),
                ),
              ),
            ),
          ));
          continue;
        }
        if (l != null) {
          s = l.label;
          final r = TapGestureRecognizer()..onTap = () => widget.onLink(p.to, l);
          _taps.add(r);
          kids.add(TextSpan(text: s, style: _styleOf(p.kind), recognizer: r, mouseCursor: SystemMouseCursors.click));
          continue;
        }
      }
      kids.add(TextSpan(text: s, style: _styleOf(p.kind)));
    }
    return TextSpan(style: _base(), children: kids);
  }
}
