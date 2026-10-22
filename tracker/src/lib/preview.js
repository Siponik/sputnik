// Картинка задачи (превью рендера ассета, скрин, референс) — чистая логика, без Google (тест — tests/preview.test.js).
// Маленькая копия живёт прямо в слое: tasks[id].preview = { thumb, file, w, h, at } — thumb (data URL, до 240 px)
// видна сразу и на всех компьютерах; большая (до 1600 px) — файлом в папке «Спутник» на Google Drive (file — id файла).
// Загрузка и скачивание — lib/previewDrive.js, вид — lib/PreviewBox.svelte.

export const THUMB = 240; // сторона маленькой копии в слое, px
export const FULL = 1600; // сторона большой копии на Drive, px
export const MAX_BYTES = 30 * 1024 * 1024; // больше — не берём (это уже не картинка-превью)

/** Размер, вписанный в квадрат max×max с сохранением пропорций; меньше — не растягиваем. */
export function fitSize(w, h, max) {
  if (!(w > 0) || !(h > 0)) return { w: 0, h: 0 };
  const k = Math.min(1, max / Math.max(w, h));
  return { w: Math.max(1, Math.round(w * k)), h: Math.max(1, Math.round(h * k)) };
}

/** data:<mime>;base64,<данные> → { mime, b64 } (или null). */
export function dataUrlParts(url) {
  const m = /^data:([^;,]+);base64,(.*)$/s.exec(url ?? '');
  return m ? { mime: m[1], b64: m[2] } : null;
}

/** Картинку ли нам дали (файл из окна выбора, перетаскивание, буфер обмена). */
export const isImage = (f) => !!f && /^image\/(png|jpe?g|webp|gif|bmp|avif)$/i.test(f.type ?? '');

/** Первая картинка из перетаскивания или вставки (DataTransfer) — File или null. */
export function imageFrom(dt) {
  if (!dt) return null;
  for (const f of Array.from(dt.files ?? [])) if (isImage(f)) return f;
  for (const it of Array.from(dt.items ?? [])) {
    if (it.kind === 'file' && /^image\//i.test(it.type)) {
      const f = it.getAsFile?.();
      if (isImage(f)) return f;
    }
  }
  return null;
}

/** Несут ли данные перетаскивания файл (во время dragover сами файлы ещё не видны). */
export const dragHasFile = (dt) => !!dt && Array.from(dt.types ?? []).includes('Files');

/** Почему картинку не взять: '' — можно. */
export function rejectWhy(f) {
  if (!f) return 'Это не картинка';
  if (!isImage(f)) return 'Подходят картинки PNG, JPG, WebP, GIF';
  if (f.size > MAX_BYTES) return 'Картинка больше 30 МБ — сохрани поменьше';
  return '';
}

/** Имя файла на Drive: «Название задачи · превью.jpg», без запрещённых знаков. */
export function fileName(title) {
  const base = String(title ?? '').replace(/[\\/:*?"<>|\n\r\t]+/g, ' ').replace(/\s+/g, ' ').trim().slice(0, 80);
  return `${base || 'Задача'} · превью.jpg`;
}

/** Есть ли у записи слоя картинка. */
export const has = (L) => !!L?.preview?.thumb;
