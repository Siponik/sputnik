// Золотые тесты разбора «когда»: ответы взяты у настоящего tracker/src/lib/when.js (tools/golden/gen.mjs).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/when.dart';

List<dynamic> _load(String name) => jsonDecode(File('test/golden/$name').readAsStringSync()) as List<dynamic>;
DateTime _today(List<dynamic> t) => DateTime(t[0] as int, t[1] as int, t[2] as int, 9);

void main() {
  group('parseWhen', () {
    for (final c in _load('when_parse.json')) {
      final today = _today(c['today'] as List<dynamic>);
      test('${c['today']} «${c['text']}»', () {
        final got = parseWhen(c['text'] as String, today);
        final want = c['out'] as Map<String, dynamic>;
        expect(got.day, want['day']);
        expect(got.time, want['time']);
        expect(got.allDay, want['allDay']);
        expect(got.rest, want['rest']);
      });
    }
  });

  group('whenText', () {
    for (final c in _load('when_text.json')) {
      final today = _today(c['today'] as List<dynamic>);
      test('${c['today']} ${c['day']} ${c['slot']}', () {
        final slot = c['slot'] as Map<String, dynamic>?;
        final got = whenText(
          c['day'] as String,
          slot == null ? null : (s: slot['s'] as String, e: slot['e'] as String),
          today,
        );
        final want = c['out'] as Map<String, dynamic>;
        expect(got.date, want['date']);
        expect(got.time, want['time']);
      });
    }
  });
}
