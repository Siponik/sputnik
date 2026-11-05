import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/notes/force.dart';

List<ForceNode> pts(int n) => [for (var i = 0; i < n; i++) ForceNode('n$i')];

double dist(ForceNode a, ForceNode b) => math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

/// Два «облака» по [n] точек: внутри каждого кольцо со связями, между облаками связей нет.
(ForceSim, int) twoClusters(int n, {ForceParams params = const ForceParams()}) {
  final ns = pts(2 * n);
  final ls = <ForceLink>[];
  for (var c = 0; c < 2; c++) {
    for (var i = 0; i < n; i++) {
      ls.add(ForceLink(c * n + i, c * n + (i + 1) % n));
      ls.add(ForceLink(c * n + i, c * n + (i + 3) % n));
    }
  }
  return (ForceSim(ns, ls, params: params), n);
}

void main() {
  test('Lcg совпадает с d3-force (seed 1)', () {
    final r = Lcg();
    // (1664525 * 1 + 1013904223) / 2^32
    expect(r.next(), closeTo(1015568748 / 4294967296, 1e-15));
    expect(r.next(), closeTo(((1664525 * 1015568748 + 1013904223) % 4294967296) / 4294967296, 1e-15));
  });

  test('начальная раскладка — подсолнух d3, заданные координаты не трогаются', () {
    final ns = [ForceNode('a'), ForceNode('b'), ForceNode('c', x: 5, y: 7)];
    ForceSim(ns, const []);
    expect(ns[0].x, closeTo(10 * math.sqrt(0.5), 1e-12));
    expect(ns[0].y, closeTo(0, 1e-12));
    final ang = math.pi * (3 - math.sqrt(5));
    expect(ns[1].x, closeTo(10 * math.sqrt(1.5) * math.cos(ang), 1e-12));
    expect((ns[2].x, ns[2].y), (5.0, 7.0));
  });

  test('остывает примерно за 300 шагов, как в d3', () {
    final (s, _) = twoClusters(10);
    final k = s.run();
    expect(k, inInclusiveRange(299, 301));
    expect(s.settled, isTrue);
  });

  test('одни и те же данные — одна и та же раскладка', () {
    final (a, _) = twoClusters(15);
    final (b, _) = twoClusters(15);
    a.run();
    b.run();
    for (var i = 0; i < a.nodes.length; i++) {
      expect(a.nodes[i].x, b.nodes[i].x);
      expect(a.nodes[i].y, b.nodes[i].y);
    }
  });

  test('связанные точки ближе друг к другу, облака расходятся', () {
    final (s, n) = twoClusters(12);
    s.run();
    double meanIn(int c) {
      var sum = 0.0, k = 0;
      for (var i = 0; i < n; i++) {
        for (var j = i + 1; j < n; j++) {
          sum += dist(s.nodes[c * n + i], s.nodes[c * n + j]);
          k++;
        }
      }
      return sum / k;
    }

    var across = 0.0;
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        across += dist(s.nodes[i], s.nodes[n + j]);
      }
    }
    across /= n * n;
    expect(across, greaterThan(meanIn(0) * 1.3));
    expect(across, greaterThan(meanIn(1) * 1.3));
  });

  test('пружина тянет к длине связи', () {
    final ns = [ForceNode('a', x: 0, y: 0), ForceNode('b', x: 200, y: 0)];
    final s = ForceSim(ns, const [ForceLink(0, 1)], params: const ForceParams(charge: 0, gravity: 0, linkDistance: 40));
    s.run();
    expect(dist(ns[0], ns[1]), closeTo(40, 2));
  });

  test('закреплённая точка стоит на месте, остальные считаются', () {
    final (s, _) = twoClusters(8);
    s.nodes[0]
      ..fx = 100
      ..fy = -50;
    s.run();
    expect(s.nodes[0].x, 100);
    expect(s.nodes[0].y, -50);
    expect(s.nodes.every((n) => n.x.isFinite && n.y.isFinite), isTrue);
  });

  test('точки в одном месте не ломают расчёт и расходятся', () {
    final ns = [for (var i = 0; i < 6; i++) ForceNode('p$i', x: 3, y: 3)];
    final s = ForceSim(ns, const [ForceLink(0, 1)]);
    s.run();
    expect(ns.every((n) => n.x.isFinite && n.y.isFinite), isTrue);
    expect(dist(ns[2], ns[3]), greaterThan(1));
  });

  test('Барнс — Хат близок к точному расчёту', () {
    List<ForceNode> scatter() {
      final r = Lcg(7);
      return [for (var i = 0; i < 300; i++) ForceNode('r$i', x: r.next() * 600, y: r.next() * 600)];
    }

    final approx = scatter(), exact = scatter();
    ForceSim(approx, const [], params: const ForceParams(gravity: 0)).tick();
    ForceSim(exact, const [], params: const ForceParams(gravity: 0, theta: 0)).tick();
    var err = 0.0, mag = 0.0;
    for (var i = 0; i < approx.length; i++) {
      err += (approx[i].vx - exact[i].vx).abs() + (approx[i].vy - exact[i].vy).abs();
      mag += exact[i].vx.abs() + exact[i].vy.abs();
    }
    expect(err / mag, lessThan(0.08));
  });

  test('collide раздвигает точки на сумму радиусов', () {
    final ns = [for (var i = 0; i < 20; i++) ForceNode('c$i', r: 10)];
    final s = ForceSim(ns, const [], params: const ForceParams(charge: 0, gravity: 0.2, collide: 1));
    s.run();
    var minD = double.infinity;
    for (var i = 0; i < ns.length; i++) {
      for (var j = i + 1; j < ns.length; j++) {
        minD = math.min(minD, dist(ns[i], ns[j]));
      }
    }
    expect(minD, greaterThan(17));
  });

  test('2000 точек и 4000 связей укладываются быстро', () {
    final r = Lcg(3);
    final ns = pts(2000);
    final ls = [for (var i = 0; i < 4000; i++) ForceLink((r.next() * 2000).floor(), (r.next() * 2000).floor())];
    final s = ForceSim(ns, ls);
    final w = Stopwatch()..start();
    s.run();
    w.stop();
    expect(ns.every((n) => n.x.isFinite && n.y.isFinite), isTrue);
    // На обычном компьютере — около секунды; запас на медленные машины CI.
    expect(w.elapsed.inSeconds, lessThan(30));
  });

  test('find и bounds', () {
    final ns = [ForceNode('a', x: 0, y: 0, r: 2), ForceNode('b', x: 10, y: 5, r: 3)];
    final s = ForceSim(ns, const []);
    expect(s.find(9, 4)!.id, 'b');
    expect(s.find(50, 50, within: 5), isNull);
    expect(s.bounds(), (-2.0, -2.0, 13.0, 8.0));
  });
}
