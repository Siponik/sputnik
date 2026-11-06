import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/state/notes_state.dart';
import 'package:sputnik_app/ui/notes/notes_page.dart';
import 'package:sputnik_app/ui/theme/tokens.dart';

void main() {
  late Directory tmp;
  late Directory vault;
  late NotesState st;

  void put(String rel, String text) {
    final f = File('${vault.path}/$rel');
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(text);
  }

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('npage');
    vault = Directory('${tmp.path}/vault')..createSync();
    put('3D/Техники/Запекание нормалей.md', '---\ntype: Техника\ntags: [baking]\n---\n# Порядок\nСм. [[UV без растяжений|развёртку]] и [[Нет такой]].\n');
    put('3D/Техники/UV без растяжений.md', 'Про UV.');
    put('3D/Щит.md', 'Пёк по [[Запекание нормалей]].');
    st = NotesState(DirNotesFiles(Directory('${tmp.path}/cfg')))
      ..saveDelay = const Duration(milliseconds: 5)
      ..watchFiles = false;
  });

  tearDown(() {
    st.dispose();
    tmp.deleteSync(recursive: true);
  });

  Future<void> pump(WidgetTester t) async {
    t.view.physicalSize = const Size(1400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(theme: spTheme(), home: Scaffold(body: NotesPage(state: st, pickFolder: () async => vault.path))));
  }

  testWidgets('первый запуск → выбрать папку → дерево и заметка', (t) async {
    await pump(t);
    expect(find.text('Где лежат твои заметки?'), findsOneWidget);
    await t.runAsync(() async {
      await t.tap(find.text('Выбрать папку…'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await t.pump();
    expect(find.text('ЗАМЕТКИ'), findsOneWidget);
    expect(find.text('3D'), findsOneWidget);
    expect(find.text('Щит'), findsNothing); // папка закрыта

    await t.tap(find.text('3D'));
    await t.pump();
    await t.tap(find.text('Техники'));
    await t.pump();
    await t.tap(find.text('Запекание нормалей'));
    await t.pump();
    // Заголовок заметки, свойство и тег в строку, «Ссылаются сюда».
    expect(find.text('Запекание нормалей'), findsWidgets);
    expect(find.text('Техника'), findsOneWidget);
    expect(find.text('baking'), findsOneWidget);
    expect(find.text('ССЫЛАЮТСЯ СЮДА · 1'), findsOneWidget);
    expect(find.text('3D › Техники'), findsOneWidget);
    expect(find.textContaining('Сохранено'), findsOneWidget);

    // Чтение: у ссылки видна подпись, шапки свойств нет.
    await t.tap(find.text('ЧТЕНИЕ'));
    await t.pump();
    final rich = t.widget<SelectableText>(find.byType(SelectableText)).textSpan!.toPlainText();
    expect(rich, contains('развёртку'));
    expect(rich, isNot(contains('type:')));
    expect(rich, isNot(contains('[[')));
  });

  testWidgets('новая заметка — можно выбрать шаблон из папки «Шаблоны»', (t) async {
    put('Шаблоны/НПС.md', '# {{title}}');
    await t.runAsync(() => st.open(vault.path, watch: false));
    await pump(t);
    await t.tap(find.byTooltip('Новая заметка').first);
    await t.pumpAndSettle();
    expect(find.text('Из шаблона'), findsOneWidget);
    expect(find.text('Пустая'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'НПС'), findsOneWidget);
    await t.tap(find.text('Отмена'));
    await t.pumpAndSettle();
  });

  testWidgets('папка пропала — понятное состояние', (t) async {
    await t.runAsync(() => st.open('${tmp.path}/нет-такой', watch: false));
    await pump(t);
    expect(find.text('Не вижу папку «нет-такой»'), findsOneWidget);
    expect(find.text('Найти заново…'), findsOneWidget);
  });
}
