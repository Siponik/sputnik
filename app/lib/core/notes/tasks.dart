// Заметки и задачи (docs/knowledge.md, шаг 13): пункты чек-листа `- [ ]` → задачи Спутника и
// заметки «про» задачу — для блока «Заметки» в окне задачи. Файл заметки при этом не меняется:
// что уже отправлено, помнит настройка раздела. Без Flutter — проверяется тестом.
import 'index.dart';
import 'parse.dart';

/// Ключ отправленного пункта: заметка + текст пункта.
String todoKey(String path, String text) => '$path|${text.trim()}';

/// Пункт чек-листа, который можно отправить в задачи.
class Todo {
  final int line;
  final String text;
  final bool sent;
  const Todo(this.line, this.text, {this.sent = false});
  @override
  String toString() => '$line:$text${sent ? ' ✓' : ''}';
}

/// Неотмеченные пункты заметки (пустые пропускаются). [sent] — уже отправленные ключи.
List<Todo> openTodos(NoteDoc doc, Set<String> sent) => [
      for (final t in doc.tasks)
        if (!t.done && t.text.trim().isNotEmpty) Todo(t.line, _plain(t.text), sent: sent.contains(todoKey(doc.path, _plain(t.text)))),
    ];

/// Текст пункта без разметки ссылок: `[[A|подпись]]` → «подпись», `[[A]]` → «A».
String _plain(String s) =>
    s.replaceAllMapped(RegExp(r'!?\[\[([^\]|]*)(?:\|([^\]]*))?\]\]'), (m) => (m[2] ?? m[1]!).split('#').first).replaceAll(RegExp(r'\s+'), ' ').trim();

/// Заметка задачи: откуда она — чтобы из задачи можно было найти заметку.
String taskNotesFrom(String notePath) => 'Из заметки «${baseName(notePath)}» · $notePath';

String _fold(String s) => s.toLowerCase().replaceAll('ё', 'е');

/// Заметки про задачу [title]: где название задачи стоит целиком (без регистра, ё = е), ссылка на
/// заметку с таким названием или пункт чек-листа с этим текстом. Сначала — где совпадение в названии.
List<String> notesAbout(NoteIndex ix, String title, {int limit = 5}) {
  final q = _fold(title.trim());
  if (q.length < 2) return const [];
  final word = RegExp('(^|[^\\p{L}\\p{N}])${RegExp.escape(q)}(\$|[^\\p{L}\\p{N}])', unicode: true);
  final byName = <String>[], byText = <String>[];
  for (final p in ix.paths) {
    final d = ix.doc(p)!;
    if (_fold(d.title) == q || _fold(baseName(p)) == q) {
      byName.add(p);
    } else if (d.links.any((l) => _fold(l.target) == q) || word.hasMatch(_fold(ix.text(p) ?? ''))) {
      byText.add(p);
    }
  }
  int cmp(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());
  return [...byName..sort(cmp), ...byText..sort(cmp)].take(limit).toList();
}

/// Путь заметки из описания задачи, отправленной из чек-листа (`taskNotesFrom`), или null.
String? noteFromTaskNotes(String notes) {
  final m = RegExp(r'Из заметки «[^»]*» · (\S[^\n]*?\.md)\s*$', multiLine: true).firstMatch(notes);
  return m?[1];
}

/// Заметки для блока «Заметки» в окне задачи: сначала та, из которой задача пришла, потом найденные про неё.
List<String> notesForTask(NoteIndex ix, String title, String notes, {int limit = 5}) {
  final from = noteFromTaskNotes(notes);
  return [
    if (from != null && ix.doc(from) != null) from,
    ...notesAbout(ix, title, limit: limit).where((p) => p != from),
  ].take(limit).toList();
}
