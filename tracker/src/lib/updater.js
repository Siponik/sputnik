// Обновление из приложения: Tauri updater смотрит latest.json в публичном Siponik/sputnik-releases
// (адрес и открытый ключ — tauri.conf.json → plugins.updater). Установщик подписан, чужой файл не встанет.
import { check } from '@tauri-apps/plugin-updater';
import { relaunch } from '@tauri-apps/plugin-process';
import { getVersion } from '@tauri-apps/api/app';

export const currentVersion = () => getVersion().catch(() => '');

/** Есть ли новая версия: { version, notes, update } или null. В режиме разработки обновлений нет. */
export async function findUpdate() {
  if (import.meta.env.DEV) return null;
  const update = await check({ timeout: 30000 });
  return update ? { version: update.version, notes: update.body ?? '', update } : null;
}

/** Скачать и поставить; onprogress(0..1). После установки приложение перезапускается. */
export async function install(found, onprogress) {
  let total = 0, got = 0;
  await found.update.downloadAndInstall((ev) => {
    if (ev.event === 'Started') total = ev.data.contentLength ?? 0;
    else if (ev.event === 'Progress') { got += ev.data.chunkLength; if (total) onprogress(Math.min(1, got / total)); }
    else if (ev.event === 'Finished') onprogress(1);
  });
  await relaunch();
}
