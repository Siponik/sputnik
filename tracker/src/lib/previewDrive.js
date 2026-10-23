// Картинка задачи на Google Drive: уменьшить, загрузить в папку «Спутник», скачать, удалить (логика — lib/preview.js).
// Двоичные данные идут через Rust-команды gapi_upload / gapi_bytes (обычный gapi понимает только JSON).
import { invoke } from '@tauri-apps/api/core';
import { gapi } from './api.js';
import { ensureFolder } from './reminders.js';
import { THUMB, FULL, fitSize, dataUrlParts, fileName } from './preview.js';

const DRIVE = 'https://www.googleapis.com/drive/v3';
const UPLOAD = 'https://www.googleapis.com/upload/drive/v3';

/** Картинка (File/Blob) → { url: data URL JPEG, w, h }, вписанная в max×max. Прозрачное — на тёмном фоне. */
async function shrink(blob, max, quality) {
  const bmp = await createImageBitmap(blob);
  try {
    const { w, h } = fitSize(bmp.width, bmp.height, max);
    const c = document.createElement('canvas');
    c.width = w; c.height = h;
    const g = c.getContext('2d');
    g.fillStyle = '#1C1A19';
    g.fillRect(0, 0, w, h);
    g.imageSmoothingQuality = 'high';
    g.drawImage(bmp, 0, 0, w, h);
    return { url: c.toDataURL('image/jpeg', quality), w: bmp.width, h: bmp.height };
  } finally { bmp.close?.(); }
}

const cache = new Map(); // id файла → data URL большой копии

/** Сделать картинку задачи: маленькая — в слой, большая — на Drive. Возвращает запись для tasks[id].preview. */
export async function make(blob, title) {
  const [thumb, full] = await Promise.all([shrink(blob, THUMB, 0.78), shrink(blob, FULL, 0.88)]);
  const parent = await ensureFolder();
  const f = await gapi('POST', `${DRIVE}/files?fields=id`, { name: fileName(title), parents: [parent], mimeType: 'image/jpeg', appProperties: { sputnik: 'preview' } });
  const { mime, b64 } = dataUrlParts(full.url);
  await invoke('gapi_upload', { method: 'PATCH', url: `${UPLOAD}/files/${f.id}?uploadType=media`, mime, data: b64 });
  cache.set(f.id, full.url);
  return { thumb: thumb.url, file: f.id, w: full.w, h: full.h, at: Date.now() };
}

/** Большая копия с Drive (data URL); нет доступа или файла — null, тогда показываем маленькую. */
export async function load(file) {
  if (!file) return null;
  if (cache.has(file)) return cache.get(file);
  try {
    const b64 = await invoke('gapi_bytes', { url: `${DRIVE}/files/${encodeURIComponent(file)}?alt=media` });
    if (!b64) return null;
    const url = `data:image/jpeg;base64,${b64}`;
    cache.set(file, url);
    return url;
  } catch { return null; }
}

/** Убрать файл с Drive (в корзину Drive не кладём — сразу удаляем). Ошибки не страшны. */
export async function remove(file) {
  if (!file) return;
  cache.delete(file);
  try { await gapi('DELETE', `${DRIVE}/files/${encodeURIComponent(file)}`); } catch {}
}
