// Порт tracker/src/lib/dropdown.js — логика выпадающего списка (поиск, клавиши, подпись, место меню).
typedef Json = Map<String, dynamic>;

String _norm(Object? s) => (s ?? '').toString().toLowerCase().replaceAll('ё', 'е');

List<Json> filterOpts(List<Json> opts, String q) {
  final words = _norm(q).trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return opts;
  return opts.where((o) {
    final t = _norm(o['label']);
    return words.every(t.contains);
  }).toList();
}

/// Куски названия для подсветки первого вхождения: [{ t, hit }].
List<Json> marks(Object? label, String q) {
  final s = (label ?? '').toString();
  final k = _norm(q).trim();
  final i = k.isNotEmpty ? _norm(s).indexOf(k) : -1;
  if (i < 0) {
    return [
      {'t': s, 'hit': false},
    ];
  }
  return [
    {'t': s.substring(0, i), 'hit': false},
    {'t': s.substring(i, i + k.length), 'hit': true},
    {'t': s.substring(i + k.length), 'hit': false},
  ].where((p) => (p['t'] as String).isNotEmpty).toList();
}

bool _usable(Json? o) => o != null && (o['disabled'] == null || o['disabled'] == false);

int moveActive(List<Json> opts, int cur, String key) {
  final n = opts.length;
  if (!opts.any(_usable)) return -1;
  if (key == 'Home') return opts.indexWhere(_usable);
  if (key == 'End') return opts.lastIndexWhere(_usable);
  final step = key == 'ArrowUp' ? -1 : 1;
  var i = cur < 0 ? (step > 0 ? -1 : n) : cur;
  for (var k = 0; k < n; k++) {
    i = (i + step + n) % n;
    if (_usable(opts[i])) return i;
  }
  return cur;
}

int jumpTo(List<Json> opts, int cur, String ch) {
  final c = _norm(ch);
  if (c.trim().isEmpty) return cur;
  final n = opts.length;
  for (var k = 1; k <= n; k++) {
    final i = ((cur < -1 ? -1 : cur) + k + n) % n;
    if (_usable(opts[i]) && _norm(opts[i]['label']).startsWith(c)) return i;
  }
  return cur;
}

List<Object?> toggleIn(List<Object?>? values, Object? id, [List<Json> opts = const []]) {
  final set = <Object?>{...?values};
  if (!set.remove(id)) set.add(id);
  final order = opts.map((o) => o['id']).toList();
  final out = set.toList();
  final idx = {for (var i = 0; i < out.length; i++) out[i]: i};
  out.sort((a, b) {
    final d = order.indexOf(a) - order.indexOf(b);
    return d != 0 ? d : idx[a]! - idx[b]!;
  });
  return out;
}

String buttonText(List<Json> opts, Object? value, [bool multi = false]) {
  if (!multi) {
    for (final o in opts) {
      if (o['id'] == value) return (o['label'] ?? '') as String;
    }
    return '';
  }
  final vs = (value as List?) ?? const [];
  final on = opts.where((o) => vs.contains(o['id'])).map((o) => (o['short'] ?? o['label']) as String).toList();
  if (on.length <= 2) return on.join(', ');
  return '${on.take(2).join(', ')}, +${on.length - 2}';
}

/// Место меню: под кнопкой или над ней. btn — {left, top, right, bottom, width}, view — {w, h}.
Json placeMenu(Json btn, num h, num w, Json view, {num gap = 6, num max = 320, num pad = 8}) {
  num mn(num a, num b) => a < b ? a : b;
  num mx(num a, num b) => a > b ? a : b;
  final bw = btn['width'] as num, vw = view['w'] as num, vh = view['h'] as num;
  final width = mn(mn(mx(w, bw), mx(max, bw)), vw - pad * 2);
  final below = vh - pad - ((btn['bottom'] as num) + gap);
  final above = (btn['top'] as num) - gap - pad;
  final up = h > below && above > below;
  final left = mx(pad, mn(btn['left'] as num, vw - pad - width));
  final room = mx(0, up ? above : below);
  return up
      ? {'left': left, 'top': null, 'bottom': vh - ((btn['top'] as num) - gap), 'width': width, 'up': up, 'maxH': room}
      : {'left': left, 'top': (btn['bottom'] as num) + gap, 'bottom': null, 'width': width, 'up': up, 'maxH': room};
}
