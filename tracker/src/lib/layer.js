// Синхронизация слоя Спутника между компьютерами.
// Слой (статусы на доске, типы, время задач, привычки, сферы, настройки…) лежит локально в layer.json,
// а копия — в скрытой папке приложения на Google Drive (appDataFolder): её видит только Спутник, место почти не занимает.
// Каждая запись раздела несёт t — время изменения (ставит touch в App). При слиянии по каждой записи
// побеждают поля более свежей (см. combine). Удалённая запись — «надгробие» { gone: true, t }, чтобы другой компьютер не вернул её.
import { gapi } from './api.js';

const DRIVE = 'https://www.googleapis.com/drive/v3';
const UPLOAD = 'https://www.googleapis.com/upload/drive/v3';
export const FILE_NAME = 'sputnik-layer.json';
export const SECTIONS = ['tasks', 'lists', 'habits', 'log', 'cals', 'settings', 'templates', 'templatesEdit', 'spheres'];

export function emptyLayer() {
  return { version: 1, ...Object.fromEntries(SECTIONS.map((s) => [s, {}])) };
}

const isObj = (v) => v && typeof v === 'object' && !Array.isArray(v);
const tOf = (rec) => (isObj(rec) && Number.isFinite(rec.t) ? rec.t : 0);
// Разделы — известные и любые новые от более свежей версии трекера на другом компьютере.
const sectionsOf = (a, b) => [...new Set([...SECTIONS, ...Object.keys(a ?? {}), ...Object.keys(b ?? {})])]
  .filter((s) => isObj(a?.[s]) || isObj(b?.[s]));

/** Сливает локальный слой с копией из облака (remote может быть null).
 *  localChanged — в локальный пришло что-то новое, remoteChanged — облачную копию надо перезаписать. */
export function merge(local, remote) {
  const merged = { ...emptyLayer(), ...(isObj(remote) ? remote : {}), ...(isObj(local) ? local : {}) };
  let localChanged = false, remoteChanged = !isObj(remote);
  for (const s of sectionsOf(local, remote)) {
    const L = isObj(local?.[s]) ? local[s] : {}, R = isObj(remote?.[s]) ? remote[s] : {};
    const out = {};
    for (const k of new Set([...Object.keys(L), ...Object.keys(R)])) {
      const l = L[k], r = R[k];
      const m = r === undefined ? l : l === undefined ? r : same(l, r) ? l : combine(l, r);
      if (l === undefined || !same(m, l)) localChanged = true;
      if (r === undefined || !same(m, r)) remoteChanged = true;
      out[k] = m;
    }
    merged[s] = out;
  }
  return { merged, localChanged, remoteChanged };
}

// Две версии одной записи: поля более свежей главнее, а поля, которых в ней нет, берём из старой.
// Трекер пишет записи только через touch (новое поверх старого), поэтому «поля нет» значит «этот компьютер
// о нём не знал», а не «удалили»: так второй компьютер, дописавший к задаче одно поле, не сотрёт остальные.
// Надгробие { gone } заменяет запись целиком.
function combine(l, r) {
  const [n, o] = newer(r, l) ? [r, l] : [l, r];
  return isObj(n) && isObj(o) && !n.gone ? { ...o, ...n } : n;
}

// Свежее по t; при равном t (старые записи без t) — одинаково на всех компьютерах, иначе они перетягивали бы запись друг у друга.
const newer = (a, b) => tOf(a) !== tOf(b) ? tOf(a) > tOf(b) : JSON.stringify(a) > JSON.stringify(b);

/** Одинаковы ли записи (порядок ключей не важен). */
export function same(a, b) {
  if (a === b) return true;
  if (typeof a !== typeof b || a === null || b === null || typeof a !== 'object') return false;
  if (Array.isArray(a) !== Array.isArray(b)) return false;
  const ka = Object.keys(a), kb = Object.keys(b);
  return ka.length === kb.length && ka.every((k) => Object.prototype.hasOwnProperty.call(b, k) && same(a[k], b[k]));
}

/** Не хватает права на appDataFolder — значит, вход был до появления синхронизации, нужно войти заново. */
export const needsLogin = (e) => /insufficient|scope|403/i.test(String(e));

// ---------- файл в appDataFolder ----------

let fileId = null;
/** Забыть найденный файл (выход из Google, другой аккаунт). */
export function reset() { fileId = null; }

async function findFile() {
  if (fileId) return fileId;
  const q = encodeURIComponent(`name='${FILE_NAME}' and trashed=false`);
  const r = await gapi('GET', `${DRIVE}/files?spaces=appDataFolder&q=${q}&fields=files(id,modifiedTime)&orderBy=modifiedTime desc&pageSize=10`);
  fileId = r?.files?.[0]?.id ?? null;
  return fileId;
}

/** Копия слоя из облака или null, если её ещё нет. */
export async function pull() {
  const id = await findFile();
  if (!id) return null;
  try {
    return await gapi('GET', `${DRIVE}/files/${id}?alt=media`);
  } catch (e) {
    if (/404/.test(String(e))) { fileId = null; return null; } // файл удалили — создадим заново
    throw e;
  }
}

/** Записывает слой в облако (создаёт файл при первой записи). */
export async function push(data) {
  let id = await findFile();
  if (!id) {
    const f = await gapi('POST', `${DRIVE}/files?fields=id`, { name: FILE_NAME, parents: ['appDataFolder'], mimeType: 'application/json' });
    id = fileId = f.id;
  }
  await gapi('PATCH', `${UPLOAD}/files/${id}?uploadType=media`, data);
}
