import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'dart:io';

import 'data/notes/drive_store.dart';
import 'data/paths.dart';
import 'state/app_state.dart';
import 'state/notes_state.dart';
import 'state/updater.dart';
import 'ui/app_shell.dart';
import 'ui/theme/tokens.dart';

void main() {
  final state = AppState()..start();
  // «Знания»: настройки и база синхронизации — в своей подпапке, общая копия — «Спутник / Знания» на Drive.
  final drive = DriveStore(state.api.auth);
  final notes = NotesState(DirNotesFiles(ownFile('notes.json').parent), remote: () => drive)
    ..tasks = TaskSink(
      lists: () => {for (final l in state.boardLists) l['id'] as String: (l['title'] ?? '') as String},
      create: (list, title, n) async => state.addTask(list, title, notes: n)['id'] as String,
    )
    ..load();
  state.notes = notes;
  if (Platform.isWindows) updater.start();
  runApp(SpRoot(state: state, notes: notes));
}

/// Корень: тема и акцент из Настройки → Вид (`settings.theme`, `settings.accent`). Смена — перестройка всего окна.
class SpRoot extends StatelessWidget {
  const SpRoot({super.key, required this.state, required this.notes});
  final AppState state;
  final NotesState notes;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) {
      final st = (state.layer['settings'] as Map?) ?? const {};
      final theme = ((st['theme'] as Map?)?['v'] ?? 'dark') as String;
      final accent = ((st['accent'] as Map?)?['v'] ?? 'orange') as String;
      SpColors.apply(theme: theme, accentId: accent);
      return MaterialApp(
        key: ValueKey('$theme/$accent'),
        title: 'Спутник',
        debugShowCheckedModeBanner: false,
        theme: spTheme(),
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: AppShell(state: state, notes: notes, initialTab: lastTab),
      );
    },
  );
}
