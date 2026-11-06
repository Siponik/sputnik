import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/preview.dart' as p;

import '../golden_util.dart';

void main() {
  for (final (i, x) in golden('preview.json').indexed) {
    test('preview ${x['fn']} #$i', () {
      final Object got = switch (x['fn']) {
        'fitSize' => p.fitSize(x['w'], x['h'], x['m']),
        'dataUrlParts' => p.dataUrlParts(x['u']) ?? 'null',
        'isImage' => p.isImage(x['f']),
        'rejectWhy' => p.rejectWhy(x['f']),
        'dragHasFile' => p.dragHasFile(x['t']),
        'fileName' => p.fileName(x['t']),
        'has' => p.has(x['L']),
        'consts' => [p.thumb, p.full, p.maxBytes],
        _ => throw 'нет ${x['fn']}',
      };
      expect(js(got == 'null' ? null : got), js(x['out']));
    });
  }
}
