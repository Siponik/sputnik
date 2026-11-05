import 'package:flutter/material.dart';

import 'state/app_state.dart';
import 'ui/today_page.dart';

void main() {
  final state = AppState()..load();
  runApp(MaterialApp(
    title: 'Спутник',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xFFD9774F),
      useMaterial3: true,
    ),
    home: TodayPage(state: state),
  ));
}
