// Общее для золотых тестов: чтение файла и сравнение ответов как JSON (целые double → int, как в JS).
import 'dart:convert';
import 'dart:io';

List<Map<String, dynamic>> golden(String name) =>
    (jsonDecode(File('test/golden/$name').readAsStringSync()) as List).cast<Map<String, dynamic>>();

Object? canon(Object? x) {
  if (x is double && x == x.roundToDouble() && x.abs() < 1e15) return x.toInt();
  // pow в JS и Dart может разойтись в последнем знаке
  if (x is double && x.isFinite) return double.parse(x.toStringAsPrecision(12));
  // undefined в JS пропадает из JSON, а null в Dart остаётся: ключ со значением null считаем отсутствующим.
  if (x is Map) return {for (final e in x.entries) if (e.value != null) e.key.toString(): canon(e.value)};
  if (x is List) return x.map(canon).toList();
  return x;
}

String js(Object? x) => jsonEncode(canon(x));
