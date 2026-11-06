// «Знания» внутри приложения: вкладка в шапке и блок «Заметки» в окне задачи.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/notes/tasks.dart';
import 'package:sputnik_app/state/app_state.dart';
import 'package:sputnik_app/state/notes_state.dart';
import 'package:sputnik_app/ui/app_shell.dart';
import 'package:sputnik_app/ui/theme/tokens.dart';
import 'package:sputnik_app/ui/widgets/task_dialog.dart';

void main() {
  late Directory tmp;
  late NotesState st;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('napp');
    final vault = Directory('${tmp.path}/vault')..createSync();
    Directory('${vault.path}/DND').createSync();
    File('${vault.path}/DND/Сессия 3.md').writeAsStringSync('- [ ] Нарисовать карту\n');
    File('${vault.path}/Карта мира.md').writeAsStringSync('Нужно нарисовать карту мира.');
    st = NotesState(DirNotesFiles(Directory('${tmp.path}/cfg')))
      ..saveDelay = const Duration(milliseconds: 5)
      ..watchFiles = false;
  });

  tearDown(() {
    st.dispose();
    tmp.deleteSync(recursive: true);
  });

  AppState app() {
    final s = AppState();
    s.started = true;
    s.lists = [
      {'id': 'L1', 'title': 'Работа'},
    ];
    s.tasks = {
      'L1': [
        {'id': 't1', 'title': 'Карта мира', 'status': 'needsAction', 'notes': taskNotesFrom('DND/Сессия 3.md')},
      ],
    };
    return s;
  }

  Future<void> size(WidgetTester t) async {
    t.view.physicalSize = const Size(1400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  testWidgets('вкладка «Знания» в шапке, без входа в Google', (t) async {
    await t.runAsync(() => st.open('${tmp.path}/vault', watch: false));
    final s = app()..needLogin = true;
    await size(t);
    await t.pumpWidget(MaterialApp(theme: spTheme(), home: AppShell(state: s, notes: st, syncEvery: const Duration(hours: 1))));
    await t.tap(find.text('ЗНАНИЯ'));
    await t.pump();
    expect(find.text('ЗАМЕТКИ'), findsOneWidget);
    expect(find.text('DND'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 4));
  });

  testWidgets('окно задачи: «Заметки» — откуда пришла и где написано; клик открывает', (t) async {
    await t.runAsync(() => st.open('${tmp.path}/vault', watch: false));
    final s = app()..notes = st;
    String? opened;
    s.showNote = (p) => opened = p;
    await size(t);
    await t.pumpWidget(
      MaterialApp(
        theme: spTheme(),
        home: Scaffold(
          body: Builder(
            builder: (c) => TextButton(onPressed: () => openTask(c, s, 'L1', s.tasks['L1']!.first), child: const Text('go')),
          ),
        ),
      ),
    );
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    expect(find.text('ЗАМЕТКИ · 2'), findsOneWidget);
    expect(find.text('Сессия 3'), findsOneWidget);
    expect(find.textContaining('＋ Заметка'), findsNothing); // заметка «Карта мира» уже есть
    await t.ensureVisible(find.text('Сессия 3'));
    await t.tap(find.text('Сессия 3'));
    await t.pumpAndSettle();
    expect(opened, 'DND/Сессия 3.md');
    await t.pump(const Duration(seconds: 6));
  });
}
