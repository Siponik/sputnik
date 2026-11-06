import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'state/app_state.dart';
import 'ui/app_shell.dart';
import 'ui/theme/tokens.dart';

void main() {
  final state = AppState()..start();
  runApp(
    MaterialApp(
      title: 'Спутник',
      debugShowCheckedModeBanner: false,
      theme: spTheme(),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: AppShell(state: state),
    ),
  );
}
