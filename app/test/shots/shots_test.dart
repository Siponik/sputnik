// Снимки экранов для сверки с макетами G: SHOTS=1 flutter test test/shots --update-goldens → test/shots/out/*.png.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/ui/app_shell.dart';
import 'package:sputnik_app/ui/create/create_dialog.dart' show openCreate;
import 'package:sputnik_app/ui/widgets/search_dialog.dart';
import 'package:sputnik_app/ui/widgets/task_dialog.dart' show openTask;
import 'package:sputnik_app/ui/calendar/calendar_page.dart' show calStartMode;
import 'package:sputnik_app/ui/habits/habits_page.dart' show habitsStartMonth;
import 'package:sputnik_app/ui/theme/tokens.dart';

import 'demo.dart';

Future<void> _fonts() async {
  for (final (fam, ws) in [
    ('Onest', [200, 400, 500, 600]),
    ('JetBrains Mono', [400, 500, 600]),
  ]) {
    final l = FontLoader(fam);
    for (final w in ws) {
      final f = fam == 'Onest' ? 'Onest-$w' : 'JetBrainsMono-$w';
      l.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$f.ttf').readAsBytesSync())));
    }
    await l.load();
  }
  final icons = FontLoader('MaterialIcons');
  final p =
      '${Platform.environment['FLUTTER_ROOT'] ?? ''}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  if (File(p).existsSync()) {
    icons.addFont(Future.value(ByteData.sublistView(File(p).readAsBytesSync())));
    await icons.load();
  }
}

void main() {
  final on = Platform.environment['SHOTS'] == '1';
  setUpAll(() async {
    if (on) await _fonts();
  });
  for (final (i, name, list) in [
    (0, 'today', ''),
    (1, 'calendar', ''),
    (1, 'month', 'M'),
    (2, 'board', ''),
    (3, 'habits', ''),
    (3, 'hmonth', 'H'),
    (4, 'settings', ''),
    (2, 'conveyor', 'A'),
    (2, 'stickers', 'D'),
    (2, 'task', 'T'),
    (2, 'create', 'C'),
    (0, 'search', 'S'),
    (2, 'list', 'U'),
  ]) {
    testWidgets('снимок $name', skip: !on, (t) async {
      t.view.physicalSize = const Size(1440, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      calStartMode = list == 'M' ? 'month' : 'week';
      habitsStartMonth = list == 'H';
      final s = gDemo();
      if (list.length == 1 && !'MHTCS'.contains(list)) s.activeList = list;
      await t.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: spTheme(),
          home: AppShell(state: s, initialTab: i),
        ),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      await t.pump();
      if (list == 'C') {
        openCreate(t.element(find.byType(AppShell)), s, text: 'Рендер щита завтра 17:00 !!');
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
      }
      if (list == 'S') {
        openSearch(t.element(find.byType(AppShell)), s, (_, _) {});
        await t.pump();
        await t.enterText(find.byType(TextField).last, 'щит');
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
      }
      if (list == 'T') {
        final ctx = t.element(find.byType(AppShell));
        final task = s.topTasks('W').first;
        openTask(ctx, s, 'W', task);
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
      }
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/$name.png'));
      await t.pump(const Duration(seconds: 6));
    });
  }
}
