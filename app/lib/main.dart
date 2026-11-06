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
  runApp(
    MaterialApp(
      title: 'Спутник',
      debugShowCheckedModeBanner: false,
      theme: spTheme(),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: AppShell(state: state, notes: notes),
    ),
  );
}
