import 'dart:ui';

import '../theme/tokens.dart';

int _hueIndex(String path, Iterable<String> all) {
  if (!path.contains('/')) return 0;
  final top = path.substring(0, path.indexOf('/'));
  final tops = {for (final p in all) if (p.contains('/')) p.substring(0, p.indexOf('/'))}.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  final i = tops.indexOf(top);
  return (i < 0 ? 0 : i) % SpColors.hues.length;
}

/// Цвет папки верхнего уровня (как сферы): по порядку названий папок, заметки в корне — серые.
Color folderHue(String path, Iterable<String> all) => path.contains('/') ? SpColors.hues[_hueIndex(path, all)] : SpColors.grey;

/// Тёмная шапка ноды того же цвета, что [folderHue].
Color folderHead(String path, Iterable<String> all) => path.contains('/') ? SpColors.heads[_hueIndex(path, all)] : SpColors.headGrey;
