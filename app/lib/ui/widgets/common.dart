// Общие виджеты: нода (карточка с шапкой), кружок-отметка, умная строка добавления.
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Нода дизайна G: тёмная карточка, шапка ЗАГЛАВНЫМИ моноширинным.
class Node extends StatelessWidget {
  Node({super.key, required this.title, required this.child, Color? head, this.trailing}) : head = head ?? SpColors.headGrey;
  final String title;
  final Widget child;
  final Color head;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Material(
    color: SpColors.node,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(SpRadius.node),
      side: BorderSide(color: SpColors.line),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: head,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: SpType.label(11, color: SpColors.ink, w: FontWeight.w600),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        child,
      ],
    ),
  );
}

/// Круглая отметка «сделано».
class Check extends StatelessWidget {
  Check({super.key, required this.done, required this.onTap});
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkResponse(
    onTap: onTap,
    radius: 16,
    child: AnimatedContainer(
      duration: SpMotion.fast,
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? SpColors.blue : Colors.transparent,
        border: Border.all(color: done ? SpColors.blue : SpColors.lineStrong, width: 1.5),
      ),
      child: done ? Icon(Icons.check, size: 12, color: SpColors.ground) : null,
    ),
  );
}

/// Строка «добавить»: Enter — создать, поле очищается и остаётся в фокусе.
class AddLine extends StatefulWidget {
  AddLine({super.key, required this.hint, required this.onSubmit, this.autofocus = false});
  final String hint;
  final bool autofocus;
  final void Function(String text) onSubmit;

  @override
  State<AddLine> createState() => _AddLineState();
}

class _AddLineState extends State<AddLine> {
  final _c = TextEditingController();
  final _f = FocusNode();

  @override
  void dispose() {
    _c.dispose();
    _f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _c,
    focusNode: _f,
    autofocus: widget.autofocus,
    style: SpType.text(14),
    decoration: InputDecoration(
      isDense: true,
      filled: true,
      fillColor: SpColors.bg,
      prefixIcon: Icon(Icons.add, size: 18, color: SpColors.accent),
      hintText: widget.hint,
      hintStyle: SpType.text(14, color: SpColors.dim),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SpRadius.button),
        borderSide: BorderSide(color: SpColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SpRadius.button),
        borderSide: BorderSide(color: SpColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SpRadius.button),
        borderSide: BorderSide(color: SpColors.accentLine),
      ),
    ),
    onSubmitted: (v) {
      if (v.trim().isEmpty) return;
      widget.onSubmit(v.trim());
      _c.clear();
      _f.requestFocus();
    },
  );
}

/// Цвет шапки по цвету колонки шаблона (0…6 → оттенок G).
Color headFor(Object? c) {
  final byPalette = [
    SpColors.headGrey,
    SpColors.headBlue,
    SpColors.headOrange,
    SpColors.headGold,
    SpColors.headViolet,
    SpColors.headGreen,
    SpColors.headBlue,
  ];
  final i = c is num ? c.toInt() : 0;
  return i >= 0 && i < byPalette.length ? byPalette[i] : SpColors.headGrey;
}

/// Цвет из имени CSS-переменной старого трекера ('var(--clay)' …) — для тем стикеров, сфер, палитры колонок.
Color cssColor(Object? v) => switch ('$v') {
  'var(--clay)' => SpColors.accent,
  'var(--gold)' => SpColors.gold,
  'var(--type-work)' => SpColors.blue,
  'var(--type-study)' => SpColors.violet,
  'var(--type-personal)' => SpColors.green,
  'var(--signal-done)' => const Color(0xFF6FB6CF),
  _ => SpColors.grey,
};
