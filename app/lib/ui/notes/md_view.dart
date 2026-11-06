// Заметка «как в чтении Obsidian» для нод холста: заголовки, абзацы с переносом строк, списки и чек-листы,
// цитаты и выноски `> [!note]`, код, линии, картинки `![[…]]` и `![](…)`, жирный, курсив, ==выделение==,
// `код`, ссылки `[[…]]` подписью и #теги. Без пакетов: разбор построчный, строки не обрезаются.
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/notes/parse.dart' show frontSpan;
import '../theme/tokens.dart';

bool _isImage(String p) => RegExp(r'\.(png|jpe?g|gif|webp|bmp)$', caseSensitive: false).hasMatch(p);

class MdView extends StatelessWidget {
  const MdView({super.key, required this.text, this.resolve, this.fileOf, this.size = 13});

  final String text;

  /// Ссылка `[[цель]]` → путь файла в папке (или null).
  final String? Function(String target)? resolve;

  /// Путь в папке → файл на диске (для картинок).
  final File Function(String path)? fileOf;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fs = frontSpan(text);
    final body = fs == null ? text : text.substring(fs.bodyStart);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: _blocks(body),
    );
  }

  TextStyle get _base => SpType.text(size, color: SpColors.body, height: size * 1.5);

  List<Widget> _blocks(String body) {
    final out = <Widget>[];
    final lines = body.split('\n');
    final para = <String>[];
    void flush() {
      if (para.isEmpty) return;
      out.add(_gap(Text.rich(_inline(para.join(' ')), style: _base)));
      para.clear();
    }

    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final l = raw.trimRight();
      if (l.trim().isEmpty) {
        flush();
        continue;
      }
      // Код ```…```
      if (l.trimLeft().startsWith('```')) {
        flush();
        final code = <String>[];
        i++;
        while (i < lines.length && !lines[i].trimLeft().startsWith('```')) {
          code.add(lines[i]);
          i++;
        }
        out.add(
          _gap(
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: SpColors.bg,
                borderRadius: BorderRadius.circular(SpRadius.button),
                border: Border.all(color: SpColors.lineSoft),
              ),
              child: Text(code.join('\n'), style: SpType.label(size - 1.5, color: SpColors.ink2, spacing: 0)),
            ),
          ),
        );
        continue;
      }
      final h = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(l);
      if (h != null) {
        flush();
        final lvl = h[1]!.length;
        final fsz = size + [9.0, 6.0, 4.0, 2.0, 1.0, 0.0][lvl - 1];
        out.add(
          Padding(
            padding: EdgeInsets.only(top: out.isEmpty ? 0 : size * .6, bottom: size * .3),
            child: Text.rich(
              _inline(h[2]!),
              style: SpType.text(
                fsz,
                w: lvl <= 2 ? FontWeight.w600 : FontWeight.w500,
                color: SpColors.ink,
                height: fsz * 1.3,
              ),
            ),
          ),
        );
        continue;
      }
      if (RegExp(r'^\s*(-{3,}|\*{3,}|_{3,})\s*$').hasMatch(l)) {
        flush();
        out.add(_gap(const Divider(height: 1, color: SpColors.line)));
        continue;
      }
      // Картинка одной строкой.
      final img =
          RegExp(r'^\s*!\[\[([^\]|#]+)(?:\|(\d+))?[^\]]*\]\]\s*$').firstMatch(l) ??
          RegExp(r'^\s*!\[[^\]]*\]\(([^)\s]+)\)\s*$').firstMatch(l);
      if (img != null) {
        flush();
        final w = _image(img[1]!, img.groupCount >= 2 && img[2] != null ? double.tryParse(img[2]!) : null);
        if (w != null) {
          out.add(_gap(w));
          continue;
        }
      }
      // Цитата и выноска.
      if (l.trimLeft().startsWith('>')) {
        flush();
        final q = <String>[];
        while (i < lines.length && lines[i].trimLeft().startsWith('>')) {
          q.add(lines[i].trimLeft().substring(1).replaceFirst(RegExp(r'^ '), ''));
          i++;
        }
        i--;
        final call = RegExp(r'^\[!(\w+)\][+-]?\s*(.*)$').firstMatch(q.first);
        final title = call == null ? null : (call[2]!.isEmpty ? call[1]!.toUpperCase() : call[2]!);
        final rest = call == null ? q : q.sublist(1);
        final c = call == null ? SpColors.lineStrong : _calloutColor(call[1]!);
        out.add(
          _gap(
            Container(
              padding: EdgeInsets.fromLTRB(10, call == null ? 2 : 8, 8, call == null ? 2 : 8),
              decoration: BoxDecoration(
                color: call == null ? null : c.withValues(alpha: .08),
                borderRadius: call == null ? null : BorderRadius.circular(SpRadius.button),
                border: Border(left: BorderSide(color: c, width: 2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        title,
                        style: SpType.text(size, w: FontWeight.w600, color: c),
                      ),
                    ),
                  ..._blocks(rest.join('\n')),
                ],
              ),
            ),
          ),
        );
        continue;
      }
      // Пункт списка или чек-листа.
      final li = RegExp(r'^(\s*)([-*+]|\d+[.)])\s+(?:\[([ xX])\]\s+)?(.*)$').firstMatch(raw);
      if (li != null) {
        flush();
        final depth = (li[1]!.replaceAll('\t', '    ').length / 2).floor().clamp(0, 6);
        final box = li[3];
        final mark = li[2]!;
        final Widget bullet = box != null
            ? Icon(
                box == ' ' ? Icons.check_box_outline_blank : Icons.check_box,
                size: size + 2,
                color: box == ' ' ? SpColors.dim : SpColors.accent,
              )
            : Text(RegExp(r'\d').hasMatch(mark) ? mark : '•', style: _base.copyWith(color: SpColors.muted));
        out.add(
          Padding(
            padding: EdgeInsets.only(left: 14.0 * depth, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: size * 1.6,
                  child: Padding(
                    padding: EdgeInsets.only(top: box != null ? size * .15 : 0),
                    child: bullet,
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    _inline(li[4]!),
                    style: box != null && box != ' '
                        ? _base.copyWith(color: SpColors.muted, decoration: TextDecoration.lineThrough)
                        : _base,
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }
      para.add(l.trim());
    }
    flush();
    return out;
  }

  Widget _gap(Widget w) => Padding(
    padding: EdgeInsets.only(bottom: size * .55),
    child: w,
  );

  Color _calloutColor(String kind) => switch (kind.toLowerCase()) {
    'warning' || 'caution' || 'attention' => SpColors.gold,
    'danger' || 'error' || 'bug' || 'failure' => SpColors.red,
    'tip' || 'hint' || 'success' || 'check' || 'done' => SpColors.green,
    'question' || 'help' || 'faq' => SpColors.violet,
    'quote' || 'cite' => SpColors.grey,
    _ => SpColors.blue,
  };

  Widget? _image(String target, double? w) {
    final f = fileOf;
    if (f == null) return null;
    final p = _isImage(target) ? (resolve?.call(target) ?? target) : null;
    if (p == null) return null;
    final img = Image(
      image: ResizeImage(FileImage(f(p)), width: 1024, policy: ResizeImagePolicy.fit),
      fit: BoxFit.contain,
      alignment: Alignment.topLeft,
      errorBuilder: (_, _, _) => Text(target, style: SpType.label(size - 3, color: SpColors.dim)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(SpRadius.button),
      child: w == null
          ? img
          : Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: w, child: img),
            ),
    );
  }

  static final _tok = RegExp(
    r'(!?\[\[[^\]]+\]\])|(\[[^\]]+\]\([^)\s]+\))|(\*\*[^*]+\*\*|__[^_]+__)|(==[^=]+==)|(`[^`]+`)|(\*[^*\s][^*]*\*|_[^_\s][^_]*_)|((?:^|(?<=\s))#[\p{L}\p{N}_/-]+)',
    unicode: true,
  );

  TextSpan _inline(String s) {
    final kids = <InlineSpan>[];
    var at = 0;
    for (final m in _tok.allMatches(s)) {
      if (m.start > at) kids.add(TextSpan(text: s.substring(at, m.start)));
      final t = m[0]!;
      if (m[1] != null) {
        final inner = t.substring(t.startsWith('!') ? 3 : 2, t.length - 2);
        final bar = inner.indexOf('|');
        final target = (bar < 0 ? inner : inner.substring(0, bar)).split('#').first;
        final label = bar < 0 ? inner.split('#').first.split('/').last : inner.substring(bar + 1);
        final found = resolve?.call(target) != null;
        kids.add(
          TextSpan(
            text: label,
            style: TextStyle(
              color: found ? SpColors.accentInk : SpColors.muted,
              decoration: found ? null : TextDecoration.underline,
            ),
          ),
        );
      } else if (m[2] != null) {
        kids.add(
          TextSpan(
            text: t.substring(1, t.indexOf('](')),
            style: const TextStyle(color: SpColors.blue),
          ),
        );
      } else if (m[3] != null) {
        kids.add(
          TextSpan(
            children: [_inline(t.substring(2, t.length - 2))],
            style: const TextStyle(fontWeight: FontWeight.w600, color: SpColors.ink),
          ),
        );
      } else if (m[4] != null) {
        kids.add(
          TextSpan(
            text: t.substring(2, t.length - 2),
            style: TextStyle(backgroundColor: SpColors.gold.withValues(alpha: .25), color: SpColors.ink),
          ),
        );
      } else if (m[5] != null) {
        kids.add(
          TextSpan(
            text: t.substring(1, t.length - 1),
            style: SpType.label(size - 1, color: SpColors.accentInk, spacing: 0).copyWith(backgroundColor: SpColors.bg),
          ),
        );
      } else if (m[6] != null) {
        kids.add(
          TextSpan(
            children: [_inline(t.substring(1, t.length - 1))],
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      } else {
        kids.add(
          TextSpan(
            text: t,
            style: const TextStyle(color: SpColors.blue),
          ),
        );
      }
      at = m.end;
    }
    if (at < s.length) kids.add(TextSpan(text: s.substring(at)));
    return TextSpan(children: kids);
  }
}
