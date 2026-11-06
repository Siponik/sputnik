// Горячие клавиши по физической клавише: работают и в русской раскладке.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/ui/app_shell.dart';
import 'package:sputnik_app/ui/calendar/calendar_page.dart';
import 'package:sputnik_app/ui/theme/tokens.dart';

import 'screens_test.dart' show demo;

void main() {
  testWidgets('Ctrl+К (KeyK) в русской раскладке — поиск, 2 — Календарь', (t) async {
    t.view.physicalSize = const Size(1400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: spTheme(),
        home: AppShell(state: demo()),
      ),
    );
    await t.pump();

    // «2» — Календарь.
    await t.sendKeyEvent(LogicalKeyboardKey.digit2, physicalKey: PhysicalKeyboardKey.digit2);
    await t.pump();
    expect(find.byType(CalendarPage), findsOneWidget);

    // Ctrl + физическая K, а логическая — русская «л».
    const el = LogicalKeyboardKey(0x0000043b);
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft, platform: 'web');
    await t.sendKeyDownEvent(el, physicalKey: PhysicalKeyboardKey.keyK, character: 'л', platform: 'web');
    await t.sendKeyUpEvent(el, physicalKey: PhysicalKeyboardKey.keyK, platform: 'web');
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft, platform: 'web');
    await t.pumpAndSettle();
    expect(find.text('Найти задачу, список или раздел'), findsOneWidget);
  });
}
