// Экраны рисуются без ошибок раскладки на данных в памяти (без Google и файлов).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/dates.dart';
import 'package:sputnik_app/state/app_state.dart';
import 'package:sputnik_app/ui/board/board_page.dart';
import 'package:sputnik_app/ui/calendar/calendar_page.dart';
import 'package:sputnik_app/ui/habits/habits_page.dart';
import 'package:sputnik_app/ui/theme/tokens.dart';
import 'package:sputnik_app/ui/today/today_page.dart';

AppState demo() {
  final s = AppState();
  final today = ymdToDue(ymd(DateTime.now()));
  s.started = true;
  s.lists = [
    {'id': 'L1', 'title': 'Работа'},
    {'id': 'L2', 'title': 'Дом'},
  ];
  s.tasks = {
    'L1': [
      for (var i = 0; i < 30; i++) {'id': 't$i', 'title': 'Задача $i', 'status': 'needsAction', 'due': today},
      {'id': 'd1', 'title': 'Сделано', 'status': 'completed', 'completed': DateTime.now().toUtc().toIso8601String()},
    ],
    'L2': [],
    'H': [
      {'id': 'h1', 'title': 'Вода', 'status': 'needsAction'},
      {'id': 'h2', 'title': 'Зарядка', 'status': 'needsAction'},
    ],
  };
  s.lists.add({'id': 'H', 'title': 'Привычки'});
  s.layer['habits'] = {
    'h1': {
      'goal': {'n': 8, 'unit': 'стаканов'},
      'createdAt': '2026-01-01',
    },
  };
  s.events = [
    {
      'summary': 'Встреча',
      'start': {'dateTime': DateTime.now().toUtc().toIso8601String()},
      'end': {'dateTime': DateTime.now().toUtc().toIso8601String()},
    },
  ];
  return s;
}

Future<void> pump(WidgetTester t, Widget w, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: spTheme(),
      home: Scaffold(body: w),
    ),
  );
  await t.pump();
}

void main() {
  for (final size in [const Size(1400, 900), const Size(700, 600)]) {
    testWidgets('Сегодня $size', (t) async {
      final s = demo();
      await pump(t, TodayPage(state: s), size);
      expect(find.text('Задача 0'), findsOneWidget);
      s.toggleDone('L1', s.tasks['L1']!.first);
      await t.pump(const Duration(seconds: 6));
    });
    testWidgets('Доска $size', (t) async {
      await pump(t, BoardPage(state: demo()), size);
      expect(find.text('Работа'), findsWidgets);
    });
    testWidgets('Привычки $size', (t) async {
      final s = demo();
      await pump(t, HabitsPage(state: s), size);
      expect(find.text('Вода'), findsOneWidget);
      s.toggleHabit(s.habits.first);
      await t.pump(const Duration(seconds: 6));
    });
    for (final v in ['pipe', 'stickers', 'list']) {
      testWidgets('Доска $v $size', (t) async {
        final s = demo();
        s.layer['lists'] = {
          'L1': {'view': v},
        };
        await pump(t, BoardPage(state: s), size);
        expect(find.text('Задача 1'), findsWidgets);
      });
    }
    testWidgets('Календарь $size', (t) async {
      await pump(t, CalendarPage(state: demo()), size);
      expect(find.text('Встреча'), findsOneWidget);
    });
  }
}
