import 'package:flutter/material.dart';

import 'data/notes/drive_store.dart';
import 'data/paths.dart';
import 'state/app_state.dart';
import 'state/notes_state.dart';
import 'ui/shell.dart';
import 'ui/theme/tokens.dart';

void main() {
  final state = AppState()..load();
  // «Знания»: настройки и база синхронизации — в своей подпапке flutter/, общая копия — «Спутник / Знания» на Drive.
  final drive = DriveStore(state.api.auth);
  final notes = NotesState(DirNotesFiles(ownFile('notes.json').parent), remote: () => drive)..load();
  runApp(
    MaterialApp(
      title: 'Спутник',
      debugShowCheckedModeBanner: false,
      theme: spTheme(),
      home: Shell(app: state, notes: notes),
    ),
  );
}
