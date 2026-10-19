// Слой Спутника — то, чего нет в Google Tasks: статусы колонок, типы, теги, привычки.
// Хранится локально и в скрытой папке приложения на Google Drive (appDataFolder),
// поэтому одинаков на всех компьютерах. Каждая запись несёт t — время изменения;
// при слиянии побеждает более свежая запись, по каждой записи отдельно.
import { gapi, layer as local } from './api.js';

const DRIVE = 'https://www.googleapis.com/drive/v3';
const UPLOAD = 'https://www.googleapis.com/upload/drive/v3';
const NAME = 'sputnik-layer.json';
export const SECTIONS = ['tasks', 'habits', 'log'];

export function normalize(d) {
  const out = { version: 2 };
  for (const s of SECTIONS) out[s] = { ...(d?.[s] ?? {}) };
  for (const s of SECTIONS) for (const k of Object.keys(out[s])) if (out[s][k] && out[s][k].t == null) out[s][k] = { ...out[s][k], t: 0 };
  return out;
}

/** Сливает два слоя. Возвращает результат и признак, что удалённую копию надо обновить. */
export function merge(a, b) {
  const x = normalize(a), y = normalize(b);
  const out = normalize({});
  let remoteChanged = false;
  for (const s of SECTIONS) {
    const keys = new Set([...Object.keys(x[s]), ...Object.keys(y[s])]);
    for (const k of keys) {
      const l = x[s][k], r = y[s][k];
      if (!r) { out[s][k] = l; remoteChanged = true; }
      else if (!l) out[s][k] = r;
      else if ((r.t || 0) > (l.t || 0)) out[s][k] = r;
      else { out[s][k] = l; if ((l.t || 0) > (r.t || 0)) remoteChanged = true; }
    }
  }
  return { merged: out, remoteChanged };
}

let fileId = null;

async function findFile() {
  if (fileId) return fileId;
  const q = encodeURIComponent(`name='${NAME}' and trashed=false`);
  const r = await gapi('GET', `${DRIVE}/files?spaces=appDataFolder&q=${q}&fields=files(id)&pageSize=10`);
  fileId = r?.files?.[0]?.id ?? null;
  return fileId;
}

/** Синхронизирует слой с Drive и сохраняет результат локально. */
export async function syncLayer(localData) {
  let id = await findFile();
  const remote = id ? await gapi('GET', `${DRIVE}/files/${id}?alt=media`) : null;
  const { merged, remoteChanged } = merge(localData, remote);
  if (!id) {
    const f = await gapi('POST', `${DRIVE}/files?fields=id`, { name: NAME, parents: ['appDataFolder'], mimeType: 'application/json' });
    id = fileId = f.id;
    await gapi('PATCH', `${UPLOAD}/files/${id}?uploadType=media`, merged);
  } else if (remoteChanged) {
    await gapi('PATCH', `${UPLOAD}/files/${id}?uploadType=media`, merged);
  }
  await local.write(merged);
  return merged;
}

export const TYPES = [
  { id: 'plain', name: 'Обычная', chip: '' },
  { id: 'work', name: 'Работа', chip: 'sp-chip-work' },
  { id: 'asset', name: 'Ассет', chip: 'sp-chip-creative' },
  { id: 'meeting', name: 'Встреча', chip: 'sp-chip-work' },
  { id: 'study', name: 'Учёба', chip: 'sp-chip-study' },
  { id: 'personal', name: 'Личное', chip: 'sp-chip-personal' },
];
export const typeOf = (id) => TYPES.find((t) => t.id === id) ?? TYPES[0];
export const PIPELINE = ['Референсы', 'Блокаут', 'Скульпт', 'Ретопология', 'UV', 'Текстуры', 'Рендер'];
export const PRIORITIES = [
  { id: '', name: 'Обычный' },
  { id: 'high', name: 'Высокий' },
  { id: 'low', name: 'Низкий' },
];
