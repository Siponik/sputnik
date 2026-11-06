import 'dart:ui';

import '../theme/tokens.dart';

/// Цвет папки верхнего уровня (как сферы): по порядку названий папок, заметки в корне — серые.
Color folderHue(String path, Iterable<String> all) {
  if (!path.contains('/')) return SpColors.grey;
  final top = path.substring(0, path.indexOf('/'));
  final tops = {for (final p in all) if (p.contains('/')) p.substring(0, p.indexOf('/'))}.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  final i = tops.indexOf(top);
  return SpColors.hues[(i < 0 ? 0 : i) % SpColors.hues.length];
}
