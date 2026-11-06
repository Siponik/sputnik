import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/state/notes_state.dart';
import 'package:sputnik_app/ui/notes/notes_page.dart';
import 'package:sputnik_app/ui/notes/notes_search.dart';
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
    await t.tap(find.text('Запекание нормалей').first); // строка в дереве (справа — та же заметка в списке папки)
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

  testWidgets('панель «Связи»: наружу, сюда, «Создать», «Связать», локальный граф', (t) async {
    put('Учёба/Конспект.md', 'Сегодня разбирали запекание нормалей.');
    await t.runAsync(() => st.open(vault.path, watch: false));
    st.openNote('3D/Техники/Запекание нормалей.md');
    await pump(t);
    expect(find.text('↔ Связи · 2'), findsOneWidget);
    await t.tap(find.text('↔ Связи · 2'));
    await t.pump();
    expect(find.text('СВЯЗИ'), findsOneWidget);
    expect(find.text('ССЫЛАЕТСЯ НА · 2'), findsOneWidget);
    expect(find.text('СОЗДАТЬ'), findsOneWidget);
    expect(find.text('ССЫЛАЮТСЯ СЮДА · 1'), findsWidgets);
    expect(find.text('УПОМЯНУТО БЕЗ ССЫЛКИ · 1'), findsOneWidget);
    expect(find.text('ЛОКАЛЬНЫЙ ГРАФ · ГЛУБИНА 1'), findsOneWidget);
    expect(find.text('Глубина 1 · 3 заметки'), findsOneWidget);

    await t.tap(find.text('Связать'));
    await t.pump();
    expect(st.textOf('Учёба/Конспект.md'), 'Сегодня разбирали [[Запекание нормалей|запекание нормалей]].');
    expect(find.text('УПОМЯНУТО БЕЗ ССЫЛКИ · 1'), findsNothing);
    expect(find.text('ССЫЛАЮТСЯ СЮДА · 2'), findsWidgets);

    await t.tap(find.text('ЗАКРЫТЬ ✕'));
    await t.pump();
    expect(find.text('СВЯЗИ'), findsNothing);
    await t.pump(const Duration(milliseconds: 20)); // таймер автосохранения (сама запись проверена в тесте состояния)
  });

  testWidgets('граф знаний: фильтры, счётчики, «Ещё не созданные», выбор и перелёт к ×3', (t) async {
    await t.runAsync(() => st.open(vault.path, watch: false));
    st.openNote('3D/Техники/Запекание нормалей.md');
    await pump(t);
    await t.tap(find.text('Граф'));
    await t.pumpAndSettle();
    expect(find.text('02 · ГРАФ ЗНАНИЙ'), findsOneWidget);
    expect(find.text('ФИЛЬТРЫ'), findsOneWidget);
    expect(find.text('3 ЗАМЕТКИ · 2 СВЯЗИ · ВЫБРАНО: 2 СОСЕДА'), findsOneWidget);
    expect(find.text('ЗАПЕКАНИЕ НОРМАЛЕЙ'), findsOneWidget); // карточка выбранной

    await t.tap(find.text('Ещё не созданные'));
    await t.pumpAndSettle();
    expect(find.textContaining('· 3 СВЯЗИ'), findsOneWidget);

    // Скрыть группу «3D» — в графе ничего не остаётся.
    await t.tap(find.text('3D'));
    await t.pumpAndSettle();
    expect(find.textContaining('0 ЗАМЕТОК'), findsOneWidget);
    await t.tap(find.text('3D'));
    await t.pumpAndSettle();

    for (var i = 0; i < 4; i++) {
      await t.tap(find.byTooltip('Ближе'));
      await t.pumpAndSettle();
    }
    expect(find.text('МАСШТАБ ×3'), findsOneWidget); // точки раскрылись в ноды с проводами
    await t.tap(find.byTooltip('Весь граф'));
    await t.pumpAndSettle();
    expect(find.text('МАСШТАБ ×1'), findsOneWidget);
    await t.tap(find.text('Открыть'));
    await t.pumpAndSettle();
    expect(st.view, 'note');
    expect(find.text('02 · ГРАФ ЗНАНИЙ'), findsNothing);
  });

  testWidgets('поиск Ctrl K: заметки с подсветкой, задачи, «Новая заметка», стрелки и Enter', (t) async {
    await t.runAsync(() => st.open(vault.path, watch: false));
    SearchPick? got;
    t.view.physicalSize = const Size(1400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      theme: spTheme(),
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async => got = await showNotesSearch(ctx, st, tasks: const [(title: 'Перепечь щит с новым кейджем', list: '3D-ассеты')]),
          child: const Text('открыть'),
        ),
      ),
    ));
    await t.tap(find.text('открыть'));
    await t.pumpAndSettle();
    expect(find.text('ПОИСК · CTRL K'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'щит');
    await t.pump();
    expect(find.text('ЗАМЕТКИ · 1'), findsOneWidget);
    expect(find.text('ЗАДАЧИ · 1'), findsOneWidget);
    expect(find.text('2 НАЙДЕНО'), findsOneWidget);
    expect(find.text('Новая заметка «щит»'), findsNothing); // «Щит» уже есть
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(got, isA<PickTask>());

    await t.tap(find.text('открыть'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Кейджи');
    await t.pump();
    expect(find.text('Новая заметка «Кейджи»'), findsOneWidget);
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect((got as PickNew).title, 'Кейджи');
  });

  testWidgets('папка: список, таблица по свойствам с условием, карточки', (t) async {
    await t.runAsync(() => st.open(vault.path, watch: false));
    await pump(t);
    await t.tap(find.text('3D'));
    await t.pump();
    expect(find.text('3 ЗАМЕТКИ'), findsOneWidget);
    expect(find.text('СПИСОК'), findsOneWidget);

    await t.tap(find.text('ТАБЛИЦА'));
    await t.pump();
    expect(find.text('ТАБЛИЦА ПО СВОЙСТВАМ'), findsOneWidget);
    expect(find.text('TYPE'), findsOneWidget);
    expect(find.text('Техника'), findsOneWidget);
    expect(st.folderMode('3D'), 'table');

    await t.tap(find.text('＋ УСЛОВИЕ'));
    await t.pumpAndSettle();
    await t.tap(find.text('Техника').last);
    await t.pumpAndSettle();
    expect(find.text('TYPE: ТЕХНИКА'), findsOneWidget);
    expect(find.text('1 ЗАМЕТКА'), findsOneWidget);
    expect(find.textContaining('с этими свойствами'), findsOneWidget);

    await t.tap(find.text('КАРТОЧКИ'));
    await t.pump();
    expect(find.text('#baking'), findsOneWidget);
    await t.tap(find.text('×'));
    await t.pump();
    expect(find.text('3 ЗАМЕТКИ'), findsOneWidget);

    await t.tap(find.text('← К заметке'));
    await t.pump();
    expect(st.view, 'note');
  });

  testWidgets('холст: в дереве, открывается, нода выделяется и удаляется Delete', (t) async {
    put('3D/Доска идей.canvas', '{"nodes":[{"id":"n1","type":"text","text":"Идея щита","x":0,"y":0,"width":250,"height":90},'
        '{"id":"n2","type":"file","file":"3D/Щит.md","x":400,"y":0,"width":260,"height":140}],'
        '"edges":[{"id":"e1","fromNode":"n1","toNode":"n2","label":"ведёт"}]}');
    await t.runAsync(() => st.open(vault.path, watch: false));
    await pump(t);
    await t.tap(find.byIcon(Icons.keyboard_arrow_right).first); // раскрыть «3D»
    await t.pump();
    expect(find.text('Доска идей'), findsOneWidget);
    await t.runAsync(() => st.canvas('3D/Доска идей.canvas')); // чтение файла — вне поддельного времени
    await t.tap(find.text('Доска идей'));
    await t.pump();
    await t.pump();
    expect(find.text('ХОЛСТ'), findsOneWidget);
    expect(find.text('Идея щита'), findsOneWidget);
    expect(find.text('ВЕДЁТ'), findsOneWidget);

    await t.tap(find.text('Идея щита'));
    await t.pump(const Duration(milliseconds: 400));
    await t.sendKeyEvent(LogicalKeyboardKey.delete);
    await t.pump();
    expect(find.text('Идея щита'), findsNothing);
    expect(find.text('ВЕДЁТ'), findsNothing); // провод ушёл вместе с нодой
    expect(st.canvases['3D/Доска идей.canvas']!.nodes.map((n) => n.id), ['n2']);

    // Ctrl+Z возвращает ноду вместе с проводом.
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await t.pump();
    expect(find.text('Идея щита'), findsOneWidget);
    expect(find.text('ВЕДЁТ'), findsOneWidget);
    expect(st.canvases['3D/Доска идей.canvas']!.nodes.map((n) => n.id), ['n1', 'n2']);

    // Ctrl+A и Delete — всё выделенное уходит.
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyA);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.delete);
    await t.pump();
    expect(st.canvases['3D/Доска идей.canvas']!.nodes, isEmpty);
    await t.pump(const Duration(milliseconds: 20)); // таймер сохранения холста (запись проверена в тесте состояния)
  });

  testWidgets('чек-лист → в задачи: пункт меню, выбор списка, отправка', (t) async {
    put('3D/Щит.md', 'Пёк по [[Запекание нормалей]].\n- [ ] Перепечь щит\n- [x] Развёртка\n');
    await t.runAsync(() => st.open(vault.path, watch: false));
    final got = <String>[];
    st.tasks = TaskSink(lists: () => {'L1': 'Работа', 'L2': '3D-ассеты'}, create: (l, title, n) async {
      got.add('$l:$title');
      return 'x';
    });
    st.openNote('3D/Щит.md');
    await pump(t);
    await t.tap(find.byTooltip('Ещё'));
    await t.pumpAndSettle();
    await t.tap(find.text('Чек-лист → в задачи · 1'));
    await t.pumpAndSettle();
    expect(find.text('Перепечь щит'), findsWidgets);
    expect(find.text('Развёртка'), findsNothing);
    await t.tap(find.text('3D-ассеты'));
    await t.pump();
    await t.tap(find.text('В задачи · 1'));
    await t.pumpAndSettle();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await t.pump();
    expect(got, ['L2:Перепечь щит']);
    expect(st.todosOf('3D/Щит.md').single.sent, isTrue);
  });

  testWidgets('папка пропала — понятное состояние', (t) async {
    await t.runAsync(() => st.open('${tmp.path}/нет-такой', watch: false));
    await pump(t);
    expect(find.text('Не вижу папку «нет-такой»'), findsOneWidget);
    expect(find.text('Найти заново…'), findsOneWidget);
  });
}
