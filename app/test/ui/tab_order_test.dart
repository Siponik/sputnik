import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/ui/app_shell.dart';

void main() {
  test('исходный порядок', () => expect(tabOrder(null), [0, 1, 2, 3, 5]));
  test('без «Знаний»', () => expect(tabOrder(null, notes: false), [0, 1, 2, 3]));
  test('сохранённый, мусор выброшен, недостающие в конец', () {
    final st = {
      'tabs': {
        'v': [3, 9, 0, 3],
      },
    };
    expect(tabOrder(st), [3, 0, 1, 2, 5]);
  });
}
