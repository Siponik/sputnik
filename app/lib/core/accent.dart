// Порт tracker/src/lib/accent.js — акцентный цвет (settings.accent.v = id набора или «#RRGGBB»).
import 'dart:math' as math;

typedef Json = Map<String, dynamic>;

const accents = <Json>[
  {'id': 'clay', 'name': 'Глина', 'dark': '#D9774F', 'light': '#AD4F2C'},
  {'id': 'coral', 'name': 'Коралл', 'dark': '#E8766E', 'light': '#B23A33'},
  {'id': 'rose', 'name': 'Роза', 'dark': '#E07A9B', 'light': '#A83A60'},
  {'id': 'lavender', 'name': 'Лаванда', 'dark': '#A68BE8', 'light': '#5B45A8'},
  {'id': 'sky', 'name': 'Небо', 'dark': '#6E9EE8', 'light': '#2D5BA8'},
  {'id': 'mint', 'name': 'Мята', 'dark': '#5DBB98', 'light': '#1E7356'},
  {'id': 'olive', 'name': 'Олива', 'dark': '#A8B85A', 'light': '#55661A'},
];
const defaultAccent = 'clay';
const _bgDark = '#1C1B19';
const _bgLight = '#FFFFFF';

String? _hex(Object? s) {
  if (s is! String || !RegExp(r'^#?[0-9a-f]{6}$', caseSensitive: false).hasMatch(s.trim())) return null;
  return '#${s.trim().replaceFirst('#', '').toUpperCase()}';
}

List<int> _rgb(String h) => [1, 3, 5].map((i) => int.parse(h.substring(i, i + 2), radix: 16)).toList();

String _toHex(List<num> c) =>
    '#${c.map((x) => _jsRound(x.clamp(0, 255)).toRadixString(16).padLeft(2, '0')).join().toUpperCase()}';

/// Math.round из JS: .5 — вверх.
int _jsRound(num x) => (x + 0.5).floor();

/// Смесь цветов a и b: t — доля a.
String mix(String a, String b, num t) {
  final A = _rgb(a), B = _rgb(b);
  return _toHex([for (var i = 0; i < 3; i++) A[i] * t + B[i] * (1 - t)]);
}

double luminance(String h) {
  final c = _rgb(h).map((v) {
    final x = v / 255;
    return x <= 0.03928 ? x / 12.92 : math.pow((x + 0.055) / 1.055, 2.4).toDouble();
  }).toList();
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
}

double contrast(String a, String b) {
  final x = luminance(a), y = luminance(b);
  final hi = x > y ? x : y, lo = x > y ? y : x;
  return (hi + 0.05) / (lo + 0.05);
}

/// Подогнать цвет под фон до контраста ≥ min.
String fit(String c, String bg, num min) {
  final toward = luminance(bg) < 0.5 ? '#FFFFFF' : '#000000';
  var out = c;
  for (var t = 1.0; t >= 0.3 && contrast(out, bg) < min; t -= 0.05) {
    out = mix(c, toward, t);
  }
  return out;
}

Json accentOf(Object? v) {
  for (final a in accents) {
    if (a['id'] == v) return a;
  }
  final h = _hex(v);
  if (h == null) return accents[0];
  return {'id': 'custom', 'name': 'Свой', 'dark': fit(h, _bgDark, 4.5), 'light': fit(h, _bgLight, 4.5)};
}

Json vars(String c, String theme) {
  if (theme == 'light') {
    return {'clay': c, 'soft': mix(c, _bgLight, 0.1), 'on': contrast(c, '#FFFFFF') >= 3 ? '#FFFFFF' : '#1C1B19'};
  }
  return {
    'clay': c,
    'soft': mix(c, _bgDark, 0.13),
    'on': contrast(c, _bgDark) >= contrast(c, '#FFFFFF') ? _bgDark : '#FFFFFF',
  };
}

String _block(Json v) => '--clay: ${v['clay']}; --clay-soft: ${v['soft']}; --on-clay: ${v['on']};';

/// CSS из старого трекера (в Flutter цвета берутся из vars; оставлено для сверки).
String accentCss(Object? v) {
  final a = accentOf(v);
  if (a['id'] == defaultAccent) return '';
  final d = _block(vars(a['dark'] as String, 'dark')), l = _block(vars(a['light'] as String, 'light'));
  return ':root:root { $d }\n'
      '@media (prefers-color-scheme: light) { :root:root:not([data-theme="dark"]) { $l } }\n'
      ':root:root[data-theme="light"] { $l }\n';
}
