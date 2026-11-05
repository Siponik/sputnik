// Золотые тесты слияния слоя: ответы взяты у настоящего tracker/src/lib/layer.js (tools/golden/gen.mjs).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/layer.dart';

void main() {
  final cases = jsonDecode(File('test/golden/layer_merge.json').readAsStringSync()) as List<dynamic>;
  for (var i = 0; i < cases.length; i++) {
    final c = cases[i] as Map<String, dynamic>;
    test('merge #$i', () {
      final got = merge(c['local'], c['remote']);
      final want = c['out'] as Map<String, dynamic>;
      expect(got.localChanged, want['localChanged']);
      expect(got.remoteChanged, want['remoteChanged']);
      expect(sameJson(got.merged, want['merged']), isTrue, reason: 'merged:\n${jsonEncode(got.merged)}\nожидали:\n${jsonEncode(want['merged'])}');
    });
  }
}
