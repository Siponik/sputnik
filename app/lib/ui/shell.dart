// Шапка нового приложения в стиле «Системы G»: знак, разделы ЗАГЛАВНЫМИ, время, «Состояние».
// Пока разделов два: «Сегодня» (пилот) и «Знания». Остальные появятся по мере переноса.
import 'dart:async';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/notes_state.dart';
import 'notes/notes_page.dart';
import 'theme/tokens.dart';
import 'today_page.dart';

class Shell extends StatefulWidget {
  const Shell({super.key, required this.app, required this.notes, this.syncEvery = const Duration(minutes: 2)});
  final AppState app;
  final NotesState notes;
  final Duration syncEvery;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;
  Timer? _clock;
  Timer? _sync;

  static const _tabs = ['СЕГОДНЯ', 'ЗНАНИЯ'];

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 20), (_) => setState(() {}));
    // «Знания» сверяются с Drive раз в 2 минуты и сразу после запуска.
    _sync = Timer.periodic(widget.syncEvery, (_) => widget.notes.syncNow());
    Future.delayed(const Duration(seconds: 3), () => mounted ? widget.notes.syncNow() : null);
  }

  @override
  void dispose() {
    _clock?.cancel();
    _sync?.cancel();
    widget.notes.flush();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final page = _tab == 1 ? NotesPage(state: widget.notes) : TodayPage(state: widget.app);
    return Scaffold(
      backgroundColor: SpColors.bg,
      body: CallbackShortcuts(
        bindings: _tab == 1 ? notesKeys(context, widget.notes) : const {},
        child: Focus(
          autofocus: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: const BoxDecoration(color: SpColors.bg, border: Border(bottom: BorderSide(color: SpColors.line))),
              child: Row(children: [
                CustomPaint(size: const Size(20, 20), painter: _Mark()),
                const SizedBox(width: 10),
                Text('СПУТНИК', style: SpType.label(11, w: FontWeight.w500, color: SpColors.ink, spacing: .14)),
                const SizedBox(width: 26),
                for (var i = 0; i < _tabs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: InkWell(
                      onTap: () => setState(() => _tab = i),
                      child: Container(
                        padding: const EdgeInsets.only(bottom: 3, top: 4),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: i == _tab ? SpColors.accent : Colors.transparent))),
                        child: Text(_tabs[i], style: SpType.label(11, w: FontWeight.w500, color: i == _tab ? SpColors.ink : SpColors.muted, spacing: .14)),
                      ),
                    ),
                  ),
                const Spacer(),
                Text(time, style: SpType.label(11, w: FontWeight.w500, spacing: .14)),
                const SizedBox(width: 16),
                ListenableBuilder(
                  listenable: widget.notes,
                  builder: (context, _) => Tooltip(
                    message: widget.notes.syncStatus,
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(border: Border.all(color: SpColors.line), borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        for (final c in [SpColors.green, SpColors.green, _notesDot(widget.notes)]) ...[
                          Container(width: 6, height: 6, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 6),
                        ],
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
            Expanded(child: page),
          ]),
        ),
      ),
    );
  }
}

/// Третья точка «Состояния» — «Знания»: зелёная — всё отправлено, золотая — отправляю или ждёт связи, красная — ошибка.
Color _notesDot(NotesState n) {
  final r = n.lastSync;
  if (n.syncError != null || r?.driveFull == true) return SpColors.red;
  if (n.syncing || r == null || !r.ok) return SpColors.gold;
  return SpColors.green;
}

/// Знак: буква «С» на орбите и квадратик-спутник.
class _Mark extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final k = s.width / 24;
    canvas.scale(k);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..color = SpColors.ink;
    canvas.save();
    canvas.translate(12, 12);
    canvas.rotate(-28 * 3.14159265 / 180);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 20, height: 8), p..strokeWidth = 1);
    canvas.restore();
    canvas.drawArc(Rect.fromCircle(center: const Offset(12, 12), radius: 5), 0.86, 4.56, false, p..strokeWidth = 1.5);
    canvas.drawRect(const Rect.fromLTWH(18, 6, 3, 3), Paint()..color = SpColors.accent);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
