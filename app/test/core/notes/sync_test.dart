import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/notes/sync.dart';

SyncSide s(String md5) => SyncSide(md5, 0);

void main() {
  test('новые файлы с каждой стороны — копируются в другую', () {
    expect(planSync({'a.md': s('1')}, {'b.md': s('2')}, {}), [
      const SyncAction(SyncOp.upload, 'a.md'),
      const SyncAction(SyncOp.download, 'b.md'),
    ]);
  });

  test('одинаковое содержимое — только запись в базу, уже в базе — ничего', () {
    expect(planSync({'a.md': s('1')}, {'a.md': s('1')}, {}), [const SyncAction(SyncOp.record, 'a.md')]);
    expect(planSync({'a.md': s('1')}, {'a.md': s('1')}, {'a.md': '1'}), isEmpty);
  });

  test('изменился один край — копируем', () {
    expect(planSync({'a.md': s('2')}, {'a.md': s('1')}, {'a.md': '1'}), [const SyncAction(SyncOp.upload, 'a.md')]);
    expect(planSync({'a.md': s('1')}, {'a.md': s('3')}, {'a.md': '1'}), [const SyncAction(SyncOp.download, 'a.md')]);
  });

  test('изменились оба по-разному — конфликт с отдельным именем для чужой копии', () {
    expect(planSync({'3D/Щит.md': s('2')}, {'3D/Щит.md': s('3')}, {'3D/Щит.md': '1'}), [
      const SyncAction(SyncOp.conflict, '3D/Щит.md', '3D/Щит (с другого компьютера).md'),
    ]);
    // Без базы и с разным содержимым — тоже конфликт (первое подключение второго компьютера).
    final p = planSync({'a.md': s('1'), 'a (с другого компьютера).md': s('9')}, {'a.md': s('2')}, {});
    expect(p, contains(const SyncAction(SyncOp.conflict, 'a.md', 'a (с другого компьютера) 2.md')));
  });

  test('удаление: не меняли на другой стороне — удаляем и там; меняли — правка главнее', () {
    expect(planSync({}, {'a.md': s('1')}, {'a.md': '1'}), [const SyncAction(SyncOp.trashRemote, 'a.md')]);
    expect(planSync({'a.md': s('1')}, {}, {'a.md': '1'}), [const SyncAction(SyncOp.trashLocal, 'a.md')]);
    expect(planSync({}, {'a.md': s('2')}, {'a.md': '1'}), [const SyncAction(SyncOp.download, 'a.md')]);
    expect(planSync({'a.md': s('2')}, {}, {'a.md': '1'}), [const SyncAction(SyncOp.upload, 'a.md')]);
    expect(planSync({}, {}, {'a.md': '1'}), [const SyncAction(SyncOp.forget, 'a.md')]);
  });

  test('порядок — по пути', () {
    final p = planSync({'b.md': s('1'), 'a.md': s('1')}, {}, {});
    expect(p.map((x) => x.path), ['a.md', 'b.md']);
  });

  test('строка состояния', () {
    expect((SyncReport()).status(), 'Знания: всё отправлено');
    expect((SyncReport()).status(pending: 3), 'Знания: отправляю 3');
    expect((SyncReport()..offline = true).status(), startsWith('Знания: нет связи'));
    expect((SyncReport()..driveFull = true).status(), startsWith('Знания: Drive полон'));
    expect((SyncReport()..conflicts.addAll(['a', 'b'])).status(), 'Знания: 2 конфликта — обе копии сохранены');
    expect((SyncReport()..conflicts.addAll(List.filled(5, 'x'))).status(), 'Знания: 5 конфликтов — обе копии сохранены');
  });

  test('parentFolders', () {
    expect(parentFolders('3D/Техники/Щит.md'), ['3D', '3D/Техники']);
    expect(parentFolders('Щит.md'), isEmpty);
  });
}
