import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart';

void main() {
  for (final pose in ['hi', 'cheer', 'flag', 'think', 'sleep', 'oops', 'face']) {
    test('енот $pose разбирается', () {
      final svg = File('assets/coon/coon-$pose.svg').readAsStringSync();
      expect(() => parseWithoutOptimizers(svg), returnsNormally);
    });
  }
}
