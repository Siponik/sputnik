import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/notes/canvas.dart';

void main() {
  const file = '''
{
	"nodes":[
		{"id":"g1","type":"group","x":-50,"y":-50,"width":700,"height":400,"label":"Вельск"},
		{"id":"a","type":"file","file":"DND/Город Вельск.md","x":0,"y":0,"width":250,"height":120,"color":"2"},
		{"id":"b","type":"text","text":"Игроки ещё не знают","x":300,"y":0,"width":250,"height":60,"myPlugin":{"keep":true}},
		{"id":"c","type":"file","file":"Вложения/карта.png","x":900,"y":0,"width":300,"height":200},
		{"broken":true}
	],
	"edges":[
		{"id":"e1","fromNode":"a","fromSide":"right","toNode":"b","toSide":"left","label":"тайна"},
		{"id":"e2","fromNode":"a","toNode":"c"}
	],
	"version":"x"
}''';

  test('разбор: ноды, провода, битые записи пропускаются, неизвестные поля сохраняются', () {
    final d = CanvasDoc.parse(file);
    expect(d.nodes.map((n) => n.id), ['g1', 'a', 'b', 'c']);
    expect(d.node('a')!.file, 'DND/Город Вельск.md');
    expect(d.node('a')!.color, '2');
    expect(d.edges.first.label, 'тайна');
    expect(d.edges.first.fromSide, CanvasSide.right);
    expect(d.edges[1].arrowTo, isTrue);
    final back = jsonDecode(d.encode()) as Map<String, dynamic>;
    expect(back['version'], 'x');
    expect((back['nodes'] as List)[2]['myPlugin'], {'keep': true});
    expect(CanvasDoc.parse('').nodes, isEmpty);
    expect(() => CanvasDoc.parse('[1]'), throwsFormatException);
  });

  test('добавить, соединить, удалить с проводами', () {
    final d = CanvasDoc.parse(file);
    final n = d.add('text', 10.4, 20.6, text: 'новое');
    expect(n.id.length, 16);
    expect((n.x, n.y), (10.0, 21.0));
    expect(d.connect(n.id, 'a', label: 'ведёт')!.label, 'ведёт');
    expect(d.connect('a', n.id), isNull); // уже есть в обратную сторону
    expect(d.connect('a', 'a'), isNull);
    final g = d.add('group', 0, 0, label: 'Г');
    expect(d.nodes.first, g); // группа — под остальными
    d.remove('a');
    expect(d.edges.map((e) => e.id), isEmpty);
  });

  test('что внутри группы, что под курсором, границы', () {
    final d = CanvasDoc.parse(file);
    expect(d.inside(d.node('g1')!).map((n) => n.id), ['a', 'b']);
    expect(d.hit(10, 10)!.id, 'a'); // нода выше группы
    expect(d.hit(-40, 300)!.id, 'g1');
    expect(d.hit(5000, 5000), isNull);
    expect(d.bounds(), (-50.0, -50.0, 1200.0, 350.0));
  });

  test('стороны провода: из файла или навстречу друг другу; ближайшая сторона', () {
    final d = CanvasDoc.parse(file);
    final a = d.node('a')!, c = d.node('c')!;
    expect(edgeSides(d.edges[1], a, c), (CanvasSide.right, CanvasSide.left));
    expect(edgeSides(d.edges[1], c, a), (CanvasSide.left, CanvasSide.right));
    expect(nearestSide(a, 125, -3), CanvasSide.top);
    expect(nearestSide(a, 249, 60), CanvasSide.right);
    expect(a.socket(CanvasSide.bottom), (125.0, 120.0));
  });

  test('авто-раскладка: ноды не налезают, группы стоят, шаг 10', () {
    final d = CanvasDoc([], []);
    for (var i = 0; i < 6; i++) {
      d.add('text', 0, 0, w: 200, h: 100);
    }
    d.connect(d.nodes[0].id, d.nodes[1].id);
    final g = d.add('group', -10, -10, w: 50, h: 50);
    d.autoLayout();
    expect((g.x, g.y), (-10.0, -10.0));
    final ns = d.nodes.where((n) => !n.isGroup).toList();
    for (final n in ns) {
      expect(n.x % 10, 0);
    }
    for (var i = 0; i < ns.length; i++) {
      for (var j = i + 1; j < ns.length; j++) {
        final a = ns[i], b = ns[j];
        final overlap = a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height;
        expect(overlap, isFalse, reason: '${a.id} и ${b.id} налезают');
      }
    }
  });
}
