import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/ui/notes/md_view.dart';
import 'package:sputnik_app/ui/theme/tokens.dart';

void main() {
  testWidgets('заметка целиком: заголовок, длинный абзац с переносом, списки, чек-лист, выноска, ссылка подписью', (t) async {
    final long = List.filled(40, 'слово').join(' ');
    const text = '---\ntype: НПС\n---\n# Вельск\n'
        'Город у реки. Тут живёт [[Мира Тёрн|трактирщица]] и **кузнец**.\n\n'
        '- первый пункт\n  - вложенный\n- [ ] нарисовать карту\n- [x] имена\n\n'
        '> [!warning] Тайна\n> Игроки ещё не знают\n\n';
    await t.pumpWidget(MaterialApp(
      theme: spTheme(),
      home: Scaffold(body: SizedBox(width: 260, child: SingleChildScrollView(child: MdView(text: '$text$long', resolve: (x) => x == 'Мира Тёрн' ? 'Мира Тёрн.md' : null)))),
    ));
    expect(find.text('Вельск'), findsOneWidget);
    expect(find.textContaining('трактирщица', findRichText: true), findsOneWidget);
    expect(find.textContaining('Мира Тёрн', findRichText: true), findsNothing);
    expect(find.textContaining('type:', findRichText: true), findsNothing);
    expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
    expect(find.byIcon(Icons.check_box), findsOneWidget);
    expect(find.text('Тайна'), findsOneWidget);
    // Длинный абзац переносится, а не обрезается в одну строку.
    final p = t.renderObject<RenderParagraph>(find.textContaining('слово слово', findRichText: true).first);
    expect(p.size.height, greaterThan(60));
    expect(p.didExceedMaxLines, isFalse);
  });
}
