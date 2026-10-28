// Слой Спутника — то, чего нет в Google (статусы на доске, типы, привычки, настройки…).
// Хранится локально (layer.json через Tauri) и сливается между компьютерами через Drive appDataFolder (lib/layer.js).
// Стор держит сам слой и состояние синхронизации; App только зовёт touch/save и читает layer.data.
import * as api from '../lib/api.js';
import * as layerSync from '../lib/layer.js';
import { say } from './toast.svelte.js';

/** data — слой; cloud.state: idle | busy | ok | login (нет права — войти заново) | err. */
export const layer = $state({ data: layerSync.emptyLayer(), cloud: { state: 'idle', at: null, err: '' } });

// Что App подставляет при запуске: можно ли сейчас ходить в облако и что сделать после каждой записи.
let hooks = { canSync: () => true, afterSave: () => {} };
export function configure(h) { hooks = { ...hooks, ...h }; }

const hideCalendars = () => api.setHiddenCalendars(Object.keys(layer.data.cals ?? {}).filter((id) => layer.data.cals[id]?.hidden));

/** Прочитать слой с диска (при запуске). */
export async function load() {
  layer.data = { ...layerSync.emptyLayer(), ...(await api.layer.read().catch(() => ({}))) };
  hideCalendars();
}

/** Каждая запись слоя несёт t — время изменения, по нему слой потом сливается между компьютерами. */
export function touch(section, key, patch) {
  const lay = layer.data;
  lay[section] ??= {};
  lay[section][key] = { ...(lay[section][key] ?? {}), ...patch, t: Date.now() };
}

let cloudTimer;
/** Записать слой на диск; через 4 с — слить с копией на Drive. */
export async function save() {
  try { await api.layer.write($state.snapshot(layer.data)); } catch (e) { say('Не удалось сохранить: ' + e); }
  clearTimeout(cloudTimer);
  cloudTimer = setTimeout(sync, 4000);
  hooks.afterSave();
}

// Сливаем при каждой синхронизации с Google (раз в 2 мин и по фокусу) и через 4 с после изменения.
let running = null, again = false;
export async function sync() {
  if (!hooks.canSync() || layer.cloud.state === 'login') return;
  if (running) { again = true; return running; }
  running = (async () => {
    layer.cloud.state = 'busy';
    try {
      const remote = await layerSync.pull();
      // Сливаем с тем, что на экране сейчас: правки, сделанные, пока шёл запрос, не теряются.
      const { merged, localChanged, remoteChanged } = layerSync.merge($state.snapshot(layer.data), remote);
      if (localChanged) {
        layer.data = merged;
        hideCalendars();
        await api.layer.write(merged).catch((e) => say('Не удалось сохранить: ' + e));
      }
      if (remoteChanged) await layerSync.push(merged);
      layer.cloud = { state: 'ok', at: new Date(), err: '' };
    } catch (e) {
      if (layerSync.needsLogin(e)) {
        layer.cloud = { state: 'login', at: null, err: String(e) };
        say('Чтобы доска, привычки и настройки совпадали на всех компьютерах, войди в Google заново: «Состояние» в шапке → «Войти».');
      } else layer.cloud = { ...layer.cloud, state: 'err', err: String(e) };
    } finally {
      running = null;
      if (again) { again = false; setTimeout(sync, 0); }
    }
  })();
  return running;
}

/** Вход с новым правом drive.appdata (кто входил до синхронизации). */
export async function cloudLogin() {
  try {
    await api.auth.login();
    layer.cloud = { state: 'idle', at: null, err: '' };
    await sync();
    if (layer.cloud.state === 'ok') say('Готово: слой Спутника теперь общий для всех компьютеров.');
  } catch (e) { say('Не удалось войти: ' + e); }
}

/** Выход из Google: облачная копия забывается. */
export function reset() {
  layerSync.reset();
  layer.cloud = { state: 'idle', at: null, err: '' };
}
