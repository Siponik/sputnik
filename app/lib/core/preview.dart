// Порт tracker/src/lib/preview.js (без imageFrom: это разбор DataTransfer браузера, во Flutter перетаскивание своё).
// Картинка задачи: tasks[id].preview = { thumb, file, w, h, at } — thumb (data URL, до 240 px) прямо в слое,
// большая (до 1600 px) — файлом на Google Drive. Только расчёты размеров и полей.

typedef Json = Map<String, dynamic>;

const thumb = 240;
const full = 1600;
const maxBytes = 30 * 1024 * 1024;

/// Размер, вписанный в квадрат max×max с сохранением пропорций; меньше — не растягиваем.
Json fitSize(num? w, num? h, num max) {
  if (w == null || h == null || !(w > 0) || !(h > 0)) return {'w': 0, 'h': 0};
  final m = w > h ? w : h;
  final k = max / m < 1 ? max / m : 1;
  int r(num x) {
    final v = (x * k + 0.5).floor();
    return v > 1 ? v : 1;
  }

  return {'w': r(w), 'h': r(h)};
}

/// `data:<mime>;base64,<данные>` → { mime, b64 } (или null).
Json? dataUrlParts(String? url) {
  final m = RegExp(r'^data:([^;,]+);base64,(.*)$', dotAll: true).firstMatch(url ?? '');
  return m != null ? {'mime': m[1], 'b64': m[2]} : null;
}

/// Картинку ли нам дали: f — { type, size }.
bool isImage(Map? f) =>
    f != null && RegExp(r'^image\/(png|jpe?g|webp|gif|bmp|avif)$', caseSensitive: false).hasMatch(f['type'] ?? '');

/// Несут ли данные перетаскивания файл: types — типы данных перетаскивания.
bool dragHasFile(List? types) => types != null && types.contains('Files');

/// Почему картинку не взять: '' — можно.
String rejectWhy(Map? f) {
  if (f == null) return 'Это не картинка';
  if (!isImage(f)) return 'Подходят картинки PNG, JPG, WebP, GIF';
  final size = f['size'];
  if (size is num && size > maxBytes) return 'Картинка больше 30 МБ — сохрани поменьше';
  return '';
}

/// Имя файла на Drive: «Название задачи · превью.jpg», без запрещённых знаков.
String fileName(Object? title) {
  var base = (title ?? '')
      .toString()
      .replaceAll(RegExp(r'[\\/:*?"<>|\n\r\t]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (base.length > 80) base = base.substring(0, 80);
  return '${base.isEmpty ? 'Задача' : base} · превью.jpg';
}

/// Есть ли у записи слоя картинка.
bool has(Map? l) {
  final t = (l?['preview'] as Map?)?['thumb'];
  return t != null && t != '';
}
